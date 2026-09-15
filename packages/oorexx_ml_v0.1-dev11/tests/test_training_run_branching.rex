rows=.array~of(.array~of(0),.array~of(1),.array~of(2),.array~of(3))
d1=.MLDataset~new(rows,.array~of(1,3,5,7),.array~of('x'),'D1')
d2=.MLDataset~new(rows,.array~of(1,4,7,10),.array~of('x'),'D2')
model=.MLLinearRegression~new('train-model')
opt=.MLGradientDescentOptimizer~new('opt',0.1,0.5)
run=.MLTrainingRun~new('RUN1',model,opt,'D1','MINIMIZE')
root=run~initialCheckpoint
run~session~begin
model~fit(d1)
p=opt~apply(.array~of(1,1),.array~of(0.5,0.25))
metrics=.directory~new; metrics['mse']=0
run~session~recordEpoch(1,0,metrics)
cp1=run~checkpoint('good-future','TRAINING_EPOCH')
call eq 1,opt~step,'optimizer advanced'
call near 9,model~predictDecimal(.array~of(4)),1E-20,'good model'

run~rollback(root,'good-future')
call eq 'CREATED',run~session~status,'session rollback'
call eq 0,opt~step,'optimizer rollback'
run~session~begin
model~fit(d2)
opt~setLearningRate(0.25)
p2=opt~apply(.array~of(1,1),.array~of(0.5,0.25))
run~session~recordEpoch(1,2)
cp2=run~checkpoint('alternate','TRAINING_EPOCH')
call near 13,model~predictDecimal(.array~of(4)),1E-20,'alternate model'

run~rollForward('good-future')
call near 9,model~predictDecimal(.array~of(4)),1E-20,'coordinated model roll-forward'
call eq 1,opt~step,'coordinated optimizer roll-forward'
call near 0.1,opt~learningRate,1E-20,'optimizer policy restored'
call eq 0,run~session~at('objective'),'session evidence restored'
run~checkout('main')
call near 13,model~predictDecimal(.array~of(4)),1E-20,'alternate coordinated future retained'
call near 0.25,opt~learningRate,1E-20,'alternate optimizer policy retained'

plain=.MLDriveableObject~new('plain-model')
noopt=.MLTrainingRun~new('RUN-NOOPT',plain,.nil,'D0')
call eq '',noopt~session~at('optimizerId'),'optimizer optional'
say 'PASS test_training_run_branching'
exit 0

eq: procedure
 use arg a,e,l
 if a\==e then do; say 'FAIL' l 'expected='e 'actual=' a; exit 1; end
 return
near: procedure
 use arg a,b,t,l
 if abs(a-b)>t then do; say 'FAIL' l 'expected=' b 'actual=' a; exit 1; end
 return
::requires "OorexxML.cls"
