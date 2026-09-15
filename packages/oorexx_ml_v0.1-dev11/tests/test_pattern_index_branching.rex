curves=.array~of(.array~of(0,1,3,7,10,7,3,1),.array~of(100,110,130,170,200,170,130,110),.array~of(0,4,8,3,7,10,4,1))
labels=.array~of('BASE','AFFINE-SAME','DIFFERENT'); ids=.array~of('A','B','C')
corpus=.MLPatternCorpus~new(curves,labels,ids,'PATTERN-INDEX-CORPUS')
s=.MLPatternHashSchema~new(.MLPatternHashPolicy~new(32,32,1,4,8,.true,.false),'PATTERN-INDEX')
idx=.MLPatternIndex~new('PATTERN-IDX'); root=idx~journalPoint; idx~fit(corpus,s); fitted=idx~journalPoint
q=idx~query(curves[1],2,'A')
call eq 'B',q~at(1)~sampleId,'affine-equivalent pattern is nearest other sample'
call truth q~at(1)~difference~exact,'nearest pattern has exact shape hash'
idx~rollback(root,'fitted-future')
call truth \idx~at('fitted'),'rollback restores unfitted index'
idx~rollForward('fitted-future')
call truth idx~at('fitted'),'roll-forward restores fitted pattern index'
call eq fitted~nodeId,idx~journalPoint~nodeId,'historical fitted point restored'
say 'PASS test_pattern_index_branching'
exit 0
eq: procedure; use arg a,e,l; if a\==e then do; say 'FAIL' l 'expected='e 'actual='a; exit 1; end; return
truth: procedure; use arg v,l; if \v then do; say 'FAIL' l; exit 1; end; return
::requires "OorexxML.cls"
