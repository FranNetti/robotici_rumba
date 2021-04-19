Set = {

    new = function (self, t)
        local set = {}
        setmetatable(set, self)
        self.__index = self
        for _, l in ipairs(t) do set[l] = true end
        return set
    end,

    add = function(self, t)
        self[t] = true
    end,

    toString = function (self)
        local s = "{"
        local sep = ""
        for e in pairs(self) do
          s = s .. sep .. e
          sep = ", "
        end
        return s .. "}"
    end,

    contain = function (self, elem)
        return self[elem] ~= nil
    end,

    containGreaterOrEqual = function  (self, elem)
        for key in pairs(self) do
            if key >= elem then
                return true
            end
        end
        return false
    end,

    toList = function (self)
        local list = {}
        for key in pairs(self) do
            table.insert(list, key)
        end
        return list
    end,

    toSortedList = function (self, sortFunction)
        local list = self:toList()
        table.sort(list, sortFunction)
        return list
    end,

    map = function (self, mapFunction)
        local newSet = Set:new{}
        for key, _ in pairs(self) do
            newSet:add(mapFunction(key))
        end
        return newSet
    end,

    __add = function (a,b)
        local res = Set:new{}
        for k in pairs(a) do res[k] = true end
        for k in pairs(b) do res[k] = true end
        return res
    end,

    __mul = function (a,b)
        local res = Set:new{}
        for k in pairs(a) do
            res[k] = b[k]
        end
        return res
    end

}

return Set