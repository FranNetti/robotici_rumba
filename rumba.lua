local math = require('math')
math.randomseed(1234)

local sensors = require('robot.sensors')
local actuators = require('robot.actuators')
local commons = require('util.commons')
local logger = require('util.logger')
local RobotState = require('robot.commons').State
local Map = require('robot.controller.map.map')

local Color, Position = commons.Color, commons.Position
local Subsumption = require('robot.controller.subsumption')
local RobotAdvance = require('robot.controller.behaviour.robot_advance.robot_advance')
local CollisionAvoidance = require('robot.controller.behaviour.collision_avoidance.collision_avoidance')
local RoomCoverage = require('robot.controller.behaviour.room_coverage.room_coverage')
local RoomCleaner = require('robot.controller.behaviour.room_cleaner.room_cleaner')

local INITIAL_ROOM_TEMPERATURE = 12
logger.level = logger.LogLevel.INFO

local temperatureSensor
local dirtDetector
local battery
local compass
local brush
local robotController
local robotMap

local firstStep = true

local function setupWorkspace()
	robot.wheels.set_velocity(0,0)
	robot.leds.set_all_colors(Color.BLACK)
	-------
	local dirt = commons.generateRandomDirtAreas()
	-------
	temperatureSensor = sensors.TemperatureSensor:new(INITIAL_ROOM_TEMPERATURE)
	dirtDetector = sensors.DirtDetector:new(dirt)
	battery = sensors.Battery:new()
	compass = sensors.Compass:new(robot)
	brush = actuators.Brush:new(dirt)
	robotMap = Map:new()
	robotController = Subsumption:new {
		RobotAdvance:new(),
		CollisionAvoidance:new(),
		RoomCoverage:new(robotMap),
		RoomCleaner:new(robotMap),
	}
	-------
	logger.stringify(robot)
end


-- Executed each time the simulation starts from 0
function init()
	setupWorkspace()
end

function step()

	if firstStep then
		logger.print('Dirt areas created: ', logger.LogLevel.INFO)
		if #dirtDetector.areaList == 0 then
			logger.print('NONE', logger.LogLevel.INFO)
		else
			for i = 1, #dirtDetector.areaList do
				logger.print(dirtDetector.areaList[i]:toString(), logger.LogLevel.INFO)
			end
		end
		firstStep = false
	end

	local position = Position:new(
		robot.positioning.position.x,
		robot.positioning.position.y
	)

	local state = RobotState:new{
		batteryLevel = battery.percentage,
		roomTemperature = temperatureSensor.temperature,
		robotDirection = compass:getCurrentDirection(),
		isDirtDetected = dirtDetector:detect(position),
		wheels = robot.wheels,
		proximity = robot.proximity,
	}

	local action = robotController:behave(state)

	if battery.percentage == 0 then
		robot.wheels.set_velocity(0, 0)
		robot.leds.set_all_colors(Color.RED)
	else

		if action.speed ~= nil then
			robot.wheels.set_velocity(action.speed.left, action.speed.right)
		end

		if action.hasToClean ~= nil and action.hasToClean then
			brush:clean(position)
		end

		if action.hasToRecharge ~= nil and action.hasToRecharge then
			battery:chargeMode()
		else
			battery:useMode()
		end

		if action.leds ~= nil and action.leds.switchedOn then
			robot.leds.set_all_colors(action.leds.color)
		elseif battery.percentage < 5 then
			robot.leds.set_all_colors(Color.MAGENTA)
		else
			robot.leds.set_all_colors(Color.BLACK)
		end

	end

	--battery:tick()
	temperatureSensor:tick()

end


--Executed when the reset button is pressed
function reset()
	setupWorkspace()
end

-- Executed on robot destruction
function destroy()
end