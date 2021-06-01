local Color = require('util.commons').Color
local Position = require('util.commons').Position
local logger = require('util.logger')
local LogLevel = logger.LogLevel
local table = require('extensions.lua.table')
local yen_ksp = require('extensions.luagraphs.shortest_paths.yen_ksp')

local Battery = require('robot.sensors').Battery
local RobotAction = require('robot.commons').Action
local MoveAction = require('robot.controller.planner.move_action')
local robot_parameters = require('robot.parameters')
local controller_utils = require('robot.controller.utils')
local MoveExecutioner = require('robot.controller.move_executioner.move_executioner')
local Planner = require('robot.controller.planner.planner')

local State = require('robot.controller.behaviour.robot_battery_monitor.state')
local helpers = require('robot.controller.behaviour.robot_battery_monitor.helpers')
local Subsumption = require('robot.controller.subsumption')

local GOING_TO_CHARGING_STATION_COLOR = Color.ORANGE
local CHARGING_COLOR = Color.GREEN
local MARGIN_AUTONOMY = 0.75
local MAX_BATTERY_PERCENTAGE_BEFORE_GOING_HOME = 0.05
local LEVELS_TO_SUBSUME = {3, 4, 5}

local function getAvailableBatteryEnoughToJustGoBackHome(robotBatteryMonitor, state)
    robotBatteryMonitor.planner = Planner:new(robotBatteryMonitor.map.map)
    robotBatteryMonitor.moveExecutioner = MoveExecutioner:new(
        robotBatteryMonitor.map,
        robotBatteryMonitor.planner,
        controller_utils.discreteDirection(state.robotDirection)
    )
    local numberOfCellsToHome = #(robotBatteryMonitor.planner:getPathTo(
        robotBatteryMonitor.map.position,
        Position:new(0,0),
        MoveAction.nextPosition(
            robotBatteryMonitor.map.position,
            controller_utils.discreteDirection(state.robotDirection),
            MoveAction.GO_BACK),
        controller_utils.getExcludedOptionsByState(state),
        false
    ))

    local distanceAutonomy = state.batteryLevel / robot_parameters.batteryUsedPerStep

    local numberOfStepsToReachHome = numberOfCellsToHome / robot_parameters.speedPerCell
    numberOfStepsToReachHome = numberOfStepsToReachHome + (numberOfStepsToReachHome * MARGIN_AUTONOMY)

    logger.print('distance autonomy = ' .. distanceAutonomy, LogLevel.WARNING)
    logger.print('distance in steps = ' .. numberOfStepsToReachHome, LogLevel.WARNING)

    return distanceAutonomy - numberOfStepsToReachHome
end

local function isRobotNotTurning(state)
    return not (state.wheels.velocity_left == robot_parameters.robotNotTurningTyreSpeed
        and state.wheels.velocity_right ~= 0
        or state.wheels.velocity_right == robot_parameters.robotNotTurningTyreSpeed
        and state.wheels.velocity_left ~= 0)
end

local function computeActionsToHome(robotBatteryMonitor, state, lastAction, obstacleEncountered)
    local yen = yen_ksp.create(
        robotBatteryMonitor.planner.graph,
        Planner.encodeCoordinatesFromPosition,
        Planner.decodeCoordinates
    )

    local actions = helpers.getFastestRoute(
        yen,
        state,
        robotBatteryMonitor.map.position,
        lastAction,
        obstacleEncountered
    )

    robotBatteryMonitor.planner.actions = actions
    robotBatteryMonitor.moveExecutioner:setActions(
        actions,
        state
    )
end

local function handleStopMove(robotBatteryMonitor, state)
    local newPosition = robotBatteryMonitor.moveExecutioner:handleStopMove(state)
    if newPosition ~= robotBatteryMonitor.map.position then
        robotBatteryMonitor.map.position = newPosition
        robotBatteryMonitor.lastKnownPosition = newPosition
        if state.isDirtDetected then
            robotBatteryMonitor.map:setCellAsDirty(newPosition)
        else
            robotBatteryMonitor.map:setCellAsClean(newPosition)
        end
    else
        robotBatteryMonitor.lastKnownPosition = robotBatteryMonitor.map.position
    end
end

local function getCheckBatteryLevelFrequency(difference)
    if difference > 500 then
        return 100
    elseif difference > 200 then
        return 50
    elseif difference > 140 then
        return 20
    else
        return 1
    end
end

RoomMonitor = {

    new = function (self, map)
        local planner = Planner:new(map.map)
        local o = {
            state = State.WORKING,
            map = map,
            moveExecutioner = MoveExecutioner:new(map, planner),
            planner = planner,
            lastKnownPosition = map.position,
            stepCounter = 0,
            checkFrequency = 0
        }
        setmetatable(o, self)
        self.__index = self
        return o
    end,

    tick = function (self, state)
        if self.state == State.WORKING then
            return self:working(state)
        elseif self.state == State.ALERT_GOING_CHARGING_STATION then
            return self:alertGoingChargingStation(state)
        elseif self.state == State.OBSTACLE_ENCOUNTERED then
            return self:handleObstacle(state)
        elseif self.state == State.CHARGING then
            return self:charging(state)
        else
            logger.printToConsole('[ROBOT_BATTERY_MONITOR] Unknown state: ' .. self.state, LogLevel.WARNING)
            logger.printTo('[ROBOT_BATTERY_MONITOR] Unknown state: ' .. self.state, LogLevel.WARNING)
        end
    end,

    --[[ --------- WORKING ---------- ]]

    working = function (self, state)
        if self.stepCounter >= self.checkFrequency or self.stepCounter == 0 then
            self.stepCounter = 0
            local batteryDifference = getAvailableBatteryEnoughToJustGoBackHome(self, state)
            self.checkFrequency = getCheckBatteryLevelFrequency(batteryDifference)
            local batteryPercentage = state.batteryLevel / Battery.BATTERY_MAX_VALUE
            if (batteryDifference <= 0 or batteryPercentage <= MAX_BATTERY_PERCENTAGE_BEFORE_GOING_HOME)
                and isRobotNotTurning(state) then
                handleStopMove(self, state)
                computeActionsToHome(self, state)
                self.state = State.ALERT_GOING_CHARGING_STATION
                return RobotAction.stayStill({leds = {
                    switchedOn = true,
                    color = GOING_TO_CHARGING_STATION_COLOR
                }}, { Subsumption.subsumeAll })
            elseif batteryDifference <= 0 or batteryPercentage <= MAX_BATTERY_PERCENTAGE_BEFORE_GOING_HOME then
                return RobotAction:new({leds = {
                    switchedOn = true,
                    color = GOING_TO_CHARGING_STATION_COLOR
                }})
            end
        end
        self.stepCounter = self.stepCounter + 1
        return RobotAction:new({})
    end,

    --[[ --------- CHARGING ---------- ]]

    charging = function (self, state)
        if self.map.position ~= Position:new(0,0) then
            self.state = State.WORKING
            return self:working(state)
        elseif state.batteryLevel >= Battery.BATTERY_MAX_VALUE then
            self.state = State.WORKING
            return RobotAction:new({})
        else
            return RobotAction.stayStill({
                hasToRecharge = true,
                leds = { switchedOn = true, color = CHARGING_COLOR }
            }, { Subsumption.subsumeAll })
        end
    end,

    --[[ --------- ALERT GOING CHARGING STATION ---------- ]]

    alertGoingChargingStation = function (self, state)

        if self.lastKnownPosition ~= self.map.position then
            self.state = State.WORKING
            return self:working(state)
        elseif self.map.position == Position:new(0,0) then
            self.state = State.CHARGING
            return RobotAction.stayStill({
                hasToRecharge = true,
                leds = { switchedOn = true, color = CHARGING_COLOR }
            }, { Subsumption.subsumeAll })
        end

        local result = self.moveExecutioner:doNextMove(state)
        self.lastKnownPosition = result.position
        self.map.position = result.position

        if result.isObstacleEncountered then
            self.state = State.OBSTACLE_ENCOUNTERED

            logger.print("[ROBOT_BATTERY_MONITOR]")
            logger.print("Currently in " .. self.map.position:toString(), LogLevel.INFO)

            for i = 1, #result.obstaclePositions do
                self.map:setCellAsObstacle(result.obstaclePositions[i])
                self.planner:setCellAsObstacle(result.obstaclePositions[i])
                logger.print(result.obstaclePositions[i]:toString() .. " detected as obstacle!", LogLevel.WARNING)
            end

            logger.print("----------------", LogLevel.WARNING)
            return RobotAction:new({}, LEVELS_TO_SUBSUME)
        elseif result.isMoveActionFinished then
            if state.isDirtDetected then
                self.map:setCellAsDirty(result.position)
                self.planner:setCellAsDirty(result.position)
            else
                self.map:setCellAsClean(result.position)
                self.planner:setCellAsClean(result.position)
            end
            return self:alertGoingChargingStationNextMove(state)
        else
            -- subsume no matter what the room coverage and room cleaner level
            table.insertMultiple(result.action.levelsToSubsume, LEVELS_TO_SUBSUME)
            result.action.leds = { switchedOn = true, color = GOING_TO_CHARGING_STATION_COLOR }
            return result.action
        end
    end,

    alertGoingChargingStationNextMove = function (self)
        if self.moveExecutioner:hasMoreActions() then
            local nextMove = self.moveExecutioner.actions[1]
            if nextMove == MoveAction.GO_AHEAD then
                return RobotAction:new({
                    leds = { switchedOn = true, color = GOING_TO_CHARGING_STATION_COLOR },
                }, LEVELS_TO_SUBSUME)
            elseif nextMove == MoveAction.GO_BACK or nextMove == MoveAction.GO_BACK_BEFORE_TURNING then
                return RobotAction.goBack({
                    leds = { switchedOn = true, color = GOING_TO_CHARGING_STATION_COLOR },
                }, {1, table.unpack(LEVELS_TO_SUBSUME)})
            elseif nextMove == MoveAction.TURN_LEFT then
                return RobotAction.turnLeft({
                    leds = { switchedOn = true, color = GOING_TO_CHARGING_STATION_COLOR },
                }, {1, table.unpack(LEVELS_TO_SUBSUME)})
            elseif nextMove == MoveAction.TURN_RIGHT then
                return RobotAction.turnRight({
                    leds = { switchedOn = true, color = GOING_TO_CHARGING_STATION_COLOR },
                }, {1, table.unpack(LEVELS_TO_SUBSUME)})
            end
        else
            self.state = State.CHARGING
            return RobotAction.stayStill({
                hasToRecharge = true,
                leds = { switchedOn = true, color = CHARGING_COLOR }
            }, { Subsumption.subsumeAll })
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
            computeActionsToHome(
                self, state, self.moveExecutioner.actions[1], true
            )
            self.state = State.ALERT_GOING_CHARGING_STATION
            return RobotAction.stayStill({
                leds = { switchedOn = true, color = GOING_TO_CHARGING_STATION_COLOR },
            }, { Subsumption.subsumeAll })
        else
            -- subsume no matter what the room coverage level
            table.insertMultiple(result.action.levelsToSubsume, LEVELS_TO_SUBSUME)
            result.action.leds = { switchedOn = true, color = GOING_TO_CHARGING_STATION_COLOR }
            return result.action
        end
    end,

}

return RoomMonitor;