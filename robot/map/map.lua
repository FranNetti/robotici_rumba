local commons = require 'util.commons'
local Position = commons.Position

local luaList = require('luagraphs.data.list')
local luaGraph = require('extensions.luagraphs.data.graph')

local CellStatus = require('robot.map.cell_status')

local CELL_TO_EXPLORE_COST = 0
local CELL_EXPLORED_COST = 1

Map = {

    new = function(self)
        local vertices = luaList.create()
        vertices:add(Map.encodeCoordinates(0, 0))

        local o = {
            position = Position:new(0, 0),
            map = {[0] = {[0] = CellStatus.CLEAN}},
            graph = luaGraph.createFromVertexList(vertices)
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
                        Map.encodeCoordinates(i, j),
                        CELL_TO_EXPLORE_COST
                    )
                    self.graph:addEdge(
                        Map.encodeCoordinates(i, j),
                        Map.encodeCoordinates(i + 1, j),
                        CELL_TO_EXPLORE_COST
                    )
                end
            end

            for i= currentDepth + 1, depth do
                self.map[i] = {[0] = CellStatus.TO_EXPLORE}
                self.graph:addEdge(
                    Map.encodeCoordinates(i - 1, 0),
                    Map.encodeCoordinates(i, 0),
                    CELL_TO_EXPLORE_COST
                )
                for j = 1, depth do
                    self.map[i][j] = CellStatus.TO_EXPLORE
                    self.graph:addEdge(
                        Map.encodeCoordinates(i, j - 1),
                        Map.encodeCoordinates(i, j),
                        CELL_TO_EXPLORE_COST
                    )
                    if i ~= depth then
                        self.graph:addEdge(
                            Map.encodeCoordinates(i, j),
                            Map.encodeCoordinates(i + 1, j),
                            CELL_TO_EXPLORE_COST
                        )
                    end
                end
            end
        end
    end,

    setCellAs = function (self, cellPosition, cellStatus)
        self.map[cellPosition.lat][cellPosition.lng] = cellStatus
        local coordinates = Map.encodeCoordinates(cellPosition.lat, cellPosition.lng)
        if cellStatus == CellStatus.OBSTACLE then
            self.graph:removeVertex(coordinates)
        else
            self.graph:changeAllEdgesWeightOfVertex(coordinates, CELL_EXPLORED_COST)
        end
    end,

    setDirtyCell = function (self, cellPosition)
        self:setCellAs(cellPosition, CellStatus.DIRTY)
    end,

    setCleanCell = function (self, cellPosition)
        self:setCellAs(cellPosition, CellStatus.CLEAN)
    end,

    setObstacleCell = function (self, cellPosition)
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