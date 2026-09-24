/* Physics World dev10 fracture -> Rexx-tronics electrical continuity example.
 * An impacting brittle link is also an energized conductor. The physical
 * solver decides when the link breaks; Rexx-tronics then opens the circuit.
 */
numeric digits 30
ctx=.Maths~defaultContext
zero=.MathVector3~new(0,0,0,ctx)
mat=.MechanicalMaterial~new('impact-brittle',2500,1000,0,10,0,0)
law=.BrittleFractureLaw~new('compression-failure',.Units~q(1000,.Units~pascal),.Units~q(20,.Units~pascal))
body=.DeformableBody~new('powered-link')
n1=body~addNode(.DeformableNode~new(.MathVector3~new(0,.005,0,ctx),1,.MathVector3~new(0,-10,0,ctx)))
n2=body~addNode(.DeformableNode~new(.MathVector3~new(0,.105,0,ctx),1,.MathVector3~new(0,-10,0,ctx)))
link=body~addLink(.DeformableLink~new(n1,n2,1,mat,.1,law))
physics=.DeformableSolver~new(zero)
physics~addBody(body)
physics~addPlane(.DeformableContactPlane~new(zero,.MathVector3~new(0,1,0,ctx),0))

c=.Circuit~new
v=.DCVoltageSource~new('V1','5 V')
wire=.PhysicsFractureConductor~new('WIRE',link,'0.01 ohm')
load=.Resistor~new('LOAD','1 kohm')
c~add(v); c~add(wire); c~add(load)
c~connectGround(v~negative); c~connectGround(load~pin('B'))
c~connect('VCC',.array~of(v~positive,wire~pin('A')))
c~connect('OUT',.array~of(wire~pin('B'),load~pin('A')))

clock=.SimulationClock~new
coupler=.FractureElectricalCoupler~new(c,physics,clock)
coupler~addConductor(wire)
initial=coupler~begin('1 ms')
say 't=0      wire='wire~state 'current mA='initial~current(wire)*1000
one=coupler~step('1 ms')
say 't=1 ms   contact events='one~contactEvents~items 'wire='wire~state 'current mA='one~electricalSolution~current(wire)*1000
two=coupler~step('0.1 ms')
say 't=1.1 ms fracture events='two~fractureEvents~items 'wire='wire~state 'current A='two~electricalSolution~current(wire)
say 'criterion='wire~fractureCriterion 'fragments='body~fragmentCount

::requires 'RexxTronicsFracture.cls'
::requires 'Deformable.cls'
::requires 'MathsBootstrap.cls'
