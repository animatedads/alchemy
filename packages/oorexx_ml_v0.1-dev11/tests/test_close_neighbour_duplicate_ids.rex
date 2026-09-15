rows=.array~of(.array~of(1),.array~of(2)); y=.array~of('a','b'); ids=.array~of('same','same')
d=.MLDataset~new(rows,y,.array~of('x'),'DUP',.nil,ids)
s=.MLCloseHashSchema~new(.array~of(.MLCloseHashDimension~new('x',0,3,3,1)),'DUP-SCHEMA')
idx=.MLCloseNeighbourIndex~new
failed=.false
signal on syntax name duplicateRejected
idx~fit(d,s)
signal off syntax
call truth .false,'duplicate ids must be rejected'
duplicateRejected:
 signal off syntax
 failed=.true
call truth failed,'duplicate sample ids rejected'
say 'PASS test_close_neighbour_duplicate_ids'
exit 0
truth: procedure
 use arg v,l
 if \v then do; say 'FAIL' l; exit 1; end
 return
::requires "OorexxML.cls"
