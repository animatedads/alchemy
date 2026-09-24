numeric digits 40
failures=0
ctx=.Maths~defaultContext
zero=.MathVector3~new(0,0,0,ctx)

/* A Physics brittle tensile coupon is also the physical support/evidence for
 * one Rexx-tronics electrical conductor. The electrical model does not decide
 * whether it fractures; it only responds to Physics' authoritative link state.
 */
mat=.MechanicalMaterial~new('brittle-wire-test',2500,1000,0,10,0,0)
law=.BrittleFractureLaw~new('wire-tension',.Units~q(50,.Units~pascal))
body=.DeformableBody~new('powered-wire')
n1=body~addNode(.DeformableNode~new(zero,1,,.true))
n2=body~addNode(.DeformableNode~new(.MathVector3~new(1.2,0,0,ctx),1))
link=body~addLink(.DeformableLink~new(n1,n2,.Units~q(1,.Units~squareMetre),mat,.Units~q(1,.Units~metre),law))
physics=.DeformableSolver~new(zero)
physics~addBody(body)

c=.Circuit~new
v=.DCVoltageSource~new('V1','5 V')
wire=.PhysicsFractureConductor~new('WIRE',link,'0.01 ohm')
load=.Resistor~new('LOAD','1 kohm')
c~add(v); c~add(wire); c~add(load)
c~connectGround(v~negative)
c~connectGround(load~pin('B'))
c~connect('VCC',.array~of(v~positive,wire~pin('A')))
c~connect('OUT',.array~of(wire~pin('B'),load~pin('A')))

before=c~solveDC
if wire~fractured then call fail 'wire should be intact before Physics evaluates the tensile state'
if wire~electricalPathPeers(wire~pin('A'))~items<>1 then call fail 'intact physical wire should expose its internal electrical path'
if before~current(wire)<.0049 then call fail 'intact wire current unexpectedly small' before~current(wire)

physics~step(.Units~q(.001,.Units~second))
ev=wire~captureFractureEvidence(physics)
if ev==.nil then call fail 'fracture event provenance was not captured'
if \wire~fractured then call fail 'Physics link did not fracture'
if wire~state<>'OPEN_FRACTURE' then call fail 'electrical state did not follow Physics fracture' wire~state
if wire~fractureCriterion<>'TENSION' then call fail 'wrong fracture criterion' wire~fractureCriterion
if wire~electricalPathPeers(wire~pin('A'))~items<>0 then call fail 'fractured conductor still exposes an internal electrical path'

after=c~solveDC
if abs(after~current(wire))>1e-9 then call fail 'fractured conductor still carries material current' after~current(wire)
if after~voltage('OUT')>1e-6 then call fail 'downstream node remained powered after fracture' after~voltage('OUT')
if wire~fractureEnergy==.nil then call fail 'fracture energy evidence was not retained'
if wire~fractureTime==.nil then call fail 'fracture time evidence was not retained'

if failures=0 then do
  say 'REXX-TRONICS / PHYSICS FRACTURE CONDUCTOR: OK'
  say 'before current A:' before~current(wire)
  say 'after current A:' after~current(wire)
  say 'fracture criterion:' wire~fractureCriterion
  say 'fracture stress Pa:' wire~fractureStress~in(.Units~pascal)
  say 'released fracture energy J:' wire~fractureEnergy~in(.Units~joule)
  say 'fragment count:' body~fragmentCount
  exit 0
end
say 'FAIL fracture conductor failures='failures
exit 1

fail: procedure expose failures
  use arg label,detail=''
  say 'FAIL:' label detail
  failures+=1
return

::requires 'RexxTronicsFracture.cls'
::requires 'Deformable.cls'
::requires 'MathsBootstrap.cls'
