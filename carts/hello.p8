-- Simple PICO-8 cart template
-- by Chad

function _init()
    -- initialize game state
    x = 64
    y = 64
    dx = 1
    dy = 1
end

function _update()
    -- update game logic
    x += dx
    y += dy
    
    -- bounce off edges
    if x >= 120 or x <= 8 then
        dx = -dx
    end
    
    if y >= 120 or y <= 8 then
        dy = -dy
    end
end

function _draw()
    -- clear screen
    cls()
    
    -- draw a bouncing ball
    circfill(x, y, 4, 8)
    
    -- draw some text
    print("hello pico-8!", 32, 10, 7)
    print("press z to test", 28, 20, 6)
    
    -- simple input test
    if btn(4) then -- z button
        print("z pressed!", 34, 30, 8)
    end
end
