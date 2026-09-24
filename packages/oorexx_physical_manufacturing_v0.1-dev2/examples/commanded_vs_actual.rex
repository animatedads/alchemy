numeric digits 20
rig=.CartesianMachineRig~create(1,0.25,700,35,40)
rig~command('0.1',0)
do 200
  rig~step('0.001')
  if i//20=0 then say rig~solver~time rig~servo~targetPosition rig~servo~position rig~servo~trackingError
end
::requires 'MachineDynamics.cls'
