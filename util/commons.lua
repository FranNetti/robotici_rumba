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

    __eq = function (a,b)
        return a.lat == b.lat and a.lng == b.lng
    end,
}

Commons.DirtArea = {

    ---Create a new DirtArea
    ---@param topLeft table Position
    ---@param bottomRight table Position
    ---@param dirtQuantity integer how much dirt there is
    ---@return table a new dirt area
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
    NORTH = {
        name = "N",
        ranges = { 180.4, 179.6, -179.6, -180.4 }
    },
    EAST = {
        name = "E",
        ranges = { 90.4, 89.6 }
    },
    SOUTH = {
        name = "S",
        ranges = { 0.4, -0.4 }
    },
    WEST ={
        name = "W",
        ranges = { -89.6, -90.4 }
    },
    NORTH_EAST ={
        name = "NE",
        ranges = {}
    },
    NORTH_WEST ={
        name = "NW",
        ranges = { }
    },
    SOUTH_EAST ={
        name = "SE",
        ranges = {}
    },
    SOUTH_WEST = {
        name = "SW",
        ranges = {}
    }
}

Commons.Color = {
    BLACK = "black", WHITE = "white", RED = "red", GREEN = "green", BLUE = "blue", MAGENTA = "magenta", CYAN = "cyan",
    YELLOW = "yellow", ORANGE = "orange", BROWN = "brown", PURPLE = "purple", GRAY = "gray40"
}

---If the given position is in dirtArea
---@param position table Position the position
---@param dirtArea table DirtArea the dirt area
---@return boolean if the given position is in dirtArea
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