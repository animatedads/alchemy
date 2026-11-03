numeric digits 30
world=.PhysicalWorld~new
body=.PhysicalBody~new('rotor',.PhysicalPose~identity)
state=.RigidBodyState~new(body,.MechanicsMassProperties~solidCylinder(2,.1,.2),.nil,.MathVector3~new(0,20,0))
fr=.RotationalViscousFriction~new(state,.MathVector3~new(0,1,0),.5)
fr~apply
if abs(fr~torque+10)>.000001 then do; say 'FAIL drag torque'; exit 1; end
if abs(fr~dissipatedPower-200)>.000001 then do; say 'FAIL friction power'; exit 1; end
say 'PHYSICS ROTATIONAL FRICTION: OK power='fr~dissipatedPower
exit 0
::requires 'RotatingMachinery.cls'
