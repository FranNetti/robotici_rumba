State = {
    ---nothing going on
    STAND_BY = "STAND BY",
    ---going to a target
    EXPLORING = "EXPLORING",
    --- target reached
    TARGET_REACHED = "TARGET REACHED",
    ---going back home
    GOING_HOME = "GOING HOME",
    -- home reached, turning the robot in the right direction
    CALIBRATING_HOME = "CALIBRATING HOME",
    ---room explored
    EXPLORED = "EXPLORED",
}

return State