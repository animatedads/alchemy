p=.VisionNativeCadencePolicy~new(30,1.6,.true)
c=.VisionNativeCadenceFeasibility~new
ok=c~check(10,10/30,11,11/30,p)
if \ok~valid then do; say 'FAIL sequential native frame'; exit 1; end
skip=c~check(10,10/30,12,12/30,p)
if skip~valid then do; say 'FAIL skipped frame accepted'; exit 1; end
slow=c~check(10,10/30,11,13/30,p)
if slow~valid then do; say 'FAIL large frame gap accepted'; exit 1; end
say 'PASS native cadence policy'
::requires 'Vision3DNativeMotion.cls'
