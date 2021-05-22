local Color = require('util.commons').Color
local Position = require('util.commons').Position
local Direction = require('util.commons').Direction
local logger = require('util.logger')
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

local function getFirstDirtyCell(map)
    local length = #map
    for i = 0, length do
        local rowLength = #map[i]
        for j = 0, rowLength do
            if map[i][j] == CellStatus.DIRTY then
                return Position:new(i, j)
            end
        end
    end
    return nil
end

local function detectDirtyPositions(state, map, lastKnownPosition, oldDirection)
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
        return { lastKnownPosition }
    elseif isTurningLeft then
        return { MoveAction.nextPosition(lastKnownPosition, oldDirection, MoveAction.TURN_LEFT) }
    elseif isTurningRight then
        return { MoveAction.nextPosition(lastKnownPosition, oldDirection, MoveAction.TURN_RIGHT) }
    elseif speed > 0 and distanceTravelled > 0 then
            return { MoveAction.nextPosition(lastKnownPosition, currentDirection, MoveAction.GO_AHEAD) }
    elseif speed < 0 and distanceTravelled < 0 then
        return { MoveAction.nextPosition(lastKnownPosition, currentDirection, MoveAction.GO_BACK) }
    elseif speed == 0 and distanceTravelled > 0 then
        return {
            MoveAction.nextPosition(lastKnownPosition, currentDirection, MoveAction.GO_AHEAD),
            lastKnownPosition
        }
    elseif speed == 0 and distanceTravelled < 0 then
        return {
            MoveAction.nextPosition(lastKnownPosition, currentDirection, MoveAction.GO_BACK),
            lastKnownPosition
        }
    end
    return { lastKnownPosition }
end

local function getExcludedOptionsByState(state)
    local excludedOptions = Set:new{}
    if not CollisionAvoidanceBehaviour.isObjectInFrontRange(state.proximity) then
        excludedOptions = Set:new{ExcludeOption.EXCLUDE_LEFT, ExcludeOption.EXCLUDE_RIGHT, ExcludeOption.EXCLUDE_BACK}
    end
    return excludedOptions
end

RoomCleaner = {

    new = function (self, map)
        local o = {
            state = State.WORKING,
            map = map,
            moveExecutioner = MoveExecutioner:new(map),
            planner = nil,
            lastKnownPosition = map.position,
            oldDirection = Direction.NORTH
        }
        setmetatable(o, self)
        self.__index = self
        return o
    end,

    tick = function (self, state)
        if state.isDirtDetected then
            local dirtPositions = detectDirtyPositions(
                state,
                self.map,
                self.lastKnownPosition,
                self.oldDirection
            )
            for i = 1, #dirtPositions do
                self.planner:setCellAsDirty(dirtPositions[i])
                self.map:setCellAsDirty(dirtPositions[i])
            end
            return RobotAction:new({
                hasToClean = true,
                leds = { switchedOn = true, color = Color.WHITE },
                speed = { left = 0, right = 0}
            }, {1, 3})
        elseif isRobotNearLastKnownPosition(self.lastKnownPosition, self.map.position) then
            if self.state == State.WORKING then
                return self:working(state)
            else
                logger.print('[ROOM_CLEANER] Unhandled state', logger.LogLevel.WARNING)
            end
        else
            local dirtPosition = getFirstDirtyCell(self.map)
            if dirtPosition ~= nil then
                self.planner = Planner:new(self.map)
                self.planner:addNewDiagonalPoint(#self.map.map)
                while dirtPosition ~= nil do
                    local success = self:computeActionsToDirtState(state, dirtPosition)
                    if success then
                        return RobotAction:new({})
                    end
                    dirtPosition = getFirstDirtyCell(self.map)
                end
            end

            return self:working(state)
        end
    end,

    working = function (self)
        if self.map:getCurrentCell() == CellStatus.DIRTY then
            self.map:setCellAsClean(self.map.position)
        end
        self.lastKnownPosition = self.map.position
        return RobotAction:new({})
    end,

    computeActionsToDirtState = function (self, state, dirtPosition)
        local excludedOptions = getExcludedOptionsByState(state)
        local actions = self.planner:getActionsTo(
            self.map.position,
            dirtPosition,
            controller_utils.discreteDirection(state.robotDirection),
            excludedOptions
        )
        self.lastKnownPosition = self.map.position

        if actions ~= nil and #actions > 0 then
            self.moveExecutioner:setActions(actions)
            self.state = State.GOING_TO_DIRT
            return true
        else
            self.planner:addNewDiagonalPoint(#self.map.map)
            self.map:addNewDiagonalPoint(#self.map.map)
            actions = self.planner:getActionsTo(
                self.map.position,
                dirtPosition,
                controller_utils.discreteDirection(state.robotDirection),
                excludedOptions
            )
            if actions ~= nil and #actions > 0 then
                self.moveExecutioner:setActions(actions)
                self.state = State.GOING_TO_DIRT
                return true
            else
                -- set cell as an obstacle
                return false
            end
        end
    end

}

return RoomCleaner;