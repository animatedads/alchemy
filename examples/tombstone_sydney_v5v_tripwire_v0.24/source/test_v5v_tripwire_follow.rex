/* Verify each independent threshold before any real evidence admission. */
numeric digits 18
n=0
first=.array~of(1,0,10,30,1,1)
call test 'THRESHOLDS_PASS', first,.array~of(2,0.1,11,30,1,1)
call test 'NO_TRANSLATION', first,.array~of(2,0.1,10,30,1,1)
call test 'SPEED_LIMIT', first,.array~of(2,0.01,12,30,1,1)
call test 'TIME_GAP', first,.array~of(2,0.6,11,30,1,1)
call test 'NONCAUSAL_TIME', first,.array~of(2,0,11,30,1,1)
r=.V5VTripwireFollow~predict(first,.array~of(2,0.1,11,30,1,1),0.20)
if r['admit']<>1 | r['left']>12 | r['right']<12 | r['area']>289 then exit 8
n=n+1
r=.V5VTripwireFollow~predict(first,.array~of(2,0.1,11,30,1,1),0.7)
if r['reason']<>'TIME_GAP' then exit 9
n=n+1
say 'V5V_TRIPWIRE_THRESHOLDS_PASS' n'/7'
exit 0
test: procedure expose n
 use arg reason,a,b
 r=.V5VTripwireFollow~threshold(a,b)
 if r['reason']<>reason then do
  say 'TEST_FAIL expected='reason 'got='r['reason']
  exit 7
 end
 n=n+1
 return
::requires 'V5VTripwireFollow.cls'
