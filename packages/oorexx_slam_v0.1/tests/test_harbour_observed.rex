/* Power SLAM actual-pixel prototype, uncalibrated, never certifies real sites.
 * Uses the EXPLICITLY coarse trial-only land rectangles from v0.1.
 */
parse arg outputDir
if outputDir=='' then outputDir='.'
numeric digits 20
checks=0
scene=.HarbourScene~new
search=.HarbourPhotoPose~new(scene)
mask=.HarbourLandMask~new
mask~addRect(-1600,-1000,250,800,'Balls Head - Waverton TEST ONLY')
mask~addRect(350,900,50,600,'North east TEST ONLY')
mask~addRect(0,160,-1250,-1000,'Customs House TEST ONLY')
focals=.array~of(500,650,800,950,1100,1250,1400,1600,1800,2100,2300,2500,2700,2900,3100,3400,3700,4000)
w=1536
/* Measured by hand from supplied screenshots, approx +/-15-35 px;
 * those are not surveyed pylon/Opera centroids. All positions are full-frame pixels.
 * Image1 bridge north / white Opera / bridge south (left to right).
 * Image2 Opera / bridge south / north.
 * Image3 bridge south / north, Customs House camera GIVEN by user.
 */
first=.array~of(.array~of('N',185),.array~of('O',575),.array~of('S',685))
second=.array~of(.array~of('O',276),.array~of('S',906),.array~of('N',1255))
third=.array~of(.array~of('S',70),.array~of('N',770))
call check scene~inOrder(-1400,425,.array~of('N','O','S')),'view1 has western land-compatible order'
call check scene~inOrder(550,225,.array~of('O','S','N')),'view2 has northeast land-compatible order'
r=search~fitHorizontal(mask,third,focals,w,25)
call check r['STATUS']=='INSUFFICIENT_LANDMARKS','two landmarks cannot identify unknown camera'
call check r['BEST']~items==0,'no invented candidate for two-landmark unknown camera'
/* Known control: -33.862128338141,151.21083913743 is Customs House;
 * camera offset/height from building centre remains unknown.
 */
customs=scene~local(-33.862128338141,151.21083913743)
cal=search~calibrateAt(customs,third,focals,w,55)
call check cal['STATUS']=='FOCAL_INTERVAL_NOT_UNIQUE','known Customs House XY constrains focal with two landmarks'
call check abs(cal['BEST'][2]-2700)<=200,'known-control focal approximately 2700 pixels'
call check cal['PASSING_FOCALS']~items>=2,'multiple lens samples accepted, calibration interval retained'
say 'CAFE_CONTROL' cal['STATUS'] 'best focal' cal['BEST'][2] 'pixel squared error' cal['BEST'][1] 'passing samples' cal['PASSING_FOCALS']~items
/* Source photo observations should be independently compared against the
 * three-camera synthesised data. Here image1/2 are not yet authoritative. */
do entry over .array~of(.array~of('VIEW1',first),.array~of('VIEW2',second))
  got=search~fitHorizontal(mask,entry[2],focals,w,25,10,35)
  call check got['LAND_TESTED']>0,entry[1] 'has land samples to evaluate'
  call check got['WATER_REJECTED']>0,entry[1] 'water excluded from inverse solve'
  call check got['STATUS']=='HYPOTHESES_NOT_LAND_QUALIFIED' | got['STATUS']=='NO_HORIZONTAL_FIT',entry[1] 'reports qualification explicitly'
  say entry[1] got['STATUS'] 'land points' got['LAND_TESTED'] 'admitted (x,f pairs)' got['ADMITTED']
  if got['BEST']~items>0 then do
    b=got['BEST'][1]
    say entry[1] 'minimum horizontal RMS px' HSqrt(b[1]/entry[2]~items) 'x metres' b[2] 'y metres' b[3] 'focal px' b[4]
  end
end
/* Independent synthetic measurements validate variable-focal search. */
truth=.array~of(-1400,425,16)
aim=scene~aim(scene~features['N'],truth[1],truth[2],500,950,w)
synthetic=scene~observe(truth,aim,950,w,709)
obs=.array~new
do p over synthetic
 obs~append(.array~of(p[1],p[2]))
end
rr=search~fitHorizontal(mask,obs,focals,w,25,10,1)
call check rr['STATUS']=='HYPOTHESES_NOT_LAND_QUALIFIED','synthetic horizontal inversion admitted'
call check rr['BEST'][1][1]<0.01,'synthetic horizontal residual near zero'
call check rr['BEST'][1][2]=-1400 & rr['BEST'][1][3]=425,'synthetic best site recovered on land grid'
call check rr['BEST'][1][4]=950,'synthetic focal value recovered from explicit trials'
/* Impossible measured locations must not be coerced to a nearest positive fit. */
bad=.array~of(.array~of('N',40),.array~of('O',40),.array~of('S',1490))
rb=search~fitHorizontal(mask,bad,focals,w,25,10,1)
call check rb['STATUS']=='NO_HORIZONTAL_FIT','geometrically inconsistent measurements rejected'
call check rr['STATUS']=='HYPOTHESES_NOT_LAND_QUALIFIED','synthetic best cannot be promoted without proper land map'
say 'POWER SLAM OBSERVED TEST: PASS ('checks 'checks)'
exit 0
check: procedure expose checks
 use arg ok,label
 checks+=1
 if ok then say 'PASS' label
 else do;say 'FAIL' label;exit 1;end
 return
::requires 'SlamHarbourObserved.cls'