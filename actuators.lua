Actuators = {

    Brush = {

        new = function(self)
            local o = {}
            setmetatable(o, self)
            self.__index = self
            return o
        end;

        clean = function(self)
            log("-- Rumba is cleaning --")
        end

    }

}

return Actuators