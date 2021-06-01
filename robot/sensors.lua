require 'math'

local commons = require('util.commons')
local logger = require('util.logger')
local LogLevel = logger.LogLevel
local Direction = commons.Direction

Sensors = {}

Sensors.Battery = {

    -- battery constants
    BATTERY_STEP_DECREASE_FREQUENCY = 40,
    BATTERY_STEP_INCREASE_FREQUENCY = 10,
    BATTERY_MAX_VALUE = 60,

    new = function(self)
        local o = {
            batteryLevel = Sensors.Battery.BATTERY_MAX_VALUE;
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
        if self.recharge and (self.stepCount % self.BATTERY_STEP_INCREASE_FREQUENCY == 0) then
            self.batteryLevel = self.batteryLevel + 1;
            if self.batteryLevel > self.BATTERY_MAX_VALUE then self.batteryLevel = self.BATTERY_MAX_VALUE end
            logger.print("---- [Battery Charging]... " .. self.batteryLevel .. "V ----", LogLevel.INFO)
        elseif not self.recharge and (self.stepCount % self.BATTERY_STEP_DECREASE_FREQUENCY == 0) then
            self.batteryLevel = self.batteryLevel - 1;
            if self.batteryLevel < 0 then self.batteryLevel = 0 end
            logger.print("----  [Battery Charge] " .. self.batteryLevel .. "V ----", LogLevel.INFO)
        end
    end;
}

Sensors.TemperatureSensor = {

    -- temperature sensor constants
    TEMPERATURE_STEP_CHANGE_FREQUENCY = 50,
    MAX_TEMPERATURE_CHANGE = 5,
    TEMPERATURE_INCREASE_PROBABILITY = 0.6,
    MAX_TEMPERATURE_IN_ROOM = 35,

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
        if self.stepCount % self.TEMPERATURE_STEP_CHANGE_FREQUENCY == 0 then
            local newValue = math.random(self.MAX_TEMPERATURE_CHANGE)
            local isTemperatureIncreasing = math.random() < self.TEMPERATURE_INCREASE_PROBABILITY
            if isTemperatureIncreasing then
                self.temperature = self.temperature + newValue
            else
                self.temperature = self.temperature - newValue
            end

            if self.temperature > self.MAX_TEMPERATURE_IN_ROOM then
                self.temperature = self.MAX_TEMPERATURE_IN_ROOM
            elseif self.temperature < 0 then
                self.temperature = 0
            end

            logger.print("---- [Room temperature] " .. self.temperature .. "°C ----", LogLevel.INFO)
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