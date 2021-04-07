require 'math'
math.randomseed(1234)

local sensors = require 'robot.sensors'
local actuators = require 'robot.actuators'
local commons = require 'util.commons'
local State = (require 'robot.commons').State
local Subsumption = require 'robot.controller.subsumption'

local RobotAdvance = require 'robot.controller.behaviour.robot_advance'
local ObstacleAvoidance = require 'robot.controller.behaviour.obstacle_avoidance'

local INITIAL_ROOM_TEMPERATURE = 12;


local dirt = {
	commons.DirtArea:new(
		commons.Position:new(0,0),
		commons.Position:new(1, -1),
		3
	)
}

local temperatureSensor;
local dirtDetector;
local battery;
local compass;
local brush;
local robotController;

local function setupWorkspace()
	robot.wheels.set_velocity(0,0)
	robot.leds.set_all_colors(commons.Color.BLACK)
	-------
	temperatureSensor = sensors.TemperatureSensor:new(INITIAL_ROOM_TEMPERATURE)
	dirtDetector = sensors.DirtDetector:new(dirt)
	battery = sensors.Battery:new()
	compass = sensors.Compass:new(robot)
	brush = actuators.Brush:new(dirt)
	robotController = Subsumption:new {
		RobotAdvance,
		ObstacleAvoidance:new()
	}
	-------
	commons.stringify(robot)
end


-- Executed each time the simulation starts from 0
function init()
	setupWorkspace()
end

function step()

	local position = commons.Position:new(
		robot.positioning.position.x,
		robot.positioning.position.y
	)

	local state = State:new{
		battery_level = battery.percentage,
		room_temperature = temperatureSensor.temperature,
		robot_direction = compass:getCurrentDirection(),
		isDirtDetected = dirtDetector:detect(position),
		wheels = robot.wheels,
		proximity = robot.proximity,
	}

	local action = robotController:behave(state)

	if battery.percentage == 0 then
		robot.wheels.set_velocity(0, 0)
		robot.leds.set_all_colors(commons.Color.RED)
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
			robot.leds.set_all_colors(commons.Color.MAGENTA)
		else
			robot.leds.set_all_colors(commons.Color.BLACK)
		end

	end

	battery:tick()
	temperatureSensor:tick()

end


--Executed when the reset button is pressed
function reset()
	setupWorkspace()
end

-- Executed on robot destruction
function destroy()
end