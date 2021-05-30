local Set = require('util.set')
local Action = require('robot.commons').Action

Subsumption = {

    subsumeAll = "SUBSUME ALL LEVELS",

    ---Create a new controller with subsumption architecture
    ---@param behaviours table Behavior[] the list of behaviours starting from the lower level up to the higher ones
    ---@return table a new controller with subsumption architecture
    new = function (self, behaviours)
        local o = {
            behaviours = behaviours,
            behavioursNumber = #behaviours
        }
        setmetatable(o, self)
        self.__index = self
        return o
    end,

    ---Activates all the behaviors
    ---@param state table Robot.State the current state
    ---@return table Robot.Action the action to perform
    behave = function (self, state)
        local behavioursActions = {}
        local behavioursToSubsume = Set:new{}
        -- flow from top to bottom in order to let heigher levels subsume lower levels
        for i = self.behavioursNumber, 1, -1 do
            if not behavioursToSubsume:contain(i) and not behavioursToSubsume:contain(Subsumption.subsumeAll) then
                local action = self.behaviours[i]:tick(state)
                --[[ if action.levelsToSubsume:containGreaterOrEqual(i) then
                    error("You're trying to subsume a level higher than you!")
                end ]]
                behavioursToSubsume = behavioursToSubsume + Set:new(action.levelsToSubsume)
                table.insert(behavioursActions, action)
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