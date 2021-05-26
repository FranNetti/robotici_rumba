local commons = require('util.commons')
local Position, Direction = commons.Position, commons.Direction
local CellStatus = require('robot.controller.map.cell_status')

Map = {

    new = function(self)
        local o = {
            position = Position:new(0, 0),
            verticalOffset = {offset = 0, direction = Direction.NORTH},
            horizontalOffset = {offset = 0, direction = Direction.WEST},
            map = {[0] = {[0] = CellStatus.CLEAN}},
            isPerimeterIdentified = false,
        }
        setmetatable(o, self)
        self.__index = self
        return o
    end,

    addNewDiagonalPoint = function(self, depth)
        local currentDepth = #self.map
        local depthDifference = depth - currentDepth
        if depthDifference > 0 then
            for i = 0, currentDepth do
                for j = currentDepth + 1, depth do
                    self.map[i][j] = CellStatus.TO_EXPLORE
                end
            end

            for i= currentDepth + 1, depth do
                self.map[i] = {[0] = CellStatus.TO_EXPLORE}
                for j = 1, depth do
                    self.map[i][j] = CellStatus.TO_EXPLORE
                end
            end
        end
    end,

    getCell = function (self, position)
        return self.map[position.lat][position.lng]
    end,

    getCurrentCell = function (self)
        return self:getCell(self.position)
    end,

    updateVerticalOffset = function (self, offset, direction)
        if direction == self.verticalOffset.direction then
            self.verticalOffset.offset = self.verticalOffset.offset + offset
        else
            self.verticalOffset.offset = -self.verticalOffset.offset + offset
            self.verticalOffset.direction = direction
        end
    end,

    updateHorizontalOffset = function (self, offset, direction)
        if direction == self.horizontalOffset.direction then
            self.horizontalOffset.offset = self.horizontalOffset.offset + offset
        else
            self.horizontalOffset.offset = -self.horizontalOffset.offset + offset
            self.horizontalOffset.direction = direction
        end
    end,

    setVerticalOffset = function (self, offset, direction)
        self.verticalOffset = { offset = offset, direction = direction }
    end,

    setHorizontalOffset = function (self, offset, direction)
        self.horizontalOffset = { offset = offset, direction = direction }
    end,

    getVerticalOffset = function (self, direction)
        if direction == self.verticalOffset.direction then
            return self.verticalOffset.offset
        else
            return -self.verticalOffset.offset
        end
    end,

    getHorizontalOffset = function (self, direction)
        if direction == self.horizontalOffset.direction then
            return self.horizontalOffset.offset
        else
            return -self.horizontalOffset.offset
        end
    end,

    updatePosition = function (self, newPosition)
        self.position = newPosition
    end,

    setCellAs = function (self, cellPosition, cellStatus)
        if cellPosition.lat >= 0 and cellPosition.lng >= 0 then
            self.map[cellPosition.lat][cellPosition.lng] = cellStatus
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
}

return Map