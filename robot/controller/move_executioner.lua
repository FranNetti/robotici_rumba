local Direction = require('util.commons').Direction
local logger = require('util.logger')

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

local function isObstacleInTheSameCell(isObstacleToX, currentDirection, currentAction, oldDirection)
    return currentDirection == oldDirection
        or currentAction == MoveAction.TURN_LEFT and isObstacleToX.right
        or currentAction == MoveAction.TURN_RIGHT and isObstacleToX.left
end

local function getDistanceTravelled(moveExecutioner, currentDirection)
    if currentDirection == Direction.SOUTH or currentDirection == Direction.NORTH then
        return moveExecutioner.verticalDistanceTravelled
    else
        return moveExecutioner.horizontalDistanceTravelled
    end
end

local function determineObstaclePosition (state, currentPosition, currentDirection, currentAction, oldDirection)
    local isObstacleToTheLeft = CollisionAvoidanceBehaviour.isObjectInLeftRange(state.proximity)
    local isObstacleToTheRight = CollisionAvoidanceBehaviour.isObjectInRightRange(state.proximity)

    if currentAction == MoveAction.GO_AHEAD or currentAction == MoveAction.GO_BACK or currentAction == MoveAction.GO_BACK_BEFORE_TURNING then
        return MoveAction.nextPosition(
            currentPosition,
            currentDirection,
            currentAction
        )
    elseif (currentAction == MoveAction.TURN_LEFT and isObstacleToTheLeft)
       or (currentAction == MoveAction.TURN_RIGHT and isObstacleToTheRight)
       or oldDirection ~= currentDirection then -- the robot is turning and it is nearer to the new direction than the old one
       return MoveAction.nextPosition(
            currentPosition,
            oldDirection,
            currentAction
        )
    elseif (currentAction == MoveAction.TURN_LEFT and isObstacleToTheRight)
      or (currentAction == MoveAction.TURN_RIGHT and isObstacleToTheLeft)
      or currentDirection == oldDirection then -- the robot is turning and it is nearer to the nold direction than the new one
        return currentPosition
    end
end

local function updateStraightDistanceTravelled(moveExecutioner, state, currentDirection)
    if state.wheels.distance_left > state.wheels.distance_right then
        updateDistanceTravelled(moveExecutioner, currentDirection, state.wheels.distance_left)
    else
        updateDistanceTravelled(moveExecutioner, currentDirection, state.wheels.distance_right)
    end
    -- updateDistanceTravelled(moveExecutioner, currentDirection, state.wheels.distance_left)
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

    ---Perform an action
    ---@param state table RobotState - the current environment state
    ---@return table {
    ---     boolean isObstacleEncountered - if there is an obstacle in the way
    ---     boolean isMoveActionNotFinished - if the robot completed an action
    ---     Position position - the current robot position
    ---     Position obstaclePosition - the obstacle position if an obstacle was found
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

            local result = nil
            if currentAction == MoveAction.GO_AHEAD then
                result = self:handleGoAheadMove(state, currentPosition, currentDirection, nextAction)
            elseif currentAction == MoveAction.TURN_LEFT then
                result = self:handleTurnLeftMove(state, currentPosition, currentDirection, nextAction)
            elseif currentAction == MoveAction.TURN_RIGHT then
                result = self:handleTurnRightMove(state, currentPosition, currentDirection, nextAction)
            elseif currentAction == MoveAction.GO_BACK then
                result = self:handleGoBackMove(state, currentPosition, currentDirection, nextAction)
            else
                result  = self:handleGoBackBeforeTurningMove(state, currentPosition, currentDirection)
            end

            result.position = result.position or currentPosition
            result.isObstacleEncountered = result.isObstacleEncountered or false
            result.isMoveActionFinished = result.isMoveActionFinished or false

            logger.print(self.verticalDistanceTravelled .. "||" .. self.horizontalDistanceTravelled)
            if result.isMoveActionFinished then
                logger.print("------------")
                removeFirstAction(self)
                self.oldDirection = currentDirection
            end
            return result
        end
        return {
            isObstacleEncountered = false,
            isMoveActionNotFinished = true,
            position = currentPosition
        }
    end,

    handleGoAheadMove = function (self, state, currentPosition, currentDirection, nextAction)
        updateStraightDistanceTravelled(self, state, currentDirection)
        local isObstacleEncountered = CollisionAvoidanceBehaviour.isObjectInFrontRange(state.proximity)
        local distanceTravelled = getDistanceTravelled(self, currentDirection)
        local newPosition = MoveAction.nextPosition(
            currentPosition,
            currentDirection,
            MoveAction.GO_AHEAD
        )

        if distanceTravelled >= robot_parameters.squareSideDimension then
            updateDistanceTravelled(self, currentDirection, -robot_parameters.squareSideDimension)
            if isObstacleEncountered then
                return {
                    isObstacleEncountered = true,
                    position = newPosition,
                    obstaclePosition = determineObstaclePosition(
                        state,
                        newPosition,
                        currentDirection,
                        MoveAction.GO_AHEAD,
                        self.oldDirection
                    )
                }
            else
                return {
                    isMoveActionFinished = true,
                    position = newPosition
                }
            end
        elseif isObstacleEncountered then
            return {
                isObstacleEncountered = true,
                obstaclePosition = determineObstaclePosition(
                    state,
                    currentPosition,
                    currentDirection,
                    MoveAction.GO_AHEAD,
                    self.oldDirection
                )
            }
        elseif nextAction == MoveAction.TURN_LEFT or nextAction == MoveAction.TURN_RIGHT then
            --[[
                if the robot has to turn immediately after then he needs to stop only
                when he reaches the middle length of a square.
            ]]
            if distanceTravelled < robot_parameters.squareSideDimension / 2 then
                return { action = RobotAction:new({}) }
            else
                --[[
                    if the robot has to turn immediately after, he is half square behind the next cell so
                    it's important to subtract a full cell dimension.
                ]]
                updateDistanceTravelled(self, currentDirection, -robot_parameters.squareSideDimension)
                return {
                    isMoveActionFinished = true,
                    position = newPosition
                }
            end
        else
            return { action = RobotAction:new({}) }
        end
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

        local isObstacleToX = {
            left = CollisionAvoidanceBehaviour.isObjectInLeftRange(state.proximity),
            right = CollisionAvoidanceBehaviour.isObjectInRightRange(state.proximity),
            front = CollisionAvoidanceBehaviour.isObjectInFrontRange(state.proximity),
        }

        if isObstacleToX.left or isObstacleToX.right or isObstacleToX.front then
            if isRobotTurning and isObstacleInTheSameCell(isObstacleToX, currentDirection, turnDirection, self.oldDirection) then
                updateDistanceTravelled(self, currentDirection, robot_parameters.squareSideDimension)
                return {
                    isObstacleEncountered = true,
                    position = MoveAction.nextPosition(currentPosition, currentDirection, MoveAction.GO_BACK),
                    obstaclePosition = currentPosition
                }
            elseif isRobotTurning then
                return {
                    isObstacleEncountered = true,
                    obstaclePosition = MoveAction.nextPosition(currentPosition, currentDirection, turnDirection)
                }
            else
                if isObstacleToX.left then
                    return {
                        isObstacleEncountered = true,
                        obstaclePosition = MoveAction.nextPosition(currentPosition, currentDirection, MoveAction.TURN_LEFT)
                    }
                elseif isObstacleToX.right then
                    return {
                        isObstacleEncountered = true,
                        obstaclePosition = MoveAction.nextPosition(currentPosition, currentDirection, MoveAction.TURN_RIGHT)
                    }
                else
                    return {
                        isObstacleEncountered = true,
                        obstaclePosition = MoveAction.nextPosition(currentPosition, currentDirection, MoveAction.GO_AHEAD)
                    }
                end
            end
        elseif isRobotTurning then
            if state.robotDirection.direction == nextDirection then
            --[[
                if the robot has finished to turn then it is ok in regards to the old direction because he is
                advanced by another half of the cell.
                for the current direction is now ahead of half cell with reguards to the current cell if the robot has not to
                turn again, after he needs to end the turn operation by advancing of half cell. In this way the robot knows only that
                he turned direction but it stayed in the same cell.
                if the robot has to turn again instead it knows that it changed cell and now it is behind of half cell with regards 
                to the new cell.
            ]]
            updateDistanceTravelled(self, self.oldDirection, robot_parameters.squareSideDimension / 2)
            if nextAction ~= MoveAction.TURN_LEFT
              and nextAction ~= MoveAction.TURN_RIGHT then
                updateDistanceTravelled(self, nextDirection, robot_parameters.squareSideDimension / 2)
                changeAction(self, 1, MoveAction.GO_AHEAD)
                return { action = RobotAction:new({}) }
            else
                updateDistanceTravelled(self, nextDirection, -robot_parameters.squareSideDimension / 2)
                return {
                    isMoveActionFinished = true,
                    position = MoveAction.nextPosition(currentPosition, self.oldDirection, turnDirection)
                }
            end
            elseif turnDirection == MoveAction.TURN_LEFT then
                return { action = RobotAction.turnLeft({1}) }
            else
                return { action = RobotAction.turnRight({1}) }
            end
        else
            --[[
                if the robot has to turn but he's not doing anything it's important
                that it goes back by a half of the cell dimension
            ]]
            addActionToHead(self, MoveAction.GO_BACK_BEFORE_TURNING)
            return { action = RobotAction.goBack({1}) }
        end
    end,

    handleGoBackMove = function (self, state, currentPosition, currentDirection, nextAction)
        updateStraightDistanceTravelled(self, state, currentDirection)
        local isObstacleEncountered = CollisionAvoidanceBehaviour.isObjectInBackRange(state.proximity)

        if getDistanceTravelled(self, currentDirection) <= -robot_parameters.squareSideDimension then
            updateDistanceTravelled(self, currentDirection, robot_parameters.squareSideDimension)
            local newPosition = MoveAction.nextPosition(
                currentPosition,
                currentDirection,
                MoveAction.GO_BACK
            )
            if isObstacleEncountered then
                return {
                    isObstacleEncountered = true,
                    position = newPosition,
                    obstaclePosition = determineObstaclePosition(
                        state,
                        newPosition,
                        currentDirection,
                        MoveAction.GO_BACK,
                        self.oldDirection
                    )
                }
            elseif nextAction == MoveAction.TURN_LEFT
              or nextAction == MoveAction.TURN_RIGHT then
                --[[
                    if the robot has to turn then it's important that it goes back
                    by another half cell to then correctly turn
                ]]
                changeAction(self, 1, MoveAction.GO_BACK_BEFORE_TURNING)
                return {
                    position = newPosition,
                    action = RobotAction.goBack({1})
                }
            else
                return {
                    isMoveActionFinished = true,
                    position = newPosition
                }
            end
        elseif isObstacleEncountered then
            return {
                isObstacleEncountered = true,
                obstaclePosition = determineObstaclePosition(
                    state,
                    currentPosition,
                    currentDirection,
                    MoveAction.GO_BACK,
                    self.oldDirection
                )
            }
        else
            return { action = RobotAction.goBack({1}) }
        end
    end,

    handleGoBackBeforeTurningMove = function (self, state, currentPosition, currentDirection)
        updateStraightDistanceTravelled(self, state, currentDirection)
        local isObstacleEncountered = CollisionAvoidanceBehaviour.isObjectInBackRange(state.proximity)

        if isObstacleEncountered then
            return {
                isObstacleEncountered = true,
                obstaclePosition = determineObstaclePosition(
                    state,
                    currentPosition,
                    currentDirection,
                    MoveAction.GO_BACK,
                    self.oldDirection
                )
            }
        elseif getDistanceTravelled(self, currentDirection) <= -robot_parameters.squareSideDimension / 2 then
            return { isMoveActionFinished = true }
        else
            return { action = RobotAction.goBack({1}) }
        end
    end,

    --[[ --------- OBSTACLE MOVES ---------- ]]

    ---perform actions to get away from an obstacle
    ---@param state table RobotState - the current environment state
    ---@return table {
    ---     boolean isMoveActionNotFinished - if the robot completed an action
    ---     RobotAction action - the action to perform
    ---}
    getAwayFromObstacle = function (self, state, currentPosition)
        local currentAction = self.actions[1]
        local result = nil
        logger.print(self.verticalDistanceTravelled .. "||" .. self.horizontalDistanceTravelled)
        if currentAction == MoveAction.GO_AHEAD or currentAction == MoveAction.GO_BACK or currentAction == MoveAction.GO_BACK_BEFORE_TURNING then
            result = self:handleCancelStraightMove(state, controller_utils.discreteDirection(state.robotDirection))
        elseif currentAction == MoveAction.TURN_LEFT then
            result = self:handleCancelTurnLeftMove(state, controller_utils.discreteDirection(state.robotDirection), currentPosition)
        else
            result = self:handleCancelTurnRightMove(state, controller_utils.discreteDirection(state.robotDirection), currentPosition)
        end

        result.isMoveActionFinished = result.isMoveActionFinished or false
        result.position = result.position or currentPosition
        return result
    end,

    handleCancelStraightMove = function (self, state, currentDirection)
        updateStraightDistanceTravelled(self, state, currentDirection)
        local distanceTravelled = getDistanceTravelled(self, currentDirection)
        local move = self.actions[1]
        if move == MoveAction.GO_AHEAD and distanceTravelled <= 0 then
            return { isMoveActionFinished = true }
        elseif (move == MoveAction.GO_BACK or move == MoveAction.GO_BACK_BEFORE_TURNING) and distanceTravelled >= 0 then
            return { isMoveActionFinished = true }
        elseif move == MoveAction.GO_AHEAD then
            return { action = RobotAction.goBack({1, 2}) }
        else
            return { action = RobotAction:new({}, {2}) }
        end
    end,

    handleCancelTurnLeftMove = function (self, state, currentDirection, currentPosition)
        return self:handleCancelTurnMove(
            MoveAction.TURN_LEFT,
            state,
            currentPosition,
            currentDirection,
            state.wheels.velocity_left == -robot_parameters.robotNotTurningTyreSpeed
              and state.wheels.velocity_right ~= 0
        )
    end,

    handleCancelTurnRightMove = function (self, state, currentDirection, currentPosition)
        return self:handleCancelTurnMove(
            MoveAction.TURN_RIGHT,
            state,
            currentPosition,
            currentDirection,
            state.wheels.velocity_right == -robot_parameters.robotNotTurningTyreSpeed
              and state.wheels.velocity_left ~= 0
        )
    end,

    handleCancelTurnMove = function (self, turnDirection, state, currentPosition, currentDirection, isRobotTurning)
        if isRobotTurning and state.robotDirection.direction == self.oldDirection then
            --[[
                It's important to obtain a positive value for the distance travelled in order to follow the algorithm
                logics. The position must be moved to the previous cell too.
            ]]
            updateDistanceTravelled(self, currentDirection, robot_parameters.squareSideDimension)
            return {
                isMoveActionFinished = true,
                position = MoveAction.nextPosition(
                    currentPosition,
                    currentDirection,
                    MoveAction.GO_BACK
                )
            }
        else
            if turnDirection == MoveAction.TURN_LEFT then
                return {
                    action = RobotAction:new({
                        speed = {
                            left = -robot_parameters.robotNotTurningTyreSpeed,
                            right = -robot_parameters.robotTurningSpeed
                        }
                    }, {1, 2})
                }
            else
                return {
                    action = RobotAction:new({
                        speed = {
                            left = -robot_parameters.robotTurningSpeed,
                            right = -robot_parameters.robotNotTurningTyreSpeed
                        }
                    }, {1, 2})
                }
            end
        end
    end,

}

return MoveExecutioner