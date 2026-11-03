/* SLAM450 v0.91 — QUAYSIDE course test. Architecture: Tom Dyer. Written by: Claude (Opus 5.5).
 * Fixed field (380 x 380 m, 8-60 m), every target inside it and scene-clear,
 * >= 2 of 5 hidden from the start, start clear, movers confined to the field,
 * a 750 x 750 map identical across seeds, LEGACY unchanged. */
numeric digits 16
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
fails=0
do seed over .array~of(45046,45047,45048)
  w=.Slam450World~new(seed,'QUAYSIDE',.false)
  f=w~fieldBox
  if f==.nil then call fail 'no field box'
  if w~targets~items\==5 then call fail 'target count'
  hidden=0
  do t over w~targets
    if t[1]<f[1] | t[1]>f[2] | t[2]<f[3] | t[2]>f[4] | t[3]<f[5] | t[3]>f[6] then call fail seed 'target outside field'
    if \w~safePoint(t,3) then call fail seed 'target not clear'
    if \w~safeLine(w~pose,t) then hidden+=1
  end
  if hidden<2 then call fail seed 'fewer than 2 hidden targets'
  if \w~safePoint(w~pose,2.2) then call fail seed 'start obstructed'
  m=.Slam450TargetMovers~new(w,seed,3.0)
  b=m~box
  do k=1 to 6;if b[k]\=f[k] then call fail seed 'movers not confined to field';end
  say 'QUAYSIDE' seed 'hidden' hidden
end
a=.Slam450PlanMap~new(.Slam450World~new(45046,'QUAYSIDE',.false))
c=.Slam450PlanMap~new(.Slam450World~new(45047,'QUAYSIDE',.false))
if a~width\==750 | a~height\==750 then call fail 'map size' a~width a~height
do r=1 to a~height;if a~rows[r]\==c~rows[r] then do;call fail 'map differs between seeds';leave;end;end
/* Salesforce (x -147..-102, y -1172..-1127) is dark grey: col (-125+230)*1.5, row (-750+1150)*1.5 */
if substr(a~rows[trunc((-750+1150)*1.5)+1],trunc((-125+230)*1.5)+1,1)\=='x' then call fail 'Salesforce missing from map'
l=.Slam450World~new(45046,'LEGACY',.false)
if l~fieldBox\==.nil then call fail 'LEGACY gained a field box'
p=l~pose;if p[1]\=270 | p[2]\=-610 | p[3]\=65 then call fail 'LEGACY start moved'
if fails==0 then say 'TEST_QUAYSIDE450 PASS'
else say 'TEST_QUAYSIDE450 FAIL' fails
exit (fails>0)
fail: fails+=1;say 'FAIL:' arg(1);return
::requires 'Slam450Flight.cls'
::requires 'Slam450TargetMovers.cls'
::requires 'Slam450PlanMap.cls'
