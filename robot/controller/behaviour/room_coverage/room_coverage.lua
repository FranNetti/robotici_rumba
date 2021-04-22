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
            target = Position:new(0,0),
            distanceTravelled = 0,
            oldPosition = nil,
            oldDirection = nil,
            currentDirection = Direction.NORTH
        }
        setmetatable(o, self)
        self.__index = self
        return o
    end,

    tick = function (self, roomState)
        if self.state == State.STAND_BY then
            return self:standByPhase(roomState)
        elseif self.state == State.EXPLORING or self.state == State.GOING_HOME then
            return self:exploringPhase(roomState)
        elseif self.state == State.TARGET_REACHED then
            return self:targetReachedPhase(roomState)
        else
            commons.printToConsole(self.map:toString())
        end
    end,

    standByPhase = function (self, state)
        self.target = Position:new(self.target.lat + 1, self.target.lng + 1)
        self.map:addNewDiagonalPoint(self.target.lat)

        local excludedOptions = Set:new{}
        if not CollisionAvoidanceBehaviour.isObjectInFrontRange(state.proximity) then
            excludedOptions = excludedOptions + Set:new{ExcludeOption.EXCLUDE_LEFT, ExcludeOption.EXCLUDE_RIGHT}
        end

        commons.print("[ROOM COVERAGE]")
        commons.print(
            "(" .. self.map.encodeCoordinates(self.map.position.lat, self.map.position.lng) .. " - "
            .. self.currentDirection.name .. ") - ("
            .. self.map.encodeCoordinates(self.target.lat, self.target.lng) .. ")"
        )
        commons.print("---------------")

        self.actions = self.map:getActionsTo(self.target, self.currentDirection, excludedOptions)
        self.state = State.EXPLORING

        commons.printToConsole(self.map:toString())

        self.distanceTravelled = 0
        return RobotAction.stayStill({1})
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
            isMoveActionNotFinished, robotAction  = self:handleTurnLeftMove(state, nextAction)
        elseif currentAction == MoveAction.TURN_RIGHT then
            isMoveActionNotFinished, robotAction  = self:handleTurnRightMove(state, nextAction)
        else
            isMoveActionNotFinished, robotAction  = self:handleGoBackMove(state)
        end

        if isMoveActionNotFinished then
            return robotAction
        end

        commons.stringify(currentAction)
        commons.stringify(self.oldDirection)
        commons.stringify(self.currentDirection)
        commons.stringify("-------")

        self.map:setCellAsClean(self.map.position)
        self.oldPosition = self.map.position
        self.oldDirection = self.currentDirection
        self.currentDirection = MoveAction.nextDirection(self.currentDirection, currentAction)
        table.remove(self.actions, 1)

        commons.stringify(self.oldDirection)
        commons.stringify(self.currentDirection)
        commons.stringify("********")

        return self:exploringPhaseNextMove()
    end,

    targetReachedPhase = function (self, state)
        self.actions = self.map:getActionsTo(Position:new(0,0), self.currentDirection)

        for i = 1, #self.actions do
            commons.print
            (self.actions[i])
        end

        self.state = State.GOING_HOME
        self.distanceTravelled = 0
        return RobotAction.stayStill({1})
    end,

    handleGoAheadMove = function (self, _, nextAction)
        if (nextAction == MoveAction.TURN_LEFT or nextAction == MoveAction.TURN_RIGHT)
              and self.distanceTravelled < robot_parameters.squareSideDimension / 2 then
            return true, RobotAction:new({})
        elseif nextAction ~= MoveAction.TURN_LEFT
            and nextAction ~= MoveAction.TURN_RIGHT
            and self.distanceTravelled < robot_parameters.squareSideDimension then
            return true, RobotAction:new({})
        else
            self.distanceTravelled = self.distanceTravelled - robot_parameters.squareSideDimension
            self.map.position = MoveAction.nextPosition(self.map.position, self.currentDirection, MoveAction.GO_AHEAD)
        end
        return false
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

        if state.wheels.velocity_left == 0 and state.wheels.velocity_right ~= 0 and state.robotDirection.direction == nextDirection then
            -- self.currentDirection = MoveAction.nextDirection(self.currentDirection, MoveAction.TURN_LEFT)
            if nextAction ~= MoveAction.TURN_LEFT and nextAction ~= MoveAction.TURN_RIGHT then
                self.distanceTravelled = robot_parameters.squareSideDimension / 2
                self.actions[1] = MoveAction.GO_AHEAD
                self.currentDirection = MoveAction.nextDirection(self.currentDirection, MoveAction.TURN_LEFT)
                return true, RobotAction:new({})
            else
                self.map.position = MoveAction.nextPosition(self.map.position, self.oldDirection, MoveAction.TURN_LEFT)
                return false, nil
            end
        elseif state.wheels.velocity_left == 0 and state.wheels.velocity_right ~= 0 and state.robotDirection.direction ~= nextDirection then
            return true, RobotAction.turnLeft({1})
        else
            self.distanceTravelled = -robot_parameters.squareSideDimension / 2
            table.insert(self.actions, 1, MoveAction.GO_BACK)
            self.map.position = MoveAction.nextPosition(self.map.position, state.robotDirection.direction, MoveAction.GO_AHEAD)
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

        if state.wheels.velocity_left ~= 0 and state.wheels.velocity_right == 0 and state.robotDirection.direction == nextDirection then
            self.currentDirection = MoveAction.nextDirection(self.currentDirection, MoveAction.TURN_RIGHT)
            if nextAction ~= MoveAction.TURN_LEFT and nextAction ~= MoveAction.TURN_RIGHT then
                self.distanceTravelled = robot_parameters.squareSideDimension / 2
                self.actions[1] = MoveAction.GO_AHEAD
                return true, RobotAction:new({})
            else
                self.map.position = MoveAction.nextPosition(self.map.position, self.oldDirection, MoveAction.TURN_RIGHT)
                return false, nil
            end
        elseif state.wheels.velocity_left ~= 0 and state.wheels.velocity_right == 0 and state.robotDirection.direction ~= nextDirection then
            return true, RobotAction.turnRight({1})
        else
            self.distanceTravelled = -robot_parameters.squareSideDimension / 2
            table.insert(self.actions, 1, MoveAction.GO_BACK)
            self.map.position = MoveAction.nextPosition(self.map.position, state.robotDirection.direction, MoveAction.GO_AHEAD)
            return true, RobotAction.goBack({1})
        end
    end,

    handleGoBackMove = function (self, state)
        if self.distanceTravelled > -robot_parameters.squareSideDimension then
            return true, RobotAction.goBack({1})
        else
            self.distanceTravelled = self.distanceTravelled + robot_parameters.squareSideDimension
            self.map.position = MoveAction.nextPosition(self.map.position, state.robotDirection.direction, MoveAction.GO_BACK)
        end
        return false, nil
    end,

    exploringPhaseNextMove = function (self)
        if #self.actions == 0 and self.state == State.EXPLORING then
            self.state = State.TARGET_REACHED
            return RobotAction.stayStill({1})
        elseif #self.actions == 0 and self.state == State.GOING_HOME then
            self.state = State.STAND_BY
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