Commons = {

    Position = {
        new = function(self, lat, lng)
            local o = {
                lat = lat,
                lng = lng
            }
            setmetatable(o, self)
            self.__index = self
            return o
        end;
    },

    DirtArea = {
        --[[
            parameters
                topLeft: Position,
                bottomRight: Position,
                dirtQuantity: integer
        ]]
        new = function(self, topLeft, bottomRight, dirtQuantity)
            local o = {
                topLeft = topLeft,
                bottomRight = bottomRight,
                dirtQuantity = dirtQuantity
            }
            setmetatable(o, self)
            self.__index = self
            return o
        end;

        clean = function (self)
            if self.dirtQuantity > 0 then
                self.dirtQuantity = self.dirtQuantity - 1
            end
        end
    },

    --[[
        parameters
            position: Position
            dirtArea: DirtArea
        return
            if the given position is in dirtArea
    ]]
    positionInDirtArea = function (position, dirtArea)
        return position.lat <= dirtArea.bottomRight.lat
            and position.lat >= dirtArea.topLeft.lat
            and position.lng <= dirtArea.topLeft.lng
            and position.lng >= dirtArea.bottomRight.lng
    end,

    stringify = function (object)
        require 'pl.pretty'.dump(object)
    end,

    log = function (message)
        log(message)
    end

}

return Commons;