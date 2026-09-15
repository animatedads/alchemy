rows=.array~of(.array~of(0,0),.array~of(.2,-.1),.array~of(-.2,.1),.array~of(5,5),.array~of(5.2,4.9),.array~of(4.8,5.1))
y=.array~of('LOW','LOW','LOW','HIGH','HIGH','HIGH')
d=.MLDataset~new(rows,y,.array~of('x','y'),'NB-DATA')
m=.MLGaussianNaiveBayes~new('nb')
m~fit(d)
call eq 'LOW',m~predict(.array~of(.1,.1)),'low cluster'
call eq 'HIGH',m~predict(.array~of(5.1,5)),'high cluster'
s=m~logScores(.array~of(5,5))
call truth s['HIGH']>s['LOW'],'high log score wins'
say 'PASS test_gaussian_naive_bayes'
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
