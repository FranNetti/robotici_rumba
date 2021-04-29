local commons = require('util.commons')
local Position = commons.Position
local Set = require('util.set')

local RobotAction = require('robot.commons').Action
local MoveAction = require('robot.planner.move_action')
local ExcludeOption = require('robot.planner.exclude_option')
local Planner = require('robot.planner.planner')

local controller_utils = require('robot.controller.utils')
local State = require('robot.controller.behaviour.room_coverage.state')
local CollisionAvoidanceBehaviour = require('robot.controller.behaviour.collision_avoidance')
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
            target = Position:new(21,21),
            moveExecutioner = MoveExecutioner:new(),
            oldDirection = nil,
            oldState = nil,
        }
        setmetatable(o, self)
        self.__index = self
        return o
    end,

    tick = function (self, roomState)
        if self.state == State.STAND_BY then
            return self:standByPhase(roomState)
        elseif self.state == State.EXPLORING or self.state == State.GOING_HOME then
            return self:exploringPhase(roomState)
        elseif self.state == State.TARGET_REACHED then
            return self:targetReachedPhase(roomState)
        elseif self.state == State.OBSTACLE_ENCOUNTERED then
            return self:handleObstacle(roomState)
        else
            commons.printToConsole(self.map:toString())
        end
    end,

    --[[ --------- STAND BY ---------- ]]

    standByPhase = function (self, state)
        self.target = Position:new(self.target.lat + 1, self.target.lng + 1)
        self.planner:addNewDiagonalPoint(self.target.lat)
        self.map:addNewDiagonalPoint(self.target.lat)

        local excludedOptions = Set:new{}
        if not CollisionAvoidanceBehaviour.isObjectInFrontRange(state.proximity) then
            excludedOptions = excludedOptions + Set:new{ExcludeOption.EXCLUDE_LEFT, ExcludeOption.EXCLUDE_RIGHT}
        end

        commons.print("[ROOM COVERAGE]")
        commons.print(
            "(" .. self.planner.encodeCoordinatesFromPosition(self.map.position) .. ") ["
            .. controller_utils.discreteDirection(state.robotDirection).name ..  "] - ("
            .. self.planner.encodeCoordinatesFromPosition(self.target) .. ")"
        )
        commons.print("---------------")

        self.moveExecutioner:setActions(self.planner:getActionsTo(
            self.map.position,
            self.target,
            controller_utils.discreteDirection(state.robotDirection),
            excludedOptions
        ))
        self.state = State.EXPLORING

        --commons.printToConsole(self.map:toString())
        self.moveExecutioner:resetDistanceTravelled()
        return RobotAction.stayStill({1})
    end,

    --[[ --------- EXPLORING ---------- ]]

    exploringPhase = function (self, state)
        self.oldState = self.state
        local currentAction = self.moveExecutioner.actions[1]
        
        local isObstacleEncountered, isMoveActionNotFinished, newPosition, robotAction =
            self.moveExecutioner:doNextMove(state, self.map.position)

        if isObstacleEncountered then
            self.state = State.OBSTACLE_ENCOUNTERED
            local obstaclePosition = self:determineObstaclePosition(
                state,
                controller_utils.discreteDirection(state.robotDirection),
                currentAction
            )
            self.map:setCellAsObstacle(obstaclePosition)
            self.planner:setCellAsObstacle(obstaclePosition)
            commons.print('Position (' .. self.planner.encodeCoordinatesFromPosition(obstaclePosition) .. ") detected as obstacle!")
            commons.print("----------------")
            return RobotAction:new{}
        elseif isMoveActionNotFinished then
            self.map.position = newPosition
            return robotAction
        else
            self.map.position = newPosition
            self.map:setCellAsClean(newPosition)
            self.planner:setCellAsClean(newPosition)
            self.oldDirection = controller_utils.discreteDirection(state.robotDirection)

            return self:exploringPhaseNextMove()
        end
    end,

    exploringPhaseNextMove = function (self)
        if self.moveExecutioner:hasNoMoreActions() and self.state == State.EXPLORING then
            self.state = State.TARGET_REACHED
            return RobotAction.stayStill({1})
        elseif self.moveExecutioner:hasNoMoreActions() and self.state == State.GOING_HOME then
            self.state = State.STAND_BY
            return RobotAction.stayStill({1})
        else
            local nextMove = self.moveExecutioner.actions[1]
            if nextMove == MoveAction.GO_AHEAD then
                return RobotAction:new({})
            elseif nextMove == MoveAction.GO_BACK then
                return RobotAction.goBack({1})
            elseif nextMove == MoveAction.TURN_LEFT then
                return RobotAction.turnLeft({1})
            elseif nextMove == MoveAction.TURN_RIGHT then
                return RobotAction.turnRight({1})
            end
        end
    end,

    --[[ ---------- TARGET REACHED --------- ]]

    targetReachedPhase = function (self, state)
        self.moveExecutioner:setActions(
            self.map:getActionsTo(self.map.position, Position:new(0,0), controller_utils.discreteDirection(state.robotDirection))
        )
        self.state = State.GOING_HOME
        self.moveExecutioner:resetDistanceTravelled()
        return RobotAction.stayStill({1})
    end,

    --[[ --------- HANDLE OBSTACLE ---------- ]]

    determineObstaclePosition = function (self, state, currentDirection, currentAction)

        local isObstacleToTheLeft = CollisionAvoidanceBehaviour.isObjectInLeftRange(state.proximity)
        local isObstacleToTheRight = CollisionAvoidanceBehaviour.isObjectInRightRange(state.proximity)

        if currentAction == MoveAction.GO_AHEAD or currentAction == MoveAction.GO_BACK then
            return MoveAction.nextPosition(
                self.map.position,
                currentDirection,
                currentAction
            )
        elseif (currentAction == MoveAction.TURN_LEFT and isObstacleToTheLeft)
           or (currentAction == MoveAction.TURN_RIGHT and isObstacleToTheRight)
           or self.oldDirection ~= currentDirection then
           return MoveAction.nextPosition(
                self.map.position,
                self.oldDirection,
                currentAction
            )
        elseif (currentAction == MoveAction.TURN_LEFT and isObstacleToTheRight)
          or (currentAction == MoveAction.TURN_RIGHT and isObstacleToTheLeft)
          or currentDirection == self.oldDirection then
            return self.map.position
        end
    end,

    handleObstacle = function (self, state)

        local isMoveActionNotFinished, robotAction = self.moveExecutioner:getAwayFromObstacle(state)

        if isMoveActionNotFinished then
            return robotAction
        else
            if self.oldState == State.EXPLORING then
                self.moveExecutioner:setActions(
                    self.planner:getActionsTo(
                        self.map.position,
                        self.target,
                        controller_utils.discreteDirection(state.robotDirection)
                    )
                )

                if self.moveExecutioner:hasMoreActions() then
                    self.map:addNewDiagonalPoint(self.target.lat + 1)
                    self.planner:addNewDiagonalPoint(self.target.lat + 1)
                    self.state = State.EXPLORING
                    return RobotAction.stayStill({1})
                else
                    commons.print('Position (' .. self.planner.encodeCoordinatesFromPosition(self.target) .. ") is unreachable!")
                    commons.print("----------------")
                    self.map:setCellAsObstacle(self.target)
                    self.planner:setCellAsObstacle(self.target)
                    self.state = State.TARGET_REACHED
                    return RobotAction.stayStill({1})
                end
            elseif self.oldState == State.GOING_HOME then
                self.state = State.TARGET_REACHED
                return RobotAction.stayStill({1})
            end
        end
    end,

}

return RoomCoverage