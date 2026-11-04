/* All pilot restrictions stay intact; independent simulator fixture knows
 * the physical obstacle, but the pilot receives ONLY the indexed raster. */
numeric digits 16
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
checks=0
w=.Slam450World~new(46051,'OBSTRUCTED')
call check w~routeMode=='OBSTRUCTED','obstructed route recognised'
call check w~targets~items=5,'five numbered targets'
call check w~scene~boxes~items=125,'current PowerSLAM solids retained'
a=w~targets[1];b=w~targets[2]
call check a[3]>=10 & a[3]<=150,'target 1 altitude bounded'
call check b[3]>=10 & b[3]<=150,'target 2 altitude bounded'
call check \w~safeLine(a,b),'second leg line-of-sight obstructed'
hit=.HarbourRayOcclusion~firstHit(w~scene,a,b)
call check hit=='SALESFORCE','real existing building blocks the second leg'
cam=.Slam450Camera~new(w)
view=.array~of(a[1],a[2],a[3],90)
image=cam~renderAt(view,720,181)
seen=(.Slam450Vision~new)~observe(image,2)
call check seen==.nil,'target 2 cannot be seen from the target 1 position'
agent=.Slam450LearningPilot~new
control=agent~control(image,2)
call check control~items>=3,'no-world-state visual action produced'
call check control[2]==0,'no forward rush toward a hidden target'
w2=.Slam450World~new(46051,'OBSTRUCTED')
call check w2~targets[1][1]==a[1] & w2~targets[2][2]==b[2],'seed replay exact'
/* Randomized instances must all preserve the *actual* hidden-leg gate;
 * this is a qualification of the generator, not a pilot navigation claim. */
foundVariation=.false
previous=.nil
do sampleSeed=46051 to 46065
  variant=.Slam450World~new(sampleSeed,'OBSTRUCTED')
  va=variant~targets[1];vb=variant~targets[2]
  call check .HarbourRayOcclusion~firstHit(variant~scene,va,vb)=='SALESFORCE',,
      'randomised tower occlusion gate'
  call check \variant~safeLine(va,vb),'randomised target leg not directly flyable'
  if previous\==.nil then do
    if abs(va[1]-previous)>0.00001 then foundVariation=.true
  end
  previous=va[1]
end
call check foundVariation,'seeds change hidden target placement'
say 'SLAM450 OBSTRUCTED BENCH PASS' checks 'checks'
exit 0
check:
 parse arg ok,reason
 if \ok then do; say 'FAIL' reason; exit 7;end
 checks+=1
return
::requires 'Slam450Learning.cls'
