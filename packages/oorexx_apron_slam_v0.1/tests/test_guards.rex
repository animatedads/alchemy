/* Negative contract test for Apron SLAM camera, vehicle, exposure and 3D basis. */
numeric digits 30
passed=0
call expectBad '.ApronOrientation~new(20,.7,.7)', 'non-unit orientation'
call expectBad '.ApronCamera~new(0,1080,1200,1200,1.5)', 'zero width camera'
call expectBad '.ApronCamera~new(1920,1080,-1200,1200,1.5)', 'negative focal length'
call expectBad '.ApronCarBox~new(.ApronOrientation~new(0,0,1),4.3,1.8,1.5,2.0)', 'plate wider than car'
call expectBad '.ApronCarBox~new(.ApronOrientation~new(0,0,1),4.3,1.8,1.5,.52,.111,2.0)', 'plate above car'
call expectBad 'camera~project(0,0,0)', 'camera near plane'
call expectBad 'car~plateCentreAt(0,12,-1,0)', 'negative velocity magnitude'
call expectBad 'car~plateCentreAt(0,12,10,-1)', 'negative time'
call expectBad '.ApronDriveBy~new(camera,car,0,12,20,25,41000)', 'exposure exceeds frame duration'
call expectBad '.ApronDriveBy~new(camera,car,0,12,20,0,1000)', 'zero frame rate'
call expectBad 'drive~exposureSample(0,0,9)', 'exposure before recording time'
call expectBad 'drive~exposureSample(1,9,9)', 'sample index out of range'
call expectBad 'drive~exposureSample(1,0,1)', 'sample count must be >1'
call expectBad 'drive~exposureSample(1,-1,9)', 'negative sample index'
say 'PASS' passed 'Apron SLAM fail-closed checks'
exit 0
expectBad: procedure expose passed
  use strict arg source,label
  camera=.ApronCamera~new(1920,1080,1200,1200,1.5)
  car=.ApronCarBox~new(.ApronOrientation~new(0,0,1))
  drive=.ApronDriveBy~new(camera,car,0,12,20,25,10000)
  signal on syntax name rejected
  interpret source
  signal off syntax
  say 'FAIL missing reject:' label
  exit 1
  rejected:
    signal off syntax
    passed=passed+1
    return
::requires '../src/ApronGeometry.cls'