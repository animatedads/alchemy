base=.array~of(0,1,3,7,10,7,3,1)
scaled=.array~of(100,110,130,170,200,170,130,110)
s=.MLPatternHashSchema~new(.MLPatternHashPolicy~new(32,32,1,4,8,.true,.false),'PATTERN-AFFINE')
a=s~encode(base); b=s~encode(scaled); d=s~difference(a,b)
call eq a~key,b~key,'offset/amplitude transformed curve has identical pattern hash'
call truth d~exact,'affine pattern difference exact'
call eq 0,d~dominantDelta,'affine dominant difference zero'
say 'PASS test_pattern_hash_affine_invariance'
exit 0
eq: procedure; use arg a,e,l; if a\==e then do; say 'FAIL' l 'expected='e 'actual='a; exit 1; end; return
truth: procedure; use arg v,l; if \v then do; say 'FAIL' l; exit 1; end; return
::requires "OorexxML.cls"
