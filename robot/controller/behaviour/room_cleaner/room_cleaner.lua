local Color = require('util.commons').Color
local Position = require('util.commons').Position
local Direction = require('util.commons').Direction
local logger = require('util.logger')

local RobotAction = require('robot.commons').Action
local MoveAction = require('robot.controller.planner.move_action')
local robot_parameters = require('robot.parameters')
local controller_utils = require('robot.controller.utils')
local CellStatus = require('robot.controller.map.cell_status')
local MoveExecutioner = require('robot.controller.move_executioner')
local Planner = require('robot.controller.planner.planner')
local State = require('robot.controller.behaviour.room_cleaner.state')

local function isRobotNearLastKnownPosition(oldPosition, newPosition)
    return oldPosition == newPosition
        or oldPosition.lat == newPosition.lat and oldPosition.lng == newPosition.lng - 1
        or oldPosition.lat == newPosition.lat and oldPosition.lng == newPosition.lng + 1
        or oldPosition.lng == newPosition.lng and oldPosition.lat == newPosition.lat - 1
        or oldPosition.lng == newPosition.lng and oldPosition.lat == newPosition.lat + 1
end

local function isThereAnyDirtyCell(map)
    local length = #map
    for i = 0, length do
        local rowLength = #map[i]
        for j = 0, rowLength do
            if map[i][j] == CellStatus.DIRTY then
                return Position:new(i, j)
            end
        end
    end
    return nil
end

local function detectDirtyPosition(state, lastKnownPosition, oldDirection)
    
    -- TODO: check if all the situations have been considered - same, front and back cells
    
    local isTurningRight = state.wheels.velocity_left == robot_parameters.robotNotTurningTyreSpeed
        and state.wheels.velocity_right ~= 0
    local isTurningLeft = state.wheels.velocity_right == robot_parameters.robotNotTurningTyreSpeed
        and state.wheels.velocity_left ~= 0
    local currentDirection = controller_utils.discreteDirection(state.robotDirection)
    local speed = state.wheels.velocity_left
    if state.wheels.velocity_right > speed then
        speed = state.wheels.velocity_right
    end

    if (isTurningLeft or isTurningRight) and currentDirection == oldDirection then
        return lastKnownPosition
    elseif isTurningLeft then
        return MoveAction.nextPosition(lastKnownPosition, oldDirection, MoveAction.TURN_LEFT)
    elseif isTurningRight then
        return MoveAction.nextPosition(lastKnownPosition, oldDirection, MoveAction.TURN_RIGHT)
    elseif speed > 0 then
        return MoveAction.nextPosition(lastKnownPosition, currentDirection, MoveAction.GO_AHEAD)
    elseif speed < 0 then
        return MoveAction.nextPosition(lastKnownPosition, currentDirection, MoveAction.GO_BACK)
    else
        return lastKnownPosition
    end
end

RoomCleaner = {

    new = function (self, map)
        local o = {
            state = State.WORKING,
            map = map,
            moveExecutioner = MoveExecutioner:new(map),
            planner = Planner:new(map.map),
            lastKnownPosition = map.position,
            oldDirection = Direction.NORTH
        }
        setmetatable(o, self)
        self.__index = self
        return o
    end,

    tick = function (self, state)
        if state.isDirtDetected then
            local dirtPosition = detectDirtyPosition(state, self.lastKnownPosition, self.oldDirection)
            self.planner:setCellAsDirty(dirtPosition)
            self.map:setCellAsDirty(dirtPosition)
            return RobotAction:new({
                hasToClean = true,
                leds = { switchedOn = true, color = Color.WHITE },
                speed = { left = 0, right = 0}
            }, {1, 3})
        elseif isRobotNearLastKnownPosition(self.lastKnownPosition, self.map.position) then
            if self.state == State.WORKING then
                return self:working(state)
            else
                logger.print('[ROOM_CLEANER] Unhandled state', logger.LogLevel.WARNING)
            end
        else
            local dirtPosition = isThereAnyDirtyCell(self.map)
            if dirtPosition == nil then
                self.lastKnownPosition = self.map.position
                self.state = State.WORKING
                return RobotAction:new({})
            else
                -- TODO: compute path to dirty cell
            end
        end
    end,

    working = function (self, state)
        -- TODO: determine when to change cell status to clean
    end

}

return RoomCleaner;