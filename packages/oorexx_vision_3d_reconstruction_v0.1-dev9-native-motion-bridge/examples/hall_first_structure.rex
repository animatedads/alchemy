/* Minimal hall-first structural example. */
left=.VisionFloorBoundarySegment~new('left-wall',.array~of(0,0),.array~of(6,0),.95,'OBSERVED',.array~of('officer-B:f0'))
returnWall=.VisionFloorBoundarySegment~new('return-wall',.array~of(4,-2),.array~of(4,2),.9,'OBSERVED',.array~of('officer-C:f15'))
corner=.VisionManhattanCornerDetector~new(15)~candidate(left,returnWall)
skel=.VisionBuildingSkeleton~new('hall-1')
skel~addBoundarySegment(left)~addBoundarySegment(returnWall)
if corner<>.nil then skel~addCorner(corner)
s=skel~summary
say 'hall skeleton boundaries='s['BOUNDARY_SEGMENTS'] 'corners='s['CORNERS']

region=.VisionRegion~new(0,0,55,98,0,2)
req=.Vision3DGeometryRefinementRequest~new('hall-1/opening-east','MORE_GEOMETRY_POINTS',region,0,2,250,2,.9)
req~addSource('officer-A')~addSource('officer-B')~addSource('officer-C')
req~addEvidenceKind(.VisionGeometryEvidenceKind~floorWallBoundary)
req~addEvidenceKind(.VisionGeometryEvidenceKind~doorwayJamb)
say 'refinement wants' req~targetObservationCount 'observations across' req~sourceRefs~items 'sources'

::requires 'Vision3DStructure.cls'
