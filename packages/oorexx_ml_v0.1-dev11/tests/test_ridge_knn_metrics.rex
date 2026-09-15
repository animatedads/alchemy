rows=.array~of(.array~of(0),.array~of(1),.array~of(2),.array~of(3))
y=.array~of(1,3,5,7)
d=.MLDataset~new(rows,y,.array~of('x'),'RIDGE')
r=.MLRidgeRegression~new('ridge',0)
r~fit(d)
call near 9,r~predictDecimal(.array~of(4)),1E-20,'ridge lambda zero matches OLS'

crows=.array~of(.array~of(0,0),.array~of(0,1),.array~of(10,10),.array~of(9,10))
cy=.array~of('LOW','LOW','HIGH','HIGH')
cd=.MLDataset~new(crows,cy,.array~of('a','b'),'KNN')
k=.MLKNNClassifier~new('knn',1); k~fit(cd)
call eq 'LOW',k~predict(.array~of(0.2,0.2)),'knn low'
call eq 'HIGH',k~predict(.array~of(9.5,9.5)),'knn high'
expected=.array~of('Y','Y','N','N'); predicted=.array~of('Y','N','Y','N')
call near 0.5,.MLMetrics~precision(expected,predicted,'Y'),1E-20,'precision'
call near 0.5,.MLMetrics~recall(expected,predicted,'Y'),1E-20,'recall'
call near 0.5,.MLMetrics~f1(expected,predicted,'Y'),1E-20,'f1'
cm=.MLMetrics~confusionMatrix(expected,predicted)
call eq 1,cm~count('Y','Y'),'tp'
call eq 1,cm~count('N','Y'),'fp'
call near 1,.MLMetrics~rSquared(y,y),1E-20,'r2 perfect'
say 'PASS test_ridge_knn_metrics'
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
