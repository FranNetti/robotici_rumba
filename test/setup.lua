require 'math'
local cell_status = require "robot.map.cell_status"
math.randomseed(1234)
local commons = require 'util.commons'
local Position = require 'util.commons'.Position
local Direction = require 'util.commons'.Direction
local ExcludeOption = require('robot.planner.exclude_option')
local Set = require 'util.set'

local map = require('robot.map.map')
local planner = require('robot.planner.planner')
local logger = require('util.logger')

local function setupWorkspace()
end


-- Executed each time the simulation starts from 0
function init()
	local miaMappa = map:new()
	local mioPlanner = planner:new(miaMappa.map)

	for i = 1, 7 do
		mioPlanner:addNewDiagonalPoint(i)
		miaMappa:addNewDiagonalPoint(i)
	end

	for i = 0, 7 do
		for y = 0, 7 do
			mioPlanner:setCellAsClean(Position:new(i,y))
			miaMappa:setCellAsClean(Position:new(i,y))
		end
	end
	mioPlanner:setCellAsObstacle(Position:new(0,7))
	miaMappa:setCellAsObstacle(Position:new(0,7))

	mioPlanner:addNewDiagonalPoint(8)
	miaMappa:addNewDiagonalPoint(8)

	logger.printToConsole(miaMappa:toString())
	logger.printToConsole('||||||||||||||||||||||')

	local ciccio = mioPlanner:getActionsTo(Position:new(0,0), Position:new(8, 8), Direction.SOUTH, Set:new{ExcludeOption.EXCLUDE_BACK})

	logger.stringify(mioPlanner.graph)
	'ciao'.toString()
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