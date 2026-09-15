rows=.array~of(.array~of(0),.array~of(1),.array~of(2),.array~of(3),.array~of(4),.array~of(5))
y=.array~of(1,3,5,7,9,11)
d=.MLDataset~new(rows,y,.array~of('x'),'LINEAR')
plan=.MLSplitter~kfold(d,3,.nil,'K3')
ev=.MLCrossValidator~evaluate(d,plan,.MLClassModelFactory~new(.MLLinearRegression,'cv'),'MSE')
say '3-fold MSE:' ev~aggregate

model=.MLLinearRegression~new('branch-model')
root=model~journalPoint
model~fit(d)
model~rollback(root,'good')
model~fit(.MLDataset~new(rows,.array~of(1,4,7,10,13,16),.array~of('x'),'ALT'))
r=.MLBranchComparator~compare(model,'good','main',d,'MSE')
say 'good MSE:' r~valueA 'alternate MSE:' r~valueB 'preferred:' r~preferredBranch
exit 0
::requires "OorexxML.cls"
