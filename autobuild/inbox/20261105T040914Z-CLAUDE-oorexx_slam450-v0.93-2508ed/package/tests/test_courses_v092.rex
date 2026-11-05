/* SLAM450 v0.92 — HILL and PYLONS course tests.
 * Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-03.
 * HILL: refuses to build without real ground; field and 8-80 m band; every
 *   target >= 3 m clear of ground and solids; >= 2 hidden from the start;
 *   the field contains Observatory Hill (ground > 40 m).
 * PYLONS: target 1 in a pylon-pair gap (<= 6 m from the gap midpoint,
 *   55-80 m); targets 2-3 under the deck (vertical ray hits DECK, 8-35 m);
 *   all >= 3 m clear, >= 55 m apart; start clear. Also builds without ground. */
numeric digits 16
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
fails=0
g=.Slam450Ground~new(value('SLAM450_HARBOUR_WORDS',,'ENVIRONMENT'),.array~of(-1500,1500,-2000,1000))
signal on syntax name noground
w=.Slam450World~new(45046,'HILL',.false)
call fail 'HILL built without ground'
signal afterground
noground:
  say 'ok: HILL refuses to build without real ground'
afterground:
signal off syntax
peak=0
do x=-720 to -300 by 25;do y=-1020 to -600 by 25;peak=max(peak,g~surface(x,y));end;end
if peak<40 then call fail 'HILL field does not contain Observatory Hill' peak
do seed over .array~of(45046,45047,45048)
  w=.Slam450World~new(seed,'HILL',.false,g);f=w~fieldBox;hidden=0
  do t over w~targets
    if t[1]<f[1] | t[1]>f[2] | t[2]<f[3] | t[2]>f[4] | t[3]<f[5] | t[3]>f[6] then call fail seed 'HILL target outside field'
    if \w~safePoint(t,3) then call fail seed 'HILL target not clear'
    if \w~safeLine(w~pose,t) then hidden+=1
  end
  if hidden<2 then call fail seed 'HILL fewer than 2 hidden'
  if \w~safePoint(w~pose,2.2) then call fail seed 'HILL start not clear'
  say 'HILL' seed 'hidden' hidden 'peak' peak
end
gaps=.array~of(.array~of(-67.75,-261),.array~of(192.25,240.5))
do seed over .array~of(45046,45047,45048)
  do withGround over .array~of(.true,.false)
    if withGround then w=.Slam450World~new(seed,'PYLONS',.false,g)
    else w=.Slam450World~new(seed,'PYLONS',.false)
    t=w~targets
    d=min(dist2(t[1],gaps[1]),dist2(t[1],gaps[2]))
    if d>6 | t[1][3]<55 | t[1][3]>80 then call fail seed 'target 1 not in a pylon gap' d t[1][3]
    do k=2 to 3
      if w~fastCollision(t[k],.array~of(t[k][1],t[k][2],60))\=='DECK' then call fail seed 'target' k 'not under the deck'
      if t[k][3]<8 | t[k][3]>35 then call fail seed 'target' k 'outside 8-35 m'
    end
    do i=1 to 5
      if \w~safePoint(t[i],3) then call fail seed 'PYLONS target' i 'not clear'
      do j=i+1 to 5;if w~distance(t[i],t[j])<55 then call fail seed 'targets' i j 'too close';end
    end
    if \w~safePoint(w~pose,2.2) then call fail seed 'PYLONS start not clear'
  end
  say 'PYLONS' seed 'gap target' format(t[1][1],,1) format(t[1][2],,1) format(t[1][3],,1)
end
if fails==0 then say 'TEST_COURSES_V092 PASS'
else say 'TEST_COURSES_V092 FAIL' fails
exit (fails>0)
fail: fails+=1;say 'FAIL:' arg(1);return
dist2: procedure
  use arg a,b
  numeric digits 16
  return RxCalcSqrt((a[1]-b[1])**2+(a[2]-b[2])**2,16)
::requires 'Slam450Flight.cls'
