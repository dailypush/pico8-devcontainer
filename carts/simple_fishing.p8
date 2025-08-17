pico-8 cartridge # http://www.pico-8.com
version 41
__lua__

-- pico-8 fishing (polished pass)
-- cart: simple_fishing.p8
-- by chatgpt + chad
-- controls: arrows aim, z cast, x set hook / reel

-- constants
water_y=80           -- water surface y
shore_y=72
cast_power_max=60
bite_min_wait=60     -- 1s at 60fps
bite_max_wait=240    -- 4s
reel_gain=0.6
fish_pull=0.5
line_max=100

-- game state
state="title"
score=0
fish_caught=0
best_w=0
best_name="-"

-- player
p={x=16,y=shore_y,aim=0.5,casting=false,cx=0,cy=0,vt=0,power=0}

-- bobber
b={x=0,y=0,vy=0,in_water=false,waiting_t=0,bite_t=0,biting=false}

-- fish
f=nil -- active hooked fish

-- particles (splashes, bubbles)
parts={}

-- ambient background fish (non-hooked, decorative)
bgfish={}
function spawn_bgfish()
 -- spawn at left or right edge
 local dir=choose({-1,1})
 local x = dir==1 and -8 or 136
 local y = water_y + 6 + flr(rnd(30))
 local speed = 0.3 + rnd(0.6)
 add(bgfish,{x=x,y=y,dir=dir,speed=speed,age=60+flr(rnd(180))})
end

function update_bgfish()
 -- occasionally spawn
 if rnd(1)<0.02 and #bgfish<6 then spawn_bgfish() end
 for i=#bgfish,1,-1 do
  local b=bgfish[i]
  b.x+=b.speed*b.dir
  b.age-=1
  if b.age<=0 or b.x<-16 or b.x>144 then del(bgfish,b) end
 end
end

function draw_bgfish()
 for b in all(bgfish) do
  -- small visible fish under surface: bright color for contrast
  pset(b.x,b.y,8)
  pset(b.x-1,b.y,6)
  -- tail
  line(b.x-2,b.y,b.x-4,b.y-1,6)
  line(b.x-2,b.y,b.x-4,b.y+1,6)
 end
end

-- surface waves as small drifting foam puffs
waves={}
function spawn_wave(x)
 add(waves,{x=x or flr(rnd(128)),y=water_y-1,r=1,vr=0.15,alpha=1,t=18,vx=(rnd(0.6)-0.3)})
end

function update_waves()
 -- spawn occasional waves along surface
 if rnd(1)<0.08 then spawn_wave() end
 for i=#waves,1,-1 do
  local w=waves[i]
  w.x+=w.vx
  w.r+=w.vr
  w.t-=1
  if w.t<=0 then del(waves,w) end
 end
end

function draw_waves()
 for w in all(waves) do
  -- draw as expanding faint rings/pset
  circ(w.x,w.y,w.r,12)
  pset(w.x,w.y,11)
 end
end

function _init()
end

-- helpers
function lerp(a,b,t) return a+(b-a)*t end
function clamp(x,a,b) return max(a,min(b,x)) end
function rndint(a,b) return flr(a+rnd(b-a+1)) end
function choose(t) return t[flr(rnd(#t))+1] end
function chance(t)
 -- pairs of {p,label}
 local r=rnd(1)
 local acc=0
 for i=1,#t,2 do
  acc+=t[i]
  if r<=acc then return t[i+1] end
 end
 return t[#t]
end

-- fx text
fx={} -- {t,x,y,c,txt}
function add_floating_text(txt,x,y,c)
 add(fx,{t=45,x=x,y=y,c=c or 7,txt=txt})
end

-- particles
function add_splash(x,y,n)
 y=water_y-2
 local count=n or 8
 for i=1,count do
  local a=rnd(1)
  local sp=0.8+rnd(1.2)
  local vx=cos(a)*sp
  local vy=sin(a)*sp-0.6
  add(parts,{k="drop",x=x,y=y,vx=vx,vy=vy,t=20+flr(rnd(20)),c=12})
 end
 -- surface ring
 add(parts,{k="ring",x=x,y=y,r=1,vr=0.6,t=18,c=12})
 -- bubbles under surface
 for i=1,flr(count/3) do
  add(parts,{k="bubble",x=x+rnd(4)-2,y=water_y+1+rnd(3),vx=rnd(0.2)-0.1,vy=-0.2-rnd(0.3),t=20+flr(rnd(20)),c=7})
 end
end

function update_parts()
 for i=#parts,1,-1 do
  local p=parts[i]
  p.t-=1
  if p.k=="drop" then
   p.vx*=0.98
   p.vy+=0.12
   p.x+=p.vx
   p.y+=p.vy
   if p.y>=water_y-1 or p.t<=0 then
    add(parts,{k="ring",x=p.x,y=water_y-2,r=1,vr=0.5+rnd(0.3),t=12,c=12})
    if rnd(1)<0.6 then add(parts,{k="bubble",x=p.x,y=water_y+1,vx=rnd(0.2)-0.1,vy=-0.25-rnd(0.25),t=20+flr(rnd(20)),c=7}) end
    del(parts,p)
   end
  elseif p.k=="bubble" then
   p.x+=p.vx + sin(time()*3+p.x*0.2)*0.1
   p.y+=p.vy
   if p.y<=water_y-2 or p.t<=0 then
    add(parts,{k="ring",x=p.x,y=water_y-2,r=1,vr=0.3,t=10,c=7})
    del(parts,p)
   end
  elseif p.k=="ring" then
   p.r+=p.vr or 0.4
   if p.t<=0 then del(parts,p) end
  elseif p.k=="spark" then
   p.x+=p.vx
   p.y+=p.vy
   p.vy-=0.02
   if p.t<=0 then del(parts,p) end
  else
   if p.t<=0 then del(parts,p) end
  end
 end
end

function draw_parts()
 for p in all(parts) do
  if p.k=="ring" then
   circ(p.x,p.y,p.r,p.c or 7)
  elseif p.k=="bubble" then
   pset(p.x,p.y,p.c or 7)
  elseif p.k=="drop" then
   pset(p.x,p.y,p.c or 12)
  elseif p.k=="spark" then
   pset(p.x,p.y,p.c or 10)
  end
 end
end

function reset_bobber()
 b.x=p.x
 b.y=p.y-2
 b.vy=0
 b.in_water=false
 b.waiting_t=0
 b.bite_t=0
 b.biting=false
end

function cast()
 local ang=lerp(-0.8,0.1,p.aim) -- up-left to slight up-right
 b.x=p.x
 b.y=p.y-2
 b.vy=0
 p.vt=0
 p.power=cast_power_max
 p.cx=cos(ang)*p.power
 p.cy=sin(ang)*p.power
 state="casting"
 sfx(0)
end

function start_waiting()
 b.in_water=true
 b.vy=0
 b.waiting_t=0
 b.bite_t=rndint(bite_min_wait,bite_max_wait)
 state="waiting"
 add_splash(b.x,water_y-2,10)
end

function hook_fish()
 -- generate a fish when setting hook
 f={x=b.x,y=b.y,dx=0,dy=0,stamina=40+rnd(40),
     weight=0.5+rnd(4),tension=0,dir=choose({-1,1}),name=rand_fish(),
     rarity=chance({0.7,"common",0.25,"uncommon",0.05,"rare"})}
 state="hooked"
 sfx(0)
end

function lose_fish(msg)
 sfx(1)
 add_floating_text(msg,b.x,b.y,9)
 reset_bobber()
 state="idle"
 f=nil
end

function fmt_w(w) return tostr(w,1).."lb" end
function rand_fish()
 local names={"sunfish","perch","bass","carp","pike","walleye","bluegill"}
 return choose(names)
end
function time() return t() end

-- drawing ------------------------------------------------------
function draw_background()
 -- sky
 rectfill(0,0,127,shore_y-1,12)
 -- distant water band (parallax)
 for y=shore_y,water_y-1 do
  local c=11
  pset(0,0,c) -- no-op, keeps color ref quiet
 end
 rectfill(0,shore_y,127,water_y-1,11)
 -- water
 rectfill(0,water_y,127,127,1)
 -- particle-like waves
 draw_waves()
end

function draw_hud()
 print("score:"..score,1,1,7)
 print("fish:"..fish_caught,1,7,7)
 if best_w>0 then
  print("best:"..best_name.."("..fmt_w(best_w)..")",44,1,6)
 else
  print("best: none",44,1,6)
 end
 if state=="idle" or state=="aim" then
  print("arrows: aim",26,1,6)
  print("z: cast   x: hook/reel",26,7,6)
 end
end

function draw_player()
 -- simple fisherman sprite made of primitives
 rectfill(p.x-2,p.y-2,p.x+2,p.y+2,10) -- body
 circfill(p.x,p.y-6,2,7) -- head
 -- rod
 line(p.x+3,p.y-6,p.x+10,p.y-14,5)
 -- aim arc / preview dotted trajectory + landing ring
 if state=="idle" or state=="aim" then
  local ang=lerp(-0.8,0.1,p.aim)
  local vx=cos(ang)*cast_power_max*0.1
  local vy=sin(ang)*cast_power_max*0.1
  local tx=p.x
  local ty=p.y-4
  for i=1,22 do
   if ty>=water_y-2 then break end
   pset(tx,ty,8)
   tx+=vx
   ty+=vy
   vy+=0.3
  end
  local lx=clamp(tx,2,125)
  circ(lx,water_y-2,3,10)
 end
end

function draw_bobber()
 if state=="casting" or b.in_water or state=="waiting" or state=="hooked" or state=="bite" then
  local wig=0
  if state=="waiting" then wig=sin(time()*20)*1 end
  if state=="bite" then wig=sin(time()*40)*2 end
  -- red/white bobber
  circfill(b.x,b.y+wig,3,7) -- base white
  circfill(b.x,b.y-1+wig,3,8) -- top red
  line(b.x,b.y-4+wig,b.x,b.y-6+wig,7) -- little stick
 end
 -- line
 if state~="idle" and state~="title" then
  line(p.x+10,p.y-14,b.x,b.y,7)
 end
end

function draw_fish()
 if f then
  -- hooked fish: make it bright so it's visible against water
  circfill(f.x,f.y,3,8)
  -- tail
  line(f.x-4,f.y,f.x-8,f.y-2,9)
  line(f.x-4,f.y,f.x-8,f.y+2,9)
 end
 -- draw ambient bg fish on top of water
 draw_bgfish()
end

function draw_meter()
 if not f then return end
 -- tension bar
 rect(92,2,124,10,0)
 local ratio=clamp(f.tension/line_max,0,1)
 rectfill(93,3,93+flr(30*ratio),9,ratio>0.8 and 8 or 11)
 print("line",94,12,7)
 -- stamina
 rect(92,16,124,24,0)
 local sratio=clamp(f.stamina/80,0,1)
 rectfill(93,17,93+flr(30*sratio),23,3)
 print("stam",94,26,7)
end

function draw_fx()
 for i=#fx,1,-1 do
  local o=fx[i]
  print(o.txt,o.x,o.y,o.c)
  o.y-=0.2
  o.t-=1
  if o.t<=0 then del(fx,o) end
 end
end

-- update -------------------------------------------------------
function _update60()
 update_parts()
 update_bgfish()
 update_waves()
 -- debug: show button presses for troubleshooting input mapping
 if btnp(4) then add_floating_text("z pressed",p.x,p.y-14,8) end
 if btnp(5) then add_floating_text("x pressed",p.x+12,p.y-14,9) end

 if state=="title" then
  if btnp(4) or btnp(5) then state="idle" reset_bobber() end
  return
 end
 
 -- aiming / idle
 if state=="idle" or state=="aim" then
  if btn(0) then p.aim=clamp(p.aim-0.01,0,1) state="aim" end
  if btn(1) then p.aim=clamp(p.aim+0.01,0,1) state="aim" end
  if btnp(4) then cast() end
  return
 end
 
 if state=="casting" then
  -- projectile motion until hits water
  b.x+=p.cx*0.1
  b.y+=p.cy*0.1
  p.cy+=0.3
  if b.y>=water_y-2 then
   b.y=water_y-2
   start_waiting()
  end
  return
 end
 
 if state=="waiting" then
  -- gentle float
  b.y=water_y-2+sin(time())
  b.waiting_t+=1
  if b.waiting_t>=b.bite_t then
   b.biting=true
   state="bite"
   b.vy=1
   sfx(2)
   b.bite_window=18 -- ~0.3s
  end
  -- set hook early does nothing
  if btnp(4) or btnp(5) then add_floating_text("too soon!",b.x,b.y,8) end
  return
 end
 
 if state=="bite" then
  -- quick dunk
  b.y=water_y+1
  b.bite_window-=1
  -- allow either button to set the hook
  if btnp(4) or btnp(5) then hook_fish() return end
  if b.bite_window<=0 then
   lose_fish("missed!")
  end
  return
 end
 
 if state=="hooked" then
  -- fish fights: random pulls + player reels
  -- fish movement
  f.dx=sin(time()*0.7)*0.4*f.dir + rnd(0.3)-0.15
  f.dy=sin(time()*1.1)*0.3 + rnd(0.2)-0.1
  f.x=clamp(f.x+f.dx,4,124)
  f.y=clamp(f.y+f.dy,water_y+6,124)
  -- bobber follows fish with slack
  b.x=lerp(b.x,f.x,0.15)
  b.y=lerp(b.y,f.y-4,0.15)
  -- rare fish sparkle
  if f.rarity=="rare" and rnd(1)<0.3 then
   add(parts,{k="spark",x=f.x,y=f.y,vx=rnd(0.3)-0.15,vy=-0.1-rnd(0.1),t=12,c=10})
  end
  
  -- player reeling (accept either button as reel)
  if btn(5) or btn(4) then
   -- reduce stamina; increase tension
   f.stamina=max(0,f.stamina-reel_gain)
   f.tension=min(line_max, f.tension+1.5)
   -- pull fish toward player x
   f.x=lerp(f.x,p.x+12,0.02)
   f.y=lerp(f.y,water_y+4,0.02)
   if rnd(1)<0.05 then add_splash(b.x,b.y,2) end
  else
   -- fish pulls if not reeling
   f.tension=max(0,f.tension-0.6)
  end
  -- sudden fish runs
  if rnd(1)<0.01 then
   f.tension=min(line_max,f.tension+20)
   add_floating_text("run!",f.x,f.y,10)
  end
  
  -- line break
  if f.tension>=line_max then
   lose_fish("snap!")
   return
  end
  
  -- land fish when close to player and low stamina
  if f.stamina<=0 and abs(f.x-(p.x+12))<6 and f.y<water_y+8 then
   sfx(3)
   local pts=flr(10+f.weight*5+(f.rarity=="rare" and 20 or f.rarity=="uncommon" and 10 or 0))
   score+=pts
   fish_caught+=1
   add_floating_text("caught "..f.name.." ("..fmt_w(f.weight)..") +"..pts,f.x,f.y-6,7)
   if f.weight>best_w then best_w=f.weight best_name=f.name end
   f=nil
   reset_bobber()
   state="idle"
  end
  return
 end
end

function _draw()
 cls(12)
 draw_background()
 draw_hud()
 draw_player()
 draw_bobber()
 draw_fish()
 draw_meter()
 draw_fx()
 draw_parts()
 if state=="title" then
  rectfill(12,40,115,88,1)
  rect(12,40,115,88,7)
  print("tiny fishing!",38,48,7)
  print("arrows aim  z cast",26,62,6)
  print("x set hook / reel",32,70,6)
  print("press any key",40,82,7)
 end
end

-- sfx map (placeholder):
-- 0: cast/hook, 1: lose, 2: bite, 3: win
-- if you add real sprites, replace draw_fish() with spr() calls.

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700007cc700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000007cc700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
001000000f0500e0500d0500c0500b0500a0500905008050070500605005050040500305002050010500005000050000500005000050000500005000050000500005000050000500005000050000500005
001000001f0501e0501d0501c0501b0501a0501905018050170501605015050140501305012050110501005000050000500005000050000500005000050000500005000050000500005000050000500005
00100000300503305035050380503a0503c0503e050400504205043050440504505046050470504805049050000500005000050000500005000050000500005000050000500005000050000500005000050
00200000600506305065050680506a0506c0506e050700507205073050740507505076050770507805079050000500005000050000500005000050000500005000050000500005000050000500005000050
__music__
00 41424344
