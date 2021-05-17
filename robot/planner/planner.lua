local cell_status = require('robot.map.cell_status')

local luaList = require('luagraphs.data.list')
local luaGraph = require('extensions.luagraphs.data.graph')
local aStar = require('extensions.luagraphs.shortest_paths.a_star')

local helpers = require('robot.planner.helpers')
local CellStatus = require('robot.map.cell_status')

local logger = require('util.logger')

Planner = {
    new = function(self, map)
        local vertices = luaList.create()
        vertices:add(Planner.encodeCoordinates(0, 0))
        local graph = luaGraph.createFromVertexList(vertices)

        local o = {
            map = map,
            graph = graph,
            aStar = aStar.create(graph),
            actions = nil
        }
        setmetatable(o, self)
        self.__index = self
        return o
    end,

    addNewDiagonalPoint = function(self, depth)
        local currentDepth = #self.map
        local depthDifference = depth - currentDepth
        self.graph:addVertexIfNotExists(self.encodeCoordinates(depth, depth))

        logger.print('Current depth = ' .. currentDepth)
        logger.print('Depth = ' .. depth)
        logger.print('Depth difference = ' .. depthDifference)

        if depthDifference > 0 then
            for i = 0, currentDepth do
                for j = currentDepth + 1, depth do
                    local cell = self.map[i][j-1]
                    --[[
                        link the new cell only if the one to the right isn't an
                        obstacle nor exists
                    ]]
                    if cell == nil or cell ~= cell_status.OBSTACLE then
                        self.graph:addEdge(
                            self.encodeCoordinates(i, j - 1),
                            self.encodeCoordinates(i, j)
                        )
                    end
                    self.graph:addEdge(
                        self.encodeCoordinates(i, j),
                        self.encodeCoordinates(i + 1, j)
                    )
                end
            end

            for i= currentDepth + 1, depth do
                local isFirstRow = i == currentDepth + 1
                if not isFirstRow or self.map[i - 1][0] ~= cell_status.OBSTACLE then
                    self.graph:addEdge(
                        self.encodeCoordinates(i - 1, 0),
                        self.encodeCoordinates(i, 0)
                    )
                end
                for j = 1, depth do
                    if i ~= j and isFirstRow and self.map[i - 1][j] ~= cell_status.OBSTACLE then
                        self.graph:addEdge(
                            self.encodeCoordinates(i - 1, j),
                            self.encodeCoordinates(i, j)
                        )
                    end
                    self.graph:addEdge(
                        self.encodeCoordinates(i, j - 1),
                        self.encodeCoordinates(i, j)
                    )
                    if i ~= depth then
                        self.graph:addEdge(
                            self.encodeCoordinates(i, j),
                            self.encodeCoordinates(i + 1, j)
                        )
                    end
                end
            end
        end
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
    ---@param excludePositions table Set - the set of position to exclude from the path
    ---@param areNewCellsToExploreMoreImportant boolean if the cells to yet explore are more important than the ones already explored
    ---@return table list of nodes to follow to reach the destination
    getPathTo = function (self, start, destination, excludePositions, areNewCellsToExploreMoreImportant)
        areNewCellsToExploreMoreImportant = areNewCellsToExploreMoreImportant or true
        excludePositions = excludePositions or Set:new{}

        return self.aStar:getPath(
            self.encodeCoordinatesFromPosition(start),
            self.encodeCoordinatesFromPosition(destination),
            function (pointA, pointB)

                if excludePositions:contain(pointB) or excludePositions:contain(pointA) then
                    return helpers.MAX_PATH_COST
                end

                local x1, y1 = Planner.decodeCoordinates(pointA)
                local x2, y2 = Planner.decodeCoordinates(pointB)

                local cost = aStar.manhattanDistance(x1, y1, x2, y2)
                if self.map[x2][y2] == CellStatus.TO_EXPLORE or not areNewCellsToExploreMoreImportant then
                    return cost
                else
                    return cost * 2
                end
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
        local excludedPositions = helpers.determinePositionsToExclude(
            excludeOptions,
            start,
            direction,
            self.encodeCoordinates
        )

        local path = self:getPathTo(
            start,
            destination,
            excludedPositions,
            areNewCellsToExploreMoreImportant
        )

        self.actions = helpers.determineActions(path, direction, self.decodeCoordinates)
        return self.actions
    end,

    setCellAs = function (self, cellPosition, cellStatus)
        if cellStatus == CellStatus.OBSTACLE and cellPosition.lat >= 0 and cellPosition.lng >= 0 then
            local coordinates = self.encodeCoordinatesFromPosition(cellPosition)
            self.graph:removeVertex(coordinates)
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