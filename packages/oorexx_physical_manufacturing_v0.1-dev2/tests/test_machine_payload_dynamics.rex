numeric digits 20
/* Same controller + command, greater manufactured payload mass => different physical response. */
light=.CartesianMachineRig~create(1,0,500,25,30)
heavy=.CartesianMachineRig~create(1,4,500,25,30)
light~command('0.1',0); heavy~command('0.1',0)
do 100
  light~step('0.001'); heavy~step('0.001')
end
if light~servo~position<=heavy~servo~position then do
  say 'FAIL: payload mass did not slow carriage response' light~servo~position heavy~servo~position
  exit 1
end
if abs(light~servo~position-heavy~servo~position)<'0.0001' then do
  say 'FAIL: payload mass response difference too small'
  exit 1
end
say 'PHYSICS MACHINE PAYLOAD DYNAMICS: OK'
::requires 'MachineDynamics.cls'
