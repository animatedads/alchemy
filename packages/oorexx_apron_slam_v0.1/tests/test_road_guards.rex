/* Road-camera / box negative tests: no external data. */
numeric digits 30
passed=0
call expectBad '.ApronRoadBasis~new(1,1,0,1,0,1)','non-unit yaw'
call expectBad '.ApronRoadBasis~new(0,1,.8,.8,0,1)','non-unit pitch'
call expectBad '.ApronRoadBasis~new(0,1,0,1,.5,.5)','non-unit roll'
call expectBad '.ApronRoadCamera~new(0,1440,1000,1000,4.8,basis)','zero width'
call expectBad '.ApronRoadCamera~new(2560,1440,0,1000,4.8,basis)','zero focal'
call expectBad '.ApronRoadCamera~new(2560,1440,1000,1000,0,basis)','zero height'
call expectBad '.ApronRoadCamera~new(2560,1440,1000,1000,4.8,basis,-.9)','distortion out of range'
call expectBad 'camera~project(.array~of(-10,0,0))','behind-camera ray'
call expectBad 'camera~project(.array~of(10,0))','wrong point dimension'
call expectBad '.ApronRoadSection~new(2,8)','road too narrow'
call expectBad 'road~edgeY(0)','invalid road side'
call expectBad '.ApronRoadCarBox~new(4.4,1.8,1.53,2)','plate wider than vehicle'
call expectBad '.ApronRoadCarBox~new(4.4,1.8,1.53,.52,.111,2)','plate height above car'
call expectBad '.ApronRoadScene~new(camera,road,car,20,3,8)','off-road vehicle'
call expectBad '.ApronRoadScene~new(camera,road,car,20,8,-5)','negative velocity'
call expectBad '.ApronRoadScene~new(camera,road,car,20,8,8,0)','zero frame rate'
call expectBad '.ApronRoadScene~new(camera,road,car,20,8,8,300)','unsupported frame rate'
call expectBad 'scene~positionAt(-1)','negative time'
call expectBad 'scene~plateExposureDisplacement(.001,10000)','exposure starts before source time'
call expectBad 'scene~plateExposureDisplacement(1,50000)','exposure above 25fps period'
call expectBad 'scene~boxResidualSquared(1,.array~of(1,2,3))','bad residual shape'
say 'PASS: road-camera fail-closed checks='passed
exit 0
expectBad: procedure expose passed
  use strict arg source,label
  basis=.ApronRoadBasis~new(0,1,0,1,0,1)
  camera=.ApronRoadCamera~new(2560,1440,1000,1000,4.8,basis)
  road=.ApronRoadSection~new(6.4,8)
  car=.ApronRoadCarBox~new(4.4,1.82,1.53)
  scene=.ApronRoadScene~new(camera,road,car,25,8,8)
  signal on syntax name rejected
  interpret source
  signal off syntax
  say 'FAIL, accepted invalid scenario:' label
  exit 1
  rejected:
    signal off syntax
    passed=passed+1
    return
::requires '../src/ApronRoadGeometry.cls'
