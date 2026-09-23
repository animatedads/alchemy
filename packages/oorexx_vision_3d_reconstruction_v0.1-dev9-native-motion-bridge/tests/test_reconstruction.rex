call test
exit 0

test:
  ctx=.MathContext~decimal(30)
  target=.MathVector3~new(0,0,-4,ctx)
  oa=.MathVector3~new(-.5,0,0,ctx); ob=.MathVector3~new(.5,0,0,ctx)
  a=.Vision3DRayObservation~new('SRC',0,'A',10,10,.MathRay3D~new(oa,target-oa,ctx),.9,'EA','OBJECT-1')
  b=.Vision3DRayObservation~new('SRC',1,'B',12,10,.MathRay3D~new(ob,target-ob,ctx),.8,'EB','OBJECT-1')
  grid=.VisionAdaptiveGrid3D~new(.MathVector3~new(-10,-10,-10,ctx),1,3)
  recon=.Vision3DReconstruction~new(grid,.01)
  tri=recon~triangulate(a,b,'OBJECT-1',1)
  call assertEq tri~status,'OK','accepted triangulation'
  call assertEq recon~accepted,1,'accepted count'
  call assertEq grid~countState(.Vision3DState~observedOccupied),1,'occupied sparse cell'
  say 'PASS test_reconstruction'
  return
assertEq: procedure
  use arg a,b,label
  if a<>b then do; say 'FAIL' label a b; exit 1; end
  say 'PASS' label; return
::requires 'Vision3DReconstruction.cls'
