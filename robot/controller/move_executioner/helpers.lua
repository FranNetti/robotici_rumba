local helpers = {}

local MoveAction = require('robot.controller.planner.move_action')
local Direction = require('util.commons').Direction
local Position = require('util.commons').Position
local robot_parameters = require('robot.parameters')
local logger = require('util.logger')
local CellStatus = require('robot.controller.map.cell_status')

local LEFT_DISTANCE_WHILE_GOING_STRAIGHT = 0.95
local RIGHT_DISTANCE_WHILE_GOING_STRAIGHT = 0.95

function helpers.isObstacleInTheOppositeTurnDirection(isObstacleToX, currentAction)
    return currentAction == MoveAction.TURN_LEFT and isObstacleToX.right
        or currentAction == MoveAction.TURN_RIGHT and isObstacleToX.left
end

function helpers.isObstacleInSameTurnDirection(isObstacleToX, currentAction)
    return currentAction == MoveAction.TURN_LEFT and isObstacleToX.left
        or currentAction == MoveAction.TURN_RIGHT and isObstacleToX.right
end

function helpers.isObstacleCloseToTheLeft(state)
    for i=3,6 do
        if state.proximity[i].value > LEFT_DISTANCE_WHILE_GOING_STRAIGHT then
            return true
        end
    end
    return false
end

function helpers.isObstacleCloseToTheRight(state)
    for i=19, 22 do
        if state.proximity[i].value > RIGHT_DISTANCE_WHILE_GOING_STRAIGHT then
            return true
        end
    end
    return false
end

function helpers.getAxisOffsets(moveExecutioner, currentDirection)
    if currentDirection == Direction.NORTH then
        return moveExecutioner.map:getVerticalOffset(Direction.NORTH), moveExecutioner.map:getHorizontalOffset(Direction.WEST)
    elseif currentDirection == Direction.WEST then
        return moveExecutioner.map:getHorizontalOffset(Direction.WEST), moveExecutioner.map:getVerticalOffset(Direction.SOUTH)
    elseif currentDirection == Direction.SOUTH then
        return moveExecutioner.map:getVerticalOffset(Direction.SOUTH), moveExecutioner.map:getHorizontalOffset(Direction.EAST)
    else
        return moveExecutioner.map:getHorizontalOffset(Direction.EAST), moveExecutioner.map:getVerticalOffset(Direction.NORTH)
    end
end

function helpers.canRobotGoBack(moveExecutioner, currentPosition, currentDirection)
    local forwardPosition = MoveAction.nextPosition(currentPosition, currentDirection, MoveAction.GO_AHEAD)
    local backPosition = MoveAction.nextPosition(currentPosition, currentDirection, MoveAction.GO_BACK)

    return currentPosition == Position:new(0,0) and currentDirection == Direction.SOUTH
        or currentDirection == Position:new(0,0) and currentDirection == Direction.EAST
        or moveExecutioner.map:getCell(forwardPosition) == CellStatus.OBSTACLE
        and moveExecutioner.map:getCell(backPosition) ~= CellStatus.OBSTACLE
        and not (currentPosition.lat == 0 and currentDirection == Direction.NORTH)
        and not (currentPosition.lng == 0 and currentDirection == Direction.WEST)
end

function helpers.determineObstaclePosition (moveExecutioner, currentPosition, currentDirection, isObstacleToX, isRobotTurning)
    isObstacleToX = isObstacleToX or {left = false, right = false, front = false, back = false}
    isRobotTurning = isRobotTurning or false
    local currentAction = moveExecutioner.actions[1]
    local oldDirection = moveExecutioner.oldDirection

    local currentAxisOffset, otherAxisOffset = helpers.getAxisOffsets(moveExecutioner, oldDirection)
    local bounds = {
        mainAxisInBetweenNextCell = currentAxisOffset >= robot_parameters.squareSideDimension / 2,
        mainAxisInBetweenPreviousCell = currentAxisOffset <= -robot_parameters.squareSideDimension / 2,
        otherAxisInBetweenNextCell = otherAxisOffset >= robot_parameters.squareSideDimension / 2,
        otherAxisInBetweenPreviousCell = otherAxisOffset <= -robot_parameters.squareSideDimension / 2,
    }

    bounds.mainAxisInCell = not bounds.mainAxisInBetweenNextCell and not bounds.mainAxisInBetweenPreviousCell
    bounds.otherAxisInCell = not bounds.otherAxisInBetweenNextCell and not bounds.otherAxisInBetweenPreviousCell

    if currentAction == MoveAction.GO_AHEAD or currentAction == MoveAction.GO_BACK or currentAction == MoveAction.GO_BACK_BEFORE_TURNING then
        local nextPosition = MoveAction.nextPosition(currentPosition, currentDirection, currentAction)
        if bounds.otherAxisInBetweenNextCell then
            return {
                nextPosition,
                MoveAction.nextPosition(nextPosition, currentDirection, MoveAction.TURN_RIGHT)
            }
        elseif bounds.otherAxisInBetweenPreviuosCell then
            return {
                nextPosition,
                MoveAction.nextPosition(nextPosition, currentDirection, MoveAction.TURN_LEFT)
            }
        else
            return { nextPosition }
        end
    else

        local oppositeAction = MoveAction.TURN_RIGHT
        if currentAction == MoveAction.TURN_RIGHT then
            oppositeAction = MoveAction.TURN_LEFT
        end

        local turnCell = MoveAction.nextPosition(currentPosition, oldDirection, currentAction)
        local oppositeTurnCell = MoveAction.nextPosition(currentPosition, oldDirection, oppositeAction)
        local upperCell = MoveAction.nextPosition(currentPosition, oldDirection, MoveAction.GO_AHEAD)
        local lowerCell = MoveAction.nextPosition(currentPosition, oldDirection, MoveAction.GO_BACK)
        local upperTurnCell = MoveAction.nextPosition(upperCell, oldDirection, currentAction)
        local lowerTurnCell = MoveAction.nextPosition(lowerCell, oldDirection, currentAction)
        local oppositeUpperTurnCell = MoveAction.nextPosition(upperCell, oldDirection, oppositeAction)

        if bounds.mainAxisInCell and bounds.otherAxisInCell then
            if currentDirection ~= oldDirection 
                and helpers.isObstacleInSameTurnDirection(isObstacleToX, currentAction) then
                return { turnCell }
            else
                return { upperCell }
            end
        elseif bounds.mainAxisInBetweenNextCell and bounds.otherAxisInCell then
            if helpers.isObstacleInSameTurnDirection(isObstacleToX, currentAction) and currentDirection == oldDirection
                or (not helpers.isObstacleInSameTurnDirection(isObstacleToX, currentAction) and currentDirection ~= oldDirection)  then
                return { upperTurnCell }
            elseif helpers.isObstacleInSameTurnDirection(isObstacleToX, currentAction) then
                return {turnCell}
            else
                return { upperCell }
            end
        elseif bounds.mainAxisInBetweenPreviousCell and bounds.otherAxisInCell then
            if helpers.isObstacleInSameTurnDirection(isObstacleToX, currentAction) and currentDirection == oldDirection
                or (not helpers.isObstacleInSameTurnDirection(isObstacleToX, currentAction) and currentDirection ~= oldDirection)  then
                return { turnCell }
            elseif helpers.isObstacleInSameTurnDirection(isObstacleToX, currentAction) then
                return {lowerTurnCell}
            else
                return { currentPosition }
            end
        elseif bounds.otherAxisInBetweenNextCell and bounds.mainAxisInCell then
            if helpers.isObstacleInSameTurnDirection(isObstacleToX, currentAction) then
                return { turnCell }
            elseif helpers.isObstacleInTheOppositeTurnDirection(isObstacleToX, currentAction)
                and currentDirection == oldDirection then
                return { upperCell }
            elseif helpers.isObstacleInTheOppositeTurnDirection(isObstacleToX, currentAction) then
                return {upperTurnCell}
            elseif isObstacleToX.front and currentDirection == oldDirection then
                return { upperCell, upperTurnCell }
            else
                return { upperTurnCell, turnCell }
            end
        elseif bounds.otherAxisInBetweenPreviousCell and bounds.mainAxisInCell then
            if helpers.isObstacleInSameTurnDirection(isObstacleToX, currentAction) then
                return { currentPosition }
            elseif helpers.isObstacleInTheOppositeTurnDirection(isObstacleToX, currentAction)
                and currentDirection == oldDirection then
                return { oppositeUpperTurnCell }
            elseif helpers.isObstacleInTheOppositeTurnDirection(isObstacleToX, currentAction) then
                return {upperCell}
            elseif isObstacleToX.front and currentDirection == oldDirection then
                return { upperCell, oppositeUpperTurnCell }
            else
                return { upperCell, currentPosition }
            end
        elseif bounds.mainAxisInBetweenNextCell and bounds.otherAxisInBetweenNextCell then
            if helpers.isObstacleInSameTurnDirection(isObstacleToX, currentAction)
                and currentDirection == oldDirection then
                return { upperTurnCell }
            elseif helpers.isObstacleInSameTurnDirection(isObstacleToX, currentAction) then
                return { turnCell }
            elseif helpers.isObstacleInTheOppositeTurnDirection(isObstacleToX, currentAction)
                and currentDirection == oldDirection then
                return { upperCell }
            elseif helpers.isObstacleInTheOppositeTurnDirection(isObstacleToX, currentAction) then
                return {upperTurnCell}
            elseif isObstacleToX.front and currentDirection == oldDirection then
                return { upperCell, upperTurnCell }
            else
                return { turnCell, upperTurnCell }
            end
        elseif bounds.mainAxisInBetweenPreviousCell and bounds.otherAxisInBetweenPreviousCell then
            if helpers.isObstacleInSameTurnDirection(isObstacleToX, currentAction)
                and currentDirection == oldDirection then
                return { currentPosition }
            elseif helpers.isObstacleInSameTurnDirection(isObstacleToX, currentAction) then
                return { lowerCell }
            elseif helpers.isObstacleInTheOppositeTurnDirection(isObstacleToX, currentAction)
                and currentDirection == oldDirection then
                return { oppositeTurnCell }
            elseif helpers.isObstacleInTheOppositeTurnDirection(isObstacleToX, currentAction) then
                return {currentPosition}
            elseif isObstacleToX.front and currentDirection == oldDirection then
                return { currentPosition, oppositeTurnCell }
            else
                return { currentPosition, lowerCell }
            end
        elseif bounds.mainAxisInBetweenNextCell and bounds.otherAxisInBetweenPreviousCell then
            if helpers.isObstacleInSameTurnDirection(isObstacleToX, currentAction) and currentDirection == oldDirection
                or (not helpers.isObstacleInSameTurnDirection(isObstacleToX, currentAction) and currentDirection ~= oldDirection) then
                return { upperCell }
            elseif helpers.isObstacleInSameTurnDirection(isObstacleToX, currentAction) then
                return {currentPosition}
            elseif helpers.isObstacleInTheOppositeTurnDirection(isObstacleToX, currentAction) then
                return {oppositeUpperTurnCell}
            else
                return { upperCell, upperTurnCell }
            end
        else
            if helpers.isObstacleInSameTurnDirection(isObstacleToX, currentAction)
                and currentDirection == oldDirection then
                return { turnCell }
            elseif helpers.isObstacleInSameTurnDirection(isObstacleToX, currentAction) then
                return { lowerTurnCell }
            elseif helpers.isObstacleInTheOppositeTurnDirection(isObstacleToX, currentAction)
                and currentDirection == oldDirection then
                return { currentPosition }
            elseif helpers.isObstacleInTheOppositeTurnDirection(isObstacleToX, currentAction) then
                return {turnCell}
            elseif isObstacleToX.front and currentDirection == oldDirection then
                return { currentPosition, turnCell }
            else
                return { turnCell, lowerTurnCell }
            end
        end
    end
end

return helpers