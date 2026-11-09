/* Only SYNTHETIC centroid observations: no actual footage or registrations. */
numeric digits 30
checks=0
src='VOLATILE-SESSION'; tr='ANONYMOUS-TRACK'
t=.ApronTransientTrack~new(src,tr,120000)
start=1712345678000000
do i=0 to 10
  o=.ApronTransientObservation~new(src,tr,start+i*40000,900-i*16,350+i*8,2560,1440)
  t~observe(o)
end
call eq t~count,11,'count'
m=t~fit
call near m~velocityX,-400,'1E-20','image x pixels/s'
call near m~velocityY,200,'1E-20','image y pixels/s'
call eq m~sampleSpanUs,400000,'integer microsecond source duration'
call eq m~sampleCount,11,'fit sample count'
d=m~displacement(10000)
call near d[1],-4,'1E-20','10ms x displacement'
call near d[2],2,'1E-20','10ms y displacement'
d=m~displacement(40000)
call near d[1],-16,'1E-20','frame x displacement'
call near d[2],8,'1E-20','frame y displacement'
call eq m~squaredMagnitude,200000,'square speed without sqrt'
call near .ApronNumericMedian~of(.array~of(8,2,1)),2,'1E-20','odd median'
call near .ApronNumericMedian~of(.array~of(8,2,1,4)),3,'1E-20','even median'
t~close
call eq t~count,0,'close discards all volatile samples'
say 'PASS' checks 'Apron SLAM volatile motion checks'
exit 0
eq: procedure expose checks
 use strict arg actual,expected,label
 if actual<>expected then do; say 'FAIL' label actual expected; exit 1; end
 checks=checks+1
 return
near: procedure expose checks
 use strict arg actual,expected,tolerance,label
 if abs(actual-expected)>tolerance then do; say 'FAIL' label actual expected; exit 1; end
 checks=checks+1
 return
::requires '../src/ApronTransientMotion.cls'