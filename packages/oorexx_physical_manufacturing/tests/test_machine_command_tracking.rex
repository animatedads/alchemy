numeric digits 20
/* A commanded position is not an instantaneous physical position. */
rig=.CartesianMachineRig~create(1,0,600,35,50)
rig~command('0.1',0)
rig~step('0.001')
if rig~servo~position>='0.1' then do; say 'FAIL: carriage teleported to command'; exit 1; end
if rig~servo~trackingError<=0 then do; say 'FAIL: expected positive tracking error'; exit 1; end
rig~runFor('0.5','0.001')
if abs(rig~servo~trackingError)>'0.002' then do; say 'FAIL: servo did not settle' rig~servo~trackingError; exit 1; end
say 'PHYSICS MACHINE COMMAND TRACKING: OK'
::requires 'MachineDynamics.cls'
