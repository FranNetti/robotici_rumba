local Color = require('util.commons').Color
local Position = require('util.commons').Position
local Direction = require('util.commons').Direction
local logger = require('util.logger')
local LogLevel = logger.LogLevel
local Set = require('util.set')

local RobotAction = require('robot.commons').Action
local MoveAction = require('robot.controller.planner.move_action')
local robot_parameters = require('robot.parameters')
local controller_utils = require('robot.controller.utils')
local CellStatus = require('robot.controller.map.cell_status')
local MoveExecutioner = require('robot.controller.move_executioner')
local Planner = require('robot.controller.planner.planner')
local ExcludeOption = require('robot.controller.planner.exclude_option')

local State = require('robot.controller.behaviour.room_cleaner.state')
local CollisionAvoidanceBehaviour = require('robot.controller.behaviour.collision_avoidance.collision_avoidance')

local function isRobotNearLastKnownPosition(oldPosition, newPosition)
    return oldPosition == newPosition
        or oldPosition.lat == newPosition.lat and oldPosition.lng == newPosition.lng - 1
        or oldPosition.lat == newPosition.lat and oldPosition.lng == newPosition.lng + 1
        or oldPosition.lng == newPosition.lng and oldPosition.lat == newPosition.lat - 1
        or oldPosition.lng == newPosition.lng and oldPosition.lat == newPosition.lat + 1
end

local function getFirstDirtyCell(map, dirtPositionsToSkip)
    local length = #map.map
    dirtPositionsToSkip = dirtPositionsToSkip or Set:new{}
    for i = 0, length do
        local rowLength = #map.map[i]
        for j = 0, rowLength do
            local position = Position:new(i, j)
            if map:getCell(position) == CellStatus.DIRTY and not dirtPositionsToSkip:contain(position) then
                return position
            end
        end
    end
    return nil
end

local function detectDirtyPositions(state, map, currentPositiom, oldDirection)
    local isTurningRight = state.wheels.velocity_left == robot_parameters.robotNotTurningTyreSpeed
        and state.wheels.velocity_right ~= 0
    local isTurningLeft = state.wheels.velocity_right == robot_parameters.robotNotTurningTyreSpeed
        and state.wheels.velocity_left ~= 0
    local currentDirection = controller_utils.discreteDirection(state.robotDirection)
    local speed = state.wheels.velocity_left
    if state.wheels.velocity_right > speed then
        speed = state.wheels.velocity_right
    end
    local distanceTravelled = map.verticalOffset
    if currentDirection == Direction.EAST or currentDirection == Direction.WEST then
        distanceTravelled = map.horizontalOffset
    end

    if (isTurningLeft or isTurningRight) and currentDirection == oldDirection then
        return { currentPositiom }
    elseif isTurningLeft then
        return { MoveAction.nextPosition(currentPositiom, oldDirection, MoveAction.TURN_LEFT) }
    elseif isTurningRight then
        return { MoveAction.nextPosition(currentPositiom, oldDirection, MoveAction.TURN_RIGHT) }
    elseif speed > 0 and distanceTravelled > 0 then
            return { MoveAction.nextPosition(currentPositiom, currentDirection, MoveAction.GO_AHEAD) }
    elseif speed < 0 and distanceTravelled < 0 then
        return { MoveAction.nextPosition(currentPositiom, currentDirection, MoveAction.GO_BACK) }
    elseif speed == 0 and distanceTravelled > 0 then
        return {
            MoveAction.nextPosition(currentPositiom, currentDirection, MoveAction.GO_AHEAD),
            currentPositiom
        }
    elseif speed == 0 and distanceTravelled < 0 then
        return {
            MoveAction.nextPosition(currentPositiom, currentDirection, MoveAction.GO_BACK),
            currentPositiom
        }
    end
    return { currentPositiom }
end

local function getExcludedOptionsByState(state)
    local excludedOptions = Set:new{}
    if not CollisionAvoidanceBehaviour.isObjectInFrontRange(state.proximity) then
        excludedOptions = Set:new{ExcludeOption.EXCLUDE_LEFT, ExcludeOption.EXCLUDE_RIGHT, ExcludeOption.EXCLUDE_BACK}
    end
    return excludedOptions
end

local function isRobotTurning(state)
    return state.wheels.velocity_left == robot_parameters.robotNotTurningTyreSpeed
        and state.wheels.velocity_right ~= 0
        or state.wheels.velocity_right == robot_parameters.robotNotTurningTyreSpeed
        and state.wheels.velocity_left ~= 0
end

RoomCleaner = {

    new = function (self, map)
        local o = {
            state = State.WORKING,
            map = map,
            moveExecutioner = MoveExecutioner:new(map),
            planner = nil,
            target = nil,
            lastKnownPosition = map.position,
            oldDirection = Direction.NORTH,
            checkedCellsAfterPerimeterIdentified = false,
            isCleaning = false,
        }
        setmetatable(o, self)
        self.__index = self
        return o
    end,

    tick = function (self, state)
        if state.isDirtDetected then
            return self:handleDirtyCell(state)
        else
            self.isCleaning = false
            if self.state == State.WORKING then
                return self:working(state)
            elseif self.state == State.GOING_TO_DIRT then
                return self:reachDirtPosition(state)
            elseif self.state == State.OBSTACLE_ENCOUNTERED then
                return self:handleObstacle(state)
            else
                logger.printToConsole('[ROOM_CLEANER] Unknown state: ' .. self.state, LogLevel.WARNING)
                logger.printTo('[ROOM_CLEANER] Unknown state: ' .. self.state, LogLevel.WARNING)
            end
        end
    end,

    --[[ --------- WORKING ---------- ]]

    working = function (self, state)
        if not isRobotNearLastKnownPosition(self.lastKnownPosition, self.map.position) then
            return self:handleDifferentPosition(state)
        end

        if self.map:getCurrentCell() == CellStatus.DIRTY then
            self.map:setCellAsClean(self.map.position)
        end

        if not isRobotTurning(state) then
            --[[
                update the direction only if the robot is not turning
                since in that case the direction may change in any moment
            ]]
            self.oldDirection = controller_utils.discreteDirection(state.robotDirection)
        end

        self.lastKnownPosition = self.map.position
        self.target = nil

        if self.map.isPerimeterIdentified and not self.checkedCellsAfterPerimeterIdentified then
            --[[
                when the robot has identified the room perimeter it needs to check
                whether there are some dirty cells or not and clean them
            ]]
            self.checkedCellsAfterPerimeterIdentified = true
            return self:goToFirstDirtyCell(state)
        else
            return RobotAction:new({})
        end
    end,

    --[[ --------- HANDLE DIRTY CELL ---------- ]]

    handleDirtyCell = function (self, state)
        if not self.isCleaning then

            logger.print(
                '[ROOM_CLEANER] Detected dirt in cell ' .. self.map.position:toString(),
                LogLevel.INFO
            )

            local newPosition = self.moveExecutioner:handleStopMove(state)
            if newPosition ~= self.map.position then
                self.map.position = newPosition
                self.lastKnownPosition = newPosition
                self.map:setCellAsClean(newPosition)
                self.planner:setCellAsClean(newPosition)
                self.oldDirection = controller_utils.discreteDirection(state.robotDirection)
            end

            local dirtPositions = detectDirtyPositions(
                state,
                self.map,
                self.map.position,
                self.oldDirection
            )
            for i = 1, #dirtPositions do
                if self.planner ~= nil then
                    self.planner:setCellAsDirty(dirtPositions[i])
                end
                self.map:setCellAsDirty(dirtPositions[i])
            end
            self.isCleaning = true
        end
        return RobotAction:new({
            hasToClean = true,
            leds = { switchedOn = true, color = Color.WHITE },
            speed = { left = 0, right = 0}
        }, {1, 3})
    end,

    --[[ --------- HANDLE DIFFERENT CELL ---------- ]]

    handleDifferentPosition = function (self, state)
        self.oldDirection = controller_utils.discreteDirection(state.robotDirection)
        self.checkedCellsAfterPerimeterIdentified = false
        return self:goToFirstDirtyCell(state)
    end,

    --[[ --------- GO TO FIRST DIRTY CELL ---------- ]]

    goToFirstDirtyCell = function (self, state)
        self.lastKnownPosition = self.map.position
        local dirtPosition = getFirstDirtyCell(self.map)
        if dirtPosition ~= nil then
            local currentDepth = #self.map.map
            local dirtPositionsToSkip = Set:new{}
            self.planner = Planner:new(self.map)
            self.planner:addNewDiagonalPoint(currentDepth)
            while dirtPosition ~= nil do
                local success = self:computeActionsToDirtCell(state, dirtPosition, currentDepth)
                if success then
                    self.target = dirtPosition
                    self.state = State.GOING_TO_DIRT
                    return RobotAction.stayStill({1,3})
                else
                    --[[
                        if the cell can't be currently reached it is added to this set
                        so that the while loop can end
                    ]]
                    dirtPositionsToSkip:add(dirtPosition)
                end
                dirtPosition = getFirstDirtyCell(self.map, dirtPositionsToSkip)
            end
        end

        self.state = State.WORKING
        return self:working(state)
    end,

    computeActionsToDirtCell = function (self, state, dirtPosition, currentDepth)
        local excludedOptions = getExcludedOptionsByState(state)
        local currentDirection = controller_utils.discreteDirection(state.robotDirection)
        local actions = self.planner:getActionsTo(
            self.map.position,
            dirtPosition,
            currentDirection,
            excludedOptions
        )

        if actions ~= nil and #actions > 0 then
            self.moveExecutioner:setActions(actions)
            return true
        else
            self.planner:addNewDiagonalPoint(currentDepth + 1)
            self.map:addNewDiagonalPoint(currentDepth + 1)
            actions = self.planner:getActionsTo(
                self.map.position,
                dirtPosition,
                currentDirection,
                excludedOptions
            )
            if actions ~= nil and #actions > 0 then
                self.moveExecutioner:setActions(actions)
                return true
            else
                if self.map.isPerimeterIdentified then
                    self.map:setCellAsObstacle(dirtPosition)
                end
                return false
            end
        end
    end,

    --[[ --------- REACH DIRT POSITION ---------- ]]

    reachDirtPosition = function (self, state)

        if self.lastKnownPosition ~= self.map.position then
            return self:handleDifferentPosition(state)
        end

        local result = self.moveExecutioner:doNextMove(state)
        self.lastKnownPosition = result.position
        self.map.position = result.position
        -- subsume no matter what the room coverage level
        table.insert(result.action.levelsToSubsume, 3)

        if result.isObstacleEncountered then
            self.state = State.OBSTACLE_ENCOUNTERED

            logger.print("[ROOM_CLEANER]")
            logger.print("Currently in " .. self.map.position:toString(), LogLevel.INFO)
            logger.print(result.obstaclePosition:toString() .. " detected as obstacle!", LogLevel.WARNING)
            logger.print("----------------", LogLevel.WARNING)

            self.map:setCellAsObstacle(result.obstaclePosition)
            self.planner:setCellAsObstacle(result.obstaclePosition)
            return RobotAction:new({}, {3})
        elseif result.isMoveActionFinished then
            self.map:setCellAsClean(result.position)
            self.planner:setCellAsClean(result.position)
            self.oldDirection = controller_utils.discreteDirection(state.robotDirection)
            return self:reachDirtPositionNextMove(state)
        else
            return result.action
        end
    end,

    reachDirtPositionNextMove = function (self, state)
        if self.moveExecutioner:hasMoreActions() then
            local nextMove = self.moveExecutioner.actions[1]
            if nextMove == MoveAction.GO_AHEAD then
                return RobotAction:new({}, {3})
            elseif nextMove == MoveAction.GO_BACK or nextMove == MoveAction.GO_BACK_BEFORE_TURNING then
                return RobotAction.goBack({1, 3})
            elseif nextMove == MoveAction.TURN_LEFT then
                return RobotAction.turnLeft({1, 3})
            elseif nextMove == MoveAction.TURN_RIGHT then
                return RobotAction.turnRight({1, 3})
            end
        else
            --[[
                the robot has already cleaned the current cell because the robot automatically cleans
                when in a dirty cell. Next move is to check whether other dirty cells have been discovered
                by upper levels
            ]]
            return self:goToFirstDirtyCell(state)
        end
    end,

    --[[ --------- HANDLE OBSTACLE ---------- ]]

    handleObstacle = function (self, state)

        if self.lastKnownPosition ~= self.map.position then
            return self:handleDifferentPosition(state)
        end

        local result = self.moveExecutioner:getAwayFromObstacle(state)
        self.lastKnownPosition = result.position
        self.map.position = result.position

        if result.isMoveActionFinished then
            self.planner:addNewDiagonalPoint(self.target.lat + 1)
            self.map:addNewDiagonalPoint(self.target.lat + 1)
            local actions = self.planner:getActionsTo(
                self.map.position,
                self.target,
                controller_utils.discreteDirection(state.robotDirection),
                getExcludedOptionsByState(state)
            )

            if actions ~= nil and #actions > 0 then
                self.moveExecutioner:setActions(actions)
                self.state = State.GOING_TO_DIRT
                return RobotAction.stayStill({1, 3})
            elseif self.map.position == self.target then
                return self:goToFirstDirtyCell(state)
            else
                logger.print("[ROOM_CLEANER]")
                logger.print(
                    self.target:toString() .. " is unreachable from "
                    .. self.map.position:toString() .. "!",
                    LogLevel.WARNING
                )
                logger.print("----------------", LogLevel.INFO)
                if self.map.isPerimeterIdentified then
                    self.map:setCellAsObstacle(self.target)
                end
                return self:goToFirstDirtyCell(state)
            end
        else
            -- subsume no matter what the room coverage level
            table.insert(result.action.levelsToSubsume, 3)
            return result.action
        end
    end,

}

return RoomCleaner;