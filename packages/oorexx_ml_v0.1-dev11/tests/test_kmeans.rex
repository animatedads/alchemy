rows=.array~of(.array~of(0,0),.array~of(.1,.2),.array~of(-.2,.1),.array~of(10,10),.array~of(10.1,9.9),.array~of(9.8,10.2))
y=.array~of(.nil,.nil,.nil,.nil,.nil,.nil)
d=.MLDataset~new(rows,y,.array~of('x','y'),'KMEANS-DATA')
m=.MLKMeans~new('km',2,50,1E-12)
m~fit(d)
a=m~predict(.array~of(0,0)); b=m~predict(.array~of(10,10))
call truth a\=b,'two separated clusters'
call eq a,m~predict(.array~of(.05,.05)),'near origin same cluster'
call eq b,m~predict(.array~of(10.05,10.05)),'near ten same cluster'
call truth m~inertia<1,'low inertia for compact clusters'
call eq 6,m~assignments~items,'assignment count'
say 'PASS test_kmeans'
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
