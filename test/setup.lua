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
local Set = require('util.set')

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

	cell_status = require('robot.map.cell_status')
	setupWorkspace()

	-- commons.printToConsole(map:toString())
	map:addNewDiagonalPoint(1)
	map.map[0][1] = cell_status.CLEAN
	map.map[1][0] = cell_status.CLEAN
	map.map[1][1] = cell_status.CLEAN
	--commons.stringify(map.graph)
	-- commons.printToConsole("----------------")
	map:addNewDiagonalPoint(5)
	-- commons.stringify(map.graph)


	--[[ commons.stringify(require('extensions.luagraphs.shortest_paths.a_star').create(map.graph):getPath(
		"0|0",
		"2|2",
		function (pointA, pointB)

			local x1, y1 = map.decodeCoordinates(pointA)
			local x2, y2 = map.decodeCoordinates(pointB)
			local cost = math.abs(x1 - x2) + math.abs(y1 - y2)
			if map.map[x2][y2] == cell_status.TO_EXPLORE then
				return cost
			else
				return cost * 2
			end
		end
	)) ]]

	local ex = require('robot.map.exclude_option')

	local cc = map:getActionsTo("2|2", commons.Direction.NORTH, Set:new{ex.EXCLUDE_LEFT, ex.EXCLUDE_RIGHT, ex.EXCLUDE_BACK})
	for i = 1, #cc do
		commons.printToConsole(require('robot.map.move_action').toString(cc[i]))
	end
	commons.printToConsole(map:toString())

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