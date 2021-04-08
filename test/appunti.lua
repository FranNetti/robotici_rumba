--[[
	local ddd = e:getCurrentDirection()
	log("Battery percentage = " .. a.percentage)
	log("Temperature = " .. b.temperature)
	a:tick()
	b:tick()
	if count % 20 == 0 then
		left_v = - robot.wheels.velocity_left;
		right_v = - robot.wheels.velocity_right;
		robot.wheels.set_velocity(left_v,right_v)
	end

	-- c:detect(commons.Position:new(0,0))
	-- d:clean(commons.Position:new(0,0))

	-- commons.stringify(robot.wheels)
	commons.print("Positioning " .. math.deg(robot.positioning.orientation:toangleaxis()))
	commons.print("Direction " .. ddd)
	commons.print("-------------")

	-- if(count == 100) then a:chargeMode() end
	]]

    	--[[ a:useMode()
	robot.wheels.set_velocity(0, 5)
	commons.stringify(robot)
	e = sensors.Compass:new(robot)
	aa = aa + Set:new{13,2,3,4,5, 65}
	local list = aa:toList()
	commons.printToConsole(aa:toString())
	table.sort( list, function(a, b) return b < a end )
	commons.stringify(aa:toSortedList(commons.decreseNumberSortFunction)) ]]