/* Two real independent moving bodies; independent scoring and camera budget. */
numeric digits 16
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
checks=0
w=.Slam450World~new(45045,'LEGACY',.false)
r=.Slam450RaceReferee~new(w,.false)
a=r~poseOf('A1');b=r~poseOf('A2')
call verify abs(w~distance(a,b)-10)<0.000001,'initial 10m separation'
call verify w~distance(a,w~targets[1])<w~distance(b,w~targets[1]),'A1 nearer first target'
call verify r~tick==0,'same start time'
call verify r~available(2),'shared target starts visible'
call verify r~nextAvailable(0)==1,'target 1 initially unclaimed'
call verify r~contactFraction(.array~of(-5,0,30),.array~of(5,0,30),.array~of(0,0,30))>0,'swept capture across moving segment'
call verify r~contactFraction(.array~of(-5,0,30),.array~of(-2,0,30),.array~of(0,0,30))>=0,'contact at endpoint'
call verify r~contactFraction(.array~of(-5,0,30),.array~of(-4,0,30),.array~of(0,0,30))<0,'no nonphysical remote capture'
call verify r~closestConcurrent(.array~of(-5,0,20),.array~of(5,0,20),.array~of(5,0,20),.array~of(-5,0,20))<0.0001,'crossing aircraft paths detected between ticks'
call verify r~closestConcurrent(.array~of(0,0,20),.array~of(0,5,20),.array~of(10,0,20),.array~of(10,5,20))==10,'parallel separated flight paths safe'
rc=.Slam450RaceCameraService~new(w)
view=rc~request('A1','CAFE_SYDNEY',5,r~claims,a,b)
call verify view['STATUS']=='GRANTED','first single fixed image admitted'
view2=rc~request('A2','BLUES_PT',5,r~claims,b,a)
call verify view2['STATUS']=='DENIED','other craft denied same step'
call verify view2['REASON']=='GLOBAL_FIVE_STEP_LIMIT','one global five-step clock'
view3=rc~request('A2','BLUES_PT',10,r~claims,b,a)
call verify view3['STATUS']=='GRANTED','other craft allowed after five steps'
call verify rc~grants==2 & rc~denies==1,'shared network counts'
cam=.Slam450Camera~new(w)
f1=cam~renderAt(a,480,121,.false,r~claims,b)
f2=cam~renderAt(b,480,121,.false,r~claims,a)
call verify f1['PIXELS']~items==121 & f2['PIXELS']~items==121,'both independently generated views'
vis=.Slam450Vision~new
call verify vis~observe(f1,'R')\==.nil,'aircraft 1 sees aircraft 2'
call verify vis~observe(f2,'R')\==.nil,'aircraft 2 sees aircraft 1'
cmd=.array~of(0,0,0,0)
events=r~advance(cmd,cmd)
call verify r~tick==1,'referee advances both aircraft together'
call verify r~status=='RUNNING','stationary separated craft do not collide'
call verify r~claims~items==0,'no target claimed without physical interception'
call verify r~minSeparation>=4,'aircraft separation maintained'
call verify w~steps==0,'original single aircraft world never stepped'
say 'SLAM450 TWO-CRAFT REFEREE PASS' checks 'checks'
exit 0
verify:
  parse arg ok,description
  if \ok then do;say 'FAIL' description;exit 7;end
  checks+=1
return
::requires 'Slam450Race.cls'
