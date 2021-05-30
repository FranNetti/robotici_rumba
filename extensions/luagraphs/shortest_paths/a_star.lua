local logger = require('util.logger')

local algorithm = {}
algorithm.__index = algorithm

----------------------------------------------------------------
-- Local variables
----------------------------------------------------------------

local INF = 1/0

----------------------------------------------------------------
-- Local functions
----------------------------------------------------------------

local function dist_between(nodeA, nodeB, distance_func)
    return distance_func(nodeA, nodeB)
end

local function heuristic_cost_estimate (nodeA, nodeB, distance_func)
	return distance_func(nodeA, nodeB)
end

local function lowest_f_score( set, f_score)

	local lowest, bestNode = INF, nil
	for _, node in ipairs ( set ) do
		local score = f_score [ node ]
		if score < lowest then
			lowest, bestNode = score, node
		end
	end
	return bestNode
end

local function neighbor_nodes(theNode, graph)
	local neighbors = {}
    local edges = graph.adjList[theNode]
	if edges ~= nil then
		for i = 0, edges.N - 1 do
			if theNode ~= edges.a[i]:to() then
				table.insert(neighbors, edges.a[i]:to())
			elseif theNode ~= edges.a[i]:from() then
				table.insert(neighbors, edges.a[i]:from())
			end
		end
	else
		logger.printToConsole('[A_STAR] neighbors were null')
    end
	return neighbors
end

local function not_in (set, theNode)
	for _, node in ipairs ( set ) do
		if node == theNode then return false end
	end
	return true
end

local function remove_node(set, theNode)
	for i, node in ipairs ( set ) do
		if node == theNode then
			set [ i ] = set [ #set ]
			set [ #set ] = nil
			break
		end
	end
end

local function unwind_path(flat_path, map, current_node)
	if map[current_node] then
		table.insert(flat_path, 1, map [current_node])
		return unwind_path(flat_path, map, map[current_node])
	else
		return flat_path
	end
end

----------------------------------------------------------------
-- Pathfinding functions
----------------------------------------------------------------

local function a_star(start, goal, graph, distance_func)

	local closedset = {}
	local openset = { start }
	local came_from = {}

	local g_score, f_score = {}, {}
	g_score [start] = 0
	f_score [start] = g_score [start] + heuristic_cost_estimate(start, goal, distance_func)

	while #openset > 0 do

		local current = lowest_f_score(openset, f_score)
		if current == goal then
			local path = unwind_path({}, came_from, goal)
			table.insert(path, goal)
			return path
		end

		remove_node(openset, current)
		table.insert(closedset, current)

		local neighbors = neighbor_nodes(current, graph)
		for _, neighbor in ipairs(neighbors) do
			if not_in ( closedset, neighbor ) then
				local tentative_g_score = g_score [ current ] + dist_between ( current, neighbor, distance_func )

				if not_in ( openset, neighbor ) or tentative_g_score < g_score [ neighbor ] then
					came_from 	[ neighbor ] = current
					g_score 	[ neighbor ] = tentative_g_score
					f_score 	[ neighbor ] = g_score [ neighbor ] + heuristic_cost_estimate ( neighbor, goal, distance_func )
					if not_in ( openset, neighbor ) then
						table.insert ( openset, neighbor )
					end
				end
			end
		end
	end
	return nil -- no valid path
end

----------------------------------------------------------------
-- Exposed functions
----------------------------------------------------------------

function algorithm.manhattanDistance(x1, y1, x2, y2)
    return math.abs(x1 - x2) + math.abs(y1 - y2)
end

function algorithm.euclideanDistance(x1, y1, x2, y2)
    return math.sqrt( math.pow(x1 - x2) + math.pow(y1 - y2))
end

function algorithm.create(graph)
    local a = {}
    setmetatable(a, algorithm)

    a.graph = graph
    return a
end

function algorithm:getPath(start, goal, distance_func)
    return a_star(start, goal, self.graph, distance_func)
end

return algorithm