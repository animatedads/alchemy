numeric digits 20
ctx=.Maths~defaultContext
world=.PhysicalWorld~new(.OpticalMedium~air)
carBody=.OpticalBody~new('car',.BoxShape~new(1,'0.4','0.2',ctx),.nil, -
    .PhysicalPose~new(.MathVector3~new(0,0,0,ctx),.nil,ctx))
car=.RigidBodyState~new(carBody,.MechanicsMassProperties~solidBox(10000,1,'0.4','0.2'), -
    .MathVector3~new(2,0,0,ctx),.nil,.false,0,'0.5')
brickBody=.OpticalBody~new('brick',.BoxShape~new('0.30','0.30','0.30',ctx), -
    .PhysicsMaterials~blackAbsorber, -
    .PhysicalPose~new(.MathVector3~new(-1,0,0,ctx),.nil,ctx))
brick=.RigidBodyState~new(brickBody,.MechanicsMassProperties~solidBox(1,'0.30','0.30','0.30'), -
    .MathVector3~new(2,0,0,ctx))
world~addBody(brickBody)
solver=.MechanicsSolver~new(world,.MathVector3~new(0,0,0,ctx),6)
solver~addBody(car); solver~addBody(brick)
solver~addSpring(.SpringConstraint~new(car,brick,1,8,'0.10'))
solver~addPlane(.CollisionPlane~new(.MathVector3~new(2,0,0,ctx),.MathVector3~new(-1,0,0,ctx),0))
sourceMount=.PhysicalMount~new(carBody,.PhysicalPose~new(.MathVector3~new('-0.25',0,'-0.50',ctx),.nil,ctx))
sensorMount=.PhysicalMount~new(carBody,.PhysicalPose~new(.MathVector3~new('-0.25',0,'0.50',ctx),.nil,ctx))
probe=.OpticalBeamProbe~new(world,sourceMount,sensorMount,'0.08','0.08',555,1,'crash-light-sensor')
initial=probe~sample
if initial~transmission<0.999999 then do; say 'FAIL: beam not initially clear' initial~transmission; exit 1; end
crashed=.false; dark=.false; clearAgain=.false; firstDark=-1; minimumTransmission=1; maxCompression=0
dt='0.01'
do i=1 to 250
  solver~step(dt)
  t=i*dt
  if abs(car~velocity~x)<'0.000001' & car~position~x>'1.49' then crashed=.true
  sep=(car~position-brick~position)~norm
  compression=1-sep
  if compression>maxCompression then maxCompression=compression
  if i//10=0 then do
    reading=probe~sample
    if reading~transmission<minimumTransmission then minimumTransmission=reading~transmission
    if crashed & reading~transmission<'0.000001' then do
      if \dark then firstDark=t
      dark=.true
    end
    else if dark & reading~transmission>'0.999999' then clearAgain=.true
  end
end
if \crashed then do; say 'FAIL: car never struck wall'; exit 1; end
if \dark then do; say 'FAIL: moving spring mass never occluded optical beam'; exit 1; end
if \clearAgain then do; say 'FAIL: beam never cleared after spring rebound'; exit 1; end
if maxCompression<'0.45' then do; say 'FAIL: spring did not compress enough' maxCompression; exit 1; end
if minimumTransmission>'0.000001' then do; say 'FAIL: optical sensor never went dark' minimumTransmission; exit 1; end
say 'PHYSICS CRASH OPTICAL SWITCH: OK firstDark='firstDark 'maxCompression='maxCompression 'clearAgain='clearAgain
exit 0
::requires 'Mechanics.cls'
::requires 'Coupling.cls'
