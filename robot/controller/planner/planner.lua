local luaList = require('luagraphs.data.list')
local luaGraph = require('extensions.luagraphs.data.graph')
local aStar = require('extensions.luagraphs.shortest_paths.a_star')
local yen_ksp = require('extensions.luagraphs.shortest_paths.yen_ksp')

local helpers = require('robot.controller.planner.helpers')
local CellStatus = require('robot.controller.map.cell_status')
local MoveAction = require('robot.controller.planner.move_action')

local logger = require('util.logger')
local Set = require('util.set')
local Pair = require('extensions.lua.pair')

local function addNewDiagonalPoint(planner, map, currentDepth, depth)
    local depthDifference = depth - currentDepth
    planner.graph:addVertexIfNotExists(planner.encodeCoordinates(depth, depth))

    if depthDifference > 0 then
        for i = 0, currentDepth do
            for j = currentDepth + 1, depth do
                local cell = map[i][j-1]
                --[[
                    link the new cell only if the one to the right isn't an
                    obstacle nor exists
                ]]
                if cell == nil or cell ~= CellStatus.OBSTACLE then
                    planner.graph:addEdge(
                        planner.encodeCoordinates(i, j - 1),
                        planner.encodeCoordinates(i, j)
                    )
                end
                planner.graph:addEdge(
                    planner.encodeCoordinates(i, j),
                    planner.encodeCoordinates(i + 1, j)
                )
            end
        end

        for i= currentDepth + 1, depth do
            local isFirstRow = i == currentDepth + 1
            if not isFirstRow or map[i - 1][0] ~= CellStatus.OBSTACLE then
                planner.graph:addEdge(
                    planner.encodeCoordinates(i - 1, 0),
                    planner.encodeCoordinates(i, 0)
                )
            end
            for j = 1, depth do
                if i ~= j and isFirstRow and map[i - 1][j] ~= CellStatus.OBSTACLE then
                    planner.graph:addEdge(
                        planner.encodeCoordinates(i - 1, j),
                        planner.encodeCoordinates(i, j)
                    )
                end
                planner.graph:addEdge(
                    planner.encodeCoordinates(i, j - 1),
                    planner.encodeCoordinates(i, j)
                )
                if i ~= depth then
                    planner.graph:addEdge(
                        planner.encodeCoordinates(i, j),
                        planner.encodeCoordinates(i + 1, j)
                    )
                end
            end
        end
    end
end

Planner = {
    new = function(self, map)
        local vertices = luaList.create()
        vertices:add(Planner.encodeCoordinates(0, 0))
        local graph = luaGraph.createFromVertexList(vertices)

        local o = {
            map = map,
            graph = graph,
            aStar = aStar.create(graph),
            yen = yen_ksp.create(
                graph,
                Planner.encodeCoordinatesFromPosition,
                Planner.decodeCoordinates
            ),
            actions = nil
        }
        setmetatable(o, self)
        self.__index = self
        if #map > 0 then
            addNewDiagonalPoint(o, map, 0, #map)
        end
        return o
    end,

    addNewDiagonalPoint = function(self, depth)
        addNewDiagonalPoint(self, self.map, #self.map, depth)
    end,

    removeFirstAction = function (self)
        if self.actions ~= nil and #self.actions >= 1 then
            table.remove(self.actions, 1)
        end
    end,

    addActionToHead = function (self, action)
        if self.actions ~= nil then
            table.insert(self.actions, 1, action)
        else
            self.actions = {action}
        end
    end,

    changeAction = function (self, index, action)
        if self.actions ~= nil and #self.actions >= index then
            self.actions[index] = action
        end
    end,

    --- Get path to a given destination
    ---@param start table Position - the position where you currently are
    ---@param destination table Position - the destination that you want to reach
    ---@param backPosition table Position - the position right behind the starting point
    ---@param excludeEdges table Set - the set of position to exclude from the path
    ---@param areNewCellsToExploreMoreImportant boolean if the cells to yet explore are more important than the ones already explored
    ---@return table list of nodes to follow to reach the destination
    getPathTo = function (self, start, destination, backPosition, excludeEdges, areNewCellsToExploreMoreImportant)
        if areNewCellsToExploreMoreImportant == nil then
            areNewCellsToExploreMoreImportant = areNewCellsToExploreMoreImportant or true
        end
        excludeEdges = excludeEdges or Set:new{}
        backPosition = self.encodeCoordinatesFromPosition(backPosition)
        start = self.encodeCoordinatesFromPosition(start)
        destination = self.encodeCoordinatesFromPosition(destination)

        return self.aStar:getPath(
            start, destination,
            function (pointA, pointB)

                local x1, y1 = Planner.decodeCoordinates(pointA)
                local x2, y2 = Planner.decodeCoordinates(pointB)

                if self.map[x1][y1] == CellStatus.OBSTACLE or self.map[x2][y2] == CellStatus.OBSTACLE then
                    return helpers.OBSTACLE_CELL_COST
                elseif Pair:new(pointA, pointB) == Pair:new(start, backPosition)
                    or Pair:new(pointA, pointB) == Pair:new(backPosition, start) then
                    return helpers.BACK_OPTION_COST
                elseif excludeEdges:contain(Pair:new(pointA, pointB):toString())
                    or excludeEdges:contain(Pair:new(pointB, pointA):toString()) then
                    return helpers.EXCLUDED_OPTIONS_COST
                end

                local cost = aStar.manhattanDistance(x1, y1, x2, y2)
                if self.map[x2][y2] == CellStatus.TO_EXPLORE
                    or self.map[x2][y2] == CellStatus.TO_EXPLORE
                    or not areNewCellsToExploreMoreImportant then
                    return cost
                else
                    return cost * 2
                end
            end,
            function (point, goal)
                return helpers.heuristicFunction(self, point, goal)
            end
        )
    end,

    --- Get actions to do in order to reach a given destination
    ---@param start table Position - the position where you currently are
    ---@param destination table Position - the destination that you want to reach
    ---@param excludeOptions table Set<ExcludeOption> - the set of cells to exclude from the path
    ---@param areNewCellsToExploreMoreImportant boolean if the cells to yet explore are more important than the ones already explored
    ---@return table list of action to do to reach the destination
    getActionsTo = function (self, start, destination, direction, excludeOptions, areNewCellsToExploreMoreImportant)
        if self.map[destination.lat][destination.lng] == CellStatus.OBSTACLE then
            self.actions = {}
            return {}
        end

        local excludedEdges = helpers.determineEdgesToExclude(
            excludeOptions,
            start,
            direction,
            self.encodeCoordinates
        )

        local path = self:getPathTo(
            start,
            destination,
            MoveAction.nextPosition(start, direction, MoveAction.GO_BACK),
            excludedEdges,
            areNewCellsToExploreMoreImportant
        )

        self.actions = helpers.determineActions(path, direction, self.decodeCoordinates)
        return self.actions
    end,

    getFastActionsTo = function (self, start, destination, direction, excludeOptions)
        local excludedEdges = helpers.determineEdgesToExclude(
            excludeOptions,
            start,
            direction,
            self.encodeCoordinates
        )

        if helpers.isCloseToHomeDestination(start, destination, direction) then
            return helpers.getGoToHomeActions(start, direction)
        end

        local paths = self.yen:getKPath(
            start,
            destination,
            helpers.NUMBER_OF_ROUTES_TO_FIND,
            excludedEdges:toList(),
            function (pointA, pointB)

                local x1, y1 = self.decodeCoordinates(pointA)
                local x2, y2 = self.decodeCoordinates(pointB)

                if self.map[x1][y1] == CellStatus.OBSTACLE or self.map[x2][y2] == CellStatus.OBSTACLE then
                    return helpers.OBSTACLE_CELL_COST
                end

                local cost = aStar.manhattanDistance(x1, y1, x2, y2)
                --[[
                    avoid cells yet to explore because anything can happen and the robot
                    wants to quickly reach home with less possible problems
                ]]
                if self.map[x1][y1] == CellStatus.TO_EXPLORE or self.map[x2][y2] == CellStatus.TO_EXPLORE then
                    return helpers.CELL_TO_EXPLORE_COST
                else
                    return cost
                end
            end,
            function (point, goal)
                return helpers.heuristicFunction(self, point, goal)
            end
        )

        local actions = {}
        local min = Pair:new(1000, 1)
        local i = 1
        while i <= helpers.NUMBER_OF_ROUTES_TO_FIND and i <= #paths do
            local listOfActions = helpers.determineActions(
                paths[i],
                direction,
                self.decodeCoordinates
            )
            local count = helpers.countNumberOfTurns(listOfActions)
            table.insert(actions, listOfActions)
            if count < min.first then
                min = Pair:new(count, i)
            end
            i = i + 1
        end

        self.actions = actions[min.second]
        return self.actions
    end,

    setCellAs = function (self, cellPosition, cellStatus)
        if cellPosition.lat >= 0 and cellPosition.lng >= 0 then
            if cellPosition.lat > #self.map then
                self:addNewDiagonalPoint(cellPosition.lat)
            elseif cellPosition.lng > #self.map[cellPosition.lat] then
                self:addNewDiagonalPoint(cellPosition.lng)
            end
        end
    end,

    setCellAsDirty = function (self, cellPosition)
        self:setCellAs(cellPosition, CellStatus.DIRTY)
    end,

    setCellAsClean = function (self, cellPosition)
        self:setCellAs(cellPosition, CellStatus.CLEAN)
    end,

    setCellAsObstacle = function (self, cellPosition)
        self:setCellAs(cellPosition, CellStatus.OBSTACLE)
    end,

    encodeCoordinates = function(lat, lng)
        return lat .. "|" .. lng
    end,

    encodeCoordinatesFromPosition = function(position)
        return Planner.encodeCoordinates(position.lat, position.lng)
    end,


    decodeCoordinates = function(coordinatesString)
        for lat, lng in string.gmatch(coordinatesString, "(%w+)|(%w+)") do
            return tonumber(lat), tonumber(lng)
        end
    end

}

return Planner