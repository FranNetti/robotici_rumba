local commons = require('util.commons')
local robot_parameters = require('robot.parameters')

local Position = commons.Position
local Direction = commons.Direction
local Set = require('util.set')
local ExcludeOption = require('robot.map.exclude_option')
local CollisionAvoidanceBehaviour = require('robot.controller.behaviour.collision_avoidance')

local RobotAction = require('robot.commons').Action
local MoveAction = require('robot.map.move_action')

local State = require('robot.controller.behaviour.room_coverage.state')

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
            oldPosition = nil,
            oldDirection = nil,
        }
        setmetatable(o, self)
        self.__index = self
        return o
    end,

    tick = function (self, roomState)
        if self.state == State.STAND_BY then
            return self:standByPhase(roomState)
        elseif self.state == State.EXPLORING then
            return self:exploringPhase(roomState)
        else
            commons.printToConsole(self.map:toString())
        end
    end,

    standByPhase = function (self, state)
        if self.target == nil then
            self.target = Position:new(5,5)
        else
            self.target = Position:new(self.target.lat + 1, self.target.lng + 1)
        end

        self.map:addNewDiagonalPoint(self.target.lat)
        local excludedOptions = Set:new{}
        if not CollisionAvoidanceBehaviour.isObjectInFrontRange(state.proximity) then
            excludedOptions = excludedOptions + Set:new{ExcludeOption.EXCLUDE_LEFT, ExcludeOption.EXCLUDE_RIGHT}
        end

        self.actions = self.map:getActionsTo(self.target, state.robotDirection.direction, excludedOptions)
        self.state = State.EXPLORING

        return RobotAction:new({
            speed = {
                left = 0,
                right = 0
            }
        }, {1})
    end,

    exploringPhase = function (self, state)
        self.distanceTravelled = self.distanceTravelled + state.wheels.distance_left
        local currentAction = self.actions[1]
        local nextAction = nil
        if #self.actions >= 2 then
            nextAction = self.actions[2]
        end

        local isMoveActionNotFinished, robotAction = false, nil
        if currentAction == MoveAction.GO_AHEAD then
            isMoveActionNotFinished, robotAction = self:handleGoAheadMove(state, nextAction)
        elseif currentAction == MoveAction.TURN_LEFT then
            isMoveActionNotFinished, robotAction = self:handleTurnLeftMove(state, nextAction)
        elseif currentAction == MoveAction.TURN_RIGHT then
            isMoveActionNotFinished, robotAction = self:handleTurnRightMove(state, nextAction)
        end

        if isMoveActionNotFinished then
            return robotAction
        end

        self.map:setCellAsClean(self.map.position)
        self.oldPosition = self.map.position
        self.oldDirection = state.robotDirection.direction
        table.remove(self.actions, 1)
        return self:exploringPhaseNextMove()
    end,

    handleGoAheadMove = function (self, state, nextAction)
        if (nextAction == MoveAction.TURN_LEFT or nextAction == MoveAction.TURN_RIGHT)
              and self.distanceTravelled < robot_parameters.squareSideDimension / 2 then
            return true, RobotAction:new({})
        elseif nextAction ~= MoveAction.TURN_LEFT
            and nextAction ~= MoveAction.TURN_RIGHT
            and self.distanceTravelled < robot_parameters.squareSideDimension then
            return true, RobotAction:new({})
        else
            self.distanceTravelled = self.distanceTravelled - robot_parameters.squareSideDimension
            if state.robotDirection.direction == Direction.NORTH then
                self.map.position = Position:new(self.map.position.lat + 1, self.map.position.lng)
            elseif state.robotDirection.direction == Direction.SOUTH then
                self.map.position = Position:new(self.map.position.lat - 1, self.map.position.lng)
            elseif state.robotDirection.direction == Direction.WEST then
                self.map.position = Position:new(self.map.position.lat, self.map.position.lng + 1)
            else
                self.map.position = Position:new(self.map.position.lat, self.map.position.lng - 1)
            end
        end
        return false, nil
    end,

    handleTurnLeftMove = function (self, state, nextAction)
        local nextDirection = Direction.WEST;
        if self.oldDirection == Direction.WEST then
            nextDirection = Direction.SOUTH
        elseif self.oldDirection == Direction.SOUTH then
            nextDirection = Direction.EAST
        elseif self.oldDirection == Direction.EAST then
            nextDirection = Direction.NORTH
        end

        commons.print(state.robotDirection.angle)

        if state.wheels.velocity_left == 0 and state.wheels.velocity_right ~= 0 and state.robotDirection.direction == nextDirection then
            if nextAction ~= MoveAction.TURN_LEFT and nextAction ~= MoveAction.TURN_RIGHT then
                self.distanceTravelled = robot_parameters.squareSideDimension / 2
                self.actions[1] = MoveAction.GO_AHEAD
                return true, RobotAction:new({})
            else
                if nextDirection == Direction.EAST then
                    self.map.position = Position:new(self.map.position.lat, self.map.position.lng - 1)
                elseif nextDirection == Direction.WEST then
                    self.map.position = Position:new(self.map.position.lat, self.map.position.lng + 1)
                elseif nextDirection == Direction.NORTH then
                    self.map.position = Position:new(self.map.position.lat + 1, self.map.position.lng)
                else
                    self.map.position = Position:new(self.map.position.lat - 1, self.map.position.lng)
                end
                return false, nil
            end
        elseif state.wheels.velocity_left == 0 and state.wheels.velocity_right ~= 0 and state.robotDirection.direction ~= nextDirection then
            return true, RobotAction.turnLeft({1})
        else
            self.distanceTravelled = -robot_parameters.squareSideDimension / 2
            table.insert(self.actions, 1, MoveAction.GO_BACK)
            return true, RobotAction.goBack({1})
        end
    end,

    handleTurnRightMove = function (self, state, nextAction)
        local nextDirection = Direction.EAST;
        if self.oldDirection == Direction.WEST then
            nextDirection = Direction.NORTH
        elseif self.oldDirection == Direction.SOUTH then
            nextDirection = Direction.WEST
        elseif self.oldDirection == Direction.EAST then
            nextDirection = Direction.SOUTH
        end

        commons.print(state.robotDirection.angle)

        if state.wheels.velocity_left ~= 0 and state.wheels.velocity_right == 0 and state.robotDirection.direction == nextDirection then
            if nextAction ~= MoveAction.TURN_LEFT and nextAction ~= MoveAction.TURN_RIGHT then
                self.distanceTravelled = robot_parameters.squareSideDimension / 2
                self.actions[1] = MoveAction.GO_AHEAD
                return true, RobotAction:new({})
            else
                if nextDirection == Direction.EAST then
                    self.map.position = Position:new(self.map.position.lat, self.map.position.lng - 1)
                elseif nextDirection == Direction.WEST then
                    self.map.position = Position:new(self.map.position.lat, self.map.position.lng + 1)
                elseif nextDirection == Direction.NORTH then
                    self.map.position = Position:new(self.map.position.lat + 1, self.map.position.lng)
                else
                    self.map.position = Position:new(self.map.position.lat - 1, self.map.position.lng)
                end
                return false, nil
            end
        elseif state.wheels.velocity_left ~= 0 and state.wheels.velocity_right == 0 and state.robotDirection.direction ~= nextDirection then
            return true, RobotAction.turnRight({1})
        else
            self.distanceTravelled = -robot_parameters.squareSideDimension / 2
            table.insert(self.actions, 1, MoveAction.GO_BACK)
            return true, RobotAction.goBack({1})
        end
    end,

    exploringPhaseNextMove = function (self)
        if #self.actions == 0 then
            self.state = State.TARGET_REACHED
            return RobotAction.stayStill({1})
        else
            local nextMove = self.actions[1]
            if nextMove == MoveAction.GO_AHEAD then
                return RobotAction:new({})
            elseif nextMove == MoveAction.GO_BACK then
                return RobotAction.goBack({1})
            elseif nextMove == MoveAction.TURN_LEFT then
                return RobotAction.turnLeft({1})
            elseif nextMove == MoveAction.TURN_RIGHT then
                return RobotAction.turnRight({1})
            end
        end
    end,

}

return RoomCoverage;