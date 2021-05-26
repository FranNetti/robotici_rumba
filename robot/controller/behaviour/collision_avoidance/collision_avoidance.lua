local Action = require('robot.commons').Action
local Color = require('util.commons').Color
local logger = require('util.logger')

local CLOSE_OBJECT_FRONT_DISTANCE_LIST = {
    0.75,
    0.7,
    0.7,
    0.75,
};
local CLOSE_OBJECT_HORIZONTAL_DISTANCE_LIST = {
    0.85,
    0.85,
    0.85,
    0.85
}

local function printObstacleDetected(where, proximityList, indexStart, indexEnd, printMessage)
    printMessage = printMessage or true
    if printMessage then
        logger.printToConsole("Obstacle detected " .. where .. "!")
    end
    for i = indexStart, indexEnd do
        logger.printToConsole("[" .. i .. "]" .. " - " .. proximityList[i].value)
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
            logger.printToConsole("----------------")
            return Action.stayStill({
                leds = {switchedOn = true, color = Color.YELLOW}
            }, {1})
        elseif self.isObjectInLeftRange(state.proximity) then
            printObstacleDetected('to the left', state.proximity, 3, 6)
            logger.printToConsole("----------------")
            return Action.stayStill({
                leds = {switchedOn = true, color = Color.YELLOW}
            }, {1})
        elseif self.isObjectInRightRange(state.proximity) then
            printObstacleDetected('to the right', state.proximity, 19, 22)
            logger.printToConsole("----------------")
            return Action.stayStill({
                leds = {switchedOn = true, color = Color.YELLOW}
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