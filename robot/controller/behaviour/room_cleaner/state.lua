State = {
    ---standard behaviour
    WORKING = "WORKING",
    ---dirt detected in another cell than the one the robot currently is
    GOING_TO_DIRT = "GOING TO DIRT POSITION",
    -- obstacle encountered during any phase of the robot movement
    OBSTACLE_ENCOUNTERED = "OBSTACLE ENCOUNTERED",
}

return State