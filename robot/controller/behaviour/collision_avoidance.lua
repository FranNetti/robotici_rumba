local Action = (require 'robot.commons').Action

local CLOSE_OBJECT_FRONT_DISTANCE = 0.1;
local CLOSE_OBJECT_LEFT_DISTANCE_LIST = {
    0.12661731817904,
    0.24415383842564,
    0.43023487292091,
    0.62871477474858,
}

CollisionAvoidance = {

    new = function (self)
        local o = {}
        setmetatable(o, self)
        self.__index = self
        return o
    end,

    tick = function (self, state)
        local isCloseToObject =
            self:isObjectInFrontRange(state.proximity) or self:isObjectInLeftRange(state.proximity)
        if isCloseToObject then
            return Action:new({
                speed = {left = 0, right = 0}
            }, {1})
        end
        return Action:new({})
    end,

    isObjectInFrontRange = function (_, proximityList)
        return proximityList[1].value > CLOSE_OBJECT_FRONT_DISTANCE
            or proximityList[2].value > CLOSE_OBJECT_FRONT_DISTANCE
            or proximityList[24].value > CLOSE_OBJECT_FRONT_DISTANCE
            or proximityList[23].value > CLOSE_OBJECT_FRONT_DISTANCE
    end,

    isObjectInLeftRange = function (_, proximityList)
        for i=3,6 do
            if proximityList[i].value > CLOSE_OBJECT_LEFT_DISTANCE_LIST[i - 2] then
                return true
            end
        end
        return false
    end,

}

return CollisionAvoidance;