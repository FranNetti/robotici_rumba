local Position = require('util.commons').Position
local Direction = require('util.commons').Direction

Action = {
    GO_AHEAD = "GO AHEAD",
    TURN_LEFT = "TURN LEFT",
    TURN_RIGHT = "TURN RIGHT",
    GO_BACK = "GO BACK",
    GO_BACK_BEFORE_TURNING = "GO BACK BEFORE TURNING",

    nextPosition = function (currentPosition, direction, move)
        if move == Action.GO_AHEAD then
            if direction == Direction.NORTH then
                return Position:new(currentPosition.lat + 1, currentPosition.lng)
            elseif direction == Direction.SOUTH then
                return Position:new(currentPosition.lat - 1, currentPosition.lng)
            elseif direction == Direction.WEST then
                return Position:new(currentPosition.lat, currentPosition.lng + 1)
            else
                return Position:new(currentPosition.lat, currentPosition.lng - 1)
            end
        elseif move == Action.GO_BACK or move == Action.GO_BACK_BEFORE_TURNING then
            if direction == Direction.NORTH then
                return Position:new(currentPosition.lat - 1, currentPosition.lng)
            elseif direction == Direction.SOUTH then
                return Position:new(currentPosition.lat + 1, currentPosition.lng)
            elseif direction == Direction.WEST then
                return Position:new(currentPosition.lat, currentPosition.lng - 1)
            else
                return Position:new(currentPosition.lat, currentPosition.lng + 1)
            end
        elseif  move == Action.TURN_LEFT then
            if direction == Direction.NORTH then
                return Position:new(currentPosition.lat, currentPosition.lng + 1)
            elseif direction == Direction.WEST then
                return Position:new(currentPosition.lat - 1, currentPosition.lng)
            elseif direction == Direction.SOUTH then
                return Position:new(currentPosition.lat, currentPosition.lng - 1)
            else
                return Position:new(currentPosition.lat + 1, currentPosition.lng)
            end
        else
            if direction == Direction.NORTH then
                return Position:new(currentPosition.lat, currentPosition.lng - 1)
            elseif direction == Direction.WEST then
                return Position:new(currentPosition.lat + 1, currentPosition.lng)
            elseif direction == Direction.SOUTH then
                return Position:new(currentPosition.lat, currentPosition.lng + 1)
            else
                return Position:new(currentPosition.lat - 1, currentPosition.lng)
            end
        end
    end,

    nextDirection = function (direction, move)
        if move == Action.GO_AHEAD or move == Action.GO_BACK or move == Action.GO_BACK_BEFORE_TURNING then
            return direction
        elseif  move == Action.TURN_LEFT then
            if direction == Direction.NORTH then
                return Direction.WEST
            elseif direction == Direction.WEST then
                return Direction.SOUTH
            elseif direction == Direction.SOUTH then
                return Direction.EAST
            else
                return Direction.NORTH
            end
        else
            if direction == Direction.NORTH then
                return Direction.EAST
            elseif direction == Direction.WEST then
                return Direction.NORTH
            elseif direction == Direction.SOUTH then
                return Direction.WEST
            else
                return Direction.SOUTH
            end
        end
    end

}

return Action
