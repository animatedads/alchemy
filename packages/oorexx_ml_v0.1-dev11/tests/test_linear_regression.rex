rows=.array~of(.array~of(0),.array~of(1),.array~of(2),.array~of(3))
y=.array~of(1,3,5,7)
d=.MLDataset~new(rows,y)
m=.MLLinearRegression~new('line')
root=m~journalPoint
fit1=m~fit(d)
coef=m~coefficients
call eq '1',coef[1]~string,'intercept exact'
call eq '2',coef[2]~string,'slope exact'
call near 9,m~predictDecimal(.array~of(4)),1E-20,'predict 2x+1'

m~rollback(root,'two-x-future')
y2=.array~of(1,4,7,10)
d2=.MLDataset~new(rows,y2)
m~fit(d2)
call near 13,m~predictDecimal(.array~of(4)),1E-20,'predict 3x+1'
m~rollForward('two-x-future')
call near 9,m~predictDecimal(.array~of(4)),1E-20,'old fitted future retained'
say 'PASS test_linear_regression'
exit 0

eq: procedure
 use arg a,e,l
 if a\==e then do; say 'FAIL' l 'expected='e 'actual='a; exit 1; end
 return
near: procedure
 use arg a,b,t,l
 if abs(a-b)>t then do; say 'FAIL' l 'expected=' b 'actual=' a; exit 1; end
 return
::requires "OorexxML.cls"
