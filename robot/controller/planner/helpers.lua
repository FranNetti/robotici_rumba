local MoveAction = require("robot.controller.planner.move_action")
local ExcludeOption = require('robot.controller.planner.exclude_option')
local CellStatus = require('robot.controller.map.cell_status')
local helpers = require ("robot.controller.move_executioner.helpers")
local aStar = require('extensions.luagraphs.shortest_paths.a_star')

local Set = require('util.set')
local Pair = require('extensions.lua.pair')
local commons = require('util.commons')
local logger = require('util.logger')
local Direction = commons.Direction
local Position = commons.Position

local helper = {}

helper.EXCLUDED_OPTIONS_COST = 9999999999
helper.BACK_OPTION_COST = helper.EXCLUDED_OPTIONS_COST * 2
helper.OBSTACLE_CELL_COST = helper.EXCLUDED_OPTIONS_COST * 3

helper.NUMBER_OF_ROUTES_TO_FIND = 4
helper.CELL_TO_EXPLORE_COST = 50

helper.MAX_HOME_DISTANCE = 4

function helper.determineActions(path, direction, coordinatesDecoder)
    local actions = {}
    local currentDirection = direction

    if path ~= nil then
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
    end
    return actions
end

function helper.determineEdgesToExclude(excludeOptions, currentPosition, currentDirection, coordinatesEncoder)
    local edgesExcluded = Set:new{}
    if excludeOptions ~= nil then
        for opt, _ in pairs(excludeOptions) do
            if currentDirection == Direction.NORTH then
                if opt == ExcludeOption.EXCLUDE_FRONT then
                    edgesExcluded:add(Pair:new(
                        coordinatesEncoder(currentPosition.lat, currentPosition.lng),
                        coordinatesEncoder(currentPosition.lat + 1, currentPosition.lng)
                    ):toString())
                elseif opt == ExcludeOption.EXCLUDE_BACK and currentPosition.lat ~= 0 then
                    edgesExcluded:add(Pair:new(
                        coordinatesEncoder(currentPosition.lat, currentPosition.lng),
                        coordinatesEncoder(currentPosition.lat - 1, currentPosition.lng)
                    ):toString())
                elseif opt == ExcludeOption.EXCLUDE_LEFT then
                    edgesExcluded:add(Pair:new(
                        coordinatesEncoder(currentPosition.lat, currentPosition.lng),
                        coordinatesEncoder(currentPosition.lat, currentPosition.lng + 1)
                    ):toString())
                elseif opt == ExcludeOption.EXCLUDE_RIGHT and currentPosition.lng ~= 0 then
                    edgesExcluded:add(Pair:new(
                        coordinatesEncoder(currentPosition.lat, currentPosition.lng),
                        coordinatesEncoder(currentPosition.lat, currentPosition.lng - 1)
                    ):toString())
                end
            elseif currentDirection == Direction.SOUTH then
                if opt == ExcludeOption.EXCLUDE_FRONT and currentPosition.lat ~= 0 then
                    edgesExcluded:add(Pair:new(
                        coordinatesEncoder(currentPosition.lat, currentPosition.lng),
                        coordinatesEncoder(currentPosition.lat - 1, currentPosition.lng)
                    ):toString())
                elseif opt == ExcludeOption.EXCLUDE_BACK then
                    edgesExcluded:add(Pair:new(
                        coordinatesEncoder(currentPosition.lat, currentPosition.lng),
                        coordinatesEncoder(currentPosition.lat + 1, currentPosition.lng)
                    ):toString())
                elseif opt == ExcludeOption.EXCLUDE_LEFT and currentPosition.lng ~= 0 then
                    edgesExcluded:add(Pair:new(
                        coordinatesEncoder(currentPosition.lat, currentPosition.lng),
                        coordinatesEncoder(currentPosition.lat, currentPosition.lng - 1)
                    ):toString())
                elseif opt == ExcludeOption.EXCLUDE_RIGHT then
                    edgesExcluded:add(Pair:new(
                        coordinatesEncoder(currentPosition.lat, currentPosition.lng),
                        coordinatesEncoder(currentPosition.lat, currentPosition.lng + 1)
                    ):toString())
                end
            elseif currentDirection == Direction.EAST then
                if opt == ExcludeOption.EXCLUDE_FRONT and currentPosition.lng ~=0 then
                    edgesExcluded:add(Pair:new(
                        coordinatesEncoder(currentPosition.lat, currentPosition.lng),
                        coordinatesEncoder(currentPosition.lat, currentPosition.lng - 1)
                    ):toString())
                elseif opt == ExcludeOption.EXCLUDE_BACK then
                    edgesExcluded:add(Pair:new(
                        coordinatesEncoder(currentPosition.lat, currentPosition.lng),
                        coordinatesEncoder(currentPosition.lat, currentPosition.lng + 1)
                    ):toString())
                elseif opt == ExcludeOption.EXCLUDE_LEFT then
                    edgesExcluded:add(Pair:new(
                        coordinatesEncoder(currentPosition.lat, currentPosition.lng),
                        coordinatesEncoder(currentPosition.lat + 1, currentPosition.lng)
                    ):toString())
                elseif opt == ExcludeOption.EXCLUDE_RIGHT and currentPosition.lat ~= 0  then
                    edgesExcluded:add(Pair:new(
                        coordinatesEncoder(currentPosition.lat, currentPosition.lng),
                        coordinatesEncoder(currentPosition.lat - 1, currentPosition.lng)
                    ):toString())
                end
            else
                if opt == ExcludeOption.EXCLUDE_FRONT then
                    edgesExcluded:add(Pair:new(
                        coordinatesEncoder(currentPosition.lat, currentPosition.lng),
                        coordinatesEncoder(currentPosition.lat, currentPosition.lng + 1)
                    ):toString())
                elseif opt == ExcludeOption.EXCLUDE_BACK and currentPosition.lng ~= 0 then
                    edgesExcluded:add(Pair:new(
                        coordinatesEncoder(currentPosition.lat, currentPosition.lng),
                        coordinatesEncoder(currentPosition.lat, currentPosition.lng - 1)
                    ):toString())
                elseif opt == ExcludeOption.EXCLUDE_LEFT and currentPosition.lat ~= 0 then
                    edgesExcluded:add(Pair:new(
                        coordinatesEncoder(currentPosition.lat, currentPosition.lng),
                        coordinatesEncoder(currentPosition.lat - 1, currentPosition.lng)
                    ):toString())
                elseif opt == ExcludeOption.EXCLUDE_RIGHT then
                    edgesExcluded:add(Pair:new(
                        coordinatesEncoder(currentPosition.lat, currentPosition.lng),
                        coordinatesEncoder(currentPosition.lat + 1, currentPosition.lng)
                    ):toString())
                end
            end
        end
    end
    return edgesExcluded
end

function helper.countNumberOfTurns(list)
    local count = 0
    for i = 1, #list do
        if list[i] == MoveAction.TURN_LEFT or list[i] == MoveAction.TURN_RIGHT then
            count = count + 1
        end
    end
    return count
end

function helper.heuristicFunction(planner, point, goal)
    local x1, y1 = planner.decodeCoordinates(point)
    local x2, y2 = planner.decodeCoordinates(goal)

    if planner.map[x1][y1] == CellStatus.OBSTACLE then
        return helper.OBSTACLE_CELL_COST
    else
        return aStar.manhattanDistance(x1, y1, x2, y2)
    end
end

function helper.isCloseToHomeDestination(currentPosition, destination, currentDirection)
    return destination == Position:new(0,0) and (
        currentPosition.lat == 0 and currentPosition.lng < helper.MAX_HOME_DISTANCE and currentDirection == Direction.WEST
        or currentPosition.lng == 0 and currentPosition.lat < helper.MAX_HOME_DISTANCE and currentDirection == Direction.NORTH
    )
end

function helper.getGoToHomeActions(currentPosition, currentDirection)
    local actions = {}
    if currentDirection == Direction.WEST then
        for _ = currentPosition.lng, 0, -1 do
            table.insert(actions, MoveAction.GO_BACK)
        end
    elseif currentDirection == Direction.NORTH then
        for _ = currentPosition.lng, 0, -1 do
            table.insert(actions, MoveAction.GO_BACK)
        end
    else
        return {}
    end
    logger.stringify(actions)
    return actions
end

return helper