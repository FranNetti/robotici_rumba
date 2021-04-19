local Set = require('util.set')
local commons = require('util.commons')
local Position = commons.Position

local luaList = require('luagraphs.data.list')
local luaGraph = require('extensions.luagraphs.data.graph')
local aStar = require('extensions.luagraphs.shortest_paths.a_star')

local CellStatus = require('robot.map.cell_status')
local helpers = require('robot.map.helpers')

Map = {

    new = function(self)
        local vertices = luaList.create()
        vertices:add(Map.encodeCoordinates(0, 0))
        local graph = luaGraph.createFromVertexList(vertices)

        local o = {
            position = Position:new(0, 0),
            map = {[0] = {[0] = CellStatus.CLEAN}},
            graph = graph,
            aStar = aStar.create(graph)
        }
        setmetatable(o, self)
        self.__index = self
        return o
    end,

    addNewDiagonalPoint = function(self, depth)
        local currentDepth = #self.map
        local depthDifference = depth - currentDepth + 1
        if depthDifference > 0 then
            for i = 0, currentDepth do
                for j = currentDepth + 1, depth do
                    self.map[i][j] = CellStatus.TO_EXPLORE
                    self.graph:addEdge(
                        Map.encodeCoordinates(i, j - 1),
                        Map.encodeCoordinates(i, j)
                    )
                    self.graph:addEdge(
                        Map.encodeCoordinates(i, j),
                        Map.encodeCoordinates(i + 1, j)
                    )
                end
            end

            for i= currentDepth + 1, depth do
                self.map[i] = {[0] = CellStatus.TO_EXPLORE}
                self.graph:addEdge(
                    Map.encodeCoordinates(i - 1, 0),
                    Map.encodeCoordinates(i, 0)
                )
                for j = 1, depth do
                    self.map[i][j] = CellStatus.TO_EXPLORE
                    self.graph:addEdge(
                        Map.encodeCoordinates(i, j - 1),
                        Map.encodeCoordinates(i, j)
                    )
                    if i ~= depth then
                        self.graph:addEdge(
                            Map.encodeCoordinates(i, j),
                            Map.encodeCoordinates(i + 1, j)
                        )
                    end
                end
            end
        end
    end,

    --- Get path to a given destination
    ---@param destination table Position - the destination that you want to reach
    ---@param excludePositions table Set - the set of position to exclude from the path
    ---@param areNewCellsToExploreMoreImportant boolean if the cells to yet explore are more important than the ones already explored
    ---@return table list of nodes to follow to reach the destination
    getPathTo = function (self, destination, excludePositions, areNewCellsToExploreMoreImportant)
        areNewCellsToExploreMoreImportant = areNewCellsToExploreMoreImportant or true
        excludePositions = excludePositions or Set:new{}

        return self.aStar:getPath(
            self.encodeCoordinates(self.position.lat, self.position.lng),
            destination,
            function (pointA, pointB)

                if excludePositions:contain(pointB) or excludePositions:contain(pointA) then
                    return helpers.MAX_PATH_COST
                end

                local x1, y1 = self.decodeCoordinates(pointA)
                local x2, y2 = self.decodeCoordinates(pointB)

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
    ---@param destination table Position - the destination that you want to reach
    ---@param excludeOptions table Set<ExcludeOption> - the set of cells to exclude from the path
    ---@param areNewCellsToExploreMoreImportant boolean if the cells to yet explore are more important than the ones already explored
    ---@return table list of action to do to reach the destination
    getActionsTo = function (self, destination, direction, excludeOptions, areNewCellsToExploreMoreImportant)
        local excludedPositions = helpers.determinePositionsToExclude(
            excludeOptions,
            self.position,
            direction,
            Map.encodeCoordinates
        )

        local path = self:getPathTo(
            destination,
            excludedPositions,
            areNewCellsToExploreMoreImportant
        )
        return helpers.determineActions(path, direction, Map.decodeCoordinates)
    end,

    updatePosition = function (self, newPosition)
        self.position = newPosition
    end,

    setCellAs = function (self, cellPosition, cellStatus)
        self.map[cellPosition.lat][cellPosition.lng] = cellStatus
        local coordinates = Map.encodeCoordinates(cellPosition.lat, cellPosition.lng)
        if cellStatus == CellStatus.OBSTACLE then
            self.graph:removeVertex(coordinates)
        end
    end,

    setCellAsDiry = function (self, cellPosition)
        self:setCellAs(cellPosition, CellStatus.DIRTY)
    end,

    setCellAsClean = function (self, cellPosition)
        self:setCellAs(cellPosition, CellStatus.CLEAN)
    end,

    setCellAsObstacle = function (self, cellPosition)
        self:setCellAs(cellPosition, CellStatus.OBSTACLE)
    end,

    toString = function(self)
        local val = ""
        local mapDepth = #self.map
        for i = 0, mapDepth do
            val = "|" .. val
            local rowDepth = #self.map[i]
            for j = 0, rowDepth do
                local cell = self.map[i][j]
                if i == self.position.lat and j == self.position.lng then
                    val = "|R" .. val
                elseif cell == CellStatus.CLEAN then
                    val = "| " .. val
                elseif cell == CellStatus.OBSTACLE then
                    val = "|X" .. val
                elseif cell == CellStatus.DIRTY then
                    val = "|D" .. val
                elseif cell == CellStatus.TO_EXPLORE then
                    val = "|?" .. val
                end
            end
            if i < mapDepth then
                val = "\n" .. val
            end
        end
        return val
    end,

    encodeCoordinates = function(lat, lng)
        return lat .. "|" .. lng
    end,

    decodeCoordinates = function(coordinatesString)
        for lat, lng in string.gmatch(coordinatesString, "(%w+)|(%w+)") do
            return tonumber(lat), tonumber(lng)
        end
    end


}

return Map