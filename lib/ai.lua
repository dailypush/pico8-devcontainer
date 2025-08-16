-- Enemy AI Library
-- Include with #INCLUDE lib/ai.lua

function simple_ai_chase(enemy, player, speed)
    if enemy.x < player.x then
        enemy.x += speed
    elseif enemy.x > player.x then
        enemy.x -= speed
    end
    
    if enemy.y < player.y then
        enemy.y += speed
    elseif enemy.y > player.y then
        enemy.y -= speed
    end
end

function patrol_ai(enemy, patrol_points, speed)
    if not enemy.patrol_target then
        enemy.patrol_target = 1
    end
    
    local target = patrol_points[enemy.patrol_target]
    local dist = distance(enemy.x, enemy.y, target.x, target.y)
    
    if dist < 2 then
        enemy.patrol_target = enemy.patrol_target % #patrol_points + 1
    else
        local dx = target.x - enemy.x
        local dy = target.y - enemy.y
        enemy.x += (dx / dist) * speed
        enemy.y += (dy / dist) * speed
    end
end
