-- battery constants
local BATTERY_STEP_DECREASE_FREQUENCY = 40
local BATTERY_STEP_INCREASE_FREQUENCY = 20

-- temperature sensor constants
local TEMPERATURE_STEP_CHANGE_FREQUENCY = 50
local MAX_TEMPERATURE_CHANGE = 5
local TEMPERATURE_INCREASE_PROBABILITY = 0.8
local MAX_TEMPERATURE_IN_ROOM = 60;

local commons = require 'commons'

Sensors = {
    Battery = {

        new = function(self)
            local o = {
                percentage = 100;
                recharge = false;
                stepCount = 0;
            }
            setmetatable(o, self)
            self.__index = self
            return o
        end;

        chargeMode = function(self)
            self.recharge = true;
            self.stepCount = 0;
        end;

        useMode = function (self)
            self.recharge = false;
            self.stepCount = 0;
        end;

        tick = function(self)
            self.stepCount = self.stepCount + 1;
            if self.recharge and (self.stepCount % BATTERY_STEP_INCREASE_FREQUENCY == 0) then
                self.percentage = self.percentage + 1;
            elseif not self.recharge and (self.stepCount % BATTERY_STEP_DECREASE_FREQUENCY == 0) then
                self.percentage = self.percentage - 1;
            end
            if self.percentage < 0 then self.percentage = 0
            elseif self.percentage > 100 then self.percentage = 100
            end
        end;
    },

    TemperatureSensor = {

        new = function(self, initialTemperature)
            local o = {
                temperature = initialTemperature;
                stepCount = 0;
            }
            setmetatable(o, self)
            self.__index = self
            return o
        end;

        tick = function(self)
            self.stepCount = self.stepCount + 1
            if self.stepCount % TEMPERATURE_STEP_CHANGE_FREQUENCY == 0 then
                local newValue = math.random(MAX_TEMPERATURE_CHANGE)
                local isTemperatureIncreasing = math.random() < TEMPERATURE_INCREASE_PROBABILITY
                if isTemperatureIncreasing then
                    self.temperature = self.temperature + newValue
                else
                    self.temperature = self.temperature - newValue
                end
            end
            if self.temperature > MAX_TEMPERATURE_IN_ROOM then
                self.temperature = MAX_TEMPERATURE_IN_ROOM
            elseif self.temperature < 0 then
                self.temperature = 0
            end
        end
    },

    DirtDetector = {

        --[[
            parameters
                areaList: DirtArea[]
        ]]
        new = function(self, areaList)
            local o = {
                areaList = areaList,
            }
            setmetatable(o, self)
            self.__index = self
            return o
        end;

        --[[
            parameters
                position: Position
            return
                if the sensor detected some dirt surface
        ]]
        detect = function(self, position)
            local length = #self.areaList
            for i=1,length do
                if commons.positionInDirtArea(position, self.areaList[i]) then
                    commons.log("-- Dirt detected dirt -- <" .. position.lat .. "|" .. position.lng .. ">")
                    return true
                end
            end
            return false
        end

    }
}

return Sensors