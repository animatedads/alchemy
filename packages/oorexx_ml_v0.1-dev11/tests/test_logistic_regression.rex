rows=.array~of(.array~of(-3),.array~of(-2),.array~of(-1),.array~of(1),.array~of(2),.array~of(3))
y=.array~of('NO','NO','NO','YES','YES','YES')
d=.MLDataset~new(rows,y,.array~of('x'),'LOGISTIC-DATA')
m=.MLBinaryLogisticRegression~new('logistic',.2,240,0)
root=m~journalPoint
m~fit(d,'YES')
call eq 'NO',m~predict(.array~of(-2.5)),'negative class'
call eq 'YES',m~predict(.array~of(2.5)),'positive class'
call truth m~predictProbability(.array~of(3))>.9,'positive probability'
call truth m~predictProbability(.array~of(-3))<.1,'negative probability'
fitPoint=m~journalPoint
m~rollback(root,'fitted-future')
call truth \m~at('fitted'),'rollback clears fitted state'
m~rollForward('fitted-future')
call eq fitPoint~nodeId,m~journalPoint~nodeId,'roll forward fitted state'
call eq 'YES',m~predict(.array~of(2.5)),'rolled-forward classifier works'
say 'PASS test_logistic_regression'
exit 0

eq: procedure
 use arg a,e,l
 if a\==e then do; say 'FAIL' l 'expected='e 'actual='a; exit 1; end
 return
truth: procedure
 use arg ok,l
 if \ok then do; say 'FAIL' l; exit 1; end
 return
::requires "OorexxML.cls"
