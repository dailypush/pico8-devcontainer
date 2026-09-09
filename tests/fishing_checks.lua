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
 -- Capture calls while still exercising the native audio engine.
 local native_sfx=sfx
 local native_music=music
 local native_menu=menuitem
 local cues={}
 local songs={}
 local menus={}
 sfx=function(id,ch)
  add(cues,{id=id,ch=ch})
  native_sfx(id,ch)
 end
 music=function(id,fade,mask)
  add(songs,{id=id,mask=mask})
  native_music(id,fade,mask)
 end
 menuitem=function(id,label,callback)
  menus[id]=callback
  native_menu(id,label,callback)
 end
 init_audio()
 state="idle"
 process_ambient()
 check(songs[#songs].id==0 and songs[#songs].mask==3,"music reserves only channels 0/1")
 play_subtle_sfx("splash")
 check(cues[#cues].id==7 and cues[#cues].ch==2,"water uses ambient channel")
 local count=#cues
 for i=1,20 do play_subtle_sfx("splash") end
 check(#cues==count,"splash storm throttled")
 play_subtle_sfx("bite")
 check(cues[#cues].id==1 and cues[#cues].ch==3,"bite uses dedicated cue channel")
 check(not music_playing and songs[#songs].id==-1,"bite fades music")
 count=#cues
 play_subtle_sfx("reel")
 play_subtle_sfx("bird")
 play_subtle_sfx("bubble")
 check(#cues==count,"bite protected from reel and ambience")
 play_subtle_sfx("hook")
 check(cues[#cues].id==6,"hook immediately follows bite")
 state="hooked"
 for i=1,100 do process_ambient() end
 check(not music_playing,"music stays quiet through fight")
 play_subtle_sfx("creak")
 check(cues[#cues].id==9,"tension warning plays")
 count=#cues
 play_subtle_sfx("reel")
 check(#cues==count,"reel cannot cut tension warning")
 play_subtle_sfx("rare_win")
 check(cues[#cues].id==15,"special catch flourish")
 state="idle"
 for i=1,149 do process_ambient() end
 check(not music_playing,"catch phrase finishes before music")
 process_ambient()
 check(music_playing,"music returns after catch")
 menus[1]()
 check(not music_enabled and not music_playing,"music toggle stops playback")
 for i=1,180 do process_ambient() end
 check(not music_playing,"muted music stays off")
 menus[2]()
 check(not sounds_enabled and cues[#cues].id==-1 and cues[#cues].ch==3,"sound toggle stops effects")
 count=#cues
 play_subtle_sfx("bite")
 play_subtle_sfx("water")
 check(#cues==count,"muted effects stay silent")
 menus[1]()
 process_ambient()
 check(music_playing and not sounds_enabled,"music works independently of effects")
 state="bite"
 process_ambient()
 check(not music_playing,"fight fades music even with effects muted")
 state="idle"
 menus[2]()
 process_ambient()
 srand(987)
 local expected=rnd(1)
 srand(987)
 play_subtle_sfx("cast")
 check(rnd(1)==expected,"sound playback preserves gameplay rng")
 for i=1,100 do process_ambient() end
 init_audio()
 tod=0.3
 amb_step=1
 amb_timer=1
 process_ambient()
 check(cues[#cues].id==10,"daytime bird ambience")
 for i=1,200 do process_ambient() end
 init_audio()
 tod=0.8
 amb_step=1
 amb_timer=1
 process_ambient()
 check(cues[#cues].id==11,"nighttime cricket ambience")
 sfx=native_sfx
 music=native_music
 menuitem=native_menu
 -- Big catches celebrate without delaying the next cast.
 state="idle"
 celebration_t=0
 for weight in all({3.4,3.5,4.2}) do
  hook_fish()
  f.weight=weight
  f.rarity="common"
  f.stamina=0
  f.x=p.x+12
  f.y=water_y+6
  tick(nil,5)
  check(state=="idle","celebration preserves cast controls")
  check((celebration_t>0)==(weight>=3.5),"big catch threshold")
  if celebration_t>0 then
   local remaining=celebration_t
   _draw()
   _draw()
   check(celebration_t==remaining,"drawing does not advance dance")
   tick()
   check(celebration_t==remaining-1,"dance advances in update")
  end
  if weight==3.5 then
   tick(4)
   check(state=="casting" and celebration_t==0,"casting interrupts dance")
   state="idle"
  end
 end
 for i=1,celebration_frames do tick() end
 check(celebration_t==0,"dance ends automatically")
 local confetti=0
 for part in all(parts) do
  if part.k=="confetti" then confetti+=1 end
 end
 check(confetti==0,"celebration particles expire")
 printh("PASS: "..checks.." fishing checks")
end
test_fishing()
extcmd("shutdown")
