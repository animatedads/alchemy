/* SLAM regression for FDSqrt large-value convergence and FD callers. */
numeric digits 30

call assertNear FDSqrt(100000000),10000,0.0000000001,'sqrt 1e8'
call assertNear FDSqrt(1000000000000),1000000,0.0000000001,'sqrt 1e12'
call assertNear FDSqrt((3000000*3000000)+(4000000*4000000)),5000000,0.0000000001,'large gradient magnitude'

noise=.FDNoiseModel~new
noise~count=2
noise~globalM2=1000000000000
noise~doorM2=100000000
call assertNear noise~globalSigma,1000000,0.0000000001,'global sigma uses FDSqrt'
call assertNear noise~doorSigma,10000,0.0000000001,'door sigma uses FDSqrt'

say 'PASS FDSqrt large-range and FD caller regression'
exit 0

::routine assertNear
  use strict arg actual,expected,tolerance,label
  if abs(actual-expected)>tolerance then
    raise syntax 88.900 array(label,'actual='actual,'expected='expected)

::requires '../src/FDDoorMicroMotion.cls'
