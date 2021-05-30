local commons = require('util.commons')
local cell_status = require("robot.controller.map.cell_status")
local Position = commons.Position

local logger = require('util.logger')
local LogLevel = logger.LogLevel

local RobotAction = require('robot.commons').Action
local MoveAction = require('robot.controller.planner.move_action')
local Planner = require('robot.controller.planner.planner')
local Subsumption = require('robot.controller.subsumption')

local controller_utils = require('robot.controller.utils')
local State = require('robot.controller.behaviour.room_coverage.state')
local MoveExecutioner = require('robot.controller.move_executioner')

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
            moveExecutioner = MoveExecutioner:new(map),
            oldState = nil,
            lastKnownPosition = nil,
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
        elseif self.state == State.RECOVERY then
            return self:recovery(roomState)
        else
            logger.printToConsole('[ROOM_COVERAGE] Unknown state: ' .. self.state, LogLevel.WARNING)
            logger.printTo('[ROOM_COVERAGE] Unknown state: ' .. self.state, LogLevel.WARNING)
        end
    end,

    --[[ --------- STAND BY ---------- ]]

    standBy = function (self, state)

        if self.map.position ~= Position:new(0,0) then
            self.state = State.RECOVERY
            self.oldState = State.GOING_HOME
            return RobotAction.stayStill({}, { Subsumption.subsumeAll })
        end


        self.target = Position:new(self.target.lat + 1, self.target.lng + 1)
        self.planner:addNewDiagonalPoint(self.target.lat)
        self.map:addNewDiagonalPoint(self.target.lat)

        local currentDirection = controller_utils.discreteDirection(state.robotDirection)

        logger.print("[ROOM COVERAGE]")
        logger.print(
            "Currently in " .. self.map.position:toString() .. " ["
            .. currentDirection.name ..  "] - Target is "
            .. self.target:toString()
        )
        logger.print("---------------")

        local excludedOptions = controller_utils.getExcludedOptionsByState(state)

        local actions = self.planner:getActionsTo(
            self.map.position,
            self.target,
            currentDirection,
            excludedOptions
        )

        self.lastKnownPosition = self.map.position

        if actions ~= nil and #actions > 0 then
            self.moveExecutioner:setActions(actions)
            self.state = State.EXPLORING
        else
            self.planner:addNewDiagonalPoint(self.target.lat + 1)
            self.map:addNewDiagonalPoint(self.target.lat + 1)
            actions = self.planner:getActionsTo(
                self.map.position,
                self.target,
                currentDirection,
                excludedOptions
            )
            if actions ~= nil and #actions > 0 then
                self.moveExecutioner:setActions(actions)
                self.state = State.EXPLORING
            else
                logger.print("[ROOM COVERAGE]")
                logger.print('Cell not reachable! Perimeter fully identified', LogLevel.INFO)
                self.state = State.PERIMETER_IDENTIFIED
                self.map.isPerimeterIdentified = true
                self.target = Position:new(0,0)
            end
        end

        logger.printToConsole(self.map:toString())
        return RobotAction.stayStill({}, { Subsumption.subsumeAll })
    end,

    --[[ --------- EXPLORING ---------- ]]

    followPlan = function (self, state)
        self.oldState = self.state

        --[[
            If the robot finds itself in a position different from the one it knows
            then some upper level might have blocked this one. It's important to update
            then its knowledge with the last updates.
        ]]
        if self.lastKnownPosition ~= self.map.position then
            self.state = State.RECOVERY
            return RobotAction.stayStill({}, { Subsumption.subsumeAll })
        end

        local result = self.moveExecutioner:doNextMove(state)
        self.lastKnownPosition = result.position
        self.map.position = result.position

        if result.isObstacleEncountered then
            self.state = State.OBSTACLE_ENCOUNTERED

            logger.print("[ROOM COVERAGE]")
            logger.print("Currently in " .. self.map.position:toString(), LogLevel.INFO)
            logger.print(result.obstaclePosition:toString() .. " detected as obstacle!", LogLevel.WARNING)
            logger.print("----------------", LogLevel.WARNING)

            self.map:setCellAsObstacle(result.obstaclePosition)
            self.planner:setCellAsObstacle(result.obstaclePosition)
            return RobotAction:new({})
        elseif result.isMoveActionFinished then
            self.map:setCellAsClean(result.position)
            self.planner:setCellAsClean(result.position)
            return self:followPlanNextMove()
        else
            return result.action
        end
    end,

    followPlanNextMove = function (self)
        if self.moveExecutioner:hasMoreActions() then
            local nextMove = self.moveExecutioner.actions[1]
            if nextMove == MoveAction.GO_AHEAD then
                return RobotAction:new({})
            elseif nextMove == MoveAction.GO_BACK or nextMove == MoveAction.GO_BACK_BEFORE_TURNING then
                return RobotAction.goBack({}, {1})
            elseif nextMove == MoveAction.TURN_LEFT then
                return RobotAction.turnLeft({}, {1})
            elseif nextMove == MoveAction.TURN_RIGHT then
                return RobotAction.turnRight({}, {1})
            end
        elseif self.state == State.EXPLORING then
            self.state = State.TARGET_REACHED
        elseif self.state == State.GOING_HOME and not self.map.isPerimeterIdentified then
            self.state = State.STAND_BY
        elseif self.state == State.GOING_HOME then
            self.state = State.EXPLORED
        end
        return RobotAction.stayStill({}, { Subsumption.subsumeAll })
    end,

    --[[ ---------- TARGET REACHED --------- ]]

    targetReached = function (self, state)
        if self.map.isPerimeterIdentified then
            self.state = State.PERIMETER_IDENTIFIED
        elseif self.map.position == Position:new(0,0) then
            self.state = State.STAND_BY
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
        return RobotAction.stayStill({}, { Subsumption.subsumeAll })
    end,

    --[[ --------- HANDLE OBSTACLE ---------- ]]

    handleObstacle = function (self, state)

        local result = nil
        if self.lastKnownPosition ~= self.map.position then
            result = { isMoveActionFinished = true }
        else
            result = self.moveExecutioner:getAwayFromObstacle(state)
            self.lastKnownPosition = result.position
            self.map.position = result.position
        end

        if result.isMoveActionFinished then
            if self.oldState == State.EXPLORING then
                self.planner:addNewDiagonalPoint(self.target.lat + 1)
                self.map:addNewDiagonalPoint(self.target.lat + 1)
                local actions = self.planner:getActionsTo(
                    self.map.position,
                    self.target,
                    controller_utils.discreteDirection(state.robotDirection),
                    controller_utils.getExcludedOptionsByState(state)
                )

                if actions ~= nil and #actions > 0 then
                    self.moveExecutioner:setActions(actions)
                    self.state = State.EXPLORING
                elseif self.map.position == self.target then
                    self.state = State.TARGET_REACHED
                else
                    logger.print("[ROOM COVERAGE]")
                    logger.print(
                        self.target:toString() .. " is unreachable from "
                        .. self.map.position:toString() .. "!",
                        LogLevel.WARNING
                    )
                    logger.print("----------------", LogLevel.INFO)
                    if self.map.isPerimeterIdentified then
                        self.state = State.PERIMETER_IDENTIFIED
                    else
                        self.state = State.TARGET_REACHED
                    end
                end
            elseif self.oldState == State.GOING_HOME then
                if self.map.position == Position:new(0,0) then
                    self.state = State.STAND_BY
                else
                    self.state = State.TARGET_REACHED
                end
            end
            return RobotAction.stayStill({}, { Subsumption.subsumeAll })
        else
            return result.action
        end
    end,

    --[[ --------- PERIMETER IDENTIFIED ---------- ]]

    perimeterIdentified = function (self, state)
        local map = self.map.map
        local excludeOptions = controller_utils.getExcludedOptionsByState(state)
        local currentDirection = controller_utils.discreteDirection(state.robotDirection)
        for i = self.target.lat, #map do
            for j = self.target.lng , #map[i] do
                local cell = Position:new(i,j)
                if map[i][j] == cell_status.TO_EXPLORE then
                    local actions = self.planner:getActionsTo(
                        self.map.position,
                        cell,
                        currentDirection,
                        excludeOptions
                    )
                    if actions ~= nil and #actions > 0 then
                        self.moveExecutioner:setActions(actions)
                        self.state = State.EXPLORING
                        self.target = cell
                        return RobotAction.stayStill({}, { Subsumption.subsumeAll })
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
        return RobotAction.stayStill({}, { Subsumption.subsumeAll })
    end,

    --[[ --------- RECOVERY ---------- ]]

    recovery = function (self, state)

        --[[
            reset the planner because something in the map could have
            changed and the planner must be in sync with that
        ]]
        self.planner = Planner:new(self.map.map)

        if self.oldState == State.EXPLORING and self.map.position == self.target then
            self.state = State.TARGET_REACHED
        elseif self.oldState == State.GOING_HOME and self.map.position == Position:new(0,0) then
            self.state = State.STAND_BY
        else
            self.state = self.oldState
            local excludedOptions = controller_utils.getExcludedOptionsByState(state)
            local target = nil

            if self.state == State.EXPLORING then
                target = self.target
            else
                target = Position:new(0,0)
            end

            local actions = self.planner:getActionsTo(
                self.map.position,
                target,
                controller_utils.discreteDirection(state.robotDirection),
                excludedOptions
            )

            if actions ~= nil and #actions > 0 then
                self.moveExecutioner:setActions(actions)
            else
                self.planner:addNewDiagonalPoint(self.target.lat + 1)
                self.map:addNewDiagonalPoint(self.target.lat + 1)
                actions = self.planner:getActionsTo(
                    self.map.position,
                    target,
                    controller_utils.discreteDirection(state.robotDirection),
                    excludedOptions
                )
                if actions ~= nil and #actions > 0 then
                    self.moveExecutioner:setActions(actions)
                else
                    logger.print("[ROOM COVERAGE]")
                    logger.print(
                        self.target:toString() .. " is unreachable from "
                        .. self.map.position:toString() .. " after being subsumpted!",
                        LogLevel.WARNING
                    )
                    logger.print("----------------", LogLevel.INFO)
                    self.state = State.TARGET_REACHED
                end
            end
        end

        self.lastKnownPosition = self.map.position
        return RobotAction.stayStill({}, { Subsumption.subsumeAll })
    end,

    --[[ --------- EXPLORED ---------- ]]

    explored = function (self)
        logger.printToConsole(self.map:toString())
        logger.printToConsole('-------------------------------')

        if self.map.position ~= Position:new(0,0) then
            self.state = State.PERIMETER_IDENTIFIED
        end
        return RobotAction.stayStill({}, { Subsumption.subsumeAll })
    end,
}

return RoomCoverage