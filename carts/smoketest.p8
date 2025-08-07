pico-8 cartridge # http://www.pico-8.com
version 41
__lua__
-- Simple PICO-8 Test Cart
-- This cart tests basic functionality

function _init()
    print("test cart loaded")
    cls()
end

function _update()
    -- Simple update logic
end

function _draw()
    cls(1)
    print("pico-8 test", 32, 60, 7)
    print("smoke test ok", 28, 70, 11)
    
    -- Draw a simple sprite
    circfill(64, 40, 10, 8)
    circfill(64, 40, 8, 14)
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__label__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
