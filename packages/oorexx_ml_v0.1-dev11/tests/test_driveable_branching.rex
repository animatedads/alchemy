initial=.directory~new; initial['value']=0
m=.MLDriveableObject~new('branch-demo','TEST',initial)
p0=m~journalPoint
c=.directory~new; c['value']=10; p1=m~mutate(c,'TEN')
c=.directory~new; c['value']=20; p2=m~mutate(c,'TWENTY')
call eq 20,m~at('value'),'main future value'
m~rollback(p1,'original-future')
call eq 10,m~at('value'),'rollback value'
c=.directory~new; c['value']=15; p3=m~mutate(c,'FIFTEEN')
call eq 15,m~at('value'),'new branch value'
call true m~retainedNodeCount>=3,'retained both futures'
m~rollForward('original-future')
call eq 20,m~at('value'),'old future restorable'
m~checkout('main')
call eq 15,m~at('value'),'new future restorable'
d=m~diff(p2,p3)
call eq 1,d['undo']~items,'branch diff undo'
call eq 1,d['redo']~items,'branch diff redo'
say 'PASS test_driveable_branching'
exit 0

eq: procedure
 use arg a,e,l
 if a\==e then do; say 'FAIL' l 'expected='e 'actual='a; exit 1; end
 return
true: procedure
 use arg v,l
 if \v then do; say 'FAIL' l; exit 1; end
 return
::requires "OorexxML.cls"
