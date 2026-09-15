rows=.array~new; y=.array~new; ids=.array~new
do i=0 to 19
  rows~append(.array~of(i/2,(i/2)+.05)); y~append(i//2); ids~append('s'||i)
end
d=.MLDataset~new(rows,y,.array~of('x','y'),'ASSESS',.nil,ids)
s=.MLCloseHashSchema~new(.array~of(.MLCloseHashDimension~new('x',0,10,20,1),.MLCloseHashDimension~new('y',0,10,20,1)),'ASSESS-SCHEMA')
idx=.MLCloseNeighbourIndex~new; idx~fit(d,s)
a=.MLCloseNeighbourAssessment~evaluate(idx,d,1,1,0,'EXACT')
call truth a~recallAtK>=.80,'close hash recovers most exact nearest neighbours'
call truth a~candidateFraction<.50,'close hash examines less than half the corpus on average'
say 'PASS test_close_neighbour_assessment recall='a~recallAtK 'candidateFraction='a~candidateFraction
exit 0
truth: procedure; use arg v,l; if \v then do; say 'FAIL' l; exit 1; end; return
::requires "OorexxML.cls"
