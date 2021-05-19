local commons = require('util.commons')
local cell_status = require "robot.map.cell_status"
local Position = commons.Position
local Set = require('util.set')

local logger = require('util.logger')
local LogLevel = logger.LogLevel

local RobotAction = require('robot.commons').Action
local MoveAction = require('robot.planner.move_action')
local ExcludeOption = require('robot.planner.exclude_option')
local Planner = require('robot.planner.planner')

local controller_utils = require('robot.controller.utils')
local State = require('robot.controller.behaviour.room_coverage.state')
local CollisionAvoidanceBehaviour = require('robot.controller.behaviour.collision_avoidance')
local MoveExecutioner = require('robot.controller.move_executioner')

local function getExcludedOptionsByState(state)
    local excludedOptions = Set:new{}
    if not CollisionAvoidanceBehaviour.isObjectInFrontRange(state.proximity) then
        excludedOptions = Set:new{ExcludeOption.EXCLUDE_LEFT, ExcludeOption.EXCLUDE_RIGHT, ExcludeOption.EXCLUDE_BACK}
    end
    return excludedOptions
end

RoomCoverage = {

    ---Create new room coverage behaviour
    ---@param map table Map the map of the robot
    ---@return table a new behaviour
    new = function (self, map)
        local o = {
            map = map,
            state = State.STAND_BY,
            planner = Planner:new(map.map),
            target = Position:new(0,0),
            moveExecutioner = MoveExecutioner:new(),
            oldDirection = nil,
            oldState = nil,
            isPerimeterIdentified = false,
        }
        setmetatable(o, self)
        self.__index = self
        return o
    end,

    tick = function (self, roomState)
        if self.state == State.STAND_BY then
            return self:standBy(roomState)
        elseif self.state == State.EXPLORING or self.state == State.GOING_HOME then
            return self:followPlan(roomState)
        elseif self.state == State.TARGET_REACHED then
            return self:targetReached(roomState)
        elseif self.state == State.OBSTACLE_ENCOUNTERED then
            return self:handleObstacle(roomState)
        elseif self.state == State.PERIMETER_IDENTIFIED then
            return self:perimeterIdentified(roomState)
        elseif self.state == State.EXPLORED then
            return self:explored(roomState)
        else
            logger.printToConsole('[ROOM_COVERAGE] Unknown state', LogLevel.WARNING)
            logger.printTo('[ROOM_COVERAGE] Unknown state', LogLevel.WARNING)
        end
    end,

    --[[ --------- STAND BY ---------- ]]

    standBy = function (self, state)
        self.target = Position:new(self.target.lat + 1, self.target.lng + 1)
        self.planner:addNewDiagonalPoint(self.target.lat)
        self.map:addNewDiagonalPoint(self.target.lat)

        logger.print("[ROOM COVERAGE]")
        logger.print(
            "Currently in " .. self.map.position:toString() .. " ["
            .. controller_utils.discreteDirection(state.robotDirection).name ..  "] - Target is "
            .. self.target:toString()
        )
        logger.print("---------------")

        local excludedOptions = getExcludedOptionsByState(state)

        local actions = self.planner:getActionsTo(
            Position:new(0,0),
            self.target,
            controller_utils.discreteDirection(state.robotDirection),
            excludedOptions
        )

        if actions ~= nil and #actions > 0 then
            self.moveExecutioner:setActions(actions)
            self.state = State.EXPLORING
        else
            self.planner:addNewDiagonalPoint(self.target.lat + 1)
            self.map:addNewDiagonalPoint(self.target.lat + 1)
            actions = self.planner:getActionsTo(
                Position:new(0,0),
                self.target,
                controller_utils.discreteDirection(state.robotDirection),
                excludedOptions
            )
            if actions ~= nil and #actions > 0 then
                self.moveExecutioner:setActions(actions)
                self.state = State.EXPLORING
            else
                logger.print("[ROOM COVERAGE]")
                logger.print('Cell not reachable! Perimeter fully identified', LogLevel.INFO)
                self.state = State.PERIMETER_IDENTIFIED
                self.isPerimeterIdentified = true
                self.target = Position:new(0,0)
            end
        end

        logger.printToConsole(self.map:toString())
        return RobotAction.stayStill({1})
    end,

    --[[ --------- EXPLORING ---------- ]]

    followPlan = function (self, state)
        self.oldState = self.state
        local result = self.moveExecutioner:doNextMove(state, self.map.position)

        if result.isObstacleEncountered then
            self.state = State.OBSTACLE_ENCOUNTERED
            self.map.position = result.position

            logger.print("[ROOM COVERAGE]")
            logger.print("Currently in " .. self.map.position:toString(), LogLevel.INFO)
            logger.print(result.obstaclePosition:toString() .. " detected as obstacle!", LogLevel.WARNING)
            logger.print("----------------", LogLevel.WARNING)

            self.map:setCellAsObstacle(result.obstaclePosition)
            self.planner:setCellAsObstacle(result.obstaclePosition)
            return RobotAction:new{}
        elseif result.isMoveActionFinished then
            self.map.position = result.position
            self.map:setCellAsClean(result.position)
            self.planner:setCellAsClean(result.position)
            self.oldDirection = controller_utils.discreteDirection(state.robotDirection)

            return self:followPlanNextMove()
        else
            self.map.position = result.position
            return result.action
        end
    end,

    followPlanNextMove = function (self)
        if self.moveExecutioner:hasMoreActions() then
            local nextMove = self.moveExecutioner.actions[1]
            if nextMove == MoveAction.GO_AHEAD then
                return RobotAction:new({})
            elseif nextMove == MoveAction.GO_BACK or nextMove == MoveAction.GO_BACK_BEFORE_TURNING then
                return RobotAction.goBack({1})
            elseif nextMove == MoveAction.TURN_LEFT then
                return RobotAction.turnLeft({1})
            elseif nextMove == MoveAction.TURN_RIGHT then
                return RobotAction.turnRight({1})
            end
        elseif self.state == State.EXPLORING then
            self.state = State.TARGET_REACHED
        elseif self.state == State.GOING_HOME and not self.isPerimeterIdentified then
            self.state = State.STAND_BY
        elseif self.state == State.GOING_HOME then
            self.state = State.EXPLORED
        end
        return RobotAction.stayStill({1})
    end,

    --[[ ---------- TARGET REACHED --------- ]]

    targetReached = function (self, state)
        if self.isPerimeterIdentified then
            self.state = State.PERIMETER_IDENTIFIED
        else
            self.moveExecutioner:setActions(
                self.planner:getActionsTo(
                    self.map.position,
                    Position:new(0,0),
                    controller_utils.discreteDirection(state.robotDirection)
                )
            )
            self.state = State.GOING_HOME
        end
        return RobotAction.stayStill({1})
    end,

    --[[ --------- HANDLE OBSTACLE ---------- ]]

    handleObstacle = function (self, state)
        local result = self.moveExecutioner:getAwayFromObstacle(state, self.map.position)

        if result.isMoveActionFinished then
            self.map.position = result.position
            if self.oldState == State.EXPLORING then
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
                    self.state = State.EXPLORING
                    return RobotAction.stayStill({1})
                elseif self.map.position == self.target then
                    self.state = State.TARGET_REACHED
                    return RobotAction.stayStill({1})
                else
                    logger.print("[ROOM COVERAGE]")
                    logger.print(
                        self.target:toString() .. " is unreachable from "
                        .. self.map.position:toString() .. "!",
                        LogLevel.WARNING
                    )
                    logger.print("----------------", LogLevel.INFO)
                    if self.isPerimeterIdentified then
                        self.state = State.PERIMETER_IDENTIFIED
                    else
                        self.state = State.TARGET_REACHED
                    end
                    return RobotAction.stayStill({1})
                end
            elseif self.oldState == State.GOING_HOME then
                if self.map.position == Position:new(0,0) then
                    self.state = State.STAND_BY
                else
                    self.state = State.TARGET_REACHED
                end
                return RobotAction.stayStill({1})
            end
        else
            return result.action
        end
    end,

    --[[ --------- PERIMETER IDENTIFIED ---------- ]]

    perimeterIdentified = function (self, state)
        local map = self.map.map
        local excludeOptions = getExcludedOptionsByState(state)
        for i = self.target.lat, #map do
            for j = self.target.lng , #map[i] do
                local cell = Position:new(i,j)
                if map[i][j] == cell_status.TO_EXPLORE then
                    local actions = self.planner:getActionsTo(
                        self.map.position,
                        cell,
                        controller_utils.discreteDirection(state.robotDirection),
                        excludeOptions
                    )
                    if actions ~= nil and #actions > 0 then
                        self.moveExecutioner:setActions(actions)
                        self.state = State.EXPLORING
                        self.target = cell
                        return RobotAction.stayStill({1})
                    else
                        self.planner:setCellAsObstacle(cell)
                        self.map:setCellAsObstacle(cell)
                    end
               end
            end
        end
        logger.print("[ROOM COVERAGE]")
        logger.print('Exploration complete!!!', LogLevel.INFO)
        if self.map.position == Position:new(0,0) then
            self.state = State.EXPLORED
        else
            self.moveExecutioner:setActions(
                self.planner:getActionsTo(
                    self.map.position,
                    Position:new(0,0),
                    controller_utils.discreteDirection(state.robotDirection),
                    excludeOptions
                )
            )
            self.state = State.GOING_HOME
        end
        return RobotAction.stayStill({1})
    end,

    --[[ --------- EXPLORED ---------- ]]

    explored = function (self)
        logger.printToConsole(self.map:toString())
        logger.printToConsole('-------------------------------')
        return RobotAction.stayStill({1})
    end,
}

return RoomCoverage