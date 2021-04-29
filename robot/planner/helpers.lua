local MoveAction = require("robot.planner.move_action")
local ExcludeOption = require('robot.planner.exclude_option')

local Set = require('util.set')
local commons = require('util.commons')
local Direction = commons.Direction

local helper = {}

helper.MAX_PATH_COST = 9999999999999999

function helper.determineActions(path, direction, coordinatesDecoder)
    local actions = {}
    local currentDirection = direction

    for i = 2, #path do
        local newLat, newLng = coordinatesDecoder(path[i])
        local oldLat, oldLng = coordinatesDecoder(path[i - 1])

        if oldLat == newLat and oldLng < newLng then

            if currentDirection == Direction.NORTH then
                table.insert(actions, MoveAction.TURN_LEFT)
                currentDirection = Direction.WEST
            elseif currentDirection == Direction.EAST then
                table.insert(actions, MoveAction.GO_BACK)
            elseif currentDirection == Direction.SOUTH then
                table.insert(actions, MoveAction.TURN_RIGHT)
                currentDirection = Direction.WEST
            else
                table.insert(actions, MoveAction.GO_AHEAD)
            end

        elseif oldLat == newLat and oldLng > newLng then

            if currentDirection == Direction.NORTH then
                table.insert(actions, MoveAction.TURN_RIGHT)
                currentDirection = Direction.EAST
            elseif currentDirection == Direction.EAST then
                table.insert(actions, MoveAction.GO_AHEAD)
            elseif currentDirection == Direction.SOUTH then
                table.insert(actions, MoveAction.TURN_LEFT)
                currentDirection = Direction.EAST
            else
                table.insert(actions, MoveAction.GO_BACK)
            end

        elseif oldLng == newLng and oldLat < newLat then

            if currentDirection == Direction.NORTH then
                table.insert(actions, MoveAction.GO_AHEAD)
            elseif currentDirection == Direction.EAST then
                table.insert(actions, MoveAction.TURN_LEFT)
                currentDirection = Direction.NORTH
            elseif currentDirection == Direction.SOUTH then
                table.insert(actions, MoveAction.GO_BACK)
            else
                table.insert(actions, MoveAction.TURN_RIGHT)
                currentDirection = Direction.NORTH
            end

        elseif oldLng == newLng and oldLat > newLat then

            if currentDirection == Direction.NORTH then
                table.insert(actions, MoveAction.GO_BACK)
            elseif currentDirection == Direction.EAST then
                table.insert(actions, MoveAction.TURN_RIGHT)
                currentDirection = Direction.SOUTH
            elseif currentDirection == Direction.SOUTH then
                table.insert(actions, MoveAction.GO_AHEAD)
            else
                table.insert(actions, MoveAction.TURN_LEFT)
                currentDirection = Direction.SOUTH
            end

        end
    end
    return actions
end

function helper.determinePositionsToExclude(excludeOptions, currentPosition, currentDirection, coordinatesEncoder)
    local positionExcluded = Set:new{}
    if excludeOptions ~= nil then
        for opt, _ in pairs(excludeOptions) do
            if currentDirection == Direction.NORTH then
                if opt == ExcludeOption.EXCLUDE_FRONT then
                    positionExcluded:add(coordinatesEncoder(currentPosition.lat + 1, currentPosition.lng))
                elseif opt == ExcludeOption.EXCLUDE_BACK and currentPosition.lat ~= 0 then
                    positionExcluded:add(coordinatesEncoder(currentPosition.lat - 1, currentPosition.lng))
                elseif opt == ExcludeOption.EXCLUDE_LEFT then
                    positionExcluded:add(coordinatesEncoder(currentPosition.lat, currentPosition.lng + 1))
                elseif opt == ExcludeOption.EXCLUDE_RIGHT and currentPosition.lng ~= 0 then
                    positionExcluded:add(coordinatesEncoder(currentPosition.lat, currentPosition.lng - 1))
                end
            elseif currentDirection == Direction.SOUTH and currentPosition.lat ~= 0 then
                if opt == ExcludeOption.EXCLUDE_FRONT then
                    positionExcluded:add(coordinatesEncoder(currentPosition.lat - 1, currentPosition.lng))
                elseif opt == ExcludeOption.EXCLUDE_BACK then
                    positionExcluded:add(coordinatesEncoder(currentPosition.lat + 1, currentPosition.lng))
                elseif opt == ExcludeOption.EXCLUDE_LEFT and currentPosition.lng ~= 0 then
                    positionExcluded:add(coordinatesEncoder(currentPosition.lat, currentPosition.lng - 1))
                elseif opt == ExcludeOption.EXCLUDE_RIGHT then
                    positionExcluded:add(coordinatesEncoder(currentPosition.lat, currentPosition.lng + 1))
                end
            elseif currentDirection == Direction.EAST then
                if opt == ExcludeOption.EXCLUDE_FRONT and currentPosition.lng ~=0 then
                    positionExcluded:add(coordinatesEncoder(currentPosition.lat, currentPosition.lng - 1))
                elseif opt == ExcludeOption.EXCLUDE_BACK then
                    positionExcluded:add(coordinatesEncoder(currentPosition.lat, currentPosition.lng + 1))
                elseif opt == ExcludeOption.EXCLUDE_LEFT then
                    positionExcluded:add(coordinatesEncoder(currentPosition.lat + 1, currentPosition.lng))
                elseif opt == ExcludeOption.EXCLUDE_RIGHT and currentPosition.lat ~= 0  then
                    positionExcluded:add(coordinatesEncoder(currentPosition.lat - 1, currentPosition.lng))
                end
            else
                if opt == ExcludeOption.EXCLUDE_FRONT then
                    positionExcluded:add(coordinatesEncoder(currentPosition.lat, currentPosition.lng + 1))
                elseif opt == ExcludeOption.EXCLUDE_BACK and currentPosition.lng ~= 0 then
                    positionExcluded:add(coordinatesEncoder(currentPosition.lat, currentPosition.lng - 1))
                elseif opt == ExcludeOption.EXCLUDE_LEFT and currentPosition.lat ~= 0 then
                    positionExcluded:add(coordinatesEncoder(currentPosition.lat - 1, currentPosition.lng))
                elseif opt == ExcludeOption.EXCLUDE_RIGHT then
                    positionExcluded:add(coordinatesEncoder(currentPosition.lat + 1, currentPosition.lng))
                end
            end
        end
    end
    return positionExcluded
end

return helper