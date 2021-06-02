local Direction = require('util.commons').Direction
local Position = require('util.commons').Position
local logger = require('util.logger')
local table = require('extensions.lua.table')

local robot_parameters = require('robot.parameters')
local RobotAction = require('robot.commons').Action

local MoveAction = require('robot.controller.planner.move_action')

local controller_utils = require('robot.controller.utils')
local helpers = require('robot.controller.move_executioner.helpers')
local CollisionAvoidanceBehaviour = require('robot.controller.behaviour.collision_avoidance.collision_avoidance')

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
        moveExecutioner.map:updateVerticalOffset(offset, currentDirection)
    else
        moveExecutioner.map:updateHorizontalOffset(offset, currentDirection)
    end
end

local function setDistanceTravelled(moveExecutioner, currentDirection, value)
    if currentDirection == Direction.SOUTH or currentDirection == Direction.NORTH then
        moveExecutioner.map:setVerticalOffset(value, currentDirection)
    else
        moveExecutioner.map:setHorizontalOffset(value, currentDirection)
    end
end

local function getDistanceTravelled(moveExecutioner, currentDirection)
    if currentDirection == Direction.SOUTH or currentDirection == Direction.NORTH then
        return moveExecutioner.map:getVerticalOffset(currentDirection)
    else
        return moveExecutioner.map:getHorizontalOffset(currentDirection)
    end
end

local function updateStraightDistanceTravelled(moveExecutioner, state, currentDirection)
    if state.wheels.distance_left > state.wheels.distance_right then
        updateDistanceTravelled(moveExecutioner, currentDirection, state.wheels.distance_left)
    else
        updateDistanceTravelled(moveExecutioner, currentDirection, state.wheels.distance_right)
    end
end

local function updateNegativeStraightDistanceTravelled(moveExecutioner, state, currentDirection)
    if state.wheels.distance_left < state.wheels.distance_right then
        updateDistanceTravelled(moveExecutioner, currentDirection, state.wheels.distance_left)
    else
        updateDistanceTravelled(moveExecutioner, currentDirection, state.wheels.distance_right)
    end
end

local MoveExecutioner = {

    new = function (self, map, planner, currentDirection)
        local o = {
            map = map,
            planner = planner,
            oldDirection = currentDirection or Direction.NORTH,
            actions = nil,
            numberOfOriginalActions = 0,
            doObstacleHelperAction = false,
            helperActionOffset = 0,
        }
        setmetatable(o, self)
        self.__index = self
        return o
    end,

    setActions = function (self, actions, state)
        self.actions = {table.unpack(actions)}
        if self.map.position == Position:new(0,0) then
            local firstAction = self.actions[1]
            local currentDirection = controller_utils.discreteDirection(state.robotDirection)
            if firstAction == MoveAction.TURN_LEFT and currentDirection == Direction.EAST
                or firstAction == MoveAction.TURN_RIGHT and currentDirection == Direction.SOUTH then
                addActionToHead(self, MoveAction.GO_BACK_BEFORE_TURNING)
            end
        end
        self.numberOfOriginalActions = #actions
    end,

    hasMoreActions = function (self)
        return self.actions ~= nil and #self.actions >= 1
    end,

    ---Perform an action
    ---@param state table RobotState - the current environment state
    ---@return table {
    ---     boolean isObstacleEncountered - if there is an obstacle in the way
    ---     boolean isMoveActionFinished - if the robot completed an action
    ---     Position position - the current robot position
    ---     Position obstaclePositions - the list of obstacle positions if an obstacle was found
    ---     RobotAction action - the action to perform
    ---}
    doNextMove = function (self, state)
        local currentPosition = self.map.position
        if self:hasMoreActions() then
            local currentDirection = controller_utils.discreteDirection(state.robotDirection)
            local currentAction = self.actions[1]
            local nextAction = nil
            if #self.actions >= 2 then
                nextAction = self.actions[2]
            end

            local isObstacleToX = {
                left = CollisionAvoidanceBehaviour.isObjectInLeftRange(state.proximity),
                right = CollisionAvoidanceBehaviour.isObjectInRightRange(state.proximity),
                front = CollisionAvoidanceBehaviour.isObjectInFrontRange(state.proximity),
                back = CollisionAvoidanceBehaviour.isObjectInBackRange(state.proximity)
            }

            local result = nil
            if currentAction == MoveAction.GO_AHEAD then
                result = self:handleGoAheadMove(state, isObstacleToX, currentPosition, currentDirection, nextAction)
            elseif currentAction == MoveAction.TURN_LEFT then
                result = self:handleTurnLeftMove(state, isObstacleToX, currentPosition, currentDirection, nextAction)
            elseif currentAction == MoveAction.TURN_RIGHT then
                result = self:handleTurnRightMove(state, isObstacleToX, currentPosition, currentDirection, nextAction)
            elseif currentAction == MoveAction.GO_BACK then
                result = self:handleGoBackMove(state, isObstacleToX, currentPosition, currentDirection, nextAction)
            else
                result  = self:handleGoBackBeforeTurningMove(state, isObstacleToX, currentPosition, currentDirection)
            end

            result.position = result.position or currentPosition
            result.isObstacleEncountered = result.isObstacleEncountered or false
            result.isMoveActionFinished = result.isMoveActionFinished or false

            --[[
                If the obstacle is in position (0,0) then we consider that the robot has resetted its position accordingly to
                the direction it currently is
            ]]
            if result.isObstacleEncountered and table.contains(result.obstaclePositions,Position:new(0,0)) then
                result.obstaclePositions = { Position:new(-1,-1) }
                if currentAction == MoveAction.GO_AHEAD then
                    result.position = Position:new(0,0)
                    self.doObstacleHelperAction = true
                end
            end

            logger.print(self.map.verticalOffset.offset .. "||" .. self.map.horizontalOffset.offset)
            if result.isMoveActionFinished then
                logger.print("------------")
                removeFirstAction(self)
                self.oldDirection = currentDirection
            end
            return result
        end
        return {
            isObstacleEncountered = false,
            isMoveActionFinished = true,
            position = currentPosition
        }
    end,

    handleGoAheadMove = function (self, state, isObstacleToX, currentPosition, currentDirection, nextAction)
        updateStraightDistanceTravelled(self, state, currentDirection)
        local distanceTravelled = getDistanceTravelled(self, currentDirection)
        local newPosition = MoveAction.nextPosition(
            currentPosition,
            currentDirection,
            MoveAction.GO_AHEAD
        )

        local isObstacleEncountered = isObstacleToX.front
            or (isObstacleToX.left and helpers.isObstacleCloseToTheLeft(state))
            or (isObstacleToX.right and helpers.isObstacleCloseToTheRight(state))

        local levelsToSubsume = {}
        if isObstacleToX.left or isObstacleToX.right then
            levelsToSubsume = {2}
        end

        if distanceTravelled >= robot_parameters.squareSideDimension then
            updateDistanceTravelled(self, currentDirection, -robot_parameters.squareSideDimension)
            if isObstacleEncountered then
                return {
                    isObstacleEncountered = true,
                    position = newPosition,
                    obstaclePositions = helpers.determineObstaclePosition(
                        self,
                        newPosition,
                        currentDirection,
                        isObstacleToX,
                        false
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
                obstaclePositions = helpers.determineObstaclePosition(
                    self,
                    currentPosition,
                    currentDirection,
                    isObstacleToX,
                    false
                )
            }
        elseif nextAction == MoveAction.TURN_LEFT or nextAction == MoveAction.TURN_RIGHT then
            --[[
                if the robot has to turn immediately after then he needs to stop only
                when he reaches the middle length of a square.
            ]]
            if distanceTravelled < robot_parameters.squareSideDimension / 2 then
                return { action = RobotAction:new({}, levelsToSubsume) }
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
            return { action = RobotAction:new({}, levelsToSubsume) }
        end
    end,

    handleTurnLeftMove = function (self, state, isObstacleToX, currentPosition, currentDirection, nextAction)
        return self:handleTurnMove(
            MoveAction.TURN_LEFT,
            state,
            isObstacleToX,
            currentPosition,
            currentDirection,
            state.wheels.velocity_left == robot_parameters.robotNotTurningTyreSpeed
              and state.wheels.velocity_right ~= 0,
            nextAction
        )
    end,

    handleTurnRightMove = function (self, state, isObstacleToX, currentPosition, currentDirection, nextAction)
        return self:handleTurnMove(
            MoveAction.TURN_RIGHT,
            state,
            isObstacleToX,
            currentPosition,
            currentDirection,
            state.wheels.velocity_right == robot_parameters.robotNotTurningTyreSpeed
              and state.wheels.velocity_left ~= 0,
            nextAction
        )
    end,

    handleTurnMove = function (self, turnDirection, state, isObstacleToX, currentPosition, currentDirection, isRobotTurning, nextAction)
        local nextDirection = MoveAction.nextDirection(self.oldDirection, turnDirection)

        if isObstacleToX.left or isObstacleToX.right or isObstacleToX.front then
            return {
                isObstacleEncountered = true,
                obstaclePositions = helpers.determineObstaclePosition(
                    self,
                    currentPosition,
                    currentDirection,
                    isObstacleToX,
                    isRobotTurning
                )
            }
        elseif isRobotTurning and state.robotDirection.direction == nextDirection then
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
                self.oldDirection = nextDirection
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
            return { action = RobotAction.turnLeft({}, {1}) }
        else
            return { action = RobotAction.turnRight({}, {1}) }
        end
    end,

    handleGoBackMove = function (self, state, isObstacleToX, currentPosition, currentDirection, nextAction)
        updateStraightDistanceTravelled(self, state, currentDirection)

        local isObstacleEncountered = isObstacleToX.back
            or (isObstacleToX.left and helpers.isObstacleCloseToTheLeft(state))
            or (isObstacleToX.right and helpers.isObstacleCloseToTheRight(state))

        local levelsToSubsume = {1}
        if isObstacleToX.left or isObstacleToX.right then
            levelsToSubsume = {1, 2}
        end

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
                    obstaclePositions = helpers.determineObstaclePosition(
                        self,
                        newPosition,
                        currentDirection,
                        isObstacleToX,
                        false
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
                    action = RobotAction.goBack({}, levelsToSubsume)
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
                obstaclePositions = helpers.determineObstaclePosition(
                    self,
                    currentPosition,
                    currentDirection,
                    isObstacleToX,
                    false
                )
            }
        else
            return { action = RobotAction.goBack({}, levelsToSubsume) }
        end
    end,

    handleGoBackBeforeTurningMove = function (self, state, isObstacleToX, currentPosition, currentDirection)
        updateStraightDistanceTravelled(self, state, currentDirection)

        local isObstacleEncountered = isObstacleToX.back
            or (isObstacleToX.left and helpers.isObstacleCloseToTheLeft(state))
            or (isObstacleToX.right and helpers.isObstacleCloseToTheRight(state))

        local levelsToSubsume = {1}
        if isObstacleToX.left or isObstacleToX.right then
            levelsToSubsume = {1, 2}
        end

        if isObstacleEncountered then
            return {
                isObstacleEncountered = true,
                obstaclePositions = helpers.determineObstaclePosition(
                    self,
                    currentPosition,
                    currentDirection,
                    isObstacleToX,
                    false
                )
            }
        elseif getDistanceTravelled(self, currentDirection) <= -robot_parameters.squareSideDimension / 2 then
            return { isMoveActionFinished = true }
        else
            return { action = RobotAction.goBack({}, levelsToSubsume) }
        end
    end,

    --[[ --------- OBSTACLE MOVES ---------- ]]

    ---perform actions to get away from an obstacle
    ---@param state table RobotState - the current environment state
    ---@return table {
    ---     boolean isMoveActionNotFinished - if the robot completed an action
    ---     RobotAction action - the action to perform
    ---}
    getAwayFromObstacle = function (self, state)
        local currentPosition = self.map.position
        local currentAction = self.actions[1]
        local currentDirection = controller_utils.discreteDirection(state.robotDirection)
        local result = nil
        logger.print(self.map.verticalOffset.offset .. "||" .. self.map.horizontalOffset.offset)
        if self.doObstacleHelperAction then
            result = self:handleHelperMove(state, currentDirection)
        elseif currentAction == MoveAction.GO_AHEAD or currentAction == MoveAction.GO_BACK or currentAction == MoveAction.GO_BACK_BEFORE_TURNING then
            result = self:handleCancelStraightMove(state, currentDirection)
        elseif currentAction == MoveAction.TURN_LEFT then
            result = self:handleCancelTurnLeftMove(state, currentDirection, currentPosition)
        else
            result = self:handleCancelTurnRightMove(state, currentDirection, currentPosition)
        end

        result.isMoveActionFinished = result.isMoveActionFinished or false
        result.position = result.position or currentPosition
        return result
    end,

    handleCancelStraightMove = function (self, state, currentDirection)
        updateNegativeStraightDistanceTravelled(self, state, currentDirection)
        local distanceTravelled = getDistanceTravelled(self, currentDirection)
        local move = self.actions[1]
        if move == MoveAction.GO_AHEAD and distanceTravelled <= -robot_parameters.squareSideDimension / 2 then
            if distanceTravelled > -robot_parameters.squareSideDimension then
                return { action = RobotAction.goBack({}, {1, 2}) }
            else
                updateDistanceTravelled(self, currentDirection, robot_parameters.squareSideDimension)
                return {
                    isMoveActionFinished = true,
                    position = MoveAction.nextPosition(self.map.position, currentDirection, MoveAction.GO_BACK)
                }
            end
        elseif move == MoveAction.GO_AHEAD and distanceTravelled <= 0 then
            return { isMoveActionFinished = true }
        elseif (move == MoveAction.GO_BACK or move == MoveAction.GO_BACK_BEFORE_TURNING)
            and distanceTravelled >= robot_parameters.squareSideDimension / 2 then
            if distanceTravelled < robot_parameters.squareSideDimension then
                return { action = RobotAction:new({}, {2}) }
            else
                updateDistanceTravelled(self, currentDirection, -robot_parameters.squareSideDimension)
                return {
                    isMoveActionFinished = true,
                    position = MoveAction.nextPosition(self.map.position, currentDirection, MoveAction.GO_AHEAD)
                }
            end
        elseif (move == MoveAction.GO_BACK or move == MoveAction.GO_BACK_BEFORE_TURNING) and distanceTravelled >= 0 then
            return { isMoveActionFinished = true }
        elseif move == MoveAction.GO_AHEAD then
            return { action = RobotAction.goBack({}, {1, 2}) }
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
            local isMoveFinished = true
            local action = nil
            if helpers.canRobotGoBack(self, currentPosition, currentDirection) then
                isMoveFinished = false
                action = RobotAction.goBack({}, {1, 2})
                self.doObstacleHelperAction = true
            end
            if self.planner.actions[1] == self.actions[1] and #self.planner.actions == self.numberOfOriginalActions then
                return {
                    isMoveActionFinished = isMoveFinished,
                    action = action
                }
            else
                --[[
                    It's important to obtain a positive value for the distance travelled in order to follow the algorithm
                    logics. The position must be moved to the previous cell too. this logic applies only if the turn action
                    isn't the first action performed by the robot.
                ]]
                updateDistanceTravelled(self, currentDirection, robot_parameters.squareSideDimension)
                return {
                    isMoveActionFinished = isMoveFinished,
                    action = action,
                    position = MoveAction.nextPosition(
                        currentPosition,
                        currentDirection,
                        MoveAction.GO_BACK
                    )
                }
            end
        elseif not isRobotTurning and state.robotDirection.direction == self.oldDirection then
            if helpers.canRobotGoBack(self, currentPosition, currentDirection) then
                self.doObstacleHelperAction = true
                return { action = RobotAction.goBack({}, {1, 2})}
            else
                return { isMoveActionFinished = true }
            end
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

    --[[ --------- HANDLE OBSTACLE HELPER MOVE ---------- ]]

    handleHelperMove = function (self, state, currentDirection)
        if state.wheels.distance_left < state.wheels.distance_right then
            self.helperActionOffset = self.helperActionOffset + state.wheels.distance_left
        else
            self.helperActionOffset = self.helperActionOffset + state.wheels.distance_right
        end
        updateNegativeStraightDistanceTravelled(self, state, currentDirection)
        local offset = getDistanceTravelled(self, currentDirection)
        local position = self.map.position
        if offset <= -robot_parameters.squareSideDimension then
            updateDistanceTravelled(self, currentDirection, robot_parameters.squareSideDimension)
            position = MoveAction.nextPosition(self.map.position, currentDirection, MoveAction.GO_BACK)
        end

        if self.helperActionOffset <= -robot_parameters.distanceToGoBackWithObstacles then
            self.helperActionOffset = 0
            self.doObstacleHelperAction = false
            return { isMoveActionFinished = true, position = position }
        else
            return { action = RobotAction.goBack({}, {1, 2}), position = position }
        end
    end,

    --[[ --------- HANDLE STOP MOVE ---------- ]]

    handleStopMove = function (self, state)
        local isTurningLeft = state.wheels.velocity_left == -robot_parameters.robotNotTurningTyreSpeed
            and state.wheels.velocity_right ~= 0
        local isTurningRight = state.wheels.velocity_right == -robot_parameters.robotNotTurningTyreSpeed
            and state.wheels.velocity_left ~= 0
        local speed = state.wheels.velocity_left
        if state.wheels.velocity_right > speed then
            speed = state.wheels.velocity_right
        end
        local currentDirection = controller_utils.discreteDirection(state.robotDirection)

        if isTurningLeft or isTurningRight or speed == 0 then
            return self.map.position
        else
            updateStraightDistanceTravelled(self, state, currentDirection)
            local distanceTravelled = getDistanceTravelled(self, currentDirection)
            if speed > 0 and distanceTravelled >= robot_parameters.squareSideDimension then
                updateDistanceTravelled(self, currentDirection, -robot_parameters.squareSideDimension)
                removeFirstAction(self)
                self.oldDirection = currentDirection
                return MoveAction.nextPosition(self.map.position, currentDirection, MoveAction.GO_AHEAD)
            elseif speed < 0 and distanceTravelled <= 0 then
                updateDistanceTravelled(self, currentDirection, robot_parameters.squareSideDimension)
                removeFirstAction(self)
                self.oldDirection = currentDirection
                return MoveAction.nextPosition(self.map.position, currentDirection, MoveAction.GO_BACK)
            else
                return self.map.position
            end
        end
    end

}

return MoveExecutioner