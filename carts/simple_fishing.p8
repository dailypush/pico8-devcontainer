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
cast_gravity=0.18
bite_window_frames=45
rarity_bonus={common=0,uncommon=10,rare=20,legendary=50}
bite_min_wait=60     -- 1s at 60fps
bite_max_wait=240    -- 4s
line_max=100
big_fish_weight=3.5
celebration_frames=150

-- game state
state="title"
score=0
fish_caught=0
best_w=0
best_name="-"

-- player
p={x=28,y=shore_y-14,aim=0.5,cx=0,cy=0}

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
 add(bgfish,{x=x,y=y,dir=dir,speed=speed,age=60+flr(rnd(180)),kind=flr(rnd(7))})
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
  local bob=sin(time()*0.7+b.x/32)
  pal(7,13)
  sspr(b.kind*16,32,16,8,b.x-4,b.y-2+bob,8,4,b.dir<0)
  pal(7,(tod>=0.6 or tod<0.1) and 6 or 7)
 end
end

-- surface waves as small drifting foam puffs
waves={}
function spawn_wave(x)
 add(waves,{x=x or flr(rnd(128)),y=water_y-1,r=1,vr=0.15,t=18,vx=(rnd(0.6)-0.3)})
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
 celebration_t=0
 shake=0
 shake_x=0
 shake_y=0
 frame_t=0
 rod_tip_x=p.x+16
 rod_tip_y=p.y-8
 reset_bobber()
 tod=0.3 -- start at morning
 tod_speed=0.0002 -- slow cycle
 init_audio()
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
 add(fx,{t=90,x=clamp(x,1,max(1,127-#txt*4)),y=y,c=c or 7,txt=txt})
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
  elseif p.k=="confetti" then
   p.x+=p.vx
   p.y+=p.vy
   p.vy+=0.04
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
  elseif p.k=="spark" or p.k=="confetti" then
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
 b.bite_window=0
end

-- Preview and flight use the same per-frame velocity and gravity.
function cast_velocity()
 return lerp(0.8,1.9,p.aim),-2.5
end

function cast_step(x,y,vx,vy)
 return clamp(x+vx,2,125),y+vy,vy+cast_gravity
end

function cast()
 celebration_t=0
 reset_bobber()
 p.cx,p.cy=cast_velocity()
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
 f.max_stamina=f.stamina
 b.biting=false
 state="hooked"
 play_subtle_sfx("hook")
end

function lose_fish(msg)
 play_subtle_sfx(msg=="snap!" and "lose" or "missed")
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
fish_names={"sunfish","perch","bass","carp","pike","walleye","bluegill"}
function rand_fish() return choose(fish_names) end
function fish_src(name)
 for i=1,#fish_names do
  if fish_names[i]==name then return (i-1)*16 end
 end
 return 0
end
function time() return t() end

-- Music owns channels 0/1, ambience 2, fishing cues 3.
-- {pattern, channel, cooldown frames, priority, protected frames}
sfx_map={
 cast={0,3,15,3,15}, bite={1,3,20,4,30},
 reel={2,3,8,1,6}, win={3,3,60,5,60},
 lose={4,3,30,5,30}, spark={5,2,90,0,0},
 hook={6,3,15,4,15}, splash={7,2,18,0,0},
 bubble={8,2,30,0,0}, creak={9,3,45,2,18},
 bird={10,2,180,0,0}, cricket={11,2,180,0,0},
 fire={12,2,90,0,0}, water={13,2,90,0,0},
 missed={14,3,30,4,30}, rare_win={15,3,90,5,90}
}

function audio_menu()
 menuitem(1,"music: "..(music_enabled and "on" or "off"),function()
  music_enabled=not music_enabled
  if not music_enabled then music(-1,300) music_playing=false end
  audio_menu()
 end)
 menuitem(2,"sounds: "..(sounds_enabled and "on" or "off"),function()
  sounds_enabled=not sounds_enabled
  if not sounds_enabled then sfx(-1,2) sfx(-1,3) end
  audio_menu()
 end)
end

function init_audio()
 music_enabled=true
 sounds_enabled=true
 music_playing=false
 music_wait=0
 audio_hold=0
 audio_priority=0
 ambient_hold=0
 audio_cooldowns={}
 amb_timer=180
 amb_step=0
 audio_menu()
end

function play_subtle_sfx(name)
 local cue=sfx_map[name]
 if not cue or not sounds_enabled then return end
 if (audio_cooldowns[name] or 0)>0 then return end
 if cue[2]==3 then
  if audio_hold>0 and cue[4]<audio_priority then return end
  audio_priority=cue[4]
  audio_hold=cue[5]
  if cue[4]>=4 then
   music_wait=cue[5]+60
   if music_playing then music(-1,120) music_playing=false end
   sfx(-1,2)
  end
 else
  if audio_hold>0 or ambient_hold>0 or state=="bite" or state=="hooked" then return end
  ambient_hold=18
 end
 audio_cooldowns[name]=cue[3]
 sfx(cue[1],cue[2])
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
    if p.t%3==0 then pset(p.x,p.y+1,c) end
   end
  elseif p.k=="ember" then
   local c=(p.t>6) and 10 or ((p.t>3) and 9 or 8)
   pset(p.x,p.y,c)
  else
   local c=(p.t>10) and 13 or 5
   pset(p.x,p.y,c)
   if p.t%4==0 then pset(p.x+1,p.y,c) end
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
  print(flr(p.aim*100).."%",94,116,6)
 elseif state=="casting" then
  shprint("casting...",43,116,12)
 elseif state=="waiting" then
  draw_keycap(17,113,"x",10)
  shprint("hook when it bites!",31,116,7)
 elseif state=="bite" then
  draw_keycap(25,113,"x",10)
  shprint("hook now!",40,116,10)
 elseif state=="hooked" then
  draw_keycap(8,114,"x",10)
  print("hold: reel",23,114,7)
  print("release: ease line",23,121,9)
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
 rectfill(0,0,127,13,12)
 rectfill(0,14,127,27,6)
 rectfill(0,28,127,50,7)

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
   local w=h-dy
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
   pset((i*29+flr(time()*2))%128,46+(i*7)%10,7)
  end
 end

 -- grass ground plane
 rectfill(0,56,127,shore_y+10,3)
 -- reusable grass-tuft tile
 for gx=8,120,24 do
  spr(82,gx,65+(gx/8)%2*5)
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
 -- four reusable dock tiles include top, highlight, seam and side
 for i=0,3 do
  spr(81,dx-2+i*8,dy-2)
 end
 -- dock posts going into water
 rectfill(dx,dy+2,dx+3,dy+15,4)
 rectfill(dx+28,dy+2,dx+31,dy+15,4)

 -- shoreline edge shadow (helps separation)
 line(0,water_y,127,water_y,1)

 -- water starts after dock
 local water_start=water_y
 -- water with smoother depth gradient
 rectfill(0,water_start,127,water_start+7,12)
 rectfill(0,water_start+8,127,100,1)
 rectfill(0,101,127,116,13)
 rectfill(0,117,127,127,0)
 -- foam / surface highlight
 line(0,water_start,127,water_start,7)
 for i=0,7 do
  local wx=(i*19+flr(time()*4))%140-6
  local wy=water_start+5+(i%4)*9
  spr(80,wx,wy)
 end
 -- occasional water sparkles (kept subtle)
 if frame_t%20<7 then
  for i=1,2 do
   local sx=(i*47+flr(frame_t/20)*13)%128
   local sy=water_start+2+(i*7+flr(frame_t/20)*3)%14
   pset(sx,sy,7)
  end
 end

 -- campfire (on grass, right side)
 draw_fire()

 -- reusable reeds soften the hard shoreline edge
 spr(83,46,water_start-6)
 spr(83,76,water_start-7)
 spr(83,115,water_start-6)

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

function celebrate_catch()
 celebration_t=celebration_frames
 add_floating_text("big catch!",p.x-12,p.y-21,10)
 -- A fixed burst keeps celebration visuals out of the gameplay RNG.
 for i=1,20 do
  local a=i/20
  add(parts,{k="confetti",x=p.x,y=p.y-10,
   vx=cos(a)*1.3,vy=-1.5+sin(a)*0.8,
   t=45+i,c=({10,8,12,7})[i%4+1]})
 end
end

function draw_player()
 -- four 16x32 poses drawn from the sprite sheet
 local x=p.x
 local y=p.y
 ovalfill(x-6,y+14,x+6,y+16,0)
 if celebration_t>0 and (state=="idle" or state=="aim") then
  local beat=(celebration_frames-celebration_t)/24
  local sway=sin(beat)*2
  local hop=abs(sin(beat))*4
  -- Park the rod on the dock while the angler hops and switches poses.
  line(x+11,y+15,rod_tip_x,rod_tip_y,4)
  local pose=flr(beat)%2==0 and 2 or 6
  spr(pose,x-8+sway,y-15-hop,2,4,flr(beat)%2==1)
  return
 end
 local frame=0
 if state=="casting" then frame=2 end
 if state=="waiting" or state=="bite" then frame=4 end
 if state=="hooked" then frame=6 end
 spr(frame,x-8,y-15,2,4)
 
 -- fishing rod (diagonal, going up-right)
 line(x+6,y+4,rod_tip_x,rod_tip_y,4)
 line(x+6,y+5,rod_tip_x,rod_tip_y-1,4)
 -- aim arc / preview dotted trajectory + landing ring
 if state=="idle" or state=="aim" then
  local vx,vy=cast_velocity()
  local tx=rod_tip_x
  local ty=rod_tip_y
  for i=1,80 do
   if ty>=water_y-2 then break end
   if i%2==0 then pset(tx,ty,8) end
   tx,ty,vy=cast_step(tx,ty,vx,vy)
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
  spr(84,b.x-4,b.y-7+wig)
  if state=="bite" then
   shprint("!",b.x-1,b.y-15+sin(time()*8)*2,10)
   line(b.x-5,b.y-8,b.x-8,b.y-11,7)
   line(b.x+5,b.y-8,b.x+8,b.y-11,7)
  end
 end
 -- line
 if state=="casting" or b.in_water then
  line(rod_tip_x,rod_tip_y,b.x,b.y,7)
 end
end

function draw_fish()
 if f then
  local sx=fish_src(f.name)
  -- rarity changes the white outline without hiding species colors
  local rim=7
  if f.rarity=="uncommon" then rim=11 end
  if f.rarity=="rare" then rim=12 end
  if f.rarity=="legendary" then rim=10 end
  ovalfill(f.x-8,f.y-5,f.x+8,f.y+5,rim)
  sspr(sx,32,16,8,f.x-8,f.y-4,16,8,f.dir<0)
 end
 -- draw ambient bg fish on top of water
 draw_bgfish()
end

function draw_meter()
 if not f then return end
 
 camera(0,-20)
 local bx=80 -- bar x position
 local bw=44 -- bar width
 
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
 local sratio=clamp(f.stamina/f.max_stamina,0,1)
 local scol=3 -- green
 if sratio<0.3 then scol=11 end -- tired = cyan
 if sratio<0.1 then scol=8 end -- exhausted = red (almost caught!)
 rectfill(bx+1,44,bx+1+flr((bw-2)*sratio),48,scol)
 camera()
end

function update_fx()
 for i=#fx,1,-1 do
  local o=fx[i]
  o.y-=0.2
  o.t-=1
  if o.t<=0 then del(fx,o) end
 end
end

function draw_fx()
 for o in all(fx) do
  shprint(o.txt,o.x,o.y,o.c)
 end
end

-- Keep the quiet layers out of the way during a bite or fight.
function process_ambient()
 audio_hold=max(0,audio_hold-1)
 ambient_hold=max(0,ambient_hold-1)
 music_wait=max(0,music_wait-1)
 for name,remaining in pairs(audio_cooldowns) do
  audio_cooldowns[name]=max(0,remaining-1)
 end
 if (state=="bite" or state=="hooked") and music_playing then
  music(-1,120)
  music_playing=false
 end
 if music_enabled and not music_playing and music_wait==0
 and state~="bite" and state~="hooked" then
  music(0,1200,3)
  music_playing=true
 end
 amb_timer-=1
 if amb_timer<=0 then
  amb_step=(amb_step+1)%4
  amb_timer=180+amb_step*53
  local night=tod>=0.6 or tod<0.1
  local names={"water","fire",night and "cricket" or "bird","water"}
  play_subtle_sfx(names[amb_step+1])
 end
end

function _update60()
 celebration_t=max(0,celebration_t-1)
 frame_t=(frame_t+1)%30000
 rod_tip_x=p.x+16
 rod_tip_y=p.y-8
 -- ambient audio processing
 process_ambient()

 -- shake decay
 shake=max(0,shake*0.9-0.1)
 shake_x=sin(frame_t*0.37)*shake/2
 shake_y=cos(frame_t*0.43)*shake/2
 -- time of day
 tod=(tod+tod_speed)%1

 update_parts()
 update_bgfish()
 update_waves()
 update_fire()
 update_fx()

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
  b.x,b.y,p.cy=cast_step(b.x,b.y,p.cx,p.cy)
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
   b.bite_window=bite_window_frames
   if btnp(4) or btnp(5) then hook_fish() end
   return
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
   if f.tension>=line_max*0.8 then
    play_subtle_sfx("creak")
   elseif frame_t%8==0 then
    play_subtle_sfx("reel")
   end
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
   play_subtle_sfx((f.rarity=="rare" or f.rarity=="legendary") and "rare_win" or "win")
   local pts=flr(10+f.weight*5+rarity_bonus[f.rarity])
   score+=pts
   fish_caught+=1
   if f.weight>=big_fish_weight then celebrate_catch() end
   add_floating_text(f.name.." "..fmt_w(f.weight).." +"..pts,4,99,7)
   if f.weight>best_w then best_w=f.weight best_name=f.name end
   f=nil
   reset_bobber()
   state="idle"
  end
  return
 end
end

-- SFX 0-15: fishing and ambience; 16-23: original low-register pop-funk groove, bass and soft ticks.
-- sprite sheet: 0/2/4/6 cat poses, y32 fish, 80+ scenery tiles

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
 sspr(0,0,16,32,cx-8,cy-17,16,32)
 line(cx+6,cy+2,58,55,4)
 line(58,55,83,79,6)
 circfill(83,81+sin(time()*2),2,7)
 pset(83,80+sin(time()*2),8)

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
 camera(shake_x,shake_y)
 
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
0000a000000a00000000a000000a00000000a000000a00000000a000000a00000000000000000000000000000000000000000000000000000000000000000000
00099900009990000009990000999000000999000099900000099900009990000000000000000000000000000000000000000000000000000000000000000000
00098900009890000009890000989000000989000098900000098900009890000000000000000000000000000000000000000000000000000000000000000000
00098911119890000009891111989000000989111198900000098911119890000000000000000000000000000000000000000000000000000000000000000000
00098911119890000009891111989000000989111198900000098911119890000000000000000000000000000000000000000000000000000000000000000000
00099100001990000009910000199000000991000019900000099100001990000000000000000000000000000000000000000000000000000000000000000000
00099999999990000009999999999000000999999999900000099999999990000000000000000000000000000000000000000000000000000000000000000000
00089999999980000008999999998000000899999999800000089999999980000000000000000000000000000000000000000000000000000000000000000000
01199999999991100119999999999110011999999999911001199999999991100000000000000000000000000000000000000000000000000000000000000000
01199199991991100119919999199110011999999999911001199199991991100000000000000000000000000000000000000000000000000000000000000000
01199199991991100119919999199110011991199119911001199199991991100000000000000000000000000000000000000000000000000000000000000000
01199999999991100119999999999110011999999999911001199999999991100000000000000000000000000000000000000000000000000000000000000000
01199991199991100119999119999110011999911999911001199991199991100000000000000000000000000000000000000000000000000000000000000000
05599991199995500559999119999550055999911999955005599991199995500000000000000000000000000000000000000000000000000000000000000000
05599999999995500559999999999550055999999999955005599999999995500000000000000000000000000000000000000000000000000000000000000000
0550999999990550055099999999059a055099999999055005509999999905500000000000000000000000000000000000000000000000000000000000000000
00088188881880000008818888188899000881888818800000088188881880000000000000000000000000000000000000000000000000000000000000000000
000881888818800000088188881888990008818888188000000881888818809a0000000000000000000000000000000000000000000000000000000000000000
08888188881888800888818888188880088881888818888000088188881888990000000000000000000000000000000000000000000000000000000000000000
08888155551888800888815555188000088881555518888000888158888888990000000000000000000000000000000000000000000000000000000000000000
08881155551188800888115555118000088811555511888000088888888888990000000000000000000000000000000000000000000000000000000000000000
0a981565565189a009981565565180000a981565565189a000081568888880000000000000000000000000000000000000000000000000000000000000000000
a990155555510990a990155555510000a990155555510990a0001555555100000000000000000000000000000000000000000000000000000000000000000000
99901555555109909990155555510000999015555551099090001555555100000000000000000000000000000000000000000000000000000000000000000000
90091111111100009009111111110000900911111111000090091111111100000000000000000000000000000000000000000000000000000000000000000000
09901111111100000990111111110000099011111111000009901111111100000000000000000000000000000000000000000000000000000000000000000000
09001111111100000900111111110000090011111111000009001111111100000000000000000000000000000000000000000000000000000000000000000000
00001110011100000000111001110000000011100111000000001110011100000000000000000000000000000000000000000000000000000000000000000000
00055550055550000005555005555000000555500555500000055550055550000000000000000000000000000000000000000000000000000000000000000000
00055550055550000005555005555000000555500555500000055550055550000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000009999990000000000aaaaaa000000000b00000b0000000000999999000000000300000300000000060000060000000000cccccc000000000000000000000
0909999a999710000a00a4aa4aa410000b0bbbbbbbb710000909998999971000030333a33337a00006066aaaaaaa10000c0ccceeeec710000000000000000000
009999999999990000aaa4aa4aa4aa0000bbbbbbbbbbbb0000999999999989000033333333333300006666666666660000cccceeeec8cc000000000000000000
009999999a99990000aaa4aa4aa4aa0000bbb3333333bb000099999999999900003333333a333300006666666666660000cccceeeecccc000000000000000000
09099999999990000a00a4aa4aa400000b0bbbbbbbbbb0000909999999899000030333333333300006066666a66660000c0ccceeeeccc0000000000000000000
000009a99990000000000a4aaaa000000000b03000b000000000098999900000000030a000300000000060a00060000000000cecccc000000000000000000000
0000000aa000000000000004400b0000000000033000000000000008800000000000000aa00000000000000aa00000000000000ee00000000000000000000000
00000000aaaaaaa4000000000003000b000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000007099999994000000000b030003000700000000090000000000000000000000000000000000000000000000000000000000000000000000000000000000
cccccc00999999940b0b003003030b03000700000000a00000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000009999999400bb030003030303088888000008880000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000055555551000b300003030303888888800008880000000000000000000000000000000000000000000000000000000000000000000000000000000000
0066666644444441bb03000003030303088888000008880000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000004444444100bb000003030303007770000999999000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000044444441000b000003030303007770004444444400000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000200001f013240232b0131c61300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000400002b03300000300333402300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100002401318613000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0004000024023280232b0230000030033340130000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020000246231f023180130000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300003001300000370130000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020000240232b023300130000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200001f6131c022130130000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020000240112b013000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300001f02123023000002102124013000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300003001134013000003201137013000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200003701300000370130000037013000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100001861300000000001f61300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0004000018012000001f0121361300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0004000028023240131f0130000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0004000024023280232b0233003300000340233702330013000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000001e0201e0230000021023000001e51323020230230000000000210202102300000215131e0201e02300000235131a0201a023000001e023000000000021020210202102300000000001e0201e02326513
001000000e0200e023000001e6131a01300000150131e6130e0100e013000001e6131a01300000150131e6131302013023000001e6131f013000001a0131e6131301013013000001e6131f013000001a0131e613
001000001e0201e0230000021023000001e513230202302300000000002602026023000002151323020230230000025513210202102300000000001e0201e02300000000001c0201c0201c023000000000028513
001000000e0200e023000001e6131a01300000150131e6130e0100e013000001e6131a01300000150131e6131502015023000001e61321013000001c0131e6131501015013000001e61321013000001c0131e613
0010000023020230202302300000000002102021023000001e0201e0230000000000210202102300000000002502025020250230000000000230202302300000210202102300000000001e0201e0201e02328513
001000001702017023000001e61323013000001e0131e6131701017013000001e61323013000001e0131e6131502015023000001e61321013000001c0131e6131501015013000001e61321013000001c0131e613
001000001e0201e0230000021023000002351323020230230000000000210202102300000265131e0201e023000001e5131c0201c023000001e02300000000001a0201a0201a0201a0201a023000000000021513
001000001302013023000001e6131f013000001a0131e6131301013013000001e6131f013000001a0131e6130e0200e023000001e6131a01300000150131e6130e0100e013000001e6131a01300000150131e613
__music__
01 10114040
00 12134040
00 14154040
02 16174040

__label__
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111166666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666111111111111
11111111111160000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006111111111111
11111111111160000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006111111111111
11111111111160000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006111111111111
11111111111160000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006111111111111
1111111111116000000000000000000000000000000aa0aaa0aaa00000aaa0aaa00aa0a0a0aaa0aa000aa0000000000000000000000000000006111111111111
111111111111600000000000000000000000000000a000a0a00a000000a0000a00a000a0a00a00a0a0a000000000000000000000000000000006111111111111
111111111111600000000000000000000000000000a000aaa00a000000aa000a00aaa0aaa00a00a0a0a000000000000000000000000000000006111111111111
111111111111600000000000000000000000000000a000a0a00a000000a0000a0000a0a0a00a00a0a0a0a0000000000000000000000000000006111111111111
1111111111116000000000000000000000000000000aa0a0a00a000000a000aaa0aa00a0a0aaa0a0a0aaa0000000000000000000000000000006111111111111
11111111111160000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006111111111111
11111111111160000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006111111111111
11111111111160000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006111111111111
11111111111160000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006111111111111
11111111111160000000000000066600000666066606600606000006000666060606660066066606600666000006660666060006660000000006111111111111
11111111111160000000000000060600000060006006060606000006000606060606000600006006060600000000600606060006000000000006111111111111
11111111111160000000000000066600000060006006060666000006000666066006600666006006060660000000600666060006600000000006111111111111
11111111111160000000000000060600000060006006060006000006000606060606000006006006060600000000600606060006000000000006111111111111
11111111111160000000000000060600000060066606060666000006660606060606660660066606660666000000600606066606660000000006111111111111
11111111111160000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006111111111111
11111111111166666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddadddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd7dddddddddddddddddddddddddddd
dddddddddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd77dddddddddddddddddddddddddddd
ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd6ddddddddddddd77ddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd777ddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd777ddddddddddddddddddddddddddddd
ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddadddddddd7777ddddddddddddddddddddddddddddd
ddddddddddddddddddddddddddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd7777ddddddddddddddddddddddddddddd
ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd77777dddddddddddddddddddddddddddd
ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd77777dddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddd6dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd777777ddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd777777dddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddd6ddddddddddddddddddddddddddddddddddddddddddddddddd77777777ddddd77ddddddddddddddddd
ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd7777777777777dddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd77777777777ddddddddddddddddddd
ddddddddddddddddddddddddddddddddddddddddddddddddd6ddddddddddddddddddddddddddddddddddddddddddddddddd777777777dddddddddddddddddddd
ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd77777ddddddddddddddaddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddaddddddadddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd6dddd
dddddddddddddddddddddddddd999dddd999dddddddddddddddddddddd6ddddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddd989dddd989ddddddddddddddddddddd4d6dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddd9891111989ddddddddddddddddddd44ddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddd9891111989dddddddddddddddddd4dddddd6dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
22222222222222222222222222991222219922222222222222222422222222622222222222222222222222222222222222222222222222222222222222222222
22222222222222222222222222999999999922222222222222224222222222262222222222222222222222222222222222222222222222222222222222222222
22222222222222222222222222899999999822222222222222442222222222226222222222222222222222222222222222222222222222222222222222222222
22222222222222222222222211999999999911222222222224222222222222222622222222222222222222222222222222222222222222222222222222222222
22222222222222222222222211991999919911222222222242222222222222222262222222222222222222222222222222222222222222222222222222222222
22222222222222222222225211991999919911222222222422225252522222222226222222222222222252525222222222222222222222222252525222222222
22222222222222222222525211999999999911222222224222525252525222222222622222222222225252525222222222222222222222225252525252222222
22222222222222222252525211999911999911222222442222525252525222222222262222222222525252525252222222222222222222225252525252222222
22222222222222222252525255999911999955222224222252525252525252222222226622222222525252525252522222222222222222525252525252522222
22222222222222225252525255999999999955222242222252525252525252222222222262222252525252525252522222222222222222525252525252522222
52222222222222225252525255599999999255222422225252525252525252522222222226222252525252525252522222222222222252525252525252525222
52522222222222525252525252881888818822244222225252525252525252525222222222625252525252525252525222222222222252525252525252525252
52522222222222525252525252881888818822422222525252525252525252525222222222265252525252525252525252222222225252525252525252525252
52525222222252525252525288881888818884222252525252525252525252525252222222526252525252525252525252222222525252525252525252525252
52525252525252525252525288881555518888525252525252525252525252525252525252525652525252525252525252525252525252525252525252525252
52525252525252525252525288811555511888525252525252525252525252525252525252525262525252525252525252525252525252525252525252525252
111111111111111111111111a981565565189a111111111111111111111111111111111111111116111111111111111111111111111111111111111111111111
11111111111111111111111a99115555551199111111111111111111111111111111111111111111611111111111111111111111111111111111111111111111
11111111111111111111111999115555551199111111111111111111111111111111111111111111161111111111111111111111111111111111111111111111
11111111111111111111111911911111111111111111111111111111111111111111111111111111117771111111111111111111111111111111111111111111
ccc1111111111111111111119911111111111111111111111111111111111ccccccccccc11111111177877111111111111111111111111111111111111111111
11111111111111111111111191111111111111111111111111111111111111111111111111111111177777111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111177777111111111111111111111111111111111111111111
11111111111111111111111111555511555511111111111111111111111111111111111111111111117771111111111111111111111111111111111111111111
11111111111111111111111111555511555511111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111111111111111ccccccccccc1111111111111111111111111111111111111111111111111111111111ccccccccccc111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111ccccccccccc1111111111111111111111111111111111111111111111111111111111ccccccccccc1111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555511111111
11111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011111111
11111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011111111
11111111000000000ccccc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011111111
11111111000000000c000c000000000000000000000000000aaaaaaaaaa000000000000000000000000aaaaaaaaaa00000000000000000000000000011111111
11111111000000000c0c0c000000000000000000000000000a00000000a000000000000000000000000a00000000a00000000000000000000000000011111111
11111111000000000c000c000000000000000000000000000a00aaa000a000000000000000000000000a00a0a000a00000000000000000000000000011111111
1111111100000ccccccccccccc00077707770777000000000a0000a000a000770777007707770000000a00a0a000a00777077707770700000000000011111111
1111111100000c000c000c000c00070700700777000000000a000a0000a007000707070000700000000a000a0000a00707070007000700000000000011111111
1111111100000c0c0c000c0c0c00077700700707000000000a00a00000a007000777077700700000000a00a0a000a00770077007700700000000000011111111
1111111100000c000c000c000c00070700700707000000000a00aaa000a007000707000700700000000a00a0a000a00707070007000700000000000011111111
1111111100000ccccccccccccc00070707770707000000000a00000000a000770707077000700000000a00000000a00707077707770777000000000011111111
11111111000000000c000c000000000000000000000000000a05555550a000000000000000000000000a05555550a00000000000000000000000000011111111
11111111000000000c0c0c000000000000000000000000000aaaaaaaaaa000000000000000000000000aaaaaaaaaa00000000000000000000000000011111111
11111111000000000c000c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011111111
11111111000000000ccccc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011111111
11111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011111111
11111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011111111
11111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011111111
11111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011111111
11111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011111111
11111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011111111
11111111000000000000000000000000000000077707770777007700770000077700000077077700000707000000000000000000000000000000000011111111
11111111000000000000000000000000000000070707070700070007000000000700000707070700000707000000000000000000000000000000000011111111
11111111000000000000000000000000000000077707700770077707770000007000000707077000000070000000000000000000000000000000000011111111
11111111000000000000000000000000000000070007070700000700070000070000000707070700000707000000000000000000000000000000000011111111
11111111000000000000000000000000000000070007070777077007700000077700000770070700000707000000000000000000000000000000000011111111
11111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011111111
11111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011111111
11111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011111111
