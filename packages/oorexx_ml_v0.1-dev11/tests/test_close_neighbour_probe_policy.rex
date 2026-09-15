s=.MLCloseHashSchema~new(.array~of(.MLCloseHashDimension~new('x',0,10,10,1),.MLCloseHashDimension~new('y',0,10,10,1)),'PROBE')
h=s~encode(.array~of(5.2,5.2))
keys=s~neighbourKeys(h,1,9)
call eq h~key,keys[1],'centre bucket probed first'
call eq 9,keys~items,'3x3 probe count'
call eq 9,s~estimatedProbeBuckets(h,1),'probe estimate exact'
failed=.false
signal on syntax name tooMany
ignored=s~neighbourKeys(h,2,10)
signal off syntax
call truth .false,'probe budget should fail closed'
tooMany:
  signal off syntax
  failed=.true
call truth failed,'oversized probe radius fails closed rather than truncating'
rows=.array~of(.array~of(5.1,5.1),.array~of(5.6,5.6),.array~of(8,8)); y=.array~of('a','b','c')
d=.MLDataset~new(rows,y,.array~of('x','y'),'POLICY')
idx=.MLCloseNeighbourIndex~new; idx~fit(d,s)
policy=.MLCloseNeighbourPolicy~new(2,1,0,'EXACT',9)
q=idx~queryPolicy(.array~of(5.2,5.2),policy)
call eq 2,q~size,'policy-driven query result count'
say 'PASS test_close_neighbour_probe_policy'
exit 0

eq: procedure
 use arg a,e,l
 if a\==e then do; say 'FAIL' l 'expected='e 'actual='a; exit 1; end
 return
truth: procedure
 use arg v,l
 if \v then do; say 'FAIL' l; exit 1; end
 return
::requires "OorexxML.cls"
