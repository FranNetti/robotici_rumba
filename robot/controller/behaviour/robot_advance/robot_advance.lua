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

local directionOffsets = {
    NORTH = {180.2, 179.8, -179.8, -180.2, 180, -180},
    WEST  = {-89.8, -90.2, -90},
    SOUTH = {0.2, -0.2, 0},
    EAST = {90.2, 89.8, 90},
}

local function inDirectionSpace(angle)
    return (angle >= directionOffsets.NORTH[2] and angle <= directionOffsets.NORTH[1])
      or (angle >= directionOffsets.NORTH[4] and angle <= directionOffsets.NORTH[3])
      or (angle >= directionOffsets.WEST[2] and angle <= directionOffsets.WEST[1])
      or (angle >= directionOffsets.SOUTH[2] and angle <= directionOffsets.SOUTH[1])
      or (angle >= directionOffsets.EAST[2] and angle <= directionOffsets.EAST[1])
end

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
        if inDirectionSpace(angle) then
            return Action.goAhead()
        elseif direction == Direction.NORTH_WEST
          or (direction == Direction.NORTH and angle > directionOffsets.NORTH[6])
          or (direction == Direction.WEST and angle < directionOffsets.WEST[3]) then
            if math.abs(angle - directionOffsets.NORTH[3]) < math.abs(angle - directionOffsets.WEST[2]) then
                return turnSlightlyRight
            else
                return turnSlightlyLeft
            end
        elseif direction == Direction.SOUTH_WEST
          or (direction == Direction.WEST and angle > directionOffsets.WEST[3])
          or (direction == Direction.SOUTH and angle < directionOffsets.SOUTH[3]) then
            if math.abs(angle - directionOffsets.WEST[1]) < math.abs(angle - directionOffsets.SOUTH[2]) then
                return turnSlightlyRight
            else
                return turnSlightlyLeft
            end
        elseif direction == Direction.SOUTH_EAST
          or (direction == Direction.SOUTH and angle > directionOffsets.SOUTH[3])
          or (direction == Direction.EAST and angle < directionOffsets.EAST[3]) then
            if math.abs(angle - directionOffsets.SOUTH[1]) < math.abs(angle - directionOffsets.EAST[2]) then
                return turnSlightlyRight
            else
                return turnSlightlyLeft
            end
        else
            if angle > 0 and math.abs(angle - directionOffsets.EAST[1]) < math.abs(angle - directionOffsets.NORTH[2]) then
                return turnSlightlyRight
            else
                return turnSlightlyLeft
            end
        end
    end

}

return RobotAdvance;