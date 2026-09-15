base=.array~of(0,1,3,7,10,6,2,.5)
rev=.array~new; do i=base~items to 1 by -1; rev~append(base[i]); end
revSchema=.MLPatternHashSchema~new(.MLPatternHashPolicy~new(32,32,1,4,8,.true,.true),'REV-YES')
a=revSchema~encode(base); b=revSchema~encode(rev)
call eq a~key,b~key,'reversal invariant policy canonicalizes reversed traversal'
fixedSchema=.MLPatternHashSchema~new(.MLPatternHashPolicy~new(32,32,1,4,8,.true,.false),'REV-NO')
c=fixedSchema~encode(base); d=fixedSchema~encode(rev)
call truth c~key\==d~key,'direction-sensitive policy retains traversal direction'
say 'PASS test_pattern_hash_reversal_policy'
exit 0
eq: procedure; use arg a,e,l; if a\==e then do; say 'FAIL' l 'expected='e 'actual='a; exit 1; end; return
truth: procedure; use arg v,l; if \v then do; say 'FAIL' l; exit 1; end; return
::requires "OorexxML.cls"
