require 'math'

-- battery constants
local BATTERY_STEP_DECREASE_FREQUENCY = 40
local BATTERY_STEP_INCREASE_FREQUENCY = 20

-- temperature sensor constants
local TEMPERATURE_STEP_CHANGE_FREQUENCY = 50
local MAX_TEMPERATURE_CHANGE = 5
local TEMPERATURE_INCREASE_PROBABILITY = 0.8
local MAX_TEMPERATURE_IN_ROOM = 60;

-- compass sensors constants
local UPPER_NORTH_BOUND = 180.2;
local LOWER_NORTH_BOUND = 179.8;
local UPPER_WEST_BOUND = 270.2;
local LOWER_WEST_BOUND = 269.8;
local UPPER_SOUTH_BOUND_1 = 360.2;
local LOWER_SOUTH_BOUND_1 = 359.8;
local UPPER_SOUTH_BOUND_2 = 0.2;
local LOWER_SOUTH_BOUND_2 = 0;
local UPPER_EAST_BOUND = 90.2;
local LOWER_EAST_BOUND = 89.8;

local commons = require 'commons'
local Direction = commons.Direction

Sensors = {}

Sensors.Battery = {

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
        if not self.recharge then
           self.stepCount = 0
        end
        self.recharge = true;
    end;

    useMode = function (self)
        if self.recharge then
            self.stepCount = 0
         end
        self.recharge = false;
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
}

Sensors.TemperatureSensor = {

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
}

Sensors.DirtDetector = {

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

Sensors.Compass = {
    new = function(self, robot)
        local o = {
            robot = robot
        }
        setmetatable(o, self)
        self.__index = self
        return o
    end;

    getCurrentDirection = function (self)
        local angle = math.deg(self.robot.positioning.orientation:toangleaxis())
        if angle >= LOWER_NORTH_BOUND and angle <= UPPER_NORTH_BOUND then
            return Direction.NORTH
        elseif angle > UPPER_NORTH_BOUND and angle < LOWER_WEST_BOUND then
            return Direction.NORTH_WEST
        elseif angle >= LOWER_WEST_BOUND and angle <= UPPER_WEST_BOUND then
            return Direction.WEST
        elseif angle > UPPER_WEST_BOUND and angle < LOWER_SOUTH_BOUND_2 then
            return Direction.SOUTH_WEST
        elseif (angle >= LOWER_SOUTH_BOUND_1 and angle <= UPPER_SOUTH_BOUND_1) or (angle >= LOWER_SOUTH_BOUND_2 and angle <= UPPER_SOUTH_BOUND_2) then
            return Direction.SOUTH
        elseif angle > UPPER_SOUTH_BOUND_2 and angle < LOWER_EAST_BOUND then
            return Direction.SOUTH_EAST
        elseif angle >= LOWER_EAST_BOUND and angle <= UPPER_EAST_BOUND then
            return Direction.EAST
        else
            return Direction.NORTH_EAST
        end
    end
}

return Sensors