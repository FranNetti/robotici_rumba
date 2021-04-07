Robot = {}

Robot.State = {

    ---create new state
    ---@param data table {
    ---     battery_level: int,
    ---     room_temperature: double,
    ---     robot_direction: Direction,
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