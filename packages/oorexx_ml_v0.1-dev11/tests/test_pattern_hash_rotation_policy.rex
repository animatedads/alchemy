base=.array~of(0,1,3,7,10,7,3,1)
rot=.array~of(3,1,0,1,3,7,10,7)
rotSchema=.MLPatternHashSchema~new(.MLPatternHashPolicy~new(32,32,1,4,8,.true,.false),'ROT-YES')
a=rotSchema~encode(base); b=rotSchema~encode(rot)
call eq a~key,b~key,'rotation invariant policy canonicalizes phase shift'
fixedSchema=.MLPatternHashSchema~new(.MLPatternHashPolicy~new(32,32,1,4,8,.false,.false),'ROT-NO')
c=fixedSchema~encode(base); d=fixedSchema~encode(rot)
call truth c~key\==d~key,'fixed-angle policy retains phase'
say 'PASS test_pattern_hash_rotation_policy'
exit 0
eq: procedure; use arg a,e,l; if a\==e then do; say 'FAIL' l 'expected='e 'actual='a; exit 1; end; return
truth: procedure; use arg v,l; if \v then do; say 'FAIL' l; exit 1; end; return
::requires "OorexxML.cls"
