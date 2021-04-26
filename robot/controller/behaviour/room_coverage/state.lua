State = {
    ---nothing going on
    STAND_BY = "STAND BY",
    ---going to a target
    EXPLORING = "EXPLORING",
    --- target reached
    TARGET_REACHED = "TARGET REACHED",
    ---going back home
    GOING_HOME = "GOING HOME",
    -- obstacle encountered during any phase of the robot movement
    OBSTACLE_ENCOUNTERED = "OBSTACLE ENCOUNTERED",
    ---room explored
    EXPLORED = "EXPLORED",
}

return State