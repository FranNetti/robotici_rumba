local Action = require('robot.commons').Action
local parameters = require('robot.parameters')

RobotAdvance = {

    new = function (self)
        local o = {}
        setmetatable(o, self)
        self.__index = self
        return o
    end,

    tick = function (_, _)
        return Action:new {
            speed = {
                left = parameters.robotForwardSpeed,
                right = parameters.robotForwardSpeed
            }
        }
    end

}

return RobotAdvance;