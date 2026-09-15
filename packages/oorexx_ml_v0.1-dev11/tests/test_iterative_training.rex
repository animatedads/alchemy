rows=.array~of(.array~of(0),.array~of(1),.array~of(2),.array~of(3))
d=.MLDataset~new(rows,.array~of(1,3,5,7),.array~of('x'),'GD-DATA')
model=.MLLinearGDRegressor~new('gd-model')
opt=.MLGradientDescentOptimizer~new('gd-opt',0.1,0)
run=.MLTrainingRun~new('GD-RUN',model,opt,'GD-DATA','MINIMIZE')
root=run~initialCheckpoint
run~session~begin
model~train(d,opt,run~session,100)
run~session~complete
trained=run~checkpoint('trained','TRAINING_COMPLETE')
call near 9,model~predict(.array~of(4)),0.01,'gradient model converged'
call eq 100,opt~step,'optimizer step count'
call eq 100,run~session~epoch,'session epoch count'
call true run~session~at('bestObjective')>=0,'best objective recorded'

run~rollback(root,'trained-future')
call eq .false,model~at('fitted'),'model rolled back to unfitted'
call eq 0,opt~step,'optimizer rolled back'
call eq 'CREATED',run~session~status,'session rolled back'
run~rollForward('trained-future')
call near 9,model~predict(.array~of(4)),0.01,'trained future restored'
call eq 100,opt~step,'optimizer future restored'
say 'PASS test_iterative_training'
exit 0

eq: procedure
 use arg a,e,l
 if a\==e then do; say 'FAIL' l 'expected='e 'actual='a; exit 1; end
 return
true: procedure
 use arg v,l
 if \v then do; say 'FAIL' l; exit 1; end
 return
near: procedure
 use arg a,b,t,l
 if abs(a-b)>t then do; say 'FAIL' l 'expected=' b 'actual=' a; exit 1; end
 return
::requires "OorexxML.cls"
