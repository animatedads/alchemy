rows=.array~of(.array~of(0,0),.array~of(0,1),.array~of(1,0),.array~of(1,1))
y=.array~of('N','Y','Y','N')
d=.MLDataset~new(rows,y,.array~of('a','b'),'XOR')
m=.MLDecisionTreeClassifier~new('tree',3,2,0)
m~fit(d)
call eq 'N',m~predict(.array~of(0,0)),'xor 00'
call eq 'Y',m~predict(.array~of(0,1)),'xor 01'
call eq 'Y',m~predict(.array~of(1,0)),'xor 10'
call eq 'N',m~predict(.array~of(1,1)),'xor 11'
call truth \m~root~isLeaf,'root is split'
call truth m~root~canonicalText~pos('NODE=')=1,'tree canonical evidence'
say 'PASS test_decision_tree'
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
