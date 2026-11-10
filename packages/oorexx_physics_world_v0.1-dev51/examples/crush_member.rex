/* Controlled deformation example: a yielding bar driven into a rigid wall. */
ctx=.Maths~defaultContext
zero=.MathVector3~new(0,0,0,ctx)
mat=.MechanicalMaterial~new('demo-crush-alloy',2700,5000000,'0.02','0.40',5000,1)
body=.DeformableBody~bar('bumper',9,'0.40',8,'0.0015',mat,.MathVector3~new('0.01',0,0,ctx),.MathVector3~new(1,0,0,ctx),ctx)
do node over body~nodes; node~velocity=.MathVector3~new(-3,0,0,ctx); end
solver=.DeformableSolver~new(zero,3)
solver~addBody(body)
solver~addPlane(.DeformableContactPlane~new(zero,.MathVector3~new(1,0,0,ctx),0))
say 'initial kinetic J:' body~kineticEnergy
do i=1 to 200; solver~step('0.00025'); end
say 'final kinetic J:  ' body~kineticEnergy
say 'elastic J:        ' body~elasticEnergy
say 'plastic work J:   ' body~plasticWork
say 'broken links:     ' body~brokenLinks
say 'front x m:         ' body~nodes[1]~position~x
say 'rear x m:          ' body~nodes[body~nodes~items]~position~x
::requires 'Deformable.cls'
::requires 'MathsBootstrap.cls'
