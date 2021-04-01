require 'math'
math.randomseed(1234)
local sensors = require 'sensors'
local actuators = require 'actuators'
local commons = require 'commons'


local dirt = {
	commons.DirtArea:new(
		commons.Position:new(0,0),
		commons.Position:new(1, -1),
		3
	)
}

local a = sensors.Battery:new()
local b = sensors.TemperatureSensor:new(12)
local c = sensors.DirtDetector:new(dirt)
local d = actuators.Brush:new(dirt)
local count = 0


-- Executed each time the simulation starts from 0
function init()
	a:useMode()
	-- require 'pl.pretty'.dump(robot)
end

function step()
	--[[log("Battery percentage = " .. a.percentage)
	log("Temperature = " .. b.temperature)
	a:tick()
	b:tick()

	count = count + 1;]]

	c:detect(commons.Position:new(0,0))
	d:clean(commons.Position:new(0,0))

	-- if(count == 100) then a:chargeMode() end
end


--Executed when the reset button is pressed
function reset()
end

-- Executed on robot destruction
function destroy()
end
