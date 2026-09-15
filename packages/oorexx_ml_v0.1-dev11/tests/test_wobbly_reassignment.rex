ev=.directory~new; ev['reason']='fits secondary bearing'; ev['confidence']='0.93'
r=.MLWobbleReassignment~new('R17','ALTERNATE_TRACK','TRACK-B',ev)
call assert r~id='R17','id retained'
call assert r~disposition='ALTERNATE_TRACK','disposition retained'
call assert r~target='TRACK-B','target retained'
call assert r~evidence['reason']='fits secondary bearing','evidence retained'
noise=.MLWobbleReassignment~new('R23','NORMATIVE_CLUTTER','')
call assert noise~disposition='NORMATIVE_CLUTTER','noise is explicit disposition, not deletion'
say 'PASS wobbly_reassignment'
exit 0
assert: procedure; use strict arg ok,msg; if \ok then raise syntax 88.900 array(msg); return
::requires "OorexxML.cls"
