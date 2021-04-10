require 'math'
math.randomseed(1234)

local sensors = require 'robot.sensors'
local actuators = require 'robot.actuators'
local commons = require 'util.commons'
local State = (require 'robot.commons').State
local Subsumption = require 'robot.controller.subsumption'

local RobotAdvance = require 'robot.controller.behaviour.robot_advance'
local ObstacleAvoidance = require 'robot.controller.behaviour.obstacle_avoidance'

local parameters = require 'robot.parameters'

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

local distanceTravelled;

local map = require('robot.map.map'):new()

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
	}
	-------
	-- commons.stringify(robot)
    distanceTravelled = 0;
    robot.wheels.set_velocity(0, 0)
end


-- Executed each time the simulation starts from 0
function init()
	setupWorkspace()

	commons.print(map:toString())
	map:addNewDiagonalPoint(1)
	print("----------------")
	commons.print(map:toString())
	map:addNewDiagonalPoint(5)
	print("----------------")
	commons.print(map:toString())

end

function step()
end


--Executed when the reset button is pressed
function reset()
	setupWorkspace()
end

-- Executed on robot destruction
function destroy()
end