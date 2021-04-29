local Action = require('robot.commons').Action
local commons = require('util.commons')

local CLOSE_OBJECT_FRONT_DISTANCE_LIST = {
    0.75,
    0.7,
    0.7,
    0.75,
};
local CLOSE_OBJECT_HORIZONTAL_DISTANCE_LIST = {
    0.75,
    0.75,
    0.85,
    0.85
}

local function printObstacleDetected(where, proximityList, indexStart, indexEnd, printMessage)
    printMessage = printMessage or true
    if printMessage then
        commons.printToConsole("Obstacle detected " .. where .. "!") 
    end
    for i = indexStart, indexEnd do
        commons.printToConsole("[" .. i .. "]" .. " - " .. proximityList[i].value)
    end
end

CollisionAvoidance = {

    new = function (self)
        local o = {}
        setmetatable(o, self)
        self.__index = self
        return o
    end,

    tick = function (self, state)
        if self.isObjectInFrontRange(state.proximity) then
            printObstacleDetected('in front', state.proximity, 1, 2)
            printObstacleDetected('in front', state.proximity, 23, 24, false)
            commons.printToConsole("----------------")
            return Action:new({
                speed = {left = 0, right = 0},
                leds = {switchedOn = true, color = commons.Color.YELLOW}
            }, {1})
        elseif self.isObjectInLeftRange(state.proximity) then
            printObstacleDetected('to the left', state.proximity, 3, 6)
            commons.printToConsole("----------------")
            return Action:new({
                speed = {left = 0, right = 0},
                leds = {switchedOn = true, color = commons.Color.YELLOW}
            }, {1})
        elseif self.isObjectInRightRange(state.proximity) then
            printObstacleDetected('to the right', state.proximity, 19, 22)
            commons.printToConsole("----------------")
            return Action:new({
                speed = {left = 0, right = 0},
                leds = {switchedOn = true, color = commons.Color.YELLOW}
            }, {1})
        end

        return Action:new({})
    end,

    isObjectInFrontRange = function (proximityList)
        return proximityList[2].value > CLOSE_OBJECT_FRONT_DISTANCE_LIST[1]
            or proximityList[1].value > CLOSE_OBJECT_FRONT_DISTANCE_LIST[2]
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

    isObjectInBackRange = function (proximityList)
        return proximityList[11].value > CLOSE_OBJECT_FRONT_DISTANCE_LIST[1]
            or proximityList[12].value > CLOSE_OBJECT_FRONT_DISTANCE_LIST[2]
            or proximityList[13].value > CLOSE_OBJECT_FRONT_DISTANCE_LIST[3]
            or proximityList[14].value > CLOSE_OBJECT_FRONT_DISTANCE_LIST[4]
    end,

}

return CollisionAvoidance;