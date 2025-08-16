-- PICO-8 Utility Library
-- Place reusable functions here and include with #INCLUDE lib/utils.lua

function distance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return sqrt(dx * dx + dy * dy)
end

function clamp(value, min_val, max_val)
    return max(min_val, min(max_val, value))
end

function lerp(a, b, t)
    return a + (b - a) * clamp(t, 0, 1)
end

-- Collision detection
function rect_collision(x1, y1, w1, h1, x2, y2, w2, h2)
    return x1 < x2 + w2 and
           x2 < x1 + w1 and
           y1 < y2 + h2 and
           y2 < y1 + h1
end
