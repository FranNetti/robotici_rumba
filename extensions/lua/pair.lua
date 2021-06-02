local pair = {}

function pair:new(first, second)
    local o = {
        first = first,
        second = second
    }
    setmetatable(o, self)
    self.__index = self
    return o
end

function pair.__eq(pair1, pair2)
    return pair2.first == pair1.first and pair2.second == pair1.second
end

function pair:toString()
    return "<<" .. self.first .. ">><<" .. self.second .. ">>"
 end

return pair