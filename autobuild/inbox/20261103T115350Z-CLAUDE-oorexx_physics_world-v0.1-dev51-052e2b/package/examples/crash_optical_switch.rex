/* Cross-domain example: mechanics moves a spring-mounted brick; the same brick
   is an optical absorber. The light gate goes dark because geometry changes. */
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

mechanics=.MechanicsSolver~new(world,.MathVector3~new(0,0,0,ctx),6)
mechanics~addBody(car); mechanics~addBody(brick)
mechanics~addSpring(.SpringConstraint~new(car,brick,1,8,'0.10'))
mechanics~addPlane(.CollisionPlane~new(.MathVector3~new(2,0,0,ctx),.MathVector3~new(-1,0,0,ctx),0))

source=.PhysicalMount~new(carBody,.PhysicalPose~new(.MathVector3~new('-0.25',0,'-0.50',ctx),.nil,ctx))
sensor=.PhysicalMount~new(carBody,.PhysicalPose~new(.MathVector3~new('-0.25',0,'0.50',ctx),.nil,ctx))
lightGate=.OpticalBeamProbe~new(world,source,sensor,'0.08','0.08',555,1,'roof-light-sensor')

say 'time    car-x    car-v    brick-relative-x  light'
state=''
dt='0.005'
do i=0 to 500
  if i>0 then mechanics~step(dt)
  if i//10<>0 then iterate
  reading=lightGate~sample
  if reading~transmission>'0.5' then light='LIGHT'
  else light='DARK'
  if light<>state | i=0 then do
    rel=brick~position~x-car~position~x
    say format(i*dt,2,3) format(car~position~x,3,3) format(car~velocity~x,3,3) format(rel,4,3) light
    state=light
  end
end
exit 0

::requires 'Mechanics.cls'
::requires 'Coupling.cls'
