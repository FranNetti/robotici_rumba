local CollisionAvoidanceBehaviour = require('robot.controller.behaviour.collision_avoidance.collision_avoidance')

local helpers = {}

function helpers.isRobotCloseToObstacle(state)
    return CollisionAvoidanceBehaviour.isObjectInLeftRange(state.proximity)
        or CollisionAvoidanceBehaviour.isObjectInRightRange(state.proximity)
        or CollisionAvoidanceBehaviour.isObjectInFrontRange(state.proximity)
end


return helpers