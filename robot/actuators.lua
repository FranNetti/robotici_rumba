local commons = require('util.commons')
local logger = require('util.logger')

local BRUSH_CLEAN_FREQUENCY = 10

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
            local area = self.areaList[i]
            if commons.positionInDirtArea(position, area) then
                logger.print("-- Rumba is cleaning --", logger.LogLevel.INFO)

                if area.counter == nil then
                    area.counter = 1
                else
                    area.counter = area.counter + 1
                end

                if area.counter % BRUSH_CLEAN_FREQUENCY == 0 then
                    area.dirtQuantity = area.dirtQuantity - 1
                    if area.dirtQuantity <= 0 then
                        table.remove(self.areaList, i)
                    end
                end
                return
            end
        end
    end

}

return Actuators