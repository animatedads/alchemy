/* Close-neighbour hashing: dominant differences first, exact rerank optional. */
rows=.array~of(.array~of(10,20),.array~of(10.2,20.1),.array~of(10.4,19.9),.array~of(30,45))
y=.array~of('reference','near-a','near-b','far')
d=.MLDataset~new(rows,y,.array~of('x','y'),'CLOSE-DEMO')
s=.MLCloseHashSchema~new(.array~of(.MLCloseHashDimension~new('x',0,50,100,1),.MLCloseHashDimension~new('y',0,50,100,1)),'DEMO')
idx=.MLCloseNeighbourIndex~new('DEMO-INDEX'); idx~fit(d,s)
q=idx~query(.array~of(10.1,20.0),3,1,0,'EXACT')
say q~canonicalText
do r over q~results; say ' 'r~canonicalText; end
exit 0
::requires "OorexxML.cls"
