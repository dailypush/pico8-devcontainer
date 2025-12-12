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
p={x=20,y=shore_y-8,aim=0.5,casting=false,cx=0,cy=0,vt=0,power=0}

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
  -- brighter, larger silhouette
  local c=13 -- dark grey/blue
  if (b.y%4<2) c=6 -- light grey variation
  
  -- body
  local off=b.dir*2
  rectfill(b.x-2,b.y-1,b.x+2,b.y+1,c)
  -- tail (directional)
  line(b.x-off,b.y,b.x-off*2,b.y-2,c)
  line(b.x-off,b.y,b.x-off*2,b.y+2,c)
  -- eye (white dot)
  pset(b.x+off,b.y-1,7)
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
 shake=0
 tod=0.3 -- start at morning
 tod_speed=0.0002 -- slow cycle
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
    -- soft splash sound
    play_subtle_sfx("splash")
    if rnd(1)<0.6 then add(parts,{k="bubble",x=p.x,y=water_y+1,vx=rnd(0.2)-0.1,vy=-0.25-rnd(0.25),t=20+flr(rnd(20)),c=7}) end
    del(parts,p)
   end
  elseif p.k=="bubble" then
   p.x+=p.vx + sin(time()*3+p.x*0.2)*0.1
   p.y+=p.vy
   if p.y<=water_y-2 or p.t<=0 then
    add(parts,{k="ring",x=p.x,y=water_y-2,r=1,vr=0.3,t=10,c=7})
    -- light bubble pop
    play_subtle_sfx("bubble")
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
 b.x=rod_tip_x or p.x+16
 b.y=rod_tip_y or p.y-8
 b.vy=0
 b.in_water=false
 b.waiting_t=0
 b.bite_t=0
 b.biting=false
end

function cast()
 local ang=lerp(0.6,0.9,p.aim) -- Up-Left to Up-Right
 b.x=rod_tip_x or p.x+16
 b.y=rod_tip_y or p.y-8
 b.vy=0
 p.vt=0
 p.power=40 -- good range
 p.cx=cos(ang)*p.power
 p.cy=sin(ang)*p.power
 state="casting"
 play_subtle_sfx("cast")
end

function start_waiting()
 b.in_water=true
 b.vy=0
 b.waiting_t=0
 b.bite_t=rndint(bite_min_wait,bite_max_wait)
 state="waiting"
 add_splash(b.x,water_y-2,10)
 -- soft splash cue
 play_subtle_sfx("splash")
end

function hook_fish()
 -- generate a fish when setting hook
 f={x=b.x,y=b.y,dx=0,dy=0,stamina=40+rnd(40),
     weight=0.5+rnd(4),tension=0,dir=choose({-1,1}),name=rand_fish(),
     rarity=chance({0.6,"common",0.25,"uncommon",0.14,"rare",0.01,"legendary"})}
 state="hooked"
 play_subtle_sfx("hook")
end

function lose_fish(msg)
 play_subtle_sfx("lose")
 add_floating_text(msg,b.x,b.y,9)
 reset_bobber()
 state="idle"
 f=nil
end

function fmt_w(w)
 -- format to 1 decimal place
 local s=tostr(flr(w))
 local d=flr((w-flr(w))*10)
 return s.."."..d.."lb"
end
function rand_fish()
 local names={"sunfish","perch","bass","carp","pike","walleye","bluegill"}
 return choose(names)
end
function time() return t() end

-- sfx map
sfx_map={
 cast=0,
 splash=0,
 bite=1,
 reel=2,
 win=3,
 lose=4,
 spark=5
}

function play_subtle_sfx(name)
 local id=sfx_map[name]
 if not id then return end
 
 -- reduce occurrence for ambient sounds
 if name=="splash" and rnd(1)>0.6 then return end
 if name=="spark" and rnd(1)>0.85 then return end
 
 sfx(id)
end

-- restore drawing functions that were removed earlier
function draw_background()
 -- grass/ground (top-down perspective)
 rectfill(0,0,127,shore_y,3)
 -- cliff face
 rectfill(0,shore_y,127,water_y,4)
 -- water
 rectfill(0,water_y,127,127,1)
 -- cliff edge highlight
 line(0,shore_y,127,shore_y,11)
 -- water edge foam
 line(0,water_y,127,water_y,7)
 
 -- particle-like waves
 draw_waves()
end

function draw_hud()
 -- top bar background
 rectfill(0,0,127,8,0)
 print("score:"..score,1,2,7)
 print("fish:"..fish_caught,50,2,7)
 
 if best_w>0 then
  print("best:"..best_name.."("..fmt_w(best_w)..")",1,10,6)
 end
 
 if state=="idle" or state=="aim" then
  -- controls at bottom
  print("arrows: aim",1,115,6)
  print("z: cast   x: hook/reel",1,121,6)
 end
end

-- rod tip position (global for line drawing)
rod_tip_x=0
rod_tip_y=0

function draw_player()
 -- cute cat fisherman (like reference image)
 local x=p.x
 local y=p.y
 
 -- shadow
 ovalfill(x-3,y+14,x+3,y+16,0)
 
 -- feet
 rectfill(x-3,y+12,x-1,y+14,1)
 rectfill(x+1,y+12,x+3,y+14,1)
 
 -- body (dark blue overalls)
 rectfill(x-4,y+2,x+4,y+12,1)
 
 -- red bow/collar
 rectfill(x-4,y,x+4,y+2,8)
 pset(x-5,y+1,8)
 pset(x+5,y+1,8)
 
 -- orange face
 rectfill(x-4,y-8,x+4,y,9)
 
 -- ears (orange with dark tips)
 rectfill(x-5,y-12,x-3,y-8,9)
 rectfill(x+3,y-12,x+5,y-8,9)
 pset(x-4,y-12,8) -- ear tips
 pset(x+4,y-12,8)
 
 -- headband (white)
 rectfill(x-4,y-10,x+4,y-9,7)
 
 -- headphones (dark blue)
 rectfill(x-6,y-10,x-5,y-5,1)
 rectfill(x+5,y-10,x+6,y-5,1)
 pset(x-7,y-7,1) -- extra ear piece
 pset(x+7,y-7,1)
 
 -- eyes (white)
 pset(x-2,y-5,7)
 pset(x+2,y-5,7)
 
 -- arms (orange)
 rectfill(x-5,y+2,x-4,y+5,9)
 rectfill(x+4,y+2,x+5,y+5,9)
 
 -- fishing rod (diagonal, going up-right)
 rod_tip_x=x+16
 rod_tip_y=y-8
 line(x+5,y+2,rod_tip_x,rod_tip_y,4)
 line(x+5,y+3,rod_tip_x,rod_tip_y-1,4)
 -- aim arc / preview dotted trajectory + landing ring
 if state=="idle" or state=="aim" then
  local ang=lerp(0.6,0.9,p.aim) -- Up-Left to Up-Right
  local vx=cos(ang)*4
  local vy=sin(ang)*4
  local tx=rod_tip_x
  local ty=rod_tip_y
  for i=1,60 do -- longer preview for arc
   if ty>=water_y-2 then break end
   if i%2==0 then pset(tx,ty,8) end -- dotted line
   tx+=vx
   ty+=vy
   vy+=0.2 -- gravity
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
  line(rod_tip_x,rod_tip_y,b.x,b.y,7)
 end
end

function draw_fish()
 if f then
  -- hooked fish: make it bright so it's visible against water
  local col=8
  if f.rarity=="uncommon" then col=11 end
  if f.rarity=="rare" then col=12 end
  if f.rarity=="legendary" then col=10+flr(time()*10)%2 end -- flash gold

  -- outline for visibility
  circfill(f.x,f.y,4,7)
  circfill(f.x,f.y,3,col)
  
  -- tail
  local off=f.dir*3
  line(f.x-off,f.y,f.x-off*2,f.y-2,col)
  line(f.x-off,f.y,f.x-off*2,f.y+2,col)
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

-- ambient sfx scheduler for Minecraft-like minimal ambience
amb_sfx={} -- queued ambient sfx {name,t}
amb_timer=180

function schedule_sfx(name,delay)
 add(amb_sfx,{name=name,t=delay})
end

-- process ambient queue and spawn sparse ambient cues
function process_ambient()
 -- tick queue
 for i=#amb_sfx,1,-1 do
  local e=amb_sfx[i]
  e.t-=1
  if e.t<=0 then
   play_subtle_sfx(e.name)
   del(amb_sfx,e)
  end
 end
 -- ambient periodic spawner
 amb_timer-=1
 if amb_timer<=0 then
  amb_timer=120+flr(rnd(240))
  -- primary gentle pluck
  play_subtle_sfx("cast")
  -- occasional soft echo plucks
  if rnd(1)<0.6 then
   local echoes=1+flr(rnd(3))
   for i=1,echoes do schedule_sfx("hook",2*i) end
  end
  -- low thud occasionally
  if rnd(1)<0.25 then schedule_sfx("lose",4) end
 end
end

function _update60()
 -- ambient audio processing
 process_ambient()

 -- shake decay
 shake=max(0,shake*0.9-0.1)
 -- time of day
 tod=(tod+tod_speed)%1

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
  p.cy+=0.2 -- gravity
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
   play_subtle_sfx("bite")
   b.bite_window=30 -- ~0.5s (easier)
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
  local spd=0.4
  if f.rarity=="legendary" then spd=0.8 end

  f.dx=sin(time()*0.7)*spd*f.dir + rnd(0.3)-0.15
  f.dy=sin(time()*1.1)*0.3 + rnd(0.2)-0.1

  -- legendary dash
  if f.rarity=="legendary" and rnd(1)<0.05 then
   f.dx+=choose({-2,2})
   add_splash(f.x,f.y,4)
  end

  f.x=clamp(f.x+f.dx,4,124)
  f.y=clamp(f.y+f.dy,water_y+6,124)

  -- shake based on tension
  if f.tension>line_max*0.5 then
   shake=(f.tension/line_max)*2
  end
  -- bobber follows fish with slack
  b.x=lerp(b.x,f.x,0.15)
  b.y=lerp(b.y,f.y-4,0.15)
  -- rare fish sparkle
  if (f.rarity=="rare" or f.rarity=="legendary") and rnd(1)<0.3 then
   add(parts,{k="spark",x=f.x,y=f.y,vx=rnd(0.3)-0.15,vy=-0.1-rnd(0.1),t=12,c=10})
   play_subtle_sfx("spark")
  end

  -- player reeling (accept either button as reel)
  if btn(5) or btn(4) then
   -- reduce stamina; increase tension
   f.stamina=max(0,f.stamina-1.0) -- faster catch
   f.tension=min(line_max, f.tension+1.0) -- less tension gain
   -- pull fish toward player x
   f.x=lerp(f.x,p.x+12,0.04) -- faster reel speed
   f.y=lerp(f.y,water_y+4,0.04)
   if rnd(1)<0.05 then add_splash(b.x,b.y,2) end
   
   -- reel sound
   if (time()*60)%8<1 then sfx(2) end
  else
   -- fish pulls if not reeling
   f.tension=max(0,f.tension-0.8) -- faster recovery
  end
  -- sudden fish runs
  if rnd(1)<0.005 then -- less frequent
   f.tension=min(line_max,f.tension+15) -- less punishment
   add_floating_text("run!",f.x,f.y,10)
  end

  -- line break
  if f.tension>=line_max then
   lose_fish("snap!")
   return
  end

  -- land fish when close to player and low stamina
  if f.stamina<=0 and abs(f.x-(p.x+12))<6 and f.y<water_y+8 then
   play_subtle_sfx("win")
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

-- sfx map (placeholder):
-- 0: cast/hook, 1: lose, 2: bite, 3: win
-- if you add real sprites, replace draw_fish() with spr() calls.

function set_palette()
 pal() -- reset
 if tod>0.4 and tod<0.6 then
  -- sunset
  pal(12,13) -- sky darker
  pal(1,13) -- water darker
 elseif tod>=0.6 or tod<0.1 then
  -- night
  pal(12,0) -- sky black
  pal(1,1) -- water dark blue
  pal(6,5) -- dim grays
  pal(7,6)
 end
end

function draw_title()
 cls(1)
 -- water shimmer
 for i=0,127 do
  local off=sin(time()+i*0.05)*2
  pset(i,64+off,12)
 end
 
 -- title
 local tx=64-24
 print("🐱 cat fishing 🐱",tx-8,30,7)
 print("cat fishing",tx,32,9)
 
 -- bobber animation
 local by=50+sin(time()*2)*3
 circfill(64,by,4,7)
 circfill(64,by-2,4,8)
 
 -- instructions
 print("arrows: aim your cast",24,80,6)
 print("z: cast line",40,90,6)
 print("x: hook & reel",36,100,6)
 
 print("press z or x to start",22,115,7)
end

function _draw()
 if state=="title" then
  draw_title()
  return
 end
 
 set_palette()
 cls(12) -- sky color
 camera(rnd(shake)-shake/2,rnd(shake)-shake/2)
 
 draw_background()
 draw_player()
 draw_bobber()
 draw_fish()
 draw_parts()
 draw_fx()
 camera(0,0)
 draw_hud()
 draw_meter()
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700007cc700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000007cc700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
01010000206501c64018630146201061000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01010000300503004000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01010000106300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0801000024050280502b050300500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
02010000105510854000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01010000350403c04000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 41424344
