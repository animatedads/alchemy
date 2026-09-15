rows=.array~of(.array~of(0,0),.array~of(0,1),.array~of(10,10),.array~of(9,10))
y=.array~of('LOW','LOW','HIGH','HIGH')
d=.MLDataset~new(rows,y)
m=.MLCentroidClassifier~new('centroid')
m~fit(d)
call eq 'LOW',m~predict(.array~of(1,1)),'low class'
call eq 'HIGH',m~predict(.array~of(8,9)),'high class'
p=.array~of(m~predict(.array~of(0,0)),m~predict(.array~of(10,10)))
call eq 1,.MLMetrics~accuracy(.array~of('LOW','HIGH'),p),'accuracy'
say 'PASS test_centroid_classifier'
exit 0

eq: procedure
 use arg a,e,l
 if a\==e then do; say 'FAIL' l 'expected='e 'actual='a; exit 1; end
 return
::requires "OorexxML.cls"
