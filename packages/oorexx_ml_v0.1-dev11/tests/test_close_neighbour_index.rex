rows=.array~of(.array~of(1.0,1.0),.array~of(1.1,1.1),.array~of(1.2,1.0),.array~of(5,5),.array~of(8,8))
y=.array~of('A','A','A','B','C'); ids=.array~of('p1','p2','p3','p4','p5')
d=.MLDataset~new(rows,y,.array~of('x','y'),'NEAR-DATA',.nil,ids)
s=.MLCloseHashSchema~new(.array~of(.MLCloseHashDimension~new('x',0,10,20,1),.MLCloseHashDimension~new('y',0,10,20,1)),'NEAR-SCHEMA')
idx=.MLCloseNeighbourIndex~new('near-index'); idx~fit(d,s)
q=idx~query(.array~of(1.05,1.05),2,1,0,'EXACT')
call eq 2,q~size,'two results returned'
call truth q~at(1)~label='A','nearest result in local cluster'
call truth q~candidatesExamined<d~sampleCount,'index examines bounded local candidate set'
root=idx~rootPoint; fitted=idx~journalPoint
idx~rollback(root,'fitted-future'); call truth \idx~at('fitted'),'index fit is rollback-capable'
idx~rollForward('fitted-future'); call truth idx~at('fitted'),'index fit future restored'
say 'PASS test_close_neighbour_index'
exit 0
eq: procedure; use arg a,e,l; if a\==e then do; say 'FAIL' l 'expected='e 'actual='a; exit 1; end; return
truth: procedure; use arg v,l; if \v then do; say 'FAIL' l; exit 1; end; return
::requires "OorexxML.cls"
