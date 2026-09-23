call test
exit 0

test:
  ctx=.MathContext~decimal(30)
  oa=.MathVector3~new(-.5,0,0,ctx); ob=.MathVector3~new(.5,0,0,ctx)
  /* deliberately inconsistent rays: closest points are separated */
  a=.Vision3DRayObservation~new('SRC',1,'F1',10,10,.MathRay3D~new(oa,.MathVector3~new(0,0,-1,ctx),ctx),1,'EA','EDGE-1')
  b=.Vision3DRayObservation~new('SRC',2,'F2',20,10,.MathRay3D~new(ob,.MathVector3~new(.2,.2,-1,ctx),ctx),1,'EB','EDGE-1')
  grid=.VisionAdaptiveGrid3D~new(.MathVector3~new(-10,-10,-10,ctx),1,3)
  recon=.Vision3DReconstruction~new(grid,.01)
  region=.VisionRegion~new(5,5,30,20,1,2)
  tri=recon~triangulateOrEnqueue(a,b,region,'EDGE-DEPTH','EDGE-1',0,.9,320,240)
  call assertEq recon~enhancementQueue~pendingCount,1,'failed geometry queues one enhancement item'
  item=recon~enhancementQueue~next
  call assertEq item~purpose,'EDGE-DEPTH','semantic purpose retained'
  call assertEq item~candidateFrames~items,2,'both useful source views retained'
  req=item~asHighResolutionRequest('SRC')
  call assertEq req~request~requestedSpatialResolution,'320x240','targeted high-resolution request'
  say 'PASS test_systematic_enhancement'
  return
assertEq: procedure
  use arg a,b,label
  if a<>b then do; say 'FAIL' label a b; exit 1; end
  say 'PASS' label; return
::requires 'Vision3DReconstruction.cls'
