ctx=.Maths~defaultContext
zero=.MathVector3~new(0,0,0,ctx)
/* A deliberately soft, yielding 1-D crush member moving into x=0 wall. */
mat=.MechanicalMaterial~new('crush-test',1000,200000,'0.015','0.35',800,1)
body=.DeformableBody~bar('crush-member',7,'0.60',7,'0.002',mat,.MathVector3~new('0.02',0,0,ctx),.MathVector3~new(1,0,0,ctx),ctx)
do n over body~nodes; n~velocity=.MathVector3~new(-2,0,0,ctx); end
solver=.DeformableSolver~new(zero,3)
solver~addBody(body)
solver~addPlane(.DeformableContactPlane~new(zero,.MathVector3~new(1,0,0,ctx),0))
initialKE=body~kineticEnergy
/* Small stable step; enough time for front contact and compression wave. */
do i=1 to 120; solver~step('0.0005'); end
ledger=solver~energyLedger
if body~plasticWork<=0 then call fail 'impact produced no plastic work'
if body~kineticEnergy>=initialKE then call fail 'impact failed to remove kinetic energy'
if body~nodes[1]~position~x<'-0.000000001' then call fail 'front node penetrated wall'
if ledger~plastic<=0 then call fail 'energy ledger missed plastic work'
say 'PHYSICS DEFORMABLE WALL IMPACT: OK'
exit 0
fail: procedure
  use arg msg; say 'FAIL' msg; exit 1
::requires 'Deformable.cls'
::requires 'MathsBootstrap.cls'
