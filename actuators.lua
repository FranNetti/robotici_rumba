local commons = require 'commons'

Actuators = {

    Brush = {

        --[[
            parameters
                areaList: DirtArea[]
        ]]
        new = function(self, areaList)
            local o = {
                areaList = areaList,
            }
            setmetatable(o, self)
            self.__index = self
            return o
        end;

        clean = function(self, position)
            local length = #self.areaList
            for i=1,length do
                if commons.positionInDirtArea(position, self.areaList[i]) then
                    commons.log("-- Rumba is cleaning --")
                    self.areaList[i].dirtQuantity = self.areaList[i].dirtQuantity - 1
                    if self.areaList[i].dirtQuantity == 0 then
                        table.remove(self.areaList, i)
                    end
                    return
                end
            end
        end

    }

}

return Actuators