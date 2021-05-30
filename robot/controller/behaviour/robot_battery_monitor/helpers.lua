local MoveAction = require('robot.controller.planner.move_action')
local planner_helpers = require('robot.controller.planner.helpers')
local controller_utils = require('robot.controller.utils')
local Planner = require('robot.controller.planner.planner')
local Position = require('util.commons').Position
local Pair = require('extensions.lua.pair')

local helpers = {}

local K_ROUTES = 4

function helpers.countNumberOfTurns(list)
    local count = 0
    for i = 1, #list do
        if list[i] == MoveAction.TURN_LEFT or list[i] == MoveAction.TURN_RIGHT then
            count = count + 1
        end
    end
    return count
end

function helpers.getFastestRoute(yen, state, currentPosition)
    local currentDirection = controller_utils.discreteDirection(state.robotDirection)
    local excludePositions = planner_helpers.determinePositionsToExclude(
        controller_utils.getExcludedOptionsByState(state),
        currentPosition,
        currentDirection,
        Planner.encodeCoordinates
    )
    table.insert(excludePositions, MoveAction.nextPosition(currentPosition, currentDirection, MoveAction.GO_BACK))

    local paths = yen:getKPath(
		currentPosition,
        Position:new(0,0),
        K_ROUTES,
        excludePositions
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


return helpers