local robot_parameters = require('robot.parameters')

Robot = {}

Robot.State = {

    ---create new state
    ---@param data table {
    ---     batteryLevel: int,
    ---     roomTemperature: double,
    ---     robotDirection: { direction: Direction, angle: double },
    ---     isDirtDetected: bool,
    ---     wheels: robot.wheels,
    ---     proximity: robot.proximity,
    --- }
    ---@return table a new robot state
    new = function(self, data)
        local o = data
        setmetatable(o, self)
        self.__index = self
        return o
    end;
}

Robot.Action = {

    ---create new action
    ---@param data table {
    ---     speed: {left: double, right: double},
    ---     hasToClean: bool,
    ---     hasToRecharge: bool,
    ---     leds: {switchedOn: bool, color: string}
    --- }
    ---@param levelsToSubsume table list of levels to subsume. Optional
    ---@return table a new action
    new = function(self, data, levelsToSubsume)
        local o = {
            speed = data.speed,
            hasToClean = data.hasToClean,
            hasToRecharge = data.hasToRecharge,
            leds = data.leds,
            levelsToSubsume = levelsToSubsume or {}
        }
        setmetatable(o, self)
        self.__index = self
        return o
    end;

    turnLeft = function (parameters, levelsToSubsume)
        parameters.speed = {
            left = robot_parameters.robotNotTurningTyreSpeed,
            right = robot_parameters.robotTurningSpeed
        }
        return Robot.Action:new(parameters, levelsToSubsume)
    end,

    turnRight = function (parameters, levelsToSubsume)
        parameters.speed = {
            left = robot_parameters.robotTurningSpeed,
            right = robot_parameters.robotNotTurningTyreSpeed
        }
        return Robot.Action:new(parameters, levelsToSubsume)
    end,

    goAhead = function (parameters, levelsToSubsume)
        parameters.speed = {
            left = robot_parameters.robotForwardSpeed,
            right = robot_parameters.robotForwardSpeed
        }
        return Robot.Action:new(parameters, levelsToSubsume)
    end,

    goBack = function (parameters, levelsToSubsume)
        parameters.speed = {
            left = robot_parameters.robotReverseSpeed,
            right = robot_parameters.robotReverseSpeed
        }
        return Robot.Action:new(parameters, levelsToSubsume)
    end,

    stayStill = function (parameters, levelsToSubsume)
        parameters.speed = {
            left = 0,
            right = 0
        }
        return Robot.Action:new(parameters, levelsToSubsume)
    end,

    __add = function (a,b)
        local actions = {}
        if b.speed ~= nil then actions.speed = b.speed
        else actions.speed = a.speed end
        ---
        if b.hasToClean ~= nil then actions.hasToClean = b.hasToClean
        else actions.hasToClean = a.hasToClean end
        ---
        if b.hasToRecharge ~= nil then actions.hasToRecharge = b.hasToRecharge
        else actions.hasToRecharge = a.hasToRecharge end
        ---
        if b.leds ~= nil then actions.leds = b.leds
        else actions.leds = a.leds end
        ---
        return Robot.Action:new(actions)
    end
}

return Robot