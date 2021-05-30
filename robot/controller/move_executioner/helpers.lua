local helpers = {}

local MoveAction = require('robot.controller.planner.move_action')
local Direction = require('util.commons').Direction
local robot_parameters = require('robot.parameters')
local logger = require('util.logger')

local LEFT_DISTANCE_WHILE_GOING_STRAIGHT = 0.95
local RIGHT_DISTANCE_WHILE_GOING_STRAIGHT = 0.95

function helpers.isObstacleInTheOppositeDirection(isObstacleToX, currentDirection, currentAction, oldDirection)
    return currentDirection == oldDirection and isObstacleToX.front
        or currentAction == MoveAction.TURN_LEFT and isObstacleToX.right
        or currentAction == MoveAction.TURN_RIGHT and isObstacleToX.left
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

function helpers.determineObstaclePosition (moveExecutioner, currentPosition, currentDirection, isObstacleToX, isRobotTurning)
    isObstacleToX = isObstacleToX or {left = false, right = false, front = false, back = false}
    isRobotTurning = isRobotTurning or false
    local currentAction = moveExecutioner.actions[1]
    local oldDirection = moveExecutioner.oldDirection

    local currentAxisOffset, otherAxisOffset = helpers.getAxisOffsets(moveExecutioner, currentDirection)
    local bounds = {
        mainAxisInBetweenNextCell = currentAxisOffset >= robot_parameters.squareSideDimension / 2,
        mainAxisInBetweenPreviousCell = currentAxisOffset <= -robot_parameters.squareSideDimension / 2,
        otherAxisInBetweenNextCell = otherAxisOffset >= robot_parameters.squareSideDimension / 2,
        otherAxisInBetweenPreviousCell = otherAxisOffset <= -robot_parameters.squareSideDimension / 2,
    }

    bounds.mainAxisInCell = not bounds.mainAxisInBetweenNextCell and not bounds.mainAxisInBetweenPreviousCell
    bounds.otherAxisInCell = not bounds.otherAxisInBetweenNextCell and not bounds.otherAxisInBetweenPreviousCell

    logger.stringify(currentAction)
    logger.stringify(currentPosition)
    logger.stringify(currentDirection)
    logger.stringify(oldDirection)
    logger.stringify(isObstacleToX)
    logger.stringify(otherAxisOffset)
    logger.stringify(bounds)

    logger.stringify('----------------------------------')

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
        local upperCell = MoveAction.nextPosition(currentPosition, oldDirection, MoveAction.GO_AHEAD)
        local upperTurnCell = MoveAction.nextPosition(upperCell, oldDirection, currentAction)
        local oppositeTurnCell = MoveAction.nextPosition(currentPosition, oldDirection, oppositeAction)
        local oppositeUpperTurnCell = MoveAction.nextPosition(upperCell, oldDirection, oppositeAction)


        if bounds.mainAxisInCell and bounds.otherAxisInCell then
            if currentDirection ~= oldDirection and (currentAction == MoveAction.TURN_LEFT and isObstacleToX.left
                or currentAction == MoveAction.TURN_RIGHT and isObstacleToX.right) then
                return { turnCell }
            else
                return { upperCell }
            end
        elseif bounds.mainAxisInBetweenNextCell and bounds.otherAxisInCell then
            if currentAction == MoveAction.TURN_LEFT and isObstacleToX.left
                or currentAction == MoveAction.TURN_RIGHT and isObstacleToX.right then
                return { upperTurnCell }
            else
                return { upperCell }
            end
        elseif bounds.mainAxisInBetweenPreviousCell and bounds.otherAxisInCell then
            if currentAction == MoveAction.TURN_LEFT and isObstacleToX.left
                or currentAction == MoveAction.TURN_RIGHT and isObstacleToX.right then
                return { turnCell }
            else
                return { currentPosition }
            end
        elseif bounds.otherAxisInBetweenNextCell and bounds.mainAxisInCell then
            if currentAction == MoveAction.TURN_LEFT and isObstacleToX.left
                or currentAction == MoveAction.TURN_RIGHT and isObstacleToX.right then
                return { turnCell }
            elseif currentDirection ~= oldDirection then
                return { upperTurnCell }
            elseif isObstacleToX.front then
                return { upperCell, upperTurnCell }
            else
                return { upperCell }
            end
        elseif bounds.otherAxisInBetweenPreviousCell and bounds.mainAxisInCell then
            if currentAction == MoveAction.TURN_LEFT and isObstacleToX.left
                or currentAction == MoveAction.TURN_RIGHT and isObstacleToX.right then
                return { currentPosition }
            elseif currentDirection ~= oldDirection then
                return { upperCell }
            elseif isObstacleToX.front then
                return { upperCell, oppositeUpperTurnCell }
            else
                return { oppositeUpperTurnCell }
            end
        elseif bounds.mainAxisInBetweenNextCell and bounds.otherAxisInBetweenNextCell then
            if currentAction == MoveAction.TURN_LEFT and isObstacleToX.left
                or currentAction == MoveAction.TURN_RIGHT and isObstacleToX.right then
                return { upperTurnCell }
            elseif currentAction == MoveAction.TURN_LEFT and isObstacleToX.right
                or currentAction == MoveAction.TURN_RIGHT and isObstacleToX.left then
                return { upperCell }
            elseif currentDirection == oldDirection then
                return { upperCell, upperTurnCell }
            else
                return { turnCell, upperTurnCell }
            end
        elseif bounds.mainAxisInBetweenPreviousCell and bounds.otherAxisInBetweenPreviousCell then
            if currentAction == MoveAction.TURN_LEFT and isObstacleToX.left
                or currentAction == MoveAction.TURN_RIGHT and isObstacleToX.right
                or currentDirection ~= oldDirection then
                return { currentPosition }
            elseif isObstacleToX.front then
                return { currentPosition, oppositeTurnCell }
            else
                return { oppositeTurnCell }
            end
        elseif bounds.mainAxisInBetweenNextCell and bounds.otherAxisInBetweenPreviousCell then
            if currentAction == MoveAction.TURN_LEFT and isObstacleToX.left
                or currentAction == MoveAction.TURN_RIGHT and isObstacleToX.right then
                return { upperCell }
            elseif isObstacleToX.front and currentDirection ~= oldDirection then
                return { upperCell }
            elseif isObstacleToX.front then
                return { upperTurnCell }
            else
                return { oppositeUpperTurnCell }
            end
        else
            if currentAction == MoveAction.TURN_LEFT and isObstacleToX.left
                or currentAction == MoveAction.TURN_RIGHT and isObstacleToX.right
                or currentDirection ~= oldDirection then
                return { turnCell }
            elseif isObstacleToX.front then
                return { currentPosition, turnCell }
            else
                return { currentPosition }
            end
        end



        --[[ local rightPosition = MoveAction.nextPosition(currentPosition, currentDirection, MoveAction.TURN_RIGHT)
        local leftPosition = MoveAction.nextPosition(currentPosition, currentDirection, MoveAction.TURN_LEFT)
        if isRobotTurning and helpers.isObstacleInTheOppositeDirection(isObstacleToX, currentDirection, currentAction, oldDirection) then
            if isRobotInBetweenNextCell and currentAction == MoveAction.TURN_LEFT then
                return { rightPosition }
            elseif isRobotInBetweenPreviuosCell and currentAction == MoveAction.TURN_RIGHT then
                return { leftPosition }
            else
                return { currentPosition }
            end
        elseif isRobotTurning then
            if currentAction == MoveAction.TURN_RIGHT and ( isRobotInBetweenNextCell or not isRobotInBetweenPreviuosCell ) then
                return { rightPosition }
            elseif currentAction == MoveAction.TURN_LEFT and ( isRobotInBetweenPreviuosCell or not isRobotInBetweenNextCell ) then
                return { leftPosition }
            else
                return { currentPosition }
            end
        else
            if isObstacleToX.left and not isRobotInBetweenNextCell then
                return { leftPosition }
            elseif isObstacleToX.right and not isRobotInBetweenPreviuosCell then
                return { rightPosition }
            elseif isRobotInBetweenPreviuosCell or isRobotInBetweenNextCell then
                return { currentPosition }
            else
                return {
                    MoveAction.nextPosition(currentPosition, currentDirection, MoveAction.GO_AHEAD)
                }
            end
        end ]]
    end
end

return helpers