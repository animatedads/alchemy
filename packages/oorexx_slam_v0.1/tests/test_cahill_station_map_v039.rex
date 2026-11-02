/* Native Power SLAM v0.39 regression — map-snapped Cahill station.
 * Requires established HarbourScene dependencies and rxmath.
 * Map coordinates approximate, not a survey.
 */
model=.HarbourOcclusionPanorama~new
report=model~configure
s=model~scene
a=s~features['STATION_W']; b=s~features['STATION_E']
if abs(a[2]-(-1022+(-84)*(a[1]+481)/754))>0.01 then call fail 'station west not on road'
if abs(b[2]-(-1022+(-84)*(b[1]+481)/754))>0.01 then call fail 'station east not on road'
p=s~features['CAHILL_MAP_EAST_END']
if abs(p[1]-273)>0.001 | abs(p[2]+1106)>0.001 then call fail 'wrong east end'
if a[2]>=-1000 | b[2]>=-1000 then call fail 'station not moved south'
seenStation=0;seenRoad=0;seenExt=0
do item over s~boxes
  if item[1]=='CQ_STATION' then seenStation+=1
  if item[1]=='CAHILL' then seenRoad+=1
  if item[1]=='CAHILL_EAST_EXTENSION' then seenExt+=1
end
if seenStation<>1 | seenRoad<>1 | seenExt<>1 then call fail 'station and east road solids missing'
if report['SEGMENTS']<2 then call fail 'approach missing'
say 'PASS 7 checks — CQ station aligned beneath snapped road with east extension'
exit 0
fail:
  parse arg message
  say 'FAIL:' message
  exit 1
::requires 'SlamHarbourOcclusion.cls'
