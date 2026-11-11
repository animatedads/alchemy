/* Reject malformed or ungrounded calibration inputs. No private data. */
numeric digits 30
n=0
call bad '.ApronCalibrationSample~new(-1,.array~of(1,2,3,4),100,100)', 'negative source time'
call bad '.ApronCalibrationSample~new(1,.array~of(1,2,3),100,100)', 'not XYWH'
call bad '.ApronCalibrationSample~new(1,.array~of(1,2,-3,4),100,100)', 'negative width'
call bad '.ApronCalibrationSample~new(1,.array~of(99,2,3,4),100,100)', 'box exceeds image'
call bad '.ApronCalibrationSample~new(1,.array~of(1,2,3,4),100,100,0)', 'zero sigma'
call bad '.ApronRoadAnchor~new(10,.array~of(1),.array~of(1,2))', 'bad road point'
call bad '.ApronRoadAnchor~new(10,.array~of(1,2),.array~of(1,2),2,"UNKNOWN")', 'unverified road basis'
call bad '.ApronRoadHypothesis~new("",scene)', 'blank hypothesis name'
call bad '.ApronRoadHypothesis~new("X",.nil)', 'wrong model type'
call bad 'track~add(.ApronCalibrationSample~new(9,.array~of(1,1,4,4),2560,1440))', 'non-monotone source time'
call bad 'track~add(.ApronCalibrationSample~new(4000000,.array~of(1,1,4,4),2560,1440))', 'gap above one second'
call bad 'track~add(.ApronCalibrationSample~new(11,.array~of(1,1,4,4),100,100))', 'changed image geometry'
call bad '.ApronRoadCalibrator~new~evaluate(.array~of(.ApronRoadHypothesis~new("A",scene),.ApronRoadHypothesis~new("A",scene)),four)', 'duplicate labels'
call bad '.ApronRoadCalibrator~new~evaluate(.array~of(.ApronRoadHypothesis~new("A",scene)),four,0)', 'bad policy'
call bad '.ApronRoadCalibrator~new~evaluate(.array~of(.ApronRoadHypothesis~new("A",otherScene)),four)', 'image dimension mismatch'
call bad 'four~addAnchor(.nil)', 'invalid anchor'
call bad 'four~add(.ApronCalibrationSample~new(120,.array~of(1,1,4,4),2560,1440))', 'closed track rejects input'
call bad '.ApronPlateSamplingGate~new~evaluate("not scene",1)', 'invalid gate scene'
say 'PASS Apron dev4 calibration guards='n
exit 0
bad: procedure expose n
 use strict arg statement,label
 basis=.ApronRoadBasis~new(0,1,0,1,0,1)
 cam=.ApronRoadCamera~new(2560,1440,1000,1000,5,basis)
 otherCamera=.ApronRoadCamera~new(1280,720,1000,1000,5,basis)
 road=.ApronRoadSection~new(6.4,8)
 car=.ApronRoadCarBox~new
 scene=.ApronRoadScene~new(cam,road,car,35,8,6)
 otherScene=.ApronRoadScene~new(otherCamera,road,car,35,8,6)
 track=.ApronCalibrationTrack~new('synthetic','synthetic')
 ignore=track~add(.ApronCalibrationSample~new(10,.array~of(1,1,4,4),2560,1440))
 four=.ApronCalibrationTrack~new('synthetic','synthetic')
 do t=0 to 3
   ignore=four~add(.ApronCalibrationSample~new(t*100000,.array~of(10,10,50,30),2560,1440))
 end
 if label='closed track rejects input' then ignore=four~close
 signal on syntax name expected
 interpret statement
 signal off syntax
 say 'FAIL accepted:' label
 exit 1
 expected:
   signal off syntax
   n+=1
   return
::requires '../src/ApronRoadCalibration.cls'
