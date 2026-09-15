a0=.directory~new; a0['x']=1
b0=.directory~new; b0['y']=2
a=.MLDriveableObject~new('A','TEST',a0)
b=.MLDriveableObject~new('B','TEST',b0)
e=.MLExperiment~new('pair')
e~register('a',a); e~register('b',b)
cp0=e~checkpoint('before','PAIR')
c=.directory~new; c['x']=10; a~mutate(c,'AX')
c=.directory~new; c['y']=20; b~mutate(c,'BY')
cp1=e~checkpoint('after','PAIR')
call eq 10,a~at('x'),'after a'; call eq 20,b~at('y'),'after b'
e~rollback(cp0,'old-future')
call eq 1,a~at('x'),'rollback a'; call eq 2,b~at('y'),'rollback b'
c=.directory~new; c['x']=11; a~mutate(c,'AX2')
c=.directory~new; c['y']=22; b~mutate(c,'BY2')
cp2=e~checkpoint('alternate','PAIR')
e~rollForward('old-future')
call eq 10,a~at('x'),'old future a'; call eq 20,b~at('y'),'old future b'
e~checkout('main')
call eq 11,a~at('x'),'alternate a'; call eq 22,b~at('y'),'alternate b'
say 'PASS test_experiment_branching'
exit 0

eq: procedure
 use arg a,e,l
 if a\==e then do; say 'FAIL' l 'expected='e 'actual='a; exit 1; end
 return
::requires "OorexxML.cls"
