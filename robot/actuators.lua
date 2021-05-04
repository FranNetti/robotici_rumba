local commons = require('util.commons')
local logger = require('util.logger')

Actuators = {}

Actuators.Brush = {

    ---Create a new brush
    ---@param areaList table DirtArea[] the list of area where dirt is located
    ---@return table a new brush
    new = function(self, areaList)
        local o = {
            areaList = areaList,
        }
        setmetatable(o, self)
        self.__index = self
        return o
    end;

    ---Clean in the current position
    ---@param position table Postion the position where the robot is located
    clean = function(self, position)
        local length = #self.areaList
        for i=1,length do
            if commons.positionInDirtArea(position, self.areaList[i]) then
                logger.print("-- Rumba is cleaning --", logger.LogLevel.INFO)
                self.areaList[i].dirtQuantity = self.areaList[i].dirtQuantity - 1
                if self.areaList[i].dirtQuantity == 0 then
                    table.remove(self.areaList, i)
                end
                return
            end
        end
    end

}

return Actuators