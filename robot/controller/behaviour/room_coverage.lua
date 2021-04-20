local commons = require('util.commons')
local robot_parameters = require('robot.parameters')

local Position = commons.Position
local Direction = commons.Direction
local Set = require('util.set')
local ExcludeOption = require('robot.map.exclude_option')
local CollisionAvoidanceBehaviour = require('robot.controller.behaviour.collision_avoidance')

local RobotAction = require('robot.commons').Action
local MoveAction = require('robot.map.move_action')

local State = {
    ---nothing going on
    STAND_BY = 1,
    ---going to a target
    EXPLORING = 2,
    --- target reached
    TARGET_REACHED = 3,
    ---going back home
    GOING_HOME = 4,
    -- home reached, turning the robot in the right direction
    CALIBRATING_HOME = 5,
    ---room explored
    EXPLORED = 6,
}

RoomCoverage = {

    ---Create new room coverage behaviour
    ---@param map table Map the map of the robot
    ---@return table a new behaviour
    new = function (self, map)
        local o = {
            map = map,
            state = State.STAND_BY,
            actions = nil,
            target = nil,
            distanceTravelled = 0,
        }
        setmetatable(o, self)
        self.__index = self
        return o
    end,

    tick = function (self, roomState)
        if self.state == State.STAND_BY then
            return self:standByFase(roomState)
        elseif self.state == State.EXPLORING then
            return self:exploringPhase(roomState)
        end
    end,

    standByPhase = function (self, roomState)
        if self.target == nil then
            self.target = Position:new(1,1)
        else
            self.target = Position:new(self.target.lat + 1, self.target.lng + 1)
        end

        self.map:addNewDiagonalPoint(self.target.lat)
        local excludedOptions = Set:new{}
        if not CollisionAvoidanceBehaviour.isObjectInFrontRange(roomState.proximity) then
            excludedOptions = excludedOptions + Set:new{ExcludeOption.EXCLUDE_LEFT, ExcludeOption.EXCLUDE_RIGHT}
        end

        self.actions = self.map:getActionsTo(self.target, roomState.robotDirection, excludedOptions)
        self.state = State.EXPLORING

        return RobotAction:new({
            speed = {
                left = 0,
                right = 0
            }
        }, {1})
    end,

    exploringPhase = function (self, roomState)
        self.distanceTravelled = self.distanceTravelled + roomState.wheels.distance_left
        local currentAction = self.actions[1]
        local nextAction = nil
        if #self.actions >= 2 then
            nextAction = self.actions[2]
        end

        if currentAction == MoveAction.GO_AHEAD then
            if (nextAction == MoveAction.TURN_LEFT or nextAction == MoveAction.TURN_RIGHT)
              and self.distanceTravelled < robot_parameters.squareSideDimension / 2 then
                return RobotAction:new({})
            elseif nextAction ~= MoveAction.TURN_LEFT
              and nextAction ~= MoveAction.TURN_RIGHT
              and self.distanceTravelled < robot_parameters.squareSideDimension then
                return RobotAction:new({})
            else
                self.distanceTravelled = self.distanceTravelled - robot_parameters.squareSideDimension
                if roomState.robotDirection == Direction.NORTH then
                    self.map.position = Position:new(self.map.position.lat + 1, self.map.position.lng)
                elseif roomState.robotDirection == Direction.SOUTH then
                    self.map.position = Position:new(self.map.position.lat - 1, self.map.position.lng)
                elseif roomState.robotDirection == Direction.WEST then
                    self.map.position = Position:new(self.map.position.lat, self.map.position.lng + 1)
                else
                    self.map.position = Position:new(self.map.position.lat, self.map.position.lng - 1)
                end
            end
        end

        table.remove(self.actions, 1)
        return self:exploringPhaseNextMove()
    end,

    exploringPhaseNextMove = function (self)
        if #self.actions == 0 then
            self.state = State.TARGET_REACHED
            return RobotAction:new({
                speed = {
                    left = 0,
                    right = 0
                }
            }, {1})
        else
            local nextMove = self.actions[1]
            if nextMove == MoveAction.GO_AHEAD then
                return RobotAction:new({})
            elseif nextMove == MoveAction.GO_BACK then
                return RobotAction:new({
                    speed = {
                        left = robot_parameters.robotReverseSpeed,
                        right = robot_parameters.robotReverseSpeed
                    }
                }, {1})
            elseif nextMove == MoveAction.TURN_LEFT then
                return RobotAction:new({
                    speed = {
                        left = 0,
                        right = robot_parameters.robotTurningSpeed
                    }
                }, {1})
            elseif nextMove == MoveAction.TURN_RIGHT then
                return RobotAction:new({
                    speed = {
                        left = robot_parameters.robotTurningSpeed,
                        right = 0
                    }
                }, {1})
            end
        end
    end

}

return RoomCoverage;