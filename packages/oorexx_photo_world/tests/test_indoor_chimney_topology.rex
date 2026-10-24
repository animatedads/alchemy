room=.SurveyIndoorActualRoomSolver~fromCurrentEvidence
if room~topologyClass<>'CHIMNEY_BREAST_WITH_TWO_ALCOVES' then raise syntax 93.900 array('wrong actual-room topology',room~topologyClass)
wall=room~chimneyWall
if \wall~hasLeftAlcove then raise syntax 93.900 array('left alcove missing','false')
if \wall~hasRightAlcove then raise syntax 93.900 array('right alcove missing','false')
if wall~segments~items<>5 then raise syntax 93.900 array('wrong chimney-wall segment count',wall~segments~items)
if wall~segments[1]~kind<>'LEFT_ALCOVE_REAR' then raise syntax 93.900 array('wrong segment 1',wall~segments[1]~kind)
if wall~segments[2]~kind<>'LEFT_RETURN' then raise syntax 93.900 array('wrong segment 2',wall~segments[2]~kind)
if wall~segments[3]~kind<>'CHIMNEY_BREAST_FACE' then raise syntax 93.900 array('wrong segment 3',wall~segments[3]~kind)
if wall~segments[4]~kind<>'RIGHT_RETURN' then raise syntax 93.900 array('wrong segment 4',wall~segments[4]~kind)
if wall~segments[5]~kind<>'RIGHT_ALCOVE_REAR' then raise syntax 93.900 array('wrong segment 5',wall~segments[5]~kind)
if wall~isDimensionallyResolved then raise syntax 93.900 array('unmeasured chimney dimensions must remain unresolved','resolved')
if room~canComputeArea then raise syntax 93.900 array('area must remain unresolved','computed')
if room~area<>.nil then raise syntax 93.900 array('area must be nil until topology dimensions solve',room~area)
if room~observation('left-wall-to-doorway')~metres<>2.750 then raise syntax 93.900 array('2.750 m evidence lost',room~observation('left-wall-to-doorway')~metres)
if room~observation('opposite-wall')~metres<>3.750 then raise syntax 93.900 array('3.750 m evidence lost',room~observation('opposite-wall')~metres)
if room~observation('long-wall')~metres<>5.000 then raise syntax 93.900 array('5.000 m prior lost',room~observation('long-wall')~metres)
say 'PASS actual room topology: central chimney breast with alcoves on both sides; dimensions remain unresolved'
return 'INDOOR-CHIMNEY-TOPOLOGY-PASS'
::requires '../rexx/SurveyIndoorRoom.cls'
