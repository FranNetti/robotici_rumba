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
	--robot.wheels.set_velocity(0, 10)
	commons.stringify(robot)
end

function step()
	--[[log("Battery percentage = " .. a.percentage)
	log("Temperature = " .. b.temperature)
	a:tick()
	b:tick() ]]

	count = count + 1;
	--[[ if count % 20 == 0 then
		left_v = - robot.wheels.velocity_left;
		right_v = - robot.wheels.velocity_right;
		robot.wheels.set_velocity(left_v,right_v)
	end ]]

	-- c:detect(commons.Position:new(0,0))
	-- d:clean(commons.Position:new(0,0))

	-- commons.stringify(robot.wheels)
	print("Positioning " .. math.deg( robot.positioning.orientation:toangleaxis()))
	print("Positioning " .. math.deg(robot.positioning.orientation:toeulerangles()))
	print(robot.wheels.distance_left)
	print(robot.wheels.distance_right)
	print(robot.wheels.velocity_left)
	print(robot.wheels.velocity_right)
	print("-------------")

	if math.ceil(math.deg(robot.positioning.orientation:toeulerangles())) == -90 then
		robot.wheels.set_velocity(0,0)
	end

	-- if(count == 100) then a:chargeMode() end
end


--Executed when the reset button is pressed
function reset()
	robot.wheels.set_velocity(0, 10)
end

-- Executed on robot destruction
function destroy()
end
