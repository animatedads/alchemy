ctx=.MathContext~decimal(40)
world=.PhysicalWorld~new(.OpticalMedium~water)

axis=.MathVector3~new(0,1,0,ctx)
q=.MathQuaternion~fromAxisAngle(axis,.MathAngle~degrees(17,ctx),ctx)
pose=.PhysicalPose~new(.MathVector3~new(0.01,0,0,ctx),q,ctx)
prism=.OpticalBody~new('odd-prism',.TriangularPrismShape~new(0.03,0.03,0.05,ctx),.PhysicsMaterials~bk7Approx,pose)
world~addBody(prism)

say 'ambient:' world~ambient~name
say 'BK7 approx n(450nm):' .OpticalMedium~bk7Approx~refractiveIndex(450)
say 'BK7 approx n(650nm):' .OpticalMedium~bk7Approx~refractiveIndex(650)
say '20 cd -> 1cm x 1cm at 2cm:' .Photometry~isotropicRectangleFlux(20,0.01,0.01,0.02) 'lm'

ray=world~ray(.MathVector3~new(0,0,-0.10,ctx),.MathVector3~new(0,0,1,ctx),555,1,ctx)
trace=world~trace(ray,12,0.000000001)
say 'trace branches:' trace~branches 'escaped weight:' trace~escaped

::requires 'PhysicsWorld.cls'
