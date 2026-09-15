base=.array~of(0,1,3,7,10,7,3,1)
near=.array~of(0,.95,3.1,6.9,10,7.05,2.95,1.05)
different=.array~of(0,4,8,3,7,10,4,1)
s=.MLPatternHashSchema~new(.MLPatternHashPolicy~new(36,48,1,4,10,.true,.false),'PATTERN-SHAPE')
h0=s~encode(base); hn=s~encode(near); hd=s~encode(different)
dn=s~difference(h0,hn); dd=s~difference(h0,hd)
call truth dd~compare(dn)>0,'changed turn structure farther than small perturbation'
call truth dd~dominantDelta>dn~dominantDelta,'largest curve discrepancy dominates'
call truth dd~curvatureMax>=dn~curvatureMax,'different bend has at least as much curvature discrepancy'
say 'PASS test_pattern_hash_shape_significance'
exit 0
truth: procedure; use arg v,l; if \v then do; say 'FAIL' l; exit 1; end; return
::requires "OorexxML.cls"
