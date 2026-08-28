pico-8 cartridge # http://www.pico-8.com
version 41
__lua__

-- pico-8 fishing (polished pass)
-- cart: simple_fishing.p8
-- by chatgpt + chad
-- controls: arrows aim, z cast, x set hook / reel

-- constants
shore_y=72
dock_y=shore_y+6
water_y=dock_y+9      -- water surface y
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
p={x=28,y=shore_y-14,aim=0.5,casting=false,cx=0,cy=0,vt=0,power=0}

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
  local c=(flr(b.y)%4<2) and 13 or 5
  local bob=sin(time()*0.7+b.x/32)
  local head=b.x+b.dir*2
  local tail=b.x-b.dir*3
  ovalfill(b.x-3,b.y-1+bob,b.x+3,b.y+1+bob,c)
  line(tail,b.y+bob,tail-b.dir*3,b.y-2+bob,c)
  line(tail,b.y+bob,tail-b.dir*3,b.y+2+bob,c)
  pset(head,b.y-1+bob,6)
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
 local ang=lerp(0.95,0.85,p.aim) -- mostly rightward, slight arc
 b.x=rod_tip_x or p.x+16
 b.y=rod_tip_y or p.y-8
 b.vy=0
 p.vt=0
 p.power=50 -- longer range
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

-- campfire particles
fire_parts={}
function update_fire()
 local base_x=105
 local base_y=shore_y-10

 -- spawn flame tongues (dense near base)
 if rnd(1)<0.7 then
  add(fire_parts,{
   k="flame",
   x=base_x+rnd(6)-3,
   y=base_y+rnd(2),
   vx=rnd(0.3)-0.15,
   vy=-0.6-rnd(0.5),
   t=10+flr(rnd(10)),
   r=1+flr(rnd(2))
  })
 end

 -- spawn embers (occasional sparks)
 if rnd(1)<0.12 then
  add(fire_parts,{
   k="ember",
   x=base_x+rnd(6)-3,
   y=base_y,
   vx=rnd(0.8)-0.4,
   vy=-1.2-rnd(0.8),
   t=8+flr(rnd(10))
  })
 end

 -- spawn smoke (less frequent, drifts)
 if rnd(1)<0.18 then
  add(fire_parts,{
   k="smoke",
   x=base_x+rnd(6)-3,
   y=base_y-6,
   vx=rnd(0.2)-0.1,
   vy=-0.3-rnd(0.2),
   t=18+flr(rnd(20))
  })
 end

 -- update particles
 for i=#fire_parts,1,-1 do
  local p=fire_parts[i]
  p.t-=1
  if p.k=="flame" then
   p.x+=p.vx + sin(time()*6+p.y*0.2)*0.08
   p.y+=p.vy
   p.vy+=0.03 -- slow as it rises
   if p.t<=0 then del(fire_parts,p) end
  elseif p.k=="ember" then
   p.x+=p.vx
   p.y+=p.vy
   p.vy+=0.08
   p.vx*=0.92
   if p.t<=0 then del(fire_parts,p) end
  else -- smoke
   p.x+=p.vx + sin(time()*2+p.x*0.15)*0.05
   p.y+=p.vy
   if p.t<=0 then del(fire_parts,p) end
  end
 end
end

function draw_fire()
 -- campfire base (logs) - isometric style
 local fx=105
 local fy=shore_y-8
 
 -- stone ring (isometric oval)
 for i=0,6 do
  local ox=cos(i/7)*5
  local oy=sin(i/7)*2
  pset(fx+ox,fy+oy+2,5)
 end
 
 -- logs (crossed, 3D)
 line(fx-3,fy+1,fx+3,fy+1,4)
 line(fx-2,fy,fx+2,fy+2,9)
 
 -- fire glow + flicker core
 local flick=sin(time()*8)
 circfill(fx,fy-1,6,2)
 circfill(fx+flick,fy-4,4,9)
 circfill(fx-flick,fy-6,3,10)

 -- tapered flame core (reads more like licking flames)
 for dy=0,11 do
  local t=dy/11
  local w=flr(4-(t*4))
  local ox=sin(time()*9+dy*0.7)*1
  local c=10
  if dy>2 then c=9 end
  if dy>6 then c=8 end
  if dy>9 then c=2 end
  if w>0 then
   line(fx-w+ox,fy-2-dy,fx+w+ox,fy-2-dy,c)
  else
   pset(fx+ox,fy-2-dy,c)
  end
 end
 pset(fx+flick,fy-14,7)

 -- particles
 for p in all(fire_parts) do
  if p.k=="flame" then
   local c=8
   if p.t>12 then c=10 elseif p.t>7 then c=9 elseif p.t>3 then c=8 else c=2 end
   if p.r==2 then
    circfill(p.x,p.y,1,c)
   else
    pset(p.x,p.y,c)
    if rnd(1)<0.4 then pset(p.x,p.y+1,c) end
   end
  elseif p.k=="ember" then
   local c=(p.t>6) and 10 or ((p.t>3) and 9 or 8)
   pset(p.x,p.y,c)
  else
   local c=(p.t>10) and 13 or 5
   pset(p.x,p.y,c)
   if rnd(1)<0.25 then pset(p.x+1,p.y,c) end
  end
 end
end

function shprint(s,x,y,c)
 print(s,x+1,y+1,0)
 print(s,x,y,c)
end

-- chunky control glyphs stay readable on a small screen
function draw_keycap(x,y,k,c)
 rectfill(x,y,x+9,y+9,0)
 rect(x,y,x+9,y+9,c or 7)
 line(x+2,y+8,x+7,y+8,5)
 print(k,x+3,y+2,c or 7)
end

function draw_dpad(x,y,c)
 local col=c or 7
 rectfill(x+4,y,x+8,y+12,0)
 rectfill(x,y+4,x+12,y+8,0)
 rect(x+4,y,x+8,y+12,col)
 rect(x,y+4,x+12,y+8,col)
 pset(x+6,y+2,col)
 pset(x+2,y+6,col)
 pset(x+10,y+6,col)
 pset(x+6,y+10,col)
end

function draw_controls()
 local flash=flr(time()*8)%2==0
 local panel=0
 local accent=7
 if state=="bite" then
  panel=flash and 8 or 2
  accent=10
 end
 rectfill(0,111,127,127,panel)
 line(0,111,127,111,state=="bite" and 10 or 5)

 if state=="idle" or state=="aim" then
  draw_dpad(3,113,12)
  shprint("aim",19,116,7)
  draw_keycap(46,113,"z",10)
  shprint("cast",59,116,7)
  print("range",91,116,6)
 elseif state=="casting" then
  shprint("casting...",43,116,12)
 elseif state=="waiting" then
  draw_keycap(17,113,"x",10)
  shprint("hook when it bites!",31,116,7)
 elseif state=="bite" then
  draw_keycap(25,113,"x",10)
  shprint("hook now!",40,116,10)
 elseif state=="hooked" then
  draw_keycap(17,113,"x",10)
  shprint("hold to reel",31,116,7)
  print("release red",84,116,8)
 end
end

-- small scenery helpers keep the landscape crisp at 128x128
function draw_cloud(x,y,c)
 circfill(x,y+2,4,c)
 circfill(x+5,y,5,c)
 circfill(x+11,y+2,4,c)
 rectfill(x,y+2,x+11,y+5,c)
end

function draw_pine(x,y,h)
 line(x,y-h,x,y,4)
 for i=3,h,4 do
  local w=flr(i/3)+2
  line(x-w,y-h+i,x+w,y-h+i,3)
  line(x-w+1,y-h+i-1,x+w-1,y-h+i-1,11)
 end
end

function draw_reeds(x,y)
 for i=0,3 do
  local rx=x+i*2
  local rh=3+(i%3)*2
  line(rx,y,rx,y-rh,3)
  pset(rx+(i%2)*2-1,y-rh,11)
 end
end

function draw_background()
 -- sky gradient
 for y=0,50 do
  local c=12
  if y>=14 and y<28 then c=6 end
  if y>=28 then c=7 end
  line(0,y,127,y,c)
 end

 -- sun, moon and fixed stars make the day cycle readable
 local sx=8+tod*112
 local sy=40-sin(tod)*27
 circfill(sx,sy,6,10)
 circfill(sx-2,sy-2,3,7)
 local mx=8+((tod+0.5)%1)*112
 local my=40-sin((tod+0.5)%1)*27
 circfill(mx,my,5,6)
 circfill(mx+2,my-1,4,12)
 if tod>=0.6 or tod<0.1 then
  for i=0,15 do
   local xx=(i*29+7)%128
   local yy=5+(i*17)%34
   pset(xx,yy,(i%3==0) and 7 or 6)
  end
 end

 -- slow cloud layers (wrapped so they never pop at screen edges)
 local drift=time()*2
 draw_cloud((18+drift)%150-14,18,7)
 draw_cloud((82+drift*0.6)%160-16,29,6)

 -- distant mountains (layered)
 local basey=52
 local function mountain(mx,h,basec,snowc)
  for dy=0,h do
   local w=dy
   line(mx-w,basey-dy,mx+w,basey-dy,basec)
  end
  for sy=0,flr(h*0.22) do
   line(mx-sy,basey-h+sy,mx+sy,basey-h+sy,snowc)
  end
 end
 -- back layer (darker)
 mountain(18,18,13,6)
 mountain(56,26,13,6)
 mountain(102,16,13,6)
 -- front layer (lighter)
 mountain(32,22,5,7)
 mountain(78,30,5,7)
 mountain(118,20,5,7)

 -- fog/haze band at horizon
 rectfill(0,46,127,55,6)
 if flr(time()*2)%3==0 then
  for i=1,5 do
   pset(flr(rnd(128)),46+flr(rnd(10)),7)
  end
 end

 -- grass ground plane
 rectfill(0,56,127,shore_y+10,3)
 -- subtle grass texture (less dense + patterned)
 for i=0,4 do
  local gx=i*26+10
  for gy=62,shore_y+6,14 do
   if (gx+gy)%5==0 then pset(gx,gy,11) end
  end
 end

 -- tree silhouettes frame the quiet campsite
 draw_pine(4,shore_y+7,19)
 draw_pine(119,shore_y+7,16)
 draw_pine(126,shore_y+8,22)

 -- dock/pier (3D wooden planks)
 local dx=10
 local dy=dock_y
 -- dock shadow onto water (fade-ish)
 rectfill(dx-3,dy+9,dx+33,dy+12,1)
 rectfill(dx-1,dy+12,dx+31,dy+14,0)
 -- dock side (depth)
 rectfill(dx-2,dy+2,dx+32,dy+9,4)
 -- dock top
 rectfill(dx-2,dy-2,dx+32,dy+2,9)
 -- plank lines
 for px=dx,dx+30,4 do
  line(px,dy-2,px,dy+2,4)
 end
 line(dx-2,dy-2,dx+32,dy-2,10)
 -- dock posts going into water
 rectfill(dx,dy+2,dx+3,dy+15,4)
 rectfill(dx+28,dy+2,dx+31,dy+15,4)

 -- shoreline edge shadow (helps separation)
 line(0,water_y,127,water_y,1)

 -- water starts after dock
 local water_start=water_y
 -- water with smoother depth gradient
 for wy=water_start,127 do
  local wc=1
  if wy<water_start+8 then wc=12 end
  if wy>100 then wc=13 end
  if wy>116 then wc=0 end
  line(0,wy,127,wy,wc)
 end
 -- foam / surface highlight
 line(0,water_start,127,water_start,7)
 for i=0,7 do
  local wx=(i*19+flr(time()*4))%140-6
  local wy=water_start+5+(i%4)*9
  line(wx,wy,wx+5+(i%3),wy,(i%2==0) and 12 or 13)
 end
 -- occasional water sparkles (kept subtle)
 if rnd(1)<0.35 then
  for i=1,2 do
   local sx=flr(rnd(128))
   local sy=water_start+2+flr(rnd(14))
   pset(sx,sy,7)
  end
 end

 -- campfire (on grass, right side)
 draw_fire()

 -- reeds soften the hard shoreline edge
 draw_reeds(48,water_start+2)
 draw_reeds(77,water_start+1)
 draw_reeds(116,water_start+2)

 -- ripples on water
 draw_waves()
end

function draw_hud()
 -- top HUD bar
 rectfill(0,0,127,10,0)
 line(0,10,127,10,5)
 -- tiny hook and fish icons break up the text-heavy hud
 circ(3,4,2,6)
 pset(5,2,6)
 shprint("score "..score,9,2,7)
 ovalfill(73,4,77,6,12)
 pset(78,4,12)
 shprint("x"..fish_caught,81,2,7)

 -- best line (own strip for readability)
 if best_w>0 then
  rectfill(0,10,127,18,0)
  shprint("best:"..best_name.."("..fmt_w(best_w)..")",2,12,6)
 end

 draw_controls()
end

-- rod tip position (global for line drawing)
rod_tip_x=0
rod_tip_y=0

function draw_player()
 -- orange cat fisherman: headphones, red shirt, blue overalls
 local x=p.x
 local y=p.y
 
 -- shadow
 ovalfill(x-6,y+14,x+6,y+16,0)

 -- curling tail behind the body
 line(x-5,y+8,x-8,y+11,9)
 line(x-8,y+11,x-10,y+8,9)
 pset(x-10,y+7,10)

 -- separated overall legs and boots
 rectfill(x-4,y+9,x-1,y+13,1)
 rectfill(x+1,y+9,x+4,y+13,1)
 rectfill(x-5,y+13,x-1,y+14,5)
 rectfill(x+1,y+13,x+5,y+14,5)

 -- red shirt, orange paws, and deep-blue overalls
 rectfill(x-5,y+2,x+5,y+7,8)
 rectfill(x-6,y+4,x-5,y+8,9)
 rectfill(x+5,y+4,x+6,y+8,9)
 pset(x-6,y+4,10)
 pset(x+6,y+4,10)
 rectfill(x-4,y+5,x+4,y+11,1)
 rectfill(x-3,y+5,x+3,y+9,5)
 line(x-3,y+2,x-2,y+6,1)
 line(x+3,y+2,x+2,y+6,1)
 pset(x-2,y+7,6)
 pset(x+2,y+7,6)

 -- squared orange face with clipped lower corners
 rectfill(x-5,y-8,x+5,y+1,9)
 pset(x-5,y+1,0)
 pset(x+5,y+1,0)
 line(x-4,y-7,x-4,y-6,10)
 line(x+4,y-7,x+4,y-6,10)

 -- tall cat ears with warm inner pixels
 rectfill(x-5,y-12,x-3,y-8,9)
 rectfill(x+3,y-12,x+5,y-8,9)
 pset(x-4,y-13,10)
 pset(x+4,y-13,10)
 pset(x-4,y-11,8)
 pset(x+4,y-11,8)

 -- navy headphone bridge and chunky ear cups
 rectfill(x-3,y-12,x+3,y-11,1)
 pset(x-4,y-10,1)
 pset(x+4,y-10,1)
 rectfill(x-7,y-7,x-5,y-2,1)
 rectfill(x+5,y-7,x+7,y-2,1)
 rectfill(x-7,y-3,x-6,y,5)
 rectfill(x+6,y-3,x+7,y,5)
 pset(x-5,y-9,8)
 pset(x+5,y-9,8)

 -- simple vertical eyes and tiny square nose
 line(x-2,y-5,x-2,y-4,0)
 line(x+2,y-5,x+2,y-4,0)
 pset(x,y-2,0)
 
 -- fishing rod (diagonal, going up-right)
 rod_tip_x=x+16
 rod_tip_y=y-8
 line(x+6,y+4,rod_tip_x,rod_tip_y,4)
 line(x+6,y+5,rod_tip_x,rod_tip_y-1,4)
 -- aim arc / preview dotted trajectory + landing ring
 if state=="idle" or state=="aim" then
  local ang=lerp(0.95,0.85,p.aim) -- match cast angle
  local vx=cos(ang)*5
  local vy=sin(ang)*5
  local tx=rod_tip_x
  local ty=rod_tip_y
  for i=1,80 do
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
  if state=="bite" then
   shprint("!",b.x-1,b.y-15+sin(time()*8)*2,10)
   line(b.x-5,b.y-8,b.x-8,b.y-11,7)
   line(b.x+5,b.y-8,b.x+8,b.y-11,7)
  end
 end
 -- line
 if state~="idle" and state~="title" then
  line(rod_tip_x,rod_tip_y,b.x,b.y,7)
 end
end

function draw_fish_shape(ff,col)
 local d=ff.dir
 local x=ff.x
 local y=ff.y
 local long=(ff.name=="pike" or ff.name=="walleye") and 2 or 0
 local fat=(ff.name=="carp" or ff.name=="sunfish") and 1 or 0
 local hw=4+long
 local hh=3+fat
 -- tail, white rim, then colored body
 local tail=x-d*(hw-1)
 for i=-3,3 do
  line(tail,y,tail-d*(3-abs(i)/2),y+i,7)
 end
 ovalfill(x-hw-1,y-hh-1,x+hw+1,y+hh+1,7)
 ovalfill(x-hw,y-hh,x+hw,y+hh,col)
 -- fins and species markings
 line(x,y+hh,x-d*2,y+hh+2,col)
 if ff.name=="perch" then
  for i=-2,2,2 do line(x+i,y-hh+1,x+i,y+hh-1,4) end
 elseif ff.name=="bass" then
  line(x-hw+1,y+1,x+hw-1,y+1,3)
 elseif ff.name=="bluegill" then
  circfill(x-d,y,2,12)
 elseif ff.name=="sunfish" then
  pset(x-2,y-1,10) pset(x+1,y+1,10)
 elseif ff.name=="walleye" then
  line(x-hw+1,y-1,x+hw-1,y-1,10)
 elseif ff.name=="pike" then
  pset(x-2,y-1,10) pset(x+1,y,10) pset(x+3,y-1,10)
 end
 -- face always points in travel direction
 pset(x+d*(hw-1),y-1,0)
 pset(x+d*hw,y+1,7)
end

function draw_fish()
 if f then
  -- hooked fish: make it bright so it's visible against water
  local col=8
  if f.rarity=="uncommon" then col=11 end
  if f.rarity=="rare" then col=12 end
  if f.rarity=="legendary" then col=10+flr(time()*10)%2 end -- flash gold

  draw_fish_shape(f,col)
 end
 -- draw ambient bg fish on top of water
 draw_bgfish()
end

function draw_meter()
 if not f then return end
 
 local bx=90 -- bar x position
 local bw=34 -- bar width
 
 -- panel background
 rectfill(bx-2,1,bx+bw+2,50,0)
 rectfill(bx-1,2,bx+bw+1,49,1)
 
 -- fish name & rarity
 local rc=7
 if f.rarity=="uncommon" then rc=11 end
 if f.rarity=="rare" then rc=12 end
 if f.rarity=="legendary" then rc=10 end
 print(f.name,bx,4,rc)
 print(fmt_w(f.weight),bx,11,6)
 
 -- line tension bar
 print("line",bx,20,7)
 rect(bx,27,bx+bw,33,5)
 local tratio=clamp(f.tension/line_max,0,1)
 local tcol=11 -- cyan
 if tratio>0.6 then tcol=9 end -- orange
 if tratio>0.8 then tcol=8 end -- red danger!
 rectfill(bx+1,28,bx+1+flr((bw-2)*tratio),32,tcol)
 -- danger flash
 if tratio>0.8 and time()*4%1>0.5 then
  rectfill(bx+1,28,bx+bw-1,32,8)
 end
 
 -- fish stamina bar
 print("fish",bx,36,7)
 rect(bx,43,bx+bw,49,5)
 local sratio=clamp(f.stamina/80,0,1)
 local scol=3 -- green
 if sratio<0.3 then scol=11 end -- tired = cyan
 if sratio<0.1 then scol=8 end -- exhausted = red (almost caught!)
 rectfill(bx+1,44,bx+1+flr((bw-2)*sratio),48,scol)
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
 update_fire()
 -- debug: show button presses for troubleshooting input mapping
 if btnp(4) then add_floating_text("z pressed",p.x,p.y-14,8) end
 if btnp(5) then add_floating_text("x pressed",p.x+12,p.y-14,9) end

 if state=="title" then
  if btnp(4) or btnp(5) then state="idle" reset_bobber() end
  return
 end

 -- aiming / idle
 if state=="idle" or state=="aim" then
  -- left or up = shorter cast (closer)
  if btn(0) or btn(2) then p.aim=clamp(p.aim-0.01,0,1) state="aim" end
  -- right or down = longer cast (further)
  if btn(1) or btn(3) then p.aim=clamp(p.aim+0.01,0,1) state="aim" end
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
 pal()
 cls(1)
 -- compact dusk postcard
 rectfill(0,32,127,58,13)
 rectfill(0,59,127,74,2)
 for i=0,11 do
  pset((i*37+9)%128,34+(i*13)%22,(i%3==0) and 10 or 6)
 end
 circfill(103,43,8,7)
 circfill(106,40,7,13)
 -- distant shore and lake
 for x=0,127,2 do
  line(x,69-sin(x/31)*5,x,74,5)
 end
 rectfill(0,75,127,95,1)
 for i=0,6 do
  local wx=(i*23+flr(time()*5))%145-8
  line(wx,79+(i%3)*6,wx+10,79+(i%3)*6,12)
 end

 -- little cat angler vignette
 local cx=31
 local cy=70
 -- red shirt and blue overall silhouette
 rectfill(cx-5,cy-2,cx+5,cy+5,8)
 rectfill(cx-4,cy+2,cx+4,cy+8,1)
 rectfill(cx-3,cy+2,cx+3,cy+6,5)
 line(cx-3,cy-2,cx-2,cy+3,1)
 line(cx+3,cy-2,cx+2,cy+3,1)
 rectfill(cx-4,cy+7,cx-1,cy+10,1)
 rectfill(cx+1,cy+7,cx+4,cy+10,1)
 -- square orange cat face and tall ears
 rectfill(cx-6,cy-13,cx+6,cy-3,9)
 line(cx-5,cy-11,cx-5,cy-17,9)
 line(cx-5,cy-17,cx-1,cy-13,9)
 line(cx+5,cy-11,cx+5,cy-17,9)
 line(cx+5,cy-17,cx+1,cy-13,9)
 pset(cx-4,cy-15,8) pset(cx+4,cy-15,8)
 -- navy headphones match the gameplay sprite
 rectfill(cx-3,cy-15,cx+3,cy-14,1)
 rectfill(cx-8,cy-10,cx-6,cy-4,1)
 rectfill(cx+6,cy-10,cx+8,cy-4,1)
 pset(cx-2,cy-9,0) pset(cx+2,cy-9,0)
 pset(cx,cy-6,0)
 rectfill(cx-6,cy+1,cx-5,cy+5,9)
 rectfill(cx+5,cy+1,cx+6,cy+5,9)
 line(cx+6,cy+2,58,55,4)
 line(58,55,83,79,6)
 circfill(83,81+sin(time()*2),2,7)
 pset(83,80+sin(time()*2),8)
 line(cx-5,cy+5,cx-10,cy+9,9)
 line(cx-10,cy+9,cx-13,cy+5,9)

 -- framed title and compact controls
 rectfill(12,8,115,28,0)
 rect(12,8,115,28,6)
 shprint("cat fishing",42,13,10)
 print("a tiny lakeside tale",27,22,6)
 rectfill(8,98,119,127,0)
 line(8,98,119,98,5)
 draw_dpad(13,101,12)
 print("aim",29,105,7)
 draw_keycap(49,102,"z",10)
 print("cast",61,105,7)
 draw_keycap(83,102,"x",10)
 print("reel",95,105,7)
 if flr(time()*2)%2==0 then
  shprint("press z or x",39,120,7)
 end
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
000400001f5501c550195501655013550105500d5500a550075500455000550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000001865000000186500000018650000001865000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00080000135500000013550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000800001355018550000001c5500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000600001055013550105500d5500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000400002455000000245500000029550000002955000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000400001855018550000001c5501c5500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 41424344
