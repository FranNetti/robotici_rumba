local commons = require 'util.commons'
local Position = commons.Position

local CellStatus = {
    CLEAN = 0, DIRTY = 1, OBSTACLE = 2
}

RobotMap = {

    new = function(self)
        local o = {
            position = Position:new(0, 0),
            map = {{CellStatus.CLEAN}}
        }
        setmetatable(o, self)
        self.__index = self
        return o
    end,

    setCellAs = function (self, cellPosition, cellStatus)
        self.map[cellPosition.lat][cellPosition.lng] = cellStatus
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


}