local Color = require('util.commons').Color
local Position = require('util.commons').Position
local logger = require('util.logger')
local LogLevel = logger.LogLevel

local RobotAction = require('robot.commons').Action
local MoveAction = require('robot.controller.planner.move_action')
local robot_parameters = require('robot.parameters')
local controller_utils = require('robot.controller.utils')
local MoveExecutioner = require('robot.controller.move_executioner')
local Planner = require('robot.controller.planner.planner')

local State = require('robot.controller.behaviour.room_monitor.state')

local TEMPERATURE_THRESHOLD_UPPER_LIMIT = 30
local TEMPERATURE_THRESHOLD_LOWER_LIMIT = 27
local ALERT_LED_COLOR = Color.CYAN

local function isRobotNotTurning(state)
    return not (state.wheels.velocity_left == robot_parameters.robotNotTurningTyreSpeed
        and state.wheels.velocity_right ~= 0
        or state.wheels.velocity_right == robot_parameters.robotNotTurningTyreSpeed
        and state.wheels.velocity_left ~= 0)
end

local function computeActionsToHome(roomMonitor, state)
    local excludedOptions = controller_utils.getExcludedOptionsByState(state)
    local currentDirection = controller_utils.discreteDirection(state.robotDirection)
    roomMonitor.planner = Planner:new(roomMonitor.map.map)

    roomMonitor.moveExecutioner:setActions(
        roomMonitor.planner:getActionsTo(
            roomMonitor.map.position,
            Position:new(0,0),
            currentDirection,
            excludedOptions,
            false
        )
    )
end

local function handleStopMove(roomMonitor, state)
    local newPosition = roomMonitor.moveExecutioner:handleStopMove(state)
    if newPosition ~= roomMonitor.map.position then
        roomMonitor.map.position = newPosition
        roomMonitor.lastKnownPosition = newPosition
        if state.isDirtDetected then
            roomMonitor.map:setCellAsDirty(newPosition)
        else
            roomMonitor.map:setCellAsClean(newPosition)
        end
    end
end

RoomMonitor = {

    new = function (self, map)
        local o = {
            state = State.WORKING,
            map = map,
            moveExecutioner = MoveExecutioner:new(map),
            planner = nil,
            lastKnownPosition = map.position,
        }
        setmetatable(o, self)
        self.__index = self
        return o
    end,

    tick = function (self, state)
        if self.state == State.WORKING then
            return self:working(state)
        elseif self.state == State.ALERT_GOING_HOME then
            return self:alertGoingHome(state)
        elseif self.state == State.OBSTACLE_ENCOUNTERED then
            return self:handleObstacle(state)
        elseif self.state == State.ALERT then
            return self:alert(state)
        else
            logger.printToConsole('[ROOM_MONITOR] Unknown state: ' .. self.state, LogLevel.WARNING)
            logger.printTo('[ROOM_MONITOR] Unknown state: ' .. self.state, LogLevel.WARNING)
        end
    end,

    --[[ --------- WORKING ---------- ]]

    working = function (self, state)
        if state.roomTemperature >= TEMPERATURE_THRESHOLD_UPPER_LIMIT and isRobotNotTurning(state) then
            self.lastKnownPosition = self.map.position
            if self.map.position ~= Position:new(0,0) then
                handleStopMove(self, state)
                computeActionsToHome(self, state)
                self.state = State.ALERT_GOING_HOME
            else
                self.state = State.ALERT
            end
            return RobotAction.stayStill({
                leds = { switchedOn = true, color = ALERT_LED_COLOR }
            }, {1, 3, 4})
        else
            return RobotAction:new({})
        end
    end,

    --[[ --------- ALERT ---------- ]]

    alert = function (self, state)
        if self.map.position ~= Position:new(0,0) then
            return self:working(state)
        elseif  state.roomTemperature < TEMPERATURE_THRESHOLD_LOWER_LIMIT then
            self.state = State.WORKING
            return RobotAction:new({})
        else
            return RobotAction.stayStill({
                leds = { switchedOn = true, color = ALERT_LED_COLOR }
            }, {1, 3, 4})
        end
    end,

    --[[ --------- ALERT GOING HOME ---------- ]]

    alertGoingHome = function (self, state)

        if self.lastKnownPosition ~= self.map.position then
            self.state = State.WORKING
            return self:working(state)
        elseif state.roomTemperature < TEMPERATURE_THRESHOLD_LOWER_LIMIT and isRobotNotTurning(state) then
            self.state = State.WORKING
            return RobotAction:new({})
        elseif self.map.position == Position:new(0,0) then
            self.state = State.ALERT
            return RobotAction.stayStill({
                leds = { switchedOn = true, color = ALERT_LED_COLOR }
            }, {1, 3, 4})
        end

        local result = self.moveExecutioner:doNextMove(state)
        self.lastKnownPosition = result.position
        self.map.position = result.position

        if result.isObstacleEncountered then
            self.state = State.OBSTACLE_ENCOUNTERED

            logger.print("[ROOM_MONITOR]")
            logger.print("Currently in " .. self.map.position:toString(), LogLevel.INFO)
            logger.print(result.obstaclePosition:toString() .. " detected as obstacle!", LogLevel.WARNING)
            logger.print("----------------", LogLevel.WARNING)

            self.map:setCellAsObstacle(result.obstaclePosition)
            self.planner:setCellAsObstacle(result.obstaclePosition)
            return RobotAction:new({}, {3, 4})
        elseif result.isMoveActionFinished then
            if state.isDirtDetected then
                self.map:setCellAsDirty(result.position)
                self.planner:setCellAsDirty(result.position)
            else
                self.map:setCellAsClean(result.position)
                self.planner:setCellAsClean(result.position)
            end
            return self:alertGoingHomeNextMove(state)
        else
            -- subsume no matter what the room coverage and room cleaner level
            table.insert(result.action.levelsToSubsume, 3)
            table.insert(result.action.levelsToSubsume, 4)
            result.action.leds = { switchedOn = true, color = ALERT_LED_COLOR }
            return result.action
        end
    end,

    alertGoingHomeNextMove = function (self)
        if self.moveExecutioner:hasMoreActions() then
            local nextMove = self.moveExecutioner.actions[1]
            if nextMove == MoveAction.GO_AHEAD then
                return RobotAction:new({
                    leds = { switchedOn = true, color = ALERT_LED_COLOR },
                }, {3, 4})
            elseif nextMove == MoveAction.GO_BACK or nextMove == MoveAction.GO_BACK_BEFORE_TURNING then
                return RobotAction.goBack({
                    leds = { switchedOn = true, color = ALERT_LED_COLOR },
                }, {1, 3, 4})
            elseif nextMove == MoveAction.TURN_LEFT then
                return RobotAction.turnLeft({
                    leds = { switchedOn = true, color = ALERT_LED_COLOR },
                }, {1, 3, 4})
            elseif nextMove == MoveAction.TURN_RIGHT then
                return RobotAction.turnRight({
                    leds = { switchedOn = true, color = ALERT_LED_COLOR },
                }, {1, 3, 4})
            end
        else
            self.state = State.ALERT
            return RobotAction.stayStill({
                leds = { switchedOn = true, color = ALERT_LED_COLOR },
            }, {1, 3, 4})
        end
    end,

    --[[ --------- HANDLE OBSTACLE ---------- ]]

    handleObstacle = function (self, state)

        if self.lastKnownPosition ~= self.map.position then
            self.state = State.WORKING
            return self:working(state)
        end

        local result = self.moveExecutioner:getAwayFromObstacle(state)
        self.lastKnownPosition = result.position
        self.map.position = result.position

        if result.isMoveActionFinished then
            self.moveExecutioner:setActions(
                self.planner:getActionsTo(
                    self.map.position,
                    Position:new(0,0),
                    controller_utils.discreteDirection(state.robotDirection),
                    controller_utils.getExcludedOptionsByState(state),
                    false
                )
            )
            self.state = State.ALERT_GOING_HOME
            return RobotAction.stayStill({
                leds = { switchedOn = true, color = ALERT_LED_COLOR },
            }, {1, 3, 4})
        else
            -- subsume no matter what the room coverage level
            table.insert(result.action.levelsToSubsume, 3)
            table.insert(result.action.levelsToSubsume, 4)
            result.action.leds = { switchedOn = true, color = ALERT_LED_COLOR }
            return result.action
        end
    end,

}

return RoomMonitor;