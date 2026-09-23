r=.VisionRegion~new(10,20,30,40,1,2)
g=.Vision3DGeometryRefinementRequest~new('doorway-1','INSUFFICIENT_FLOOR_FRONTIER',r,1,2,250,2,.9)
g~addSource('officer-A')~addSource('officer-B')
g~addEvidenceKind(.VisionGeometryEvidenceKind~floorWallBoundary)
g~addEvidenceKind(.VisionGeometryEvidenceKind~doorwayJamb)
if g~targetObservationCount<>250 then do; say 'FAIL count'; exit 1; end
if g~sourceRefs~items<>2 then do; say 'FAIL sources'; exit 1; end
hr=g~asHighResolutionRequest('officer-A',192,341)
if hr~requestedWidth<>192 | hr~requestedHeight<>341 then do; say 'FAIL high resolution conversion'; exit 1; end
say 'PASS geometry refinement request'
::requires 'Vision3DStructure.cls'
