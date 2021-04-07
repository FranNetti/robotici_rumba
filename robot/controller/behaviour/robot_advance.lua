local Action = (require 'robot/commons').Action

local ROBOT_FORWARD_SPEED = 10;

RobotAdvance = {

    tick = function (_, _)
        return Action:new {
            speed = {
                left = ROBOT_FORWARD_SPEED,
                right = ROBOT_FORWARD_SPEED
            }
        }
    end

}

return RobotAdvance;