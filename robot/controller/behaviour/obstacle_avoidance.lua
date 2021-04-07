local commons = require 'util.commons'
local robot_parameters = require 'robot.parameters'

local Action = (require 'robot.commons').Action

local CLOSE_OBJECT_MIN_DISTANCE_FRONT_LEFT = 0.1;
local CLOSE_OBJECT_MIN_DISTANCE_FRONT_RIGHT = 0.2;
local TURNING_SPEED = 5;
local REVERSE_SPEED = 5;

local State = {
    ---no obstacle has been revealed
    NOTHING_REVEALED = 1,
    ---an obstacle has been revealed, currently getting away from it
    OBSTACLE_REVEALED = 2,
    ---the robot has got away from the obstacle, now it is turning left
    TURNING_MANOUVRE = 3
}

ObstacleAvoidance = {

    ---Create new obstacle avoidance behaviour
    ---@param initialDirection table Direction the initial direction of the robot
    ---@return table a new obstacle avoidance behaviour
    new = function (self, initialDirection)
        local o = {
            previousDirection = initialDirection,
            state = State.NOTHING_REVEALED,
            distanceTravelled = 0
        }
        setmetatable(o, self)
        self.__index = self
        return o
    end,

    tick = function (self, state)
        if(self.state == State.NOTHING_REVEALED) then
            return self:nothingHasBeenRevealed(state)
        elseif self.state == State.OBSTACLE_REVEALED then
            return self:obstacleRevealed(state)
        elseif self.state == State.TURNING_MANOUVRE then
            commons.print("TURNINGGGG")
        end
    end,

    nothingHasBeenRevealed = function (self, state)
        self.distanceTravelled = (self.distanceTravelled + state.wheels.distance_left) % robot_parameters.squareSideDimension
        commons.print(self.distanceTravelled)
        local isCloseToObject =
            self:isObjectInRange(state.proximity, 1, 4, CLOSE_OBJECT_MIN_DISTANCE_FRONT_LEFT)
            or self:isObjectInRange(state.proximity, 22, 24, CLOSE_OBJECT_MIN_DISTANCE_FRONT_RIGHT)
        if isCloseToObject then
            self.state = State.OBSTACLE_REVEALED
            self.previousDirection = state.robot_direction
            return Action:new({
                speed = {left = -REVERSE_SPEED, right = -REVERSE_SPEED}
            }, {1})
        end
        return Action:new{}
    end,

    obstacleRevealed = function (self, state)
        self.distanceTravelled = self.distanceTravelled + state.wheels.distance_left
        commons.print(self.distanceTravelled)
        if self.distanceTravelled <= -(robot_parameters.squareSideDimension / 2) then
            self.state = State.TURNING_MANOUVRE
            return Action:new({
                speed = {left = 0, right = TURNING_SPEED}
            }, {1})
        end
        return Action:new({}, {1})
    end,

    --[[ tick = function (self, state)
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
    end, ]]

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