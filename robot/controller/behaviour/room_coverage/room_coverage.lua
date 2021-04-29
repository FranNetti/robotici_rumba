local commons = require('util.commons')
local Position = commons.Position
local Set = require('util.set')

local robot_parameters = require('robot.parameters')
local RobotAction = require('robot.commons').Action
local MoveAction = require('robot.planner.move_action')
local ExcludeOption = require('robot.planner.exclude_option')
local Planner = require('robot.planner.planner')

local robot_utils = require('robot.controller.behaviour.utils')
local State = require('robot.controller.behaviour.room_coverage.state')
local CollisionAvoidanceBehaviour = require('robot.controller.behaviour.collision_avoidance')

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
            distanceTravelled = 0,
            oldPosition = nil,
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
            .. robot_utils.discreteDirection(state.robotDirection).name ..  "] - ("
            .. self.planner.encodeCoordinatesFromPosition(self.target) .. ")"
        )
        commons.print("---------------")

        self.planner:getActionsTo(
            self.map.position,
            self.target,
            robot_utils.discreteDirection(state.robotDirection),
            excludedOptions
        )
        self.state = State.EXPLORING

        --commons.printToConsole(self.map:toString())
        self.distanceTravelled = 0
        return RobotAction.stayStill({1})
    end,

    --[[ --------- EXPLORING ---------- ]]

    exploringPhase = function (self, state)
        self.oldState = self.state
        local currentAction = self.planner.actions[1]
        local nextAction = nil
        if #self.planner.actions >= 2 then
            nextAction = self.planner.actions[2]
        end

        local isMoveActionNotFinished, robotAction = false, nil
        if currentAction == MoveAction.GO_AHEAD then
            if CollisionAvoidanceBehaviour.isObjectInFrontRange(state.proximity) then
                self.state = State.OBSTACLE_ENCOUNTERED
            else
                isMoveActionNotFinished, robotAction = self:handleGoAheadMove(state, nextAction)
            end
        elseif currentAction == MoveAction.TURN_LEFT then
            if CollisionAvoidanceBehaviour.isObjectInLeftRange(state.proximity)
               or CollisionAvoidanceBehaviour.isObjectInRightRange(state.proximity)
               or CollisionAvoidanceBehaviour.isObjectInFrontRange(state.proximity) then
                self.state = State.OBSTACLE_ENCOUNTERED
            else
                isMoveActionNotFinished, robotAction  = self:handleTurnLeftMove(state, nextAction)
            end
        elseif currentAction == MoveAction.TURN_RIGHT then
            if CollisionAvoidanceBehaviour.isObjectInLeftRange(state.proximity)
               or CollisionAvoidanceBehaviour.isObjectInRightRange(state.proximity)
               or CollisionAvoidanceBehaviour.isObjectInFrontRange(state.proximity) then
                self.state = State.OBSTACLE_ENCOUNTERED
            else
                isMoveActionNotFinished, robotAction  = self:handleTurnRightMove(state, nextAction)
            end
        else
            if CollisionAvoidanceBehaviour.isObjectInBackRange(state.proximity) then
                self.state = State.OBSTACLE_ENCOUNTERED
            else
                isMoveActionNotFinished, robotAction  = self:handleGoBackMove(state)
            end
        end

        if self.state == State.OBSTACLE_ENCOUNTERED then
            local obstaclePosition = self:determineObstaclePosition(
                state,
                robot_utils.discreteDirection(state.robotDirection),
                currentAction
            )
            self.map:setCellAsObstacle(obstaclePosition)
            self.planner:setCellAsObstacle(obstaclePosition)
            commons.print('Position (' .. self.planner.encodeCoordinatesFromPosition(obstaclePosition) .. ") detected as obstacle!")
            commons.print("----------------")
            return RobotAction:new{}
        elseif isMoveActionNotFinished then
            return robotAction
        else
            self.map:setCellAsClean(self.map.position)
            self.planner:setCellAsClean(self.map.position)
            self.oldPosition = self.map.position
            self.oldDirection = robot_utils.discreteDirection(state.robotDirection)
            self.planner:removeFirstAction()

            return self:exploringPhaseNextMove()
        end
    end,

    handleGoAheadMove = function (self, state, nextAction)
        self.distanceTravelled = self.distanceTravelled + state.wheels.distance_left
        if (nextAction == MoveAction.TURN_LEFT or nextAction == MoveAction.TURN_RIGHT)
              and self.distanceTravelled < robot_parameters.squareSideDimension / 2 then
            return true, RobotAction:new({})
        elseif nextAction ~= MoveAction.TURN_LEFT
            and nextAction ~= MoveAction.TURN_RIGHT
            and self.distanceTravelled < robot_parameters.squareSideDimension then
            return true, RobotAction:new({})
        else
            self.distanceTravelled = self.distanceTravelled - robot_parameters.squareSideDimension
            self.map.position = MoveAction.nextPosition(self.map.position, robot_utils.discreteDirection(state.robotDirection), MoveAction.GO_AHEAD)
            return false, nil
        end
    end,

    handleTurnLeftMove = function (self, state, nextAction)
        return self:handleTurnMove(
            MoveAction.TURN_LEFT,
            state,
            state.wheels.velocity_left == robot_parameters.robotNotTurningTyreSpeed
              and state.wheels.velocity_right ~= 0,
            nextAction
        )
    end,

    handleTurnRightMove = function (self, state, nextAction)
        return self:handleTurnMove(
            MoveAction.TURN_RIGHT,
            state,
            state.wheels.velocity_right == robot_parameters.robotNotTurningTyreSpeed
              and state.wheels.velocity_left ~= 0,
            nextAction
        )
    end,

    handleTurnMove = function (self, turnDirection, state, isRobotTurning, nextAction)
        local nextDirection = MoveAction.nextDirection(self.oldDirection, turnDirection)

        if isRobotTurning and state.robotDirection.direction == nextDirection then
            if nextAction ~= MoveAction.TURN_LEFT
              and nextAction ~= MoveAction.TURN_RIGHT then
                self.distanceTravelled = robot_parameters.squareSideDimension / 2
                self.planner:changeAction(1, MoveAction.GO_AHEAD)
                return true, RobotAction:new({})
            else
                self.map.position = MoveAction.nextPosition(self.map.position, self.oldDirection, turnDirection)
                return false, nil
            end
        elseif isRobotTurning and state.robotDirection.direction ~= nextDirection then
            if turnDirection == MoveAction.TURN_LEFT then
                return true, RobotAction.turnLeft({1})
            else
                return true, RobotAction.turnRight({1})
            end
        else
            self.distanceTravelled = -robot_parameters.squareSideDimension / 2
            self.planner:addActionToHead(MoveAction.GO_BACK)
            self.map.position = MoveAction.nextPosition(self.map.position, robot_utils.discreteDirection(state.robotDirection), MoveAction.GO_AHEAD)
            return true, RobotAction.goBack({1})
        end

    end,

    handleGoBackMove = function (self, state)
        self.distanceTravelled = self.distanceTravelled + state.wheels.distance_left
        if self.distanceTravelled > -robot_parameters.squareSideDimension then
            return true, RobotAction.goBack({1})
        else
            self.distanceTravelled = self.distanceTravelled + robot_parameters.squareSideDimension
            self.map.position = MoveAction.nextPosition(self.map.position, robot_utils.discreteDirection(state.robotDirection), MoveAction.GO_BACK)
        end
        return false, nil
    end,

    exploringPhaseNextMove = function (self)
        if #self.planner.actions == 0 and self.state == State.EXPLORING then
            self.state = State.TARGET_REACHED
            return RobotAction.stayStill({1})
        elseif #self.planner.actions == 0 and self.state == State.GOING_HOME then
            self.state = State.STAND_BY
            return RobotAction.stayStill({1})
        else
            local nextMove = self.planner.actions[1]
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
        self.map:getActionsTo(self.map.position, Position:new(0,0), robot_utils.discreteDirection(state.robotDirection))
        self.state = State.GOING_HOME
        self.distanceTravelled = 0
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
        local currentAction = self.planner.actions[1]

        local isMoveActionNotFinished, robotAction = false, nil
        if currentAction == MoveAction.GO_AHEAD or currentAction == MoveAction.GO_BACK then
            isMoveActionNotFinished, robotAction = self:handleCancelStraightMove(state, currentAction)
        elseif currentAction == MoveAction.TURN_LEFT then
            isMoveActionNotFinished, robotAction  = self:handleCancelTurnLeftMove(state)
        elseif currentAction == MoveAction.TURN_RIGHT then
            isMoveActionNotFinished, robotAction  = self:handleCancelTurnRightMove(state)
        end

        if isMoveActionNotFinished then
            return robotAction
        else
            if self.oldState == State.EXPLORING then
                self.planner:getActionsTo(
                    self.map.position,
                    self.target,
                    robot_utils.discreteDirection(state.robotDirection)
                )

                if self.planner.actions ~= nil and #self.planner.actions > 0 then
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

    handleCancelStraightMove = function (self, state, move)
        self.distanceTravelled = self.distanceTravelled + state.wheels.distance_left
        if move == MoveAction.GO_AHEAD and self.distanceTravelled <= 0 then
            return false, nil
        elseif move == MoveAction.GO_BACK and self.distanceTravelled >= 0 then
            return false, nil
        elseif move == MoveAction.GO_AHEAD then
            return true, RobotAction.goBack({1, 2})
        else
            return true, RobotAction:new({}, {2})
        end
    end,

    handleCancelTurnLeftMove = function (self, state)
        return self:handleCancelTurnMove(
            MoveAction.TURN_LEFT,
            state,
            state.wheels.velocity_left == -robot_parameters.robotNotTurningTyreSpeed
              and state.wheels.velocity_right ~= 0
        )
    end,

    handleCancelTurnRightMove = function (self, state)
        return self:handleCancelTurnMove(
            MoveAction.TURN_RIGHT,
            state,
            state.wheels.velocity_right == -robot_parameters.robotNotTurningTyreSpeed
              and state.wheels.velocity_left ~= 0
        )
    end,

    handleCancelTurnMove = function (self, turnDirection, state, isRobotTurning)
        if isRobotTurning and state.robotDirection.direction == self.oldDirection then
            self.distanceTravelled = robot_parameters.squareSideDimension / 2
            self.planner:changeAction(1, MoveAction.GO_AHEAD)
            return true, RobotAction.goBack({1, 2})
        else
            if turnDirection == MoveAction.TURN_LEFT then
                return true, RobotAction:new({
                    speed = {
                        left = -robot_parameters.robotNotTurningTyreSpeed,
                        right = -robot_parameters.robotTurningSpeed
                    }
                }, {1, 2})
            else
                return true, RobotAction:new({
                    speed = {
                        left = -robot_parameters.robotTurningSpeed,
                        right = -robot_parameters.robotNotTurningTyreSpeed
                    }
                }, {1, 2})
            end
        end
    end,

}

return RoomCoverage;