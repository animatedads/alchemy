numeric digits 30
ctx=.Maths~defaultContext
mat=.MechanicalMaterial~new('impact-brittle',2500,1000,0,10,0,0)
law=.BrittleFractureLaw~new('compression-failure',.Units~q(1000,.Units~pascal),.Units~q(20,.Units~pascal))
body=.DeformableBody~new('impact-coupon')
n1=body~addNode(.DeformableNode~new(.MathVector3~new(0,.005,0,ctx),1,.MathVector3~new(0,-10,0,ctx)))
n2=body~addNode(.DeformableNode~new(.MathVector3~new(0,.105,0,ctx),1,.MathVector3~new(0,-10,0,ctx)))
link=body~addLink(.DeformableLink~new(n1,n2,1,mat,.1,law))
plane=.DeformableContactPlane~new(.MathVector3~new(0,0,0,ctx),.MathVector3~new(0,1,0,ctx),0)
solver=.DeformableSolver~new(.MathVector3~new(0,0,0,ctx))
solver~addBody(body); solver~addPlane(plane)
solver~step(.Units~q(.001,.Units~second))
if solver~contactEvents~items<1 then call fail 'first step did not create contact impulse'
if link~broken then call fail 'link fractured before impact-created compression existed'
solver~step(.Units~q(.0001,.Units~second))
if solver~fractureEvents~items<>1 then call fail 'impact compression did not create fracture event' solver~fractureEvents~items
e=solver~fractureEvents[1]
if e~criterion<>'COMPRESSION' then call fail 'unexpected impact fracture criterion' e~criterion
if body~fragmentCount<>2 then call fail 'impact fracture did not split load path' body~fragmentCount
say 'PHYSICS CONTACT -> FRACTURE COUPLING: OK'
exit 0
fail: procedure
  use arg msg,detail
  say 'FAIL' msg detail; exit 1
::requires 'Deformable.cls'
::requires 'MathsBootstrap.cls'
