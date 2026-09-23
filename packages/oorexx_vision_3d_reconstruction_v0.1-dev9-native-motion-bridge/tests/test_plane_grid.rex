call test
exit 0

test:
  ctx=.MathContext~decimal(30)
  p1=.MathVector3~new(0,0,0,ctx); p2=.MathVector3~new(1,0,0,ctx); p3=.MathVector3~new(0,1,0,ctx)
  plane=.Vision3DGeometry~planeFromPoints(p1,p2,p3)
  ray=.MathRay3D~new(.MathVector3~new(.25,.25,2,ctx),.MathVector3~new(0,0,-1,ctx),ctx)
  hit=.Vision3DGeometry~intersectRayPlane(ray,plane)
  call assertEq hit~status,'OK','plane hit status'
  call assertNear hit~point~z,0,'plane hit z'
  grid=.VisionAdaptiveGrid3D~new(.MathVector3~new(-2,-2,-2,ctx),1,3)
  c=grid~observePoint(.MathVector3~new(.1,.1,.1,ctx),.Vision3DState~observedOccupied,1,'P1',0,'OBJECT')
  call assertEq c~state,.Vision3DState~observedOccupied,'occupied state'
  grid~traceFree(.MathRay3D~new(.MathVector3~new(-1.5,.1,.1,ctx),.MathVector3~new(1,0,0,ctx),ctx),1.2,1,'RAY',0)
  call assertTrue grid~cellCount>=2,'sparse free cells created'
  say 'PASS test_plane_grid'
  return
assertEq: procedure
  use arg a,b,label
  if a<>b then do; say 'FAIL' label a b; exit 1; end
  say 'PASS' label; return
assertNear: procedure
  use arg a,b,label
  if abs(a-b)>'1E-10' then do; say 'FAIL' label a b; exit 1; end
  say 'PASS' label; return
assertTrue: procedure
  use arg a,label
  if \a then do; say 'FAIL' label; exit 1; end
  say 'PASS' label; return
::requires 'Vision3DReconstruction.cls'
