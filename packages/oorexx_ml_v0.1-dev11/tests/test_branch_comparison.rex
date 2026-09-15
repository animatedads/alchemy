rows=.array~of(.array~of(0),.array~of(1),.array~of(2),.array~of(3))
dGood=.MLDataset~new(rows,.array~of(1,3,5,7),.array~of('x'),'GOOD')
dAlt=.MLDataset~new(rows,.array~of(1,4,7,10),.array~of('x'),'ALT')
m=.MLLinearRegression~new('branch-model')
root=m~journalPoint
m~fit(dGood)
m~rollback(root,'two-x-plus-one')
m~fit(dAlt)
currentPoint=m~journalPoint~string
r=.MLBranchComparator~compare(m,'two-x-plus-one','main',dGood,'MSE')
call near 0,r~valueA,1E-20,'old branch mse'
call true r~valueB>0,'alternate branch worse on good data'
call eq 'two-x-plus-one',r~preferredBranch,'preferred branch'
call eq currentPoint,m~journalPoint~string,'comparison restores live point'
call near 13,m~predictDecimal(.array~of(4)),1E-20,'live alternate branch unchanged'
say 'PASS test_branch_comparison'
exit 0

eq: procedure
 use arg a,e,l
 if a\==e then do; say 'FAIL' l 'expected='e 'actual=' a; exit 1; end
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
