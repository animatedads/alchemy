numeric digits 30
ctx=.Maths~defaultContext
world=.PhysicalWorld~new
axis=.MathVector3~new(0,0,1,ctx)
q=.MathQuaternion~fromAxisAngle(axis,.MathAngle~degrees(15,ctx),ctx)
body=.PhysicalBody~new('tumble-body',.BoxShape~new(.06,.12,.06,ctx), -
  .PhysicalPose~new(.MathVector3~new(0,.065,0,ctx),q,ctx))
props=.MechanicsMassProperties~solidCylinder(.5,.03,.12)
hull=.RigidContactHull~cylinder(.03,.12,4,ctx)
state=.HullRigidBodyState~new(body,props,hull,.MathVector3~new(.4,-4.429,0,ctx),.nil,.false,.15)
solver=.GeneralContactMechanicsSolver~new(world,.MathVector3~new(0,-9.80665,0,ctx),1)
solver~addBody(state)
solver~addPlane(.CollisionSurface~new(.MathVector3~new(0,0,0,ctx),.MathVector3~new(0,1,0,ctx),.1,.nil,.35))
tracker=.RigidTumbleTracker~new(state)
do i=1 to 30
  solver~step(.Units~q(.01,.Units~second))
  tracker~observeStep(solver,.Units~q(.01,.Units~second))
end
if tracker~contactCount<1 then do; say 'FAIL no finite-hull contacts'; exit 1; end
if tracker~turns<.10 then do; say 'FAIL body did not acquire meaningful tumble rotation' tracker~turns; exit 1; end
if tracker~peakAngularSpeed<=0 then do; say 'FAIL no angular speed generated'; exit 1; end
if state~position~y<-.001 then do; say 'FAIL rigid hull penetrated plane' state~position~y; exit 1; end
if \tracker~peakAngularSpeedQuantity~dimension~compatible((.Units~radian/.Units~second)~dimension) then do; say 'FAIL angular-speed unit'; exit 1; end
say 'PHYSICS FINITE CONTACT + TUMBLE: OK turns='tracker~turns 'contacts='tracker~contactCount
exit 0
::requires 'ContactDynamics.cls'
