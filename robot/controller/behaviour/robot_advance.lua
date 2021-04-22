local math = require('math')
local robot_parameters = require('robot.parameters')

local Action = require('robot.commons').Action
local Direction = require('util.commons').Direction

local turnSlightlyLeft = Action:new{
    speed = {left = robot_parameters.robotAdjustAngleSpeed, right = robot_parameters.robotForwardSpeed}
}

local turnSlightlyRight = Action:new{
    speed = {left = robot_parameters.robotForwardSpeed , right = robot_parameters.robotAdjustAngleSpeed}
}

RobotAdvance = {

    new = function (self)
        local o = {}
        setmetatable(o, self)
        self.__index = self
        return o
    end,

    tick = function (_, state)
        local direction = state.robotDirection.direction
        local angle = state.robotDirection.angle
        return Action.goAhead()
        --[[ if direction == Direction.NORTH or direction == Direction.SOUTH
          or direction == Direction.EAST or direction == Direction.WEST then
            return Action.goAhead()
        elseif direction == Direction.NORTH_WEST then
            if math.abs(angle - Direction.NORTH.ranges[3]) < math.abs(angle - Direction.WEST.ranges[2]) then
                return turnSlightlyRight
            else
                return turnSlightlyLeft
            end
        elseif direction == Direction.SOUTH_WEST then
            if math.abs(angle - Direction.WEST.ranges[1]) < math.abs(angle - Direction.SOUTH.ranges[2]) then
                return turnSlightlyRight
            else
                return turnSlightlyLeft
            end
        elseif direction == Direction.SOUTH_EAST then
            if math.abs(angle - Direction.SOUTH.ranges[1]) < math.abs(angle - Direction.EAST.ranges[2]) then
                return turnSlightlyRight
            else
                return turnSlightlyLeft
            end
        else
            if angle > 0 and math.abs(angle - Direction.WEST.ranges[1]) < math.abs(angle - Direction.NORTH.ranges[2]) then
                return turnSlightlyRight
            else
                return turnSlightlyLeft
            end
        end ]]
    end

}

return RobotAdvance;