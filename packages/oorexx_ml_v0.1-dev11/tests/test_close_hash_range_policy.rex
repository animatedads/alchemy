failDim=.MLCloseHashDimension~new('x',0,10,10,1,'FAIL')
failed=.false
signal on syntax name outOfRange
ignored=failDim~quantize(11)
signal off syntax
call truth .false,'default fail policy must reject out-of-range value'
outOfRange:
 signal off syntax
 failed=.true
call truth failed,'out-of-range fail-closed observed'
clampDim=.MLCloseHashDimension~new('x',0,10,10,1,'CLAMP')
call eq 9,clampDim~quantize(11),'explicit clamp permits upper clipping'
call eq 0,clampDim~quantize(-1),'explicit clamp permits lower clipping'
say 'PASS test_close_hash_range_policy'
exit 0

eq: procedure
 use arg a,e,l
 if a\==e then do; say 'FAIL' l 'expected='e 'actual='a; exit 1; end
 return
truth: procedure
 use arg v,l
 if \v then do; say 'FAIL' l; exit 1; end
 return
::requires "OorexxML.cls"
