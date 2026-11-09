/* Synthetic texture and matching block-mosaic injection. This test verifies
 * purely numerical evidence, not any living person's appearance.
 */
passed=0
w=64;h=64
raw='';mosaic=''
do y=0 to h-1
 do x=0 to w-1
  v=(x*17+y*37+x*y*3)//256
  raw=raw||d2c(v)||d2c(v)||d2c(v)
  bx=trunc(x/8);by=trunc(y/8)
  v=(bx*37+by*51+bx*by*13)//256
  mosaic=mosaic||d2c(v)||d2c(v)||d2c(v)
 end
end
p=.FaceSlamMosaicProbe~new
m=p~inspectRgb24(mosaic,w,h,0,0,w,h)
r=p~inspectRgb24(raw,w,h,0,0,w,h)
call yes m~gridLift>r~gridLift*1.5,'mosaic periodic edges > random pattern'
call yes m~flatFraction>r~flatFraction,'mosaic flatter than random'
call yes m~xGridSize=8,'injected horizontal grid recovered'
call yes m~yGridSize=8,'injected vertical grid recovered'
call eq 'MOSAIC_CANDIDATE',m~assessment,'mosaic assessment'
call eq 'NO_PERIODIC_MOSAIC_EVIDENCE',r~assessment,'non-mosaic assessment'
say 'PROBE PASS:'passed 'mosaic grid='m~gridLift 'flat='m~flatFraction -
   'raw grid='r~gridLift 'flat='r~flatFraction
exit 0
 eq: procedure expose passed
 use strict arg expected,actual,message
 if expected\==actual then call bad message||' expected='||expected||' actual='||actual
 passed=passed+1
 return
 yes: procedure expose passed
 use strict arg predicate,message
 if \predicate then call bad message
 passed=passed+1
 return
 bad: procedure
 use strict arg msg
 say 'FAIL:'msg
 exit 1
::requires 'FaceSlamMosaicProbe.cls'