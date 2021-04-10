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

--[[ 	local vertices = require('luagraphs.data.list').create()
	vertices:add("0-0")
	vertices:add("0-1")
	vertices:add("0-2")
	vertices:add("1-0")
	vertices:add("1-1")
	vertices:add("1-2")
	vertices:add("2-0")
	vertices:add("2-1")
	vertices:add("2-2")
	local g = require('extensions.luagraphs.data.graph').createFromVertexList(vertices)
	g:addEdge("0-0", "1-0", 1)
	g:addEdge("0-1", "1-1", 1)
	g:addEdge("0-2", "1-2", 0)
	g:addEdge("1-0", "1-1", 1)
	g:addEdge("1-0", "2-0", 0)
	g:addEdge("1-1", "1-2", 0)
	g:addEdge("1-1", "2-1", 0)
	g:addEdge("1-2", "2-2", 0)
	g:addEdge("2-0", "2-1", 0)
	g:addEdge("2-1", "2-2", 0)

	commons.print(g:vertexCount())

	g:changeEdgeWeight("2-1", "2-2")
	g:removeEdge("0-0","1-0")

	commons.stringify(g)

	local dfs = require('luagraphs.shortest_paths.Dijkstra').create()
	local s = "1-0"
	dfs:run(g, s)
	local path = dfs:getPathTo("2-2")
	local pathText = ""
	while not path:isEmpty() do
		local x = path:pop()
		if pathText == "" then
			pathText = pathText .. x
		else
			pathText = pathText .. " -> " .. x
		end
	end
	for i=0,path:size()-1 do
		pathText = pathText .. "\n" .. path:get(i):from() .. " -> " .. path:get(i):to()
	end
	commons.print(pathText) ]]