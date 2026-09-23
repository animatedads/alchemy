call test
exit 0

test:
  region=.VisionRegion~new(10,20,30,40,5,6)
  item=.Vision3DEnhancementItem~new('DOOR-HINGE-AXIS','DEPTH-UNCERTAINTY',region,5,6,.35,.8,'DOOR-1')
  item~priority='HIGH'; item~requireDimensions(640,960); item~addCandidateFrame('F150')
  req=item~asHighResolutionRequest('video:bodycam')
  call assertEq req~reason,'DOOR-HINGE-AXIS:DEPTH-UNCERTAINTY','semantic enhancement reason'
  call assertEq req~requestedWidth,640,'requested width'
  call assertEq req~requestedHeight,960,'requested height'
  call assertEq req~request~requestedSpatialResolution,'640x960','Vision request dimensions'
  call assertEq item~candidateFrames~items,1,'candidate frame retained'
  say 'PASS test_enhancement'
  return
assertEq: procedure
  use arg a,b,label
  if a<>b then do; say 'FAIL' label a b; exit 1; end
  say 'PASS' label; return
::requires 'Vision3DReconstruction.cls'
