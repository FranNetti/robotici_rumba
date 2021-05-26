State = {
    ---standard behaviour
    WORKING = "WORKING",
    --- room temperature over threshold, going to home
    ALERT_GOING_HOME = "ALERT GOING HOME",
    -- robot at home waiting for room temperature to decrease
    ALERT = "ALERT",
    -- obstacle encountered during any phase of the robot movement
    OBSTACLE_ENCOUNTERED = "OBSTACLE ENCOUNTERED",
}

return State