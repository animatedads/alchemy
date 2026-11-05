/* SLAM450 v0.92 — scanner, radio altimeter, GPWS rules and GPS.
 * Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-03.
 * Scanner: open water returns nothing within 60 m; facing the south pylon
 *   pair from 40 m returns a hit at about that range; facing the water
 *   steeply... the -10 deg rays see the sea from low height.
 * Radio altimeter: 0 over water, the deck top (49 m) over the deck, the
 *   ground height over land.
 * GPWS: silent when both devices are off; PULL UP when an obstacle is close
 *   and closing; altimeter PULL UP when low and sinking; SLAM ignores PULL UP
 *   when its own visible target is nearer than the obstacle.
 * GPS: cold 30 s, warm 8 s, hot <= 1 s, 0.9 unit/s, fix in map pixels. */
numeric digits 16
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
fails=0
g=.Slam450Ground~new(value('SLAM450_HARBOUR_WORDS',,'ENVIRONMENT'),.array~of(-1500,1500,-2000,1000))
w=.Slam450World~new(45046,'PYLONS',.false,g)
/* scanner */
sc=w~scan(.array~of(250,-150,40,90))
hits=0;do d over sc;if d['HIT'] then hits+=1;end
if hits>0 then call fail 'open water east of the bridge should give no returns, got' hits
gap=.array~of(-67.75,-261)
p=.array~of(gap[1]+40,gap[2]+12,70,0)
/* face the gap midpoint from 40 m east */
dx=gap[1]-p[1];dy=gap[2]-p[2];h=RxCalcArcTan(dx/dy);if dy<0 then h+=180;if h<0 then h+=360;p[4]=h
sc=w~scan(p);near=1e9;do d over sc;if d['HIT'] then near=min(near,d['RANGE']);end
if near>45 then call fail 'facing the pylons from ~40 m: nearest return' near
lowSea=w~scan(.array~of(250,-150,5,90));seaHit=0
do d over lowSea;if d['EL']=-10 & d['HIT'] then seaHit+=1;end
if seaHit=0 then call fail 'the -10 deg rays should see the sea from 5 m up'
/* radio altimeter */
if w~surfaceBelow(.array~of(250,-150,40))\=0 then call fail 'water below should read 0'
deckTop=w~surfaceBelow(.array~of(62,-10,60))
if abs(deckTop-49)>0.5 then call fail 'over the deck the surface should be 49 m, got' deckTop
obs=w~surfaceBelow(.array~of((151.2045-151.210)*92300,(-33.8597+33.852)*111200,80))
if obs<40 then call fail 'over Observatory Hill the surface should be ~41 m, got' obs
/* GPWS rules */
q=.Slam450Gpws~new('QUAD')
if q~llmText(.nil,'OFF',0,0,.false,.false)\=='' then call fail 'both devices off must be silent'
fake=.array~new
do el over .array~of(-10,0,10);do az=-15 to 15 by 5
  d=.directory~new;d['AZ']=az;d['EL']=el;d['RANGE']=60;d['HIT']=.false
  if abs(az)<=5 & el<=0 then do;d['RANGE']=8;d['HIT']=.true;end
  fake~append(d)
end;end
r=q~read(fake,'OFF',0,5)
if \r['SCAN_PULL_UP'] then call fail 'obstacle at 8 m should call PULL UP'
if \r['UP_CLEAR'] then call fail 'upper ray should be clear'
q2=.Slam450Gpws~new('QUAD')
r=q2~read(.nil,20,0,0);r=q2~read(.nil,5,-1,0)
if \r['ALT_PULL_UP'] then call fail 'altimeter 5 m and sinking should call PULL UP'
/* SLAM ignores when its target is nearer than the obstacle: target 2 m at ~6 m = ~19 deg = ~25 px */
rows=.array~new;do y=1 to 121;rows[y]='.'~copies(480);end
do y=48 to 74;rows[y]=overlay('2'~copies(25),rows[y],229);end
fr=.directory~new;fr['PIXELS']=rows;fr['WIDTH']=480;fr['HEIGHT']=121
far=.array~new
do el over .array~of(-10,0,10);do az=-15 to 15 by 5
  d=.directory~new;d['AZ']=az;d['EL']=el;d['RANGE']=60;d['HIT']=.false
  if az=0 & el=0 then do;d['RANGE']=12;d['HIT']=.true;end
  far~append(d)
end;end
q3=.Slam450Gpws~new('QUAD')
out=q3~slamAdjust(1,fr,.array~of(0,5,0,0),2,far,30)
if out[1]\=0 | out[3]\=0 then call fail 'SLAM should ignore PULL UP when its target is nearer than the obstacle'
/* GPS */
gp=.Slam450Gps~new(7);crop=.array~of(-260,360,-410,330,1.5);pose=.array~of(0,0,50,0)
n=0;do t=1 to 40;d=gp~step(t,.true,pose,crop);if d['STATUS']=='FIX' then leave;n+=1;end
if n\=29 then call fail 'cold fix should take 30 ticks, took' n+1
d=gp~step(41,.false,pose,crop);d=gp~step(51,.true,pose,crop)
if d['STATUS']\=='ACQUIRING' | d['SECONDS_TO_FIX']\=7 then call fail 'warm restart after 10 s should need 8 s'
d=gp~step(52,.false,pose,crop);d=gp~step(53,.true,pose,crop)
if d['STATUS']\=='FIX' then call fail 'hot restart after 1 s should fix at once'
if .Slam450Gps~power\=0.9 then call fail 'GPS power should be 0.9 unit/s'
/* JSON booleans from the model (v0.92 fix: lookup/sensor switches were dropped) */
jb=.JSON~fromJSON('{"lookup":true,"gps":false,"scanner":"on"}')
if \jsonTrue(jb['lookup']) then call fail 'JSON true must switch lookup on'
if jsonTrue(jb['gps']) then call fail 'JSON false must stay off'
if \jsonTrue(jb['scanner']) then call fail '"on" must switch on'
if fails==0 then say 'TEST_SENSORS_V092 PASS'
else say 'TEST_SENSORS_V092 FAIL' fails
exit (fails>0)
fail: fails+=1;say 'FAIL:' arg(1);return
::requires 'Slam450Flight.cls'
::requires 'Slam450Gpws.cls'
::requires 'Slam450Gps.cls'
::requires 'Slam450LlmPilot.cls'
::requires 'json.cls'
