local MoveAction = require('robot.controller.planner.move_action')
local planner_helpers = require('robot.controller.planner.helpers')
local controller_utils = require('robot.controller.utils')
local Planner = require('robot.controller.planner.planner')
local CellStatus = require('robot.controller.map.cell_status')
local Position = require('util.commons').Position
local Pair = require('extensions.lua.pair')
local logger = require('util.logger')
local a_star = require('extensions.luagraphs.shortest_paths.a_star')
local CollisionAvoidanceBehaviour = require('robot.controller.behaviour.collision_avoidance.collision_avoidance')

local helpers = {}

local K_ROUTES = 4
local OBSTACLE_CELL_COST = 5000000000
local CELL_TO_EXPLORE_COST = 50

function helpers.countNumberOfTurns(list)
    local count = 0
    for i = 1, #list do
        if list[i] == MoveAction.TURN_LEFT or list[i] == MoveAction.TURN_RIGHT then
            count = count + 1
        end
    end
    return count
end

function helpers.getFastestRoute(yen, map, state, lastAction, obstacleEncountered)
    obstacleEncountered = obstacleEncountered or false
    local currentDirection = controller_utils.discreteDirection(state.robotDirection)
    local excludedOptions = controller_utils.getExcludedOptionsByState(state)
    if obstacleEncountered and lastAction ~= nil then
        excludedOptions = controller_utils.getExcludedOptionsAfterObstacle(lastAction, state)
    end

    local excludePositions = planner_helpers.determinePositionsToExclude(
        excludedOptions,
        map.position,
        currentDirection,
        function (lat, lng)
            return Position:new(lat, lng)
        end
    )
    excludePositions:add(MoveAction.nextPosition(map.position, currentDirection, MoveAction.GO_BACK))

    local paths = yen:getKPath(
		map.position,
        Position:new(0,0),
        K_ROUTES,
        excludePositions:toList(),
        function (pointA, pointB)

            local x1, y1 = Planner.decodeCoordinates(pointA)
            local x2, y2 = Planner.decodeCoordinates(pointB)

            if map.map[x1][y1] == CellStatus.OBSTACLE or map.map[x2][y2] == CellStatus.OBSTACLE then
                return OBSTACLE_CELL_COST
            end

            local cost = a_star.manhattanDistance(x1, y1, x2, y2)
            --[[
                avoid cells yet to explore because anything can happen and the robot
                wants to quickly reach home with less possible problems
            ]]
            if map.map[x1][y1] == CellStatus.TO_EXPLORE or map.map[x2][y2] == CellStatus.TO_EXPLORE then
                return CELL_TO_EXPLORE_COST
            else
                return cost
            end
        end
	)

    local actions = {}
    local min = Pair:new(100, 1)
    for i = 1, K_ROUTES do
        local listOfActions = planner_helpers.determineActions(
            paths[i],
            currentDirection,
            Planner.decodeCoordinates
        )
        local count = helpers.countNumberOfTurns(listOfActions)
        table.insert(actions, listOfActions)
        if count < min.first then
            min = Pair:new(count, i)
        end
    end

    return actions[min.second]
end

function helpers.isRobotCloseToObstacle(state)
    return CollisionAvoidanceBehaviour.isObjectInLeftRange(state.proximity)
        or CollisionAvoidanceBehaviour.isObjectInRightRange(state.proximity)
        or CollisionAvoidanceBehaviour.isObjectInFrontRange(state.proximity)
end


return helpers