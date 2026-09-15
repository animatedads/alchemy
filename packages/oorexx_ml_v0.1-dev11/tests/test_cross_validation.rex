rows=.array~of(.array~of(0),.array~of(1),.array~of(2),.array~of(3),.array~of(4),.array~of(5))
y=.array~of(1,3,5,7,9,11)
d=.MLDataset~new(rows,y,.array~of('x'),'LINEAR-DATA')
plan=.MLSplitter~kfold(d,3,.nil,'LINEAR-K3')
factory=.MLClassModelFactory~new(.MLLinearRegression,'LR')
ev=.MLCrossValidator~evaluate(d,plan,factory,'MSE')
call near 0,ev~aggregate,1E-20,'perfect linear cross validation'
call eq 3,ev~results~items,'fold evidence count'
call eq 'LINEAR-DATA',ev~datasetId,'evidence dataset identity'
say 'PASS test_cross_validation'
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
