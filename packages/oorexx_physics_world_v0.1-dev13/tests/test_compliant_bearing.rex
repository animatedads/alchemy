numeric digits 30
world=.PhysicalWorld~new
pose=.PhysicalPose~new(.MathVector3~new(.001,0,0),.MathQuaternion~new(1,0,0,0))
body=.PhysicalBody~new('shaft',.SphereShape~new(.01),pose)
state=.RigidBodyState~new(body,.MechanicsMassProperties~solidCylinder(2,.02,.2))
bearing=.CompliantRadialBearing~new(state,.MathVector3~new(0,0,0),.MathVector3~new(0,1,0),100000,0)
f=bearing~apply
if abs(f~x+100)>.000001 | abs(f~y)>.000001 then do; say 'FAIL radial bearing force' f~x f~y f~z; exit 1; end
say 'PHYSICS COMPLIANT RADIAL BEARING: OK force='f~x
exit 0
::requires 'RotatingMachinery.cls'
