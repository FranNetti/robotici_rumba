require 'math'
math.randomseed(1234)
local sensors = require 'sensors'

local a = sensors.Battery:new()
local b = sensors.TemperatureSensor:new(12)
local count = 0


-- Executed each time the simulation starts from 0
function init()
	a:useMode()
	-- require 'pl.pretty'.dump(robot)
end

function step()
	log("Battery percentage = " .. a.percentage)
	log("Temperature = " .. b.temperature)
	a:tick()
	b:tick()

	count = count + 1;

	if(count == 100) then a:chargeMode() end
end


--Executed when the reset button is pressed
function reset()
	a:aaa()
end

-- Executed on robot destruction
function destroy()
end
