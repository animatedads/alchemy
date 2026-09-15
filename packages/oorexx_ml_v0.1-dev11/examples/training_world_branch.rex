rows=.array~of(.array~of(0),.array~of(1),.array~of(2),.array~of(3))
d1=.MLDataset~new(rows,.array~of(1,3,5,7),.array~of('x'),'D1')
d2=.MLDataset~new(rows,.array~of(1,4,7,10),.array~of('x'),'D2')
model=.MLLinearRegression~new('model')
opt=.MLGradientDescentOptimizer~new('optimizer',0.1,0.5)
run=.MLTrainingRun~new('EXAMPLE',model,opt,'D1')
root=run~initialCheckpoint

run~session~begin
model~fit(d1)
opt~apply(.array~of(1,1),.array~of(0.5,0.25))
run~session~recordEpoch(1,0)
run~checkpoint('2x-plus-1')
say 'future A prediction:' model~predictDecimal(.array~of(4)) 'optimizer step:' opt~step

run~rollback(root,'2x-plus-1')
run~session~begin
model~fit(d2)
opt~setLearningRate(0.25)
opt~apply(.array~of(1,1),.array~of(0.5,0.25))
run~session~recordEpoch(1,2)
run~checkpoint('3x-plus-1')
say 'future B prediction:' model~predictDecimal(.array~of(4)) 'learning rate:' opt~learningRate

run~rollForward('2x-plus-1')
say 'restored A:' model~predictDecimal(.array~of(4)) 'learning rate:' opt~learningRate
exit 0
::requires "OorexxML.cls"
