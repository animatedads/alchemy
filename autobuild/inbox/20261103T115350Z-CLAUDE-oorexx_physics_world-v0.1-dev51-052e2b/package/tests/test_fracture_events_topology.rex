numeric digits 30
ctx=.Maths~defaultContext
z=.MathVector3~new(0,0,0,ctx)
mat=.MechanicalMaterial~new('brittle-topology',2500,1000,0,10,0,0)
law=.BrittleFractureLaw~new('tension',.Units~q(50,.Units~pascal))
body=.DeformableBody~new('three-node-coupon')
n1=body~addNode(.DeformableNode~new(z,1,,.true))
n2=body~addNode(.DeformableNode~new(.MathVector3~new(1.2,0,0,ctx),1))
n3=body~addNode(.DeformableNode~new(.MathVector3~new(2.2,0,0,ctx),1))
l1=body~addLink(.DeformableLink~new(n1,n2,1,mat,1,law))
l2=body~addLink(.DeformableLink~new(n2,n3,1,mat,1,law))
solver=.DeformableSolver~new(.MathVector3~new(0,0,0,ctx))
solver~addBody(body)
solver~step(.Units~q(.001,.Units~second))
if solver~fractureEvents~items<>1 then call fail 'expected one fracture event' solver~fractureEvents~items
event=solver~fractureEvents[1]
if event~kind<>'DEFORMABLE_FRACTURE' then call fail 'wrong fracture event kind' event~kind
if event~body<>body | event~link<>l1 then call fail 'fracture provenance lost'
if event~criterion<>'TENSION' then call fail 'wrong fracture criterion' event~criterion
if event~releasedEnergy<=0 then call fail 'fracture event has no released energy'
fragments=body~fragments
if fragments~items<>2 then call fail 'expected two connected fragments' fragments~items
mass=0
foundOne=.false; foundTwo=.false
do f over fragments
  mass=mass+f~mass
  if f~nodeCount=1 then foundOne=.true
  if f~nodeCount=2 then foundTwo=.true
end
call near mass,3,'0.0000001','fragment mass conservation'
if \foundOne | \foundTwo then call fail 'unexpected fragment node partition'
say 'PHYSICS FRACTURE EVENTS + TOPOLOGY: OK'
exit 0
near: procedure
  use arg actual,expected,tol,label
  if abs(actual-expected)>tol then do; say 'FAIL' label actual expected; exit 1; end
  return
fail: procedure
  use arg msg,detail
  say 'FAIL' msg detail; exit 1
::requires 'Deformable.cls'
::requires 'MathsBootstrap.cls'
