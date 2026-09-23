call addPath
f=.Wire3DTrackingField~new('4A91C37D')
d=f~asDirectory
if d['version'] <> 'wire3d-tracking/1' then raise syntax 93.900 array('wrong version')
if d['seed'] <> '4A91C37D' then raise syntax 93.900 array('wrong seed')
if d['coordinateSpace'] <> 'NORMALIZED_PROJECTOR' then raise syntax 93.900 array('wrong coordinate space')
if d['applicationState'] <> .false then raise syntax 93.900 array('tracking field became application state')
say 'PASS test_tracking_field'
exit 0
addPath: procedure
  here=filespec('location',parse source . . src)
  call value 'REXX_PATH', here'../src:'value('REXX_PATH',,'ENVIRONMENT'),'ENVIRONMENT'
  return
::requires 'Wire3DAll.cls'
