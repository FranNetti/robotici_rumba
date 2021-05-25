local math = require('math')

local DIRT_AREA_WIDTH = 0.5
local MIN_NUMBER_OF_DIRT_AREAS = 0
local MAX_NUMBER_OF_DIRT_AREAS = 5
local MIN_INTENSITY_OF_DIRT_AREAS = 2
local MAX_INTENSITY_OF_DIRT_AREAS = 10
local START_LAT = -0.5
local END_LAT = 0.5
local START_LNG = -0.5
local END_LNG = 0.5

local commons = {}

commons.Position = {
    new = function(self, lat, lng)
        local o = {
            lat = lat,
            lng = lng
        }
        setmetatable(o, self)
        self.__index = self
        return o
    end;

    toString = function (self)
        return 'Position(' .. self.lat ..'||' .. self.lng .. ')'
    end,

    __eq = function (a,b)
        return a.lat == b.lat and a.lng == b.lng
    end,
}
commons.DirtArea = {

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
    end,

    toString = function (self)
        return 'DirtArea(topLeft: ' .. self.topLeft:toString()
            .. "| bottomRight: " .. self.bottomRight:toString()
            .. "| dirtQuantity: " .. self.dirtQuantity .. ")"
    end
}
commons.Direction = {
    NORTH = {
        name = "N",
        ranges = { 180.6, 179.4, -179.4, -180.6 }
    },
    EAST = {
        name = "E",
        ranges = { 90.6, 89.4 }
    },
    SOUTH = {
        name = "S",
        ranges = { 0.6, -0.6 }
    },
    WEST ={
        name = "W",
        ranges = { -89.4, -90.6 }
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
commons.Color = {
    BLACK = "black", WHITE = "white", RED = "red", GREEN = "green", BLUE = "blue", MAGENTA = "magenta", CYAN = "cyan",
    YELLOW = "yellow", ORANGE = "orange", BROWN = "brown", PURPLE = "purple", GRAY = "gray40"
}

---If the given position is in dirtArea
---@param position table Position the position
---@param dirtArea table DirtArea the dirt area
---@return boolean if the given position is in dirtArea
commons.positionInDirtArea = function (position, dirtArea)
    return position.lat <= dirtArea.bottomRight.lat
        and position.lat >= dirtArea.topLeft.lat
        and position.lng >= dirtArea.topLeft.lng
        and position.lng <= dirtArea.bottomRight.lng
end
commons.decreseNumberSortFunction = function(a, b) return b < a end

commons.generateRandomDirtAreas = function ()
    local dirtAreas = {}
    local numberOfDirtAreas = math.random(
        MIN_NUMBER_OF_DIRT_AREAS,
        MAX_NUMBER_OF_DIRT_AREAS
    )
    for i = 0, numberOfDirtAreas do
        local dirtAreaIntensity = math.random(
            MIN_INTENSITY_OF_DIRT_AREAS,
            MAX_INTENSITY_OF_DIRT_AREAS
        )
        local centerLat = START_LAT + math.random() * (END_LAT - START_LAT)
        local centerLng = START_LNG + math.random() * (END_LNG - START_LNG)
        table.insert(dirtAreas, commons.DirtArea:new(
            commons.Position:new(centerLat - (DIRT_AREA_WIDTH / 2), centerLng - (DIRT_AREA_WIDTH / 2)),
            commons.Position:new(centerLat + (DIRT_AREA_WIDTH / 2), centerLng + (DIRT_AREA_WIDTH / 2)),
            dirtAreaIntensity
        ))
    end
    return dirtAreas
end

return commons;