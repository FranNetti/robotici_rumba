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
end

function step()
	robot.wheels.set_velocity(10, 10)
    distanceTravelled = distanceTravelled + robot.wheels.distance_left
	local c = robot.proximity[1].value ~= 0 or robot.proximity[2].value ~= 0 or robot.proximity[24].value ~= 0 or robot.proximity[23].value ~= 0
	for i=1,#robot.proximity do
		commons.print("prox " .. i .. " | " .. robot.proximity[i].value)
	end
	commons.print("-------")
    if c then
        robot.wheels.set_velocity(0, 0)
    end
    
end


--Executed when the reset button is pressed
function reset()
	setupWorkspace()
end

-- Executed on robot destruction
function destroy()
end