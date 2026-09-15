d=.MLCloseHashDimension~new('x',0,256,256,1); s=.MLCloseHashSchema~new(.array~of(d),'BOUNDARY')
a=s~encode(.array~of(127.9)); b=s~encode(.array~of(128.1)); c=s~encode(.array~of(200.1))
call eq 1,s~difference(a,b)~score,'adjacent cells across binary carry remain close'
call truth s~difference(a,c)~score>s~difference(a,b)~score,'large numeric separation is farther'
say 'PASS test_close_hash_boundary'
exit 0
eq: procedure; use arg a,e,l; if a\==e then do; say 'FAIL' l 'expected='e 'actual='a; exit 1; end; return
truth: procedure; use arg v,l; if \v then do; say 'FAIL' l; exit 1; end; return
::requires "OorexxML.cls"
