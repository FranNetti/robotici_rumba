Commons = {}

Commons.Position = {
    new = function(self, lat, lng)
        local o = {
            lat = lat,
            lng = lng
        }
        setmetatable(o, self)
        self.__index = self
        return o
    end;
}

Commons.DirtArea = {
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
}

Commons.Direction = {
    NORTH = "NORTH", EAST = "EAST", SOUTH = "SOUTH", WEST = "WEST",
    NORTH_EAST = "NORTH_EAST", NORTH_WEST = "NORTH_WEST", SOUTH_EAST = "SOUTH_EAST", SOUTH_WEST = "SOUTH_WEST"
}

--[[
    parameters
        position: Position
        dirtArea: DirtArea
    return
        if the given position is in dirtArea
]]
Commons.positionInDirtArea = function (position, dirtArea)
    return position.lat <= dirtArea.bottomRight.lat
        and position.lat >= dirtArea.topLeft.lat
        and position.lng <= dirtArea.topLeft.lng
        and position.lng >= dirtArea.bottomRight.lng
end

Commons.stringify = function (object)
    require 'pl.pretty'.dump(object)
end

Commons.print = function (message)
    log(message)
end

Commons.printToConsole = function (message)
    print(message)
end

Commons.decreseNumberSortFunction = function(a, b) return b < a end

return Commons;