local commons = require 'util/commons'
local Set = require 'util/set'

local Action = (require 'robot/commons').Action

local CLOSE_OBJECT_MIN_DISTANCE_FRONT_LEFT = 0.1;
local CLOSE_OBJECT_MIN_DISTANCE_FRONT_RIGHT = 0.2;
local TURNING_SPEED = 5;

ObstacleAvoidance = {

    new = function (self)
        local o = {
            -- behaviours = behaviours
        }
        setmetatable(o, self)
        self.__index = self
        return o
    end,

    tick = function (self, state)
        local isCloseToObject =
            self:isObjectInRange(state.proximity, 1, 4, CLOSE_OBJECT_MIN_DISTANCE_FRONT_LEFT)
            or self:isObjectInRange(state.proximity, 22, 24, CLOSE_OBJECT_MIN_DISTANCE_FRONT_RIGHT)
        --commons.stringify(list)
        if isCloseToObject then
            return Action:new({
                speed = {left = 0, right = TURNING_SPEED}
            }, {1})
        end
        return Action:new({})
    end,

    isObjectInRange = function (_, proximityList, startIndex, endIndex, value)
        if startIndex < 1 or endIndex > #proximityList then
            error("Wrong indexes! [" .. startIndex .. " | " .. endIndex .. "]")
        end
        for i = startIndex, endIndex do
            if proximityList[i].value > value then
                return true
            end
        end
        return false
        
    end,

    getIndexOfCloseObjects = function(_, proximityList)
        local proximity = {}
        for i = 1, #proximityList do
            if proximityList[i].value > CLOSE_OBJECT_MIN_DISTANCE then
                table.insert( proximity, i)
            end
        end
        return proximity
    end

}

return ObstacleAvoidance;