local Action = require('robot.commons').Action
local commons = require('util.commons')

local CLOSE_OBJECT_FRONT_DISTANCE_LIST = {
    0.75,
    0.85,
    0.85,
    0.75,
};
local CLOSE_OBJECT_HORIZONTAL_DISTANCE_LIST = {
    0.75,
    0.75,
    0.85,
    0.85
}

CollisionAvoidance = {

    new = function (self)
        local o = {}
        setmetatable(o, self)
        self.__index = self
        return o
    end,

    tick = function (self, state)
        --[[ local isCloseToObject =
            self.isObjectInFrontRange(state.proximity)
            or self.isObjectInLeftRange(state.proximity)
            or self.isObjectInRightRange(state.proximity)
        if isCloseToObject then

            commons.print("Obstacle encountered!!!")
            for i = 1, #state.proximity do
                commons.print("[" .. i .. "]" .. " - " .. state.proximity[i].value)
            end
            commons.print("----------------")

            return Action:new({
                speed = {left = 0, right = 0},
                leds = {switchedOn = true, color = commons.Color.YELLOW}
            }, {1})
        end ]]

        if self.isObjectInFrontRange(state.proximity) then
            commons.print("Obstacle detected in front!")
            for i = 1, 2 do
                commons.print("[" .. i .. "]" .. " - " .. state.proximity[i].value)
            end
            for i = 23, 24 do
                commons.print("[" .. i .. "]" .. " - " .. state.proximity[i].value)
            end
            commons.print("----------------")
            --[[ return Action:new({
                speed = {left = 0, right = 0},
                leds = {switchedOn = true, color = commons.Color.YELLOW}
            }, {1}) ]]
        elseif self.isObjectInLeftRange(state.proximity) then
            commons.print("Obstacle detected to the left!")
            for i = 3, 6 do
                commons.print("[" .. i .. "]" .. " - " .. state.proximity[i].value)
            end
            commons.print("----------------")
            return Action:new({
                speed = {left = 0, right = 0},
                leds = {switchedOn = true, color = commons.Color.YELLOW}
            }, {1})
        elseif self.isObjectInRightRange(state.proximity) then
                commons.print("Obstacle detected to the right!")
            for i = 19, 22 do
                commons.print("[" .. i .. "]" .. " - " .. state.proximity[i].value)
            end
            commons.print("----------------")
            return Action:new({
                speed = {left = 0, right = 0},
                leds = {switchedOn = true, color = commons.Color.YELLOW}
            }, {1})
        end

        return Action:new({})
    end,

    isObjectInFrontRange = function (proximityList)
        return proximityList[1].value > CLOSE_OBJECT_FRONT_DISTANCE_LIST[2]
            or proximityList[2].value > CLOSE_OBJECT_FRONT_DISTANCE_LIST[1]
            or proximityList[24].value > CLOSE_OBJECT_FRONT_DISTANCE_LIST[3]
            or proximityList[23].value > CLOSE_OBJECT_FRONT_DISTANCE_LIST[4]
    end,

    isObjectInLeftRange = function (proximityList)
        for i=3,6 do
            if proximityList[i].value > CLOSE_OBJECT_HORIZONTAL_DISTANCE_LIST[i - 2] then
                return true
            end
        end
        return false
    end,

    isObjectInRightRange = function (proximityList)
        for i=22, 19, -1 do
            if proximityList[i].value > CLOSE_OBJECT_HORIZONTAL_DISTANCE_LIST[23 - i] then
                return true
            end
        end
        return false
    end,

}

return CollisionAvoidance;