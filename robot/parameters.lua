local Direction = require('util.commons').Direction
local Battery = require('robot.sensors').Battery

local ROBOT_INITIAL_DIRECTION = Direction.NORTH

local SQUARE_SIDE_DIMENSION = 12
local DISTANCE_TO_GO_WITH_OBSTACLES = 3

local ROBOT_FORWARD_SPEED = 10
local ROBOT_REVERSE_SPEED = -5
local ROBOT_TURNING_SPEED = 5
local ROBOT_TYRE_NOT_TURNING_SPEED = 0
local ROBOT_ADJUST_ANGLE_SPEED = 9

local BATTERY_USED_PER_STEP = 1 / Battery.BATTERY_STEP_DECREASE_FREQUENCY
local SPEED_PER_STEP = ((ROBOT_FORWARD_SPEED * 1 / 10) + (ROBOT_TURNING_SPEED * 9 / 10)) / 10
local SPEED_PER_CELL = SPEED_PER_STEP / SQUARE_SIDE_DIMENSION

return {
    robotInitialDirection = ROBOT_INITIAL_DIRECTION,

    squareSideDimension = SQUARE_SIDE_DIMENSION,
    distanceToGoBackWithObstacles= DISTANCE_TO_GO_WITH_OBSTACLES,

    robotForwardSpeed = ROBOT_FORWARD_SPEED,
    robotReverseSpeed = ROBOT_REVERSE_SPEED,
    robotTurningSpeed = ROBOT_TURNING_SPEED,
    robotNotTurningTyreSpeed = ROBOT_TYRE_NOT_TURNING_SPEED,
    robotAdjustAngleSpeed = ROBOT_ADJUST_ANGLE_SPEED,

    batteryUsedPerStep = BATTERY_USED_PER_STEP,
    speedPerStep = SPEED_PER_STEP,
    speedPerCell = SPEED_PER_CELL,
}