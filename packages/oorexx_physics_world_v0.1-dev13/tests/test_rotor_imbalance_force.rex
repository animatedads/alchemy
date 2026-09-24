numeric digits 30
world=.PhysicalWorld~new
body=.PhysicalBody~new('rotor',.PhysicalPose~identity)
mp=.MechanicsMassProperties~solidCylinder(10,.1,.4)
state=.RigidBodyState~new(body,mp,.MathVector3~new(0,0,0),.MathVector3~new(0,100,0))
ecc=.RotorMassEccentricity~new(.1,.MathVector3~new(.002,0,0))
f=ecc~centrifugalForce(state)
expected=.1*.002*100*100
if abs(f~norm-expected)>.000001 then do; say 'FAIL imbalance force' f~norm expected; exit 1; end
say 'PHYSICS ROTOR IMBALANCE FORCE: OK force='f~norm
exit 0
::requires 'RotatingMachinery.cls'
