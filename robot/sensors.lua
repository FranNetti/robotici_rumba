require 'math'

-- battery constants
local BATTERY_STEP_DECREASE_FREQUENCY = 40
local BATTERY_STEP_INCREASE_FREQUENCY = 20

-- temperature sensor constants
local TEMPERATURE_STEP_CHANGE_FREQUENCY = 50
local MAX_TEMPERATURE_CHANGE = 5
local TEMPERATURE_INCREASE_PROBABILITY = 0.8
local MAX_TEMPERATURE_IN_ROOM = 60;

local commons = require('util.commons')
local logger = require('util.logger')
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

    ---Create new Temperature sensor
    ---@param initialTemperature number the initial temperature of the room
    ---@return table a new temperature sensor
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

    ---Create a new Dirt Detector
    ---@param areaList table DirtArea[] the list of area where dirt is located
    ---@return table a new Dirt Detector
    new = function(self, areaList)
        local o = {
            areaList = areaList,
        }
        setmetatable(o, self)
        self.__index = self
        return o
    end;

    ---Detect if there is dirt in your position
    ---@param position table Position the position where you are
    ---@return boolean if the sensor detected some dirt surface
    detect = function(self, position)
        local length = #self.areaList
        for i=1,length do
            if commons.positionInDirtArea(position, self.areaList[i]) then
                logger.printToConsole("|| Dirt detected dirt in " .. position:toString() .. " ||")
                return true
            end
        end
        return false
    end

}

Sensors.Compass = {
    
    ---Create a new compass sensor
    ---@param robot any the robot of argos
    ---@return table a new compass sensor
    new = function(self, robot)
        local o = {
            robot = robot
        }
        setmetatable(o, self)
        self.__index = self
        return o
    end;

    ---Get the current robot direction
    ---@return table Direction
    getCurrentDirection = function (self)
        local angle = math.deg(self.robot.positioning.orientation:toeulerangles())
        local direction;
        if (angle >= Direction.NORTH.ranges[2] and angle <= Direction.NORTH.ranges[1])
          or (angle >= Direction.NORTH.ranges[4] and angle <= Direction.NORTH.ranges[3]) then
            direction = Direction.NORTH
        elseif angle > Direction.NORTH.ranges[3] and angle < Direction.WEST.ranges[2] then
            direction = Direction.NORTH_WEST
        elseif angle >= Direction.WEST.ranges[2] and angle <= Direction.WEST.ranges[1] then
            direction = Direction.WEST
        elseif angle > Direction.WEST.ranges[1] and angle < Direction.SOUTH.ranges[2] then
            direction = Direction.SOUTH_WEST
        elseif angle >= Direction.SOUTH.ranges[2] and angle <= Direction.SOUTH.ranges[1] then
            direction = Direction.SOUTH
        elseif angle > Direction.SOUTH.ranges[1] and angle < Direction.EAST.ranges[2] then
            direction = Direction.SOUTH_EAST
        elseif angle >= Direction.EAST.ranges[2] and angle <= Direction.EAST.ranges[1] then
            direction = Direction.EAST
        else
            direction = Direction.NORTH_EAST
        end
        return {
            direction = direction,
            angle = angle
        }
    end
}

return Sensors