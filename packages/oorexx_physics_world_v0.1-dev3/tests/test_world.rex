ctx=.MathContext~decimal(40)
world=.PhysicalWorld~new(.OpticalMedium~water)
body=.OpticalBody~new('glass-sphere',.SphereShape~new(0.5),.PhysicsMaterials~bk7Approx,.PhysicalPose~identity(ctx))
world~addBody(body)
ray=.OpticalRayState~new(.MathVector3~new(0,0,-2,ctx),.MathVector3~new(0,0,1,ctx),555,1,.OpticalMedium~water,0,ctx)
trace=world~trace(ray,6,0.0000001)
if trace~branches<3 then do; say 'FAIL expected Fresnel branching' trace~branches; exit 1; end
if trace~escaped<=0 then do; say 'FAIL expected escaped energy' trace~escaped; exit 1; end
say 'PHYSICS WORLD UNDER WATER: OK branches='trace~branches 'escaped='trace~escaped
exit 0
::requires 'PhysicsWorld.cls'
