numeric digits 40
failures=0
ctx=.Maths~defaultContext
zero=.MathVector3~new(0,0,0,ctx)

/* Same Physics fixture as the dev10 contact->fracture qualification, now
 * attached to an energized Rexx-tronics conductor. The first partition creates
 * the contact impulse; the second sees the resulting compression and fractures
 * the real load path. No electrical impact-damage heuristic exists.
 */
mat=.MechanicalMaterial~new('impact-brittle',2500,1000,0,10,0,0)
law=.BrittleFractureLaw~new('compression-failure',.Units~q(1000,.Units~pascal),.Units~q(20,.Units~pascal))
body=.DeformableBody~new('impact-powered-conductor')
n1=body~addNode(.DeformableNode~new(.MathVector3~new(0,.005,0,ctx),1,.MathVector3~new(0,-10,0,ctx)))
n2=body~addNode(.DeformableNode~new(.MathVector3~new(0,.105,0,ctx),1,.MathVector3~new(0,-10,0,ctx)))
link=body~addLink(.DeformableLink~new(n1,n2,.Units~q(1,.Units~squareMetre),mat,.Units~q(.1,.Units~metre),law))
plane=.DeformableContactPlane~new(zero,.MathVector3~new(0,1,0,ctx),0)
physics=.DeformableSolver~new(zero)
physics~addBody(body); physics~addPlane(plane)

c=.Circuit~new
v=.DCVoltageSource~new('V1','5 V')
wire=.PhysicsFractureConductor~new('WIRE',link,'0.01 ohm')
load=.Resistor~new('LOAD','1 kohm')
c~add(v); c~add(wire); c~add(load)
c~connectGround(v~negative); c~connectGround(load~pin('B'))
c~connect('VCC',.array~of(v~positive,wire~pin('A')))
c~connect('SENSE',.array~of(wire~pin('B'),load~pin('A')))

clock=.SimulationClock~new
coupler=.FractureElectricalCoupler~new(c,physics,clock)
coupler~addConductor(wire)
initial=coupler~begin('1 ms')
if initial~current(wire)<.0049 then call fail 'initial energized conductor current too small' initial~current(wire)

first=coupler~step('1 ms')
if first~contactEvents~items<1 then call fail 'first partition did not create Physics contact evidence'
if first~fractureEvents~items<>0 then call fail 'wire fractured before contact-created compression existed'
if wire~fractured then call fail 'wire should still be intact after first impact partition'
if first~electricalSolution~current(wire)<.0049 then call fail 'wire stopped conducting before fracture'
if clock~now~milliseconds<>1 then call fail 'shared clock not at 1 ms after first partition' clock~now~milliseconds

second=coupler~step('0.1 ms')
if second~fractureEvents~items<>1 then call fail 'impact compression did not create exactly one fracture event' second~fractureEvents~items
if \wire~fractured then call fail 'electrical conductor did not observe Physics fracture'
if wire~fractureCriterion<>'COMPRESSION' then call fail 'unexpected impact fracture criterion' wire~fractureCriterion
if body~fragmentCount<>2 then call fail 'Physics fracture did not split the physical load path' body~fragmentCount
if abs(second~electricalSolution~current(wire))>1e-9 then call fail 'fractured wire still conducts appreciable current' second~electricalSolution~current(wire)
if second~electricalSolution~voltage('SENSE')>1e-6 then call fail 'load remained powered after impact fracture' second~electricalSolution~voltage('SENSE')
if clock~now~microseconds<>1100 then call fail 'shared simulation clock not at 1.1 ms' clock~now~microseconds
if abs(physics~time-'0.0011')>'0.000000000001' then call fail 'Physics time not aligned with circuit time' physics~time
if coupler~result~pointCount<>3 then call fail 'persistent electrical trace should contain t0 + two partitions' coupler~result~pointCount

if failures=0 then do
  say 'REXX-TRONICS / PHYSICS CONTACT -> FRACTURE -> OPEN CIRCUIT: OK'
  say 'initial current mA:' initial~current(wire)*1000
  say 'post-impact/pre-fracture current mA:' first~electricalSolution~current(wire)*1000
  say 'post-fracture current A:' second~electricalSolution~current(wire)
  say 'fracture criterion:' wire~fractureCriterion
  say 'fracture event time ms:' wire~fractureTime~in(.Units~millisecond)
  say 'electrical end time ms:' second~endTime~in(.Units~millisecond)
  say 'physical fragments:' body~fragmentCount
  exit 0
end
say 'FAIL impact fracture coupling failures='failures
exit 1

fail: procedure expose failures
  use arg label,detail=''
  say 'FAIL:' label detail
  failures+=1
return

::requires 'RexxTronicsFracture.cls'
::requires 'Deformable.cls'
::requires 'MathsBootstrap.cls'
