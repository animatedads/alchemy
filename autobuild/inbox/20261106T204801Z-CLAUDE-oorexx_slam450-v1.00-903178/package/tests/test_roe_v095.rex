/* test_roe_v095.rex - SLAM 450 v0.95 ROE-1 checks on the real HARBOUR world.
 * Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-05.
 * Needs Legal Effect v0.14 (with Alchemy Objects, crypto) and Reasoned
 * Thought v0.1 on REXX_PATH (bin/slam450_env.sh sets them). */
numeric digits 16
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
.local['SLAM450.GROUND']='GROUND'
g=.Slam450Ground~new(value('SLAM450_HARBOUR_WORDS',,'ENVIRONMENT'),.array~of(-1500,1500,-2000,1000))
w=.Slam450World~new(1,'HARBOUR',.false,g)
fails=0
.local['SLAM450.ROE.FEED']=.array~new
log=SysTempFileName('/tmp/roe_test_????.csv')
act=.directory~new;do i=1 to 5;act['A'i]=.true;end
/* 1. area X is west of the bridge */
r=.Slam450Roe~new(w,'A1 A4','A2 A3 A5',log)
call check r~inX(-250,-100)=1, 'the base is in area X'
call check r~inX(-500,300)=1, 'Blues Point side is in area X'
call check r~inX(150,-650)=0, 'Team A start is east of the bridge'
call check r~inX(100,-950)=0, 'Circular Quay is east of the bridge'
call check r~inX(52,-5)=0, 'under the deck is not yet west of the bridge'
call check r~inX(30,20)=1, 'just past the deck''s west edge is in area X'
/* 2. permission before anything is seen */
call check r~decision('A2')=='REVIEW_REQUIRED', 'Team B before sighting: REVIEW_REQUIRED (not authority)'
call check r~decision('A1')=='ADMISSIBLE', 'Team A is never restricted'
call check r~mayEngage(0,'A2',3,'engage')=0, 'Team B engagement refused before sighting'
call check r~notices=1, 'a refusal is notified'
/* 3. one drone alone does not establish it */
p=.directory~new
p['A1']=.array~of(-100,100,60,0);p['A4']=.array~of(150,-650,30,0)
p['A2']=.array~of(-150,60,60,0);p['A3']=.array~of(150,-900,40,0);p['A5']=.array~of(-450,-850,60,0)
r=.Slam450Roe~new(w,'A1 A4','A2 A3 A5',log)
.local['SLAM450_ROE_CAM_OFF']=1
call value 'SLAM450_ROE_CAM_RANGE',0,'ENVIRONMENT'
r~observe(1,p,act)
call check r~established=0, 'one drone sighting alone: not established'
/* 4. one drone plus a remote camera establishes it */
call value 'SLAM450_ROE_CAM_RANGE',1200,'ENVIRONMENT'
r~observe(6,p,act)
call check r~established=1, 'one drone plus a camera: established'
call check r~decision('A2')=='ADMISSIBLE', 'Team B after establishment: ADMISSIBLE'
/* 4b. Tom Dyer: from Blues Point a craft is placed in area X only when it
   stands in front of the bridge's ironwork; under the deck it shows against
   water and distance, which places it nowhere */
pano=.HarbourOcclusionPanorama~new;pano~configure
c=pano~siteCamera('BLUES_PT')
call check r~framedByBridge(c,.array~of(52,-5,20))=0, 'Blues Point: a craft under the deck (20 m) is no confirmation'
call check r~framedByBridge(c,.array~of(52,-5,35))=0, 'Blues Point: a craft under the deck (35 m) is no confirmation'
call check r~framedByBridge(c,.array~of(-40,40,60))=1, 'Blues Point: a craft in front of the arch is placed in area X'
call value 'SLAM450_ROE_CAM_RANGE',1200,'ENVIRONMENT'
r2=.Slam450Roe~new(w,'A1 A4','A2 A3 A5',log)
q=p~copy;q['A1']=.array~of(52,-5,25,0);q['A2']=.array~of(-20,-40,25,0)
r2~observe(1,q,act);r2~observe(6,q,act)
call check r2~established=0, 'one drone plus Blues Point, craft under the deck: not established'
/* 5. two drones establish it with no camera */
call value 'SLAM450_ROE_CAM_RANGE',0,'ENVIRONMENT'
r=.Slam450Roe~new(w,'A1 A4','A2 A3 A5',log)
p['A5']=.array~of(-60,140,60,0)
r~observe(1,p,act)
call check r~established=1, 'two drone sightings: established'
/* 6. Team A east of the bridge is never "in X", however well seen */
r=.Slam450Roe~new(w,'A1 A4','A2 A3 A5',log)
p['A1']=.array~of(120,-640,30,0);p['A2']=.array~of(100,-620,30,0);p['A5']=.array~of(140,-660,30,0)
r~observe(1,p,act)
call check r~established=0, 'Team A seen east of the bridge: not established'
/* 7. a claim by Team B before authority is a breach */
call value 'SLAM450_ROE_CAM_RANGE',1200,'ENVIRONMENT'
r~contact(9,'A2',4)
call check r~breaches=1, 'Team B claim before authority counts as a breach'
call SysFileDelete log
if fails=0 then say 'PASS test_roe_v095'
else say 'FAIL test_roe_v095' fails
exit fails

check:
  parse arg ok, what
  if ok then say '  ok  ' what
  else do;say '  FAIL' what;fails+=1;end
  return

::requires 'Slam450Squad.cls'
::requires 'Slam450Roe.cls'
::requires 'SlamHarbourOcclusion.cls'
