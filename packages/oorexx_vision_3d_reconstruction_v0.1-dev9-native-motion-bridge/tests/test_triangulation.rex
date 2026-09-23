call test
exit 0

test:
  ctx=.MathContext~decimal(30)
  target=.MathVector3~new(0,0,-5,ctx)
  oa=.MathVector3~new(-1,0,0,ctx); ob=.MathVector3~new(1,0,0,ctx)
  ra=.MathRay3D~new(oa,target-oa,ctx); rb=.MathRay3D~new(ob,target-ob,ctx)
  a=.Vision3DRayObservation~new('SRC',0,'A',0,0,ra,1,'EA','TARGET')
  b=.Vision3DRayObservation~new('SRC',1,'B',0,0,rb,1,'EB','TARGET')
  tri=.Vision3DGeometry~closestPointBetweenRays(ra,rb,'1E-12',a,b)
  call assertEq tri~status,'OK','triangulation status'
  call assertNear tri~point~x,0,'target x'
  call assertNear tri~point~y,0,'target y'
  call assertNear tri~point~z,-5,'target z'
  call assertNear tri~separation,0,'ray separation'
  say 'PASS test_triangulation'
  return
assertEq: procedure
  use arg a,b,label
  if a<>b then do; say 'FAIL' label a b; exit 1; end
  say 'PASS' label; return
assertNear: procedure
  use arg a,b,label
  if abs(a-b)>'1E-10' then do; say 'FAIL' label a b; exit 1; end
  say 'PASS' label; return
::requires 'Vision3DReconstruction.cls'
