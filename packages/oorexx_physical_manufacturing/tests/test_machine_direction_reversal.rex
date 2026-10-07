numeric digits 20
/* Direction reversal retains physical momentum: actual motion cannot reverse instantaneously. */
rig=.CartesianMachineRig~create(1,0,500,20,20)
rig~command('0.2','0.2')
rig~runFor('0.08','0.001')
vBefore=rig~servo~velocity
if vBefore<=0 then do; say 'FAIL: carriage never acquired +X velocity' vBefore; exit 1; end
rig~command('-0.2','-0.2')
rig~step('0.001')
vAfter=rig~servo~velocity
if vAfter<=0 then do; say 'FAIL: carriage reversed instantaneously' vBefore vAfter; exit 1; end
if rig~servo~targetVelocity>=0 then do; say 'FAIL: reversal command not installed'; exit 1; end
say 'PHYSICS MACHINE DIRECTION REVERSAL: OK'
::requires 'MachineDynamics.cls'
