numeric digits 30
f=.ContactFrictionExcitation~new(.MathVector3~new(0,1,0),.4,.3)
force=f~frictionForce(100,.MathVector3~new(2,0,0))
if abs(force~x+30)>.000001 then do; say 'FAIL kinetic friction force' force~x; exit 1; end
if abs(f~dissipatedPower-60)>.000001 then do; say 'FAIL friction dissipation' f~dissipatedPower; exit 1; end
say 'PHYSICS CONTACT FRICTION EXCITATION: OK force='force~x 'power='f~dissipatedPower
exit 0
::requires 'RotatingVibration.cls'
