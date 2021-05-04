local commons = require('util.commons')
local Direction = commons.Direction

local robot_parameters = require('robot.parameters')
local RobotAction = require('robot.commons').Action

local MoveAction = require('robot.planner.move_action')

local controller_utils = require('robot.controller.utils')
local CollisionAvoidanceBehaviour = require('robot.controller.behaviour.collision_avoidance')

local function removeFirstAction(moveExecutioner)
    if moveExecutioner.actions ~= nil and #moveExecutioner.actions >= 1 then
        table.remove(moveExecutioner.actions, 1)
    end
end

local function addActionToHead(moveExecutioner, action)
    if moveExecutioner.actions ~= nil then
        table.insert(moveExecutioner.actions, 1, action)
    else
        moveExecutioner.actions = {action}
    end
end

local function changeAction(moveExecutioner, index, action)
    if moveExecutioner.actions ~= nil and #moveExecutioner.actions >= index then
        moveExecutioner.actions[index] = action
    end
end

local function updateDistanceTravelled(moveExecutioner, currentDirection, offset)
    if currentDirection == Direction.SOUTH or currentDirection == Direction.NORTH then
        moveExecutioner.verticalDistanceTravelled = moveExecutioner.verticalDistanceTravelled + offset
    else
        moveExecutioner.horizontalDistanceTravelled = moveExecutioner.horizontalDistanceTravelled + offset
    end
end

local function setDistanceTravelled(moveExecutioner, currentDirection, value)
    if currentDirection == Direction.SOUTH or currentDirection == Direction.NORTH then
        moveExecutioner.verticalDistanceTravelled = value
    else
        moveExecutioner.horizontalDistanceTravelled = value
    end
end

local function getDistanceTravelled(moveExecutioner, currentDirection)
    if currentDirection == Direction.SOUTH or currentDirection == Direction.NORTH then
        return moveExecutioner.verticalDistanceTravelled
    else
        return moveExecutioner.horizontalDistanceTravelled
    end
end

local MoveExecutioner = {

    new = function (self)
        local o = {
            verticalDistanceTravelled = 0,
            horizontalDistanceTravelled = 0,
            oldDirection = nil,
            actions = nil,
        }
        setmetatable(o, self)
        self.__index = self
        return o
    end,

    setActions = function (self, actions)
        self.actions = actions
    end,

    hasMoreActions = function (self)
        return self.actions ~= nil and #self.actions >= 1
    end,

    hasNoMoreActions = function (self)
        return self.actions ~= nil and #self.actions <= 0
    end,

    resetDistanceTravelled = function (self)
        setDistanceTravelled(self, Direction.NORTH, 0)
        setDistanceTravelled(self, Direction.SOUTH, 0)
    end,

    ---Perform an action
    ---@param state table RobotState - the current environment state
    ---@return table {
    ---     boolean isObstacleEncountered - if there is an obstacle in the way
    ---     boolean isMoveActionNotFinished - if the robot completed an action
    ---     Position position - the current robot position
    ---     RobotAction action - the action to perform
    ---}
    doNextMove = function (self, state, currentPosition)
        if self:hasMoreActions() then
            local currentDirection = controller_utils.discreteDirection(state.robotDirection)
            local currentAction = self.actions[1]
            local nextAction = nil
            if #self.actions >= 2 then
                nextAction = self.actions[2]
            end

            local result, isObstacleEncountered = nil, false
            if currentAction == MoveAction.GO_AHEAD then
                if CollisionAvoidanceBehaviour.isObjectInFrontRange(state.proximity) then
                    isObstacleEncountered = true
                else
                    result = self:handleGoAheadMove(state, currentPosition, currentDirection, nextAction)
                end
            elseif currentAction == MoveAction.TURN_LEFT then
                if CollisionAvoidanceBehaviour.isObjectInLeftRange(state.proximity)
                or CollisionAvoidanceBehaviour.isObjectInRightRange(state.proximity)
                or CollisionAvoidanceBehaviour.isObjectInFrontRange(state.proximity) then
                    isObstacleEncountered = true
                else
                    result = self:handleTurnLeftMove(state, currentPosition, currentDirection, nextAction)
                end
            elseif currentAction == MoveAction.TURN_RIGHT then
                if CollisionAvoidanceBehaviour.isObjectInLeftRange(state.proximity)
                or CollisionAvoidanceBehaviour.isObjectInRightRange(state.proximity)
                or CollisionAvoidanceBehaviour.isObjectInFrontRange(state.proximity) then
                    isObstacleEncountered = true
                else
                    result = self:handleTurnRightMove(state, currentPosition, currentDirection, nextAction)
                end
            elseif currentAction == MoveAction.GO_BACK then
                if CollisionAvoidanceBehaviour.isObjectInBackRange(state.proximity) then
                    isObstacleEncountered = true
                else
                    result = self:handleGoBackMove(state, currentPosition, currentDirection, nextAction)
                end
            else
                if CollisionAvoidanceBehaviour.isObjectInBackRange(state.proximity) then
                    isObstacleEncountered = true
                else
                    result  = self:handleGoBackBeforeTurningMove(state, currentPosition, currentDirection)
                end
            end

            if isObstacleEncountered then
                return {
                    isObstacleEncountered = true,
                    position = currentPosition
                }
            end

            commons.print(self.verticalDistanceTravelled .. "||" .. self.horizontalDistanceTravelled)
            if not result.isMoveActionNotFinished then
                commons.print("------------")
                removeFirstAction(self)
                self.oldDirection = currentDirection
            end

            result.isObstacleEncountered = false
            return result

        end
        return {
            obstacleEncountered = false,
            isMoveActionNotFinished = true,
            position = currentPosition
        }
    end,

    handleGoAheadMove = function (self, state, currentPosition, currentDirection, nextAction)
        updateDistanceTravelled(self, currentDirection, state.wheels.distance_left)
        local distanceTravelled = getDistanceTravelled(self, currentDirection)
        if (nextAction == MoveAction.TURN_LEFT or nextAction == MoveAction.TURN_RIGHT)
          and distanceTravelled < robot_parameters.squareSideDimension / 2 then
            return {
                isMoveActionNotFinished = true,
                position = currentPosition,
                action = RobotAction:new({})
            }
        elseif nextAction ~= MoveAction.TURN_LEFT
          and nextAction ~= MoveAction.TURN_RIGHT
          and distanceTravelled < robot_parameters.squareSideDimension then
            return {
                isMoveActionNotFinished = true,
                position = currentPosition,
                action = RobotAction:new({})
            }
        end

        -- in any case the robot advanced by a cell so it's important to subtract a cell full dimension
        updateDistanceTravelled(self, currentDirection, -robot_parameters.squareSideDimension)
        return {
            isMoveActionNotFinished = false,
            position = MoveAction.nextPosition(
                currentPosition,
                currentDirection,
                MoveAction.GO_AHEAD
            )
        }
    end,

    handleTurnLeftMove = function (self, state, currentPosition, currentDirection, nextAction)
        return self:handleTurnMove(
            MoveAction.TURN_LEFT,
            state,
            currentPosition,
            currentDirection,
            state.wheels.velocity_left == robot_parameters.robotNotTurningTyreSpeed
              and state.wheels.velocity_right ~= 0,
            nextAction
        )
    end,

    handleTurnRightMove = function (self, state, currentPosition, currentDirection, nextAction)
        return self:handleTurnMove(
            MoveAction.TURN_RIGHT,
            state,
            currentPosition,
            currentDirection,
            state.wheels.velocity_right == robot_parameters.robotNotTurningTyreSpeed
              and state.wheels.velocity_left ~= 0,
            nextAction
        )
    end,

    handleTurnMove = function (self, turnDirection, state, currentPosition, currentDirection, isRobotTurning, nextAction)
        local nextDirection = MoveAction.nextDirection(self.oldDirection, turnDirection)

        if isRobotTurning and state.robotDirection.direction == nextDirection then
            updateDistanceTravelled(self, self.oldDirection, robot_parameters.squareSideDimension / 2)
            if nextAction ~= MoveAction.TURN_LEFT
              and nextAction ~= MoveAction.TURN_RIGHT then
                updateDistanceTravelled(self, nextDirection, robot_parameters.squareSideDimension / 2)
                changeAction(self, 1, MoveAction.GO_AHEAD)
                return {
                    isMoveActionNotFinished = true,
                    position = currentPosition,
                    action = RobotAction:new({})
                }
            else
                updateDistanceTravelled(self, nextDirection, -robot_parameters.squareSideDimension / 2)
                return {
                    isMoveActionNotFinished = false,
                    position = MoveAction.nextPosition(currentPosition, self.oldDirection, turnDirection)
                }
            end
        elseif isRobotTurning and state.robotDirection.direction ~= nextDirection then
            if turnDirection == MoveAction.TURN_LEFT then
                return {
                    isMoveActionNotFinished = true,
                    position = currentPosition,
                    action = RobotAction.turnLeft({1})
                }
            else
                return {
                    isMoveActionNotFinished = true,
                    position = currentPosition,
                    action = RobotAction.turnRight({1})
                }
            end
        else
            addActionToHead(self, MoveAction.GO_BACK_BEFORE_TURNING)
            return {
                isMoveActionNotFinished = true,
                position = currentPosition,
                action = RobotAction.goBack({1})
            }
        end

    end,

    handleGoBackMove = function (self, state, currentPosition, currentDirection, nextAction)
        updateDistanceTravelled(self, currentDirection, state.wheels.distance_left)
        if getDistanceTravelled(self, currentDirection) > -robot_parameters.squareSideDimension then
            return {
                isMoveActionNotFinished = true,
                position = currentPosition,
                action = RobotAction.goBack({1})
            }
        end

        updateDistanceTravelled(self, currentDirection, robot_parameters.squareSideDimension)
        local newPosition = MoveAction.nextPosition(
            currentPosition,
            currentDirection,
            MoveAction.GO_BACK
        )
        if nextAction == MoveAction.TURN_LEFT
          or nextAction == MoveAction.TURN_RIGHT then
            changeAction(self, 1, MoveAction.GO_BACK_BEFORE_TURNING)
            return {
                isMoveActionNotFinished = true,
                position = newPosition,
                action = RobotAction.goBack({1})
            }
        else
            return {
                isMoveActionNotFinished = false,
                position = newPosition
            }
        end
    end,

    handleGoBackBeforeTurningMove = function (self, state, currentPosition, currentDirection)
        updateDistanceTravelled(self, currentDirection, state.wheels.distance_left)
        if getDistanceTravelled(self, currentDirection) > -robot_parameters.squareSideDimension / 2 then
            return {
                isMoveActionNotFinished = true,
                position = currentPosition,
                action = RobotAction.goBack({1})
            }
        else
            return {
                isMoveActionNotFinished = false,
                position = currentPosition,
            }
        end
    end,

    --[[ --------- OBSTACLE MOVES ---------- ]]

    ---perform actions to get away from an obstacle
    ---@param state table RobotState - the current environment state
    ---@param currentPosition table Position - the current robot position
    ---@return table {
    ---     boolean isMoveActionNotFinished - if the robot completed an action
    ---     Position position - the current robot position
    ---     RobotAction action - the action to perform
    ---}
    getAwayFromObstacle = function (self, state, currentPosition)
        local currentAction = self.actions[1]
        commons.print(self.verticalDistanceTravelled .. "||" .. self.horizontalDistanceTravelled)
        if currentAction == MoveAction.GO_AHEAD or currentAction == MoveAction.GO_BACK or currentAction == MoveAction.GO_BACK_BEFORE_TURNING then
            return self:handleCancelStraightMove(state, currentPosition, controller_utils.discreteDirection(state.robotDirection))
        elseif currentAction == MoveAction.TURN_LEFT then
            return self:handleCancelTurnLeftMove(state, currentPosition)
        else
            return self:handleCancelTurnRightMove(state, currentPosition)
        end
    end,

    handleCancelStraightMove = function (self, state, currentPosition, currentDirection)
        updateDistanceTravelled(self, currentDirection, state.wheels.distance_left)
        local distanceTravelled = getDistanceTravelled(self, currentDirection)
        local move = self.actions[1]
        if move == MoveAction.GO_AHEAD and distanceTravelled <= 0 then
            return {
                isMoveActionNotFinished = false,
                position = currentPosition
            }
        elseif (move == MoveAction.GO_BACK or move == MoveAction.GO_BACK_BEFORE_TURNING) and distanceTravelled >= 0 then
            return {
                isMoveActionNotFinished = false,
                position = currentPosition
            }
        elseif move == MoveAction.GO_AHEAD then
            return {
                isMoveActionNotFinished = true,
                action = RobotAction.goBack({1, 2}),
            }
        else
            return {
                isMoveActionNotFinished = true,
                action = RobotAction:new({}, {2}),
            }
        end
    end,

    handleCancelTurnLeftMove = function (self, state, currentPosition)
        return self:handleCancelTurnMove(
            MoveAction.TURN_LEFT,
            state,
            currentPosition,
            state.wheels.velocity_left == -robot_parameters.robotNotTurningTyreSpeed
              and state.wheels.velocity_right ~= 0
        )
    end,

    handleCancelTurnRightMove = function (self, state, currentPosition)
        return self:handleCancelTurnMove(
            MoveAction.TURN_RIGHT,
            state,
            currentPosition,
            state.wheels.velocity_right == -robot_parameters.robotNotTurningTyreSpeed
              and state.wheels.velocity_left ~= 0
        )
    end,

    handleCancelTurnMove = function (self, turnDirection, state, currentPosition, isRobotTurning)
        if isRobotTurning and state.robotDirection.direction == self.oldDirection then
            return {
                isMoveActionNotFinished = false,
                position = currentPosition
            }
        else
            if turnDirection == MoveAction.TURN_LEFT then
                return {
                    isMoveActionNotFinished = true,
                    action = RobotAction:new({
                        speed = {
                            left = -robot_parameters.robotNotTurningTyreSpeed,
                            right = -robot_parameters.robotTurningSpeed
                        }
                    }, {1, 2}),
                    position = currentPosition
                }
            else
                return {
                    isMoveActionNotFinished = true,
                    action = RobotAction:new({
                        speed = {
                            left = -robot_parameters.robotTurningSpeed,
                            right = -robot_parameters.robotNotTurningTyreSpeed
                        }
                    }, {1, 2}),
                    position = currentPosition
                }
            end
        end
    end,

}

return MoveExecutioner