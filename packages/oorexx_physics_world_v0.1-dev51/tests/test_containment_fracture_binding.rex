numeric digits 30
ctx=.Maths~defaultContext
water=.FluidMedium~water20C
tank=.RectangularTankGeometry2D~new(1,.5,.5,10,6)
boundary=.FluidContainmentBoundary2D~new(tank)
mat=.MechanicalMaterial~new('wall-material',2500,1000,0,10,0,0)
law=.BrittleFractureLaw~new('wall',50)
body=.DeformableBody~new('wall')
a=body~addNode(.DeformableNode~new(.MathVector3~new(0,0,0,ctx),1,,.true))
b=body~addNode(.DeformableNode~new(.MathVector3~new(1.2,0,0,ctx),1))
link=body~addLink(.DeformableLink~new(a,b,1,mat,1,law))
solver=.DeformableSolver~new(.MathVector3~new(0,0,0,ctx))
solver~addBody(body)
solver~step(.001)
events=solver~fractureEvents
if events~items<>1 then do; say 'FAIL expected fracture event'; exit 1; end
breach=.RectangularBoundaryBreach2D~new('fracture-opening','RIGHT',0,.05,.1,.05,.6,events[1])
binding=.FractureContainmentBinding2D~new(boundary)
binding~bindLink(link,breach)
opened=binding~consume(events)
if opened~items<>1 | boundary~state<>'BREACHED' | boundary~breachCount<>1 then do; say 'FAIL fracture did not open containment'; exit 1; end
if binding~consume(events)~items<>0 then do; say 'FAIL fracture binding reopened duplicate breach'; exit 1; end
say 'PHYSICS FRACTURE -> CONTAINMENT: OK'
exit 0
::requires 'FluidContainment.cls'
::requires 'Deformable.cls'
::requires 'MathsBootstrap.cls'
