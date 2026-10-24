/* Actual room topology from explicit survey statements.
 * No image-derived geometry is promoted here and no unmeasured chimney/alcove
 * dimension is invented. */
parse arg outputPath
if outputPath='' then outputPath='../output/indoor_room_topology.svg'
room=.SurveyIndoorActualRoomSolver~fromCurrentEvidence
written=.SurveyIndoorTopologySvg~topDown(room,outputPath,'Indoor room - chimney breast and two alcoves')
say 'topology='room~topologyClass
say 'left-wall-to-doorway='room~observation('left-wall-to-doorway')~metres
say 'opposite-wall='room~observation('opposite-wall')~metres
say 'long-wall-prior='room~observation('long-wall')~metres
say 'area-state='room~areaState
say 'wrote' written
::requires '../rexx/SurveyIndoorRoom.cls'
