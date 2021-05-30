State = {
    ---standard behaviour
    WORKING = "WORKING",
    --- battery at limit, going to home
    ALERT_GOING_CHARGING_STATION = "ALERT GOING CHARGING STATION",
    -- robot at home charging the battery
    CHARGING = "CHARGING",
    -- obstacle encountered during any phase of the robot movement
    OBSTACLE_ENCOUNTERED = "OBSTACLE ENCOUNTERED",
}

return State