local Set = require 'set'
local Action = (require 'robot').Action

Subsumption = {

    --[[
        parameters
            behaviours: Behaviour[] bottom-up
    ]]
    new = function (self, behaviours)
        local o = {
            behaviours = behaviours,
            behavioursNumber = #behaviours
        }
        setmetatable(o, self)
        self.__index = self
        return o
    end,

    --[[
        parameters
            state: Robot.State
        returns
            Robot.Action
    ]]
    behave = function (self, state)
        local behavioursActions = {}
        local behavioursToSubsume = Set:new{}
        -- flow from top to bottom in order to let heigher levels subsume lower levels
        for i = self.behavioursNumber, 1, -1 do
            if not behavioursToSubsume:contain(i) then
                local action = self.behaviours[i].tick(state)
                --[[ if action.levelsToSubsume:containGreaterOrEqual(i) then
                    error("You're trying to subsume a level higher than you!")
                end ]]
                behavioursToSubsume = behavioursToSubsume + Set:new(action.levelsToSubsume)
                table.insert(behavioursActions, 1, action)
            end
        end
        local finalAction = Action:new{}
        local actionsNumber = #behavioursActions
        for i = 1, actionsNumber do
            finalAction = finalAction + behavioursActions[i]
        end
        return finalAction
    end

}

return Subsumption