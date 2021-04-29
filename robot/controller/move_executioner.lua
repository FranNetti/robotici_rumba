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

local MoveExecutioner = {

    new = function (self)
        local o = {
            distanceTravelled = 0,
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
        self.distanceTravelled = 0
    end,

    ---Perform an action
    ---@param state table RobotState - the current environment state
    ---@return boolean - if there is an obstacle in the way
    ---@return boolean - if the robot completed an action
    ---@return table Position - the current robot position
    ---@return table RobotAction - the action to perform
    doNextMove = function (self, state, currentPosition)
        if self:hasMoreActions() then
            local currentAction = self.actions[1]
            local nextAction = nil
            if #self.actions >= 2 then
                nextAction = self.actions[2]
            end

            local isMoveActionNotFinished, robotAction, newPosition = false, nil, nil
            if currentAction == MoveAction.GO_AHEAD then
                if CollisionAvoidanceBehaviour.isObjectInFrontRange(state.proximity) then
                    return true, nil, currentPosition, nil
                else
                    isMoveActionNotFinished, newPosition, robotAction = self:handleGoAheadMove(state, currentPosition, nextAction)
                end
            elseif currentAction == MoveAction.TURN_LEFT then
                if CollisionAvoidanceBehaviour.isObjectInLeftRange(state.proximity)
                or CollisionAvoidanceBehaviour.isObjectInRightRange(state.proximity)
                or CollisionAvoidanceBehaviour.isObjectInFrontRange(state.proximity) then
                    return true, nil, currentPosition, nil
                else
                    isMoveActionNotFinished, newPosition, robotAction  = self:handleTurnLeftMove(state, currentPosition, nextAction)
                end
            elseif currentAction == MoveAction.TURN_RIGHT then
                if CollisionAvoidanceBehaviour.isObjectInLeftRange(state.proximity)
                or CollisionAvoidanceBehaviour.isObjectInRightRange(state.proximity)
                or CollisionAvoidanceBehaviour.isObjectInFrontRange(state.proximity) then
                    return true, nil, currentPosition, nil
                else
                    isMoveActionNotFinished, newPosition, robotAction  = self:handleTurnRightMove(state, currentPosition, nextAction)
                end
            else
                if CollisionAvoidanceBehaviour.isObjectInBackRange(state.proximity) then
                    return true, nil, currentPosition, nil
                else
                    isMoveActionNotFinished, newPosition, robotAction  = self:handleGoBackMove(state, currentPosition)
                end
            end

            if not isMoveActionNotFinished then
                removeFirstAction(self)
                self.oldDirection = controller_utils.discreteDirection(state.robotDirection)
            end

            return false, isMoveActionNotFinished, newPosition, robotAction

        end
        return false, true, currentPosition, nil
    end,

    handleGoAheadMove = function (self, state, currentPosition, nextAction)
        self.distanceTravelled = self.distanceTravelled + state.wheels.distance_left
        if (nextAction == MoveAction.TURN_LEFT or nextAction == MoveAction.TURN_RIGHT)
              and self.distanceTravelled < robot_parameters.squareSideDimension / 2 then
            return true, currentPosition, RobotAction:new({})
        elseif nextAction ~= MoveAction.TURN_LEFT
            and nextAction ~= MoveAction.TURN_RIGHT
            and self.distanceTravelled < robot_parameters.squareSideDimension then
            return true, currentPosition, RobotAction:new({})
        else
            self.distanceTravelled = self.distanceTravelled - robot_parameters.squareSideDimension
            return false, MoveAction.nextPosition(
                currentPosition,
                controller_utils.discreteDirection(state.robotDirection),
                MoveAction.GO_AHEAD
            ), nil
        end
    end,

    handleTurnLeftMove = function (self, state, currentPosition, nextAction)
        return self:handleTurnMove(
            MoveAction.TURN_LEFT,
            state,
            currentPosition,
            state.wheels.velocity_left == robot_parameters.robotNotTurningTyreSpeed
              and state.wheels.velocity_right ~= 0,
            nextAction
        )
    end,

    handleTurnRightMove = function (self, state, currentPosition, nextAction)
        return self:handleTurnMove(
            MoveAction.TURN_RIGHT,
            state,
            currentPosition,
            state.wheels.velocity_right == robot_parameters.robotNotTurningTyreSpeed
              and state.wheels.velocity_left ~= 0,
            nextAction
        )
    end,

    handleTurnMove = function (self, turnDirection, state, currentPosition, isRobotTurning, nextAction)
        local nextDirection = MoveAction.nextDirection(self.oldDirection, turnDirection)

        if isRobotTurning and state.robotDirection.direction == nextDirection then
            if nextAction ~= MoveAction.TURN_LEFT
              and nextAction ~= MoveAction.TURN_RIGHT then
                self.distanceTravelled = robot_parameters.squareSideDimension / 2
                changeAction(self, 1, MoveAction.GO_AHEAD)
                return true, currentPosition, RobotAction:new({})
            else
                return false, MoveAction.nextPosition(currentPosition, self.oldDirection, turnDirection), nil
            end
        elseif isRobotTurning and state.robotDirection.direction ~= nextDirection then
            if turnDirection == MoveAction.TURN_LEFT then
                return true, currentPosition, RobotAction.turnLeft({1})
            else
                return true, currentPosition, RobotAction.turnRight({1})
            end
        else
            self.distanceTravelled = -robot_parameters.squareSideDimension / 2
            addActionToHead(self, MoveAction.GO_BACK)
            return true, MoveAction.nextPosition(
                currentPosition,
                controller_utils.discreteDirection(state.robotDirection),
                MoveAction.GO_AHEAD
            ), RobotAction.goBack({1})
        end

    end,

    handleGoBackMove = function (self, state, currentPosition)
        self.distanceTravelled = self.distanceTravelled + state.wheels.distance_left
        if self.distanceTravelled > -robot_parameters.squareSideDimension then
            return true, currentPosition, RobotAction.goBack({1})
        else
            self.distanceTravelled = self.distanceTravelled + robot_parameters.squareSideDimension
        end
        return false, MoveAction.nextPosition(
            currentPosition,
            controller_utils.discreteDirection(state.robotDirection),
            MoveAction.GO_BACK
        ), nil
    end,

    --[[ --------- OBSTACLE MOVES ---------- ]]

    ---perform actions to get away from an obstacle
    ---@param state table RobotState - the current environment state
    ---@return boolean - if the move is not finished
    ---@return table RobotAction - The action to perform
    getAwayFromObstacle = function (self, state)
        local currentAction = self.actions[1]
        if currentAction == MoveAction.GO_AHEAD or currentAction == MoveAction.GO_BACK then
            return self:handleCancelStraightMove(state)
        elseif currentAction == MoveAction.TURN_LEFT then
            return self:handleCancelTurnLeftMove(state)
        else
            return self:handleCancelTurnRightMove(state)
        end
    end,

    handleCancelStraightMove = function (self, state)
        self.distanceTravelled = self.distanceTravelled + state.wheels.distance_left
        local move = self.actions[1]
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
            changeAction(self, 1, MoveAction.GO_AHEAD)
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

return MoveExecutioner