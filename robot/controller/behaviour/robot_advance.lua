local Action = require('robot.commons').Action

RobotAdvance = {

    new = function (self)
        local o = {}
        setmetatable(o, self)
        self.__index = self
        return o
    end,

    tick = function (_, _)
        return Action.goAhead()
    end

}

return RobotAdvance;