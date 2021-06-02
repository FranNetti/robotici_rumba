local a_star = require('extensions.luagraphs.shortest_paths.a_star')
local Pair = require('extensions.lua.pair')
local table = require('extensions.lua.table')
local logger = require('util.logger')

local algorithm = {}
algorithm.__index = algorithm


local MAX_COST = 10000000000

local function distanceFunction(self, p1, p2, distanceFunc)
    if table.containsAny(self.nodesToExclude, {p1 , p2}) then
        return MAX_COST
    elseif table.contains(self.edgeToExclude, Pair:new(p1, p2)) then
        return MAX_COST
    else
        return distanceFunc(p1, p2)
    end
end

function algorithm:getKPath(start, goal, K, _excludeEdges, distanceFunc)
    _excludeEdges = _excludeEdges or {}
    local edgeToExclude, excludePositions = {}, {}
    local startEncoded = self.encodeFunction(start)
    local goalEncoded = self.encodeFunction(goal)
    edgeToExclude = _excludeEdges

    self.edgeToExclude = {table.unpack(edgeToExclude)}
    self.nodesToExclude = {table.unpack(excludePositions)}

    -- determine the shortest path from the source to the destination
    local shortestPath = a_star.create(self.graph):getPath(
        startEncoded,
        goalEncoded,
        function (p1, p2)
            return distanceFunction(self, p1, p2, distanceFunc)
        end
    )

    if shortestPath == nil then
        return {}
    end

    -- shortest paths
    local A = { shortestPath }
    -- potential shortest paths
    local B = {}

    for k = 2, K do
        local nodes = A[k - 1]

        -- the spur node ranges from the first node to the next to last node in the previous k-shortest path
        for i = 1, (#nodes - 1) do
            -- spur node is retrieved from the previous k-shortest path, k-1
            local spurNode = nodes[i]
            -- the sequence of nodes from the source to the spur node of the previous k-shortest path
            local rootPath = table.split(nodes, i)

            for path = 1, #A do
                if table.equals(rootPath, table.split(A[path], i)) then
                    -- remove the links that are part of the previous shortest paths which share the same root path
                    table.insert(self.edgeToExclude, Pair:new(nodes[i], nodes[i + 1]))
                end
            end

            for rootPathNode = 1, #rootPath do
                if rootPath[rootPathNode] ~= spurNode then
                    table.insert(self.nodesToExclude, rootPath[rootPathNode])
                end
            end

            -- calculate the spur path from the spur node to the destination
            local spurPath = a_star.create(self.graph):getPath(
                spurNode, goalEncoded,
                function (p1, p2)
                    return distanceFunction(self, p1, p2, distanceFunc)
                end
            )

            if spurPath ~= nil then
                -- entire path is made up of the root path and spur path
                local totalPath
                if #rootPath > 0 then
                    totalPath = rootPath
                    table.insertMultiple(totalPath, spurPath)
                else
                    totalPath = spurPath
                end
                -- add the potential k-shortest path to the heap
                if table.none(B, function (elem) return table.equals(totalPath, elem.first) end) then
                    table.insert(B, Pair:new(totalPath, #totalPath))
                end
            end

            self.edgeToExclude = {table.unpack(edgeToExclude)}
            self.nodesToExclude = {table.unpack(excludePositions)}
        end

        if #B == 0 then
            break
        end

        table.sort(B, function (a, b)
            return a.second < b.second
        end)

        local index = 1
        for i = 2, k do
            while table.equals(A[k - 1], B[index].first) do
                index = index + 1
            end
        end
        A[k] = B[index].first
        _, B = table.split(B, index)
    end
    return A
end

function algorithm.create(graph, encodeFunction, decodeFunction)
    local a = {}
    setmetatable(a, algorithm)

    a.graph = graph
    a.decodeFunction = decodeFunction
    a.encodeFunction = encodeFunction
    a.edgeToExclude = {}
    a.nodesToExclude = {}
    return a
end

return algorithm
