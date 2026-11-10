numeric digits 30
ctx=.Maths~defaultContext
mat=.MechanicalMaterial~new('glass-like-development-coupon',2500,70000000000,0,.50,0,0)
law=.BrittleFractureLaw~new('brittle-coupon-law',.Units~q(50000000,.Units~pascal),,.Units~q(8,.Units~joule/.Units~squareMetre))
body=.DeformableBody~bar('coupon',3,.Units~q(.10,.Units~metre),.Units~q(.030,.Units~kilogram),.Units~q(.0001,.Units~squareMetre),mat,,,.nil,law)
nodes=body~nodes
/* Pull the centre node far enough to fail the left load path. */
nodes[2]~position=.MathVector3~new(.05005,0,0,ctx)
solver=.DeformableSolver~new(.MathVector3~new(0,0,0,ctx))
solver~addBody(body)
solver~step(.Units~q(.00001,.Units~second))
say 'fracture events:' solver~fractureEvents~items
if solver~fractureEvents~items>0 then do
  e=solver~fractureEvents[1]
  say 'criterion:' e~criterion
  say 'stress (MPa):' e~stress/1000000
  say 'released elastic energy (J):' e~releasedEnergy
end
say 'connected fragments:' body~fragmentCount
::requires 'Deformable.cls'
::requires 'MathsBootstrap.cls'
