-- Runs against the real cart in PICO-8; input is scripted per frame.
local checks=0
local held={}
local pressed={}
btn=function(i) return held[i] or false end
btnp=function(i) return pressed[i] or false end
local function check(ok,msg)
 assert(ok,msg)
 checks+=1
end
local function tick(key,hold)
 pressed={}
 held={}
 if key then pressed[key]=true end
 if hold then held[hold]=true end
 _update60()
end
local function test_fishing()
 _init()
 srand(42)
 check(b.x==p.x+16 and b.y==p.y-8,"rod initialized before drawing")
 tick(4)
 check(state=="idle","start title")
 for aim=0,1,0.25 do
  p.aim=aim
  local x,y=rod_tip_x,rod_tip_y
  local vx,vy=cast_velocity()
  local steps=0
  while y<water_y-2 and steps<80 do
   x,y,vy=cast_step(x,y,vx,vy)
   steps+=1
  end
  tick(4)
  check(state=="casting","cast input")
  for i=1,steps do tick() end
  check(state=="waiting","cast lands")
  check(abs(b.x-x)<0.01 and b.y==water_y-2,"preview matches landing")
  check(b.x>=2 and b.x<=125,"cast remains on screen")
  if aim>0 then check(b.x>last_landing,"aim increases range") end
  last_landing=b.x
  if aim==0 then
   tick(5)
   check(state=="waiting" and not f,"early hook waits")
  end
  b.bite_t=b.waiting_t+1
  tick(5)
  check(state=="hooked" and f,"hook on first bite frame")
  check(f.max_stamina==f.stamina,"stamina starts full")
  lose_fish("reset")
 end
 cast()
 for i=1,80 do
  if state=="waiting" then break end
  tick()
 end
 b.bite_t=b.waiting_t+1
 tick()
 check(state=="bite","bite begins")
 for i=1,bite_window_frames-1 do tick() end
 check(state=="bite","full reaction window")
 tick()
 check(state=="idle" and not f and not b.in_water,"miss resets")
 hook_fish()
 f.tension=50
 tick()
 check(f.tension<50,"release eases tension")
 f.tension=line_max-1
 tick(nil,5)
 check(state=="idle" and not f,"line breaks")
 for rarity in all({"common","uncommon","rare","legendary"}) do
  hook_fish()
  f.rarity=rarity
  f.name="bass"
  f.weight=4
  f.stamina=0
  f.x=p.x+12
  f.y=water_y+6
  local before=score
  local count=fish_caught
  tick(nil,5)
  check(state=="idle" and not f,"land "..rarity)
  check(score-before==30+rarity_bonus[rarity],"rarity points")
  check(fish_caught==count+1 and best_w==4,"catch records")
 end
 fx={}
 add_floating_text("feedback",120,90,7)
 local y=fx[1].y
 local life=fx[1].t
 for scene in all({"title","idle","aim","casting","waiting","bite","hooked"}) do
  hook_fish()
  state=scene
  for day in all({0.3,0.5,0.8}) do
   tod=day
   srand(123)
   local expected=rnd(1)
   srand(123)
   _draw()
   check(rnd(1)==expected,"drawing preserves rng: "..scene)
   check(fx[1].t==life and fx[1].y==y,"drawing preserves feedback")
  end
 end
 f=nil
 state="idle"
 tick()
 check(fx[1].t==life-1 and fx[1].y<y,"update animates feedback")
 for i=1,90 do tick() end
 check(#fx==0,"feedback expires")
 for i=1,3600 do
  tick()
  if i%60==0 then _draw() end
 end
 check(#bgfish<=6 and #parts<100 and #fire_parts<100,"ambient effects bounded")
 printh("PASS: "..checks.." fishing checks")
end
test_fishing()
extcmd("shutdown")
