call addlib
planner=.OperationalPlanner~new('opctl')
d=planner~decide('INTERNODE.TELEMETRY','constrained')
if d['ACTION'] <> 'sample' then raise syntax 98.900 array('expected sample')
if d['TRANSMIT'] <> '0' then raise syntax 98.900 array('sample must not pass original traffic')
say 'PASS ooRexx transport-neutral operational planner hook'
exit 0
addlib:
  return
::requires 'OperationalPlanner.cls'
