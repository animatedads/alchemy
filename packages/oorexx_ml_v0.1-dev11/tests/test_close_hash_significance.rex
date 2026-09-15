dims=.array~of(.MLCloseHashDimension~new('x',0,16,16,1),.MLCloseHashDimension~new('y',0,16,16,1),.MLCloseHashDimension~new('z',0,16,16,1))
s=.MLCloseHashSchema~new(dims,'SIG')
base=s~encode(.array~of(4.1,4.1,4.1))
near=s~encode(.array~of(5.1,4.1,4.1))
manySmall=s~encode(.array~of(6.1,6.1,6.1))
oneLarge=s~encode(.array~of(7.1,4.1,4.1))
d0=s~difference(base,base); d1=s~difference(base,near); d2=s~difference(base,manySmall); d3=s~difference(base,oneLarge)
call eq 0,d0~score,'identical hash distance zero'
call eq 1,d1~dominantDelta,'adjacent bin has unit dominant difference'
call truth d3~score>d2~score,'one larger significant difference dominates several smaller differences'
call truth d2~score>d1~score,'several two-bin differences farther than one adjacent-bin difference'
say 'PASS test_close_hash_significance'
exit 0
eq: procedure; use arg a,e,l; if a\==e then do; say 'FAIL' l 'expected='e 'actual='a; exit 1; end; return
truth: procedure; use arg v,l; if \v then do; say 'FAIL' l; exit 1; end; return
::requires "OorexxML.cls"
