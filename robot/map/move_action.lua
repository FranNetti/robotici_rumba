Action = {
    GO_AHEAD = 0,
    TURN_LEFT = 1,
    TURN_RIGHT = 2,
    GO_BACK = 3,

    toString = function (val)
        if val == Action.GO_BACK then
            return "GO_BACK"
        elseif val == Action.TURN_LEFT then
            return "TURN LEFT"
        elseif val == Action.TURN_RIGHT then
            return "TURN RIGHT"
        else
            return "GO AHEAD"
        end
    end
}

return Action
