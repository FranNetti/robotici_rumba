local Direction = require('util.commons').Direction
local Set = require('util.set')

local ExcludeOption = require('robot.controller.planner.exclude_option')
local CollisionAvoidanceBehaviour = require('robot.controller.behaviour.collision_avoidance.collision_avoidance')

local utils = {}

function utils.discreteDirection(robotDirection)
    local angle = robotDirection.angle
    local direction = robotDirection.direction

    if direction == Direction.NORTH or direction == Direction.SOUTH
          or direction == Direction.EAST or direction == Direction.WEST then
            return direction
        elseif direction == Direction.NORTH_WEST then
            if math.abs(angle - Direction.NORTH.ranges[3]) < math.abs(angle - Direction.WEST.ranges[2]) then
                return Direction.NORTH
            else
                return Direction.WEST
            end
        elseif direction == Direction.SOUTH_WEST then
            if math.abs(angle - Direction.WEST.ranges[1]) < math.abs(angle - Direction.SOUTH.ranges[2]) then
                return Direction.WEST
            else
                return Direction.SOUTH
            end
        elseif direction == Direction.SOUTH_EAST then
            if math.abs(angle - Direction.SOUTH.ranges[1]) < math.abs(angle - Direction.EAST.ranges[2]) then
                return Direction.SOUTH
            else
                return Direction.EAST
            end
        else
            if angle > 0 and math.abs(angle - Direction.EAST.ranges[1]) < math.abs(angle - Direction.NORTH.ranges[2]) then
                return Direction.EAST
            else
                return Direction.NORTH
            end
        end
end

function utils.getExcludedOptionsByState(state)
    local excludedOptions = Set:new{}
    --[[ if not CollisionAvoidanceBehaviour.isObjectInFrontRange(state.proximity) then
        excludedOptions = Set:new{ExcludeOption.EXCLUDE_LEFT, ExcludeOption.EXCLUDE_RIGHT}
    end ]]
    return excludedOptions
end

return utils