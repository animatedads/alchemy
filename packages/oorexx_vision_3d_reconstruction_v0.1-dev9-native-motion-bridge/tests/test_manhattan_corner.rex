a=.VisionFloorBoundarySegment~new('a',.array~of(0,0),.array~of(4,0),1,'OBSERVED',.array~of('A:10'))
b=.VisionFloorBoundarySegment~new('b',.array~of(2,-3),.array~of(2,3),1,'OBSERVED',.array~of('B:12'))
c=.VisionManhattanCornerDetector~new(15)~candidate(a,b)
if c==.nil then do; say 'FAIL no corner'; exit 1; end
if abs(c~point[1]-2)>.000001 | abs(c~point[2])>.000001 then do; say 'FAIL point'; exit 1; end
if c~evidenceRefs~items<>2 then do; say 'FAIL evidence'; exit 1; end
say 'PASS Manhattan corner'
::requires 'Vision3DStructure.cls'
