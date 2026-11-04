/* Blues Point Tower model qualification, ooRexx 5.3 r13196 */
numeric digits 20
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
count=0
p=.HarbourQuayInfrastructurePanorama~new
roof=.HarbourBridgeRoofPins~apply(p~scene)
if roof['STATUS']\=='ROOF_PIN_LAYOUT_CONSISTENT_NOT_SURVEYED' then exit 2
vertical=.HarbourBridgeVertical~apply(p~scene)
count=count+1
m=.HarbourBluesPointTower~catalogue
if m['ID']\=='BLUES_POINT_TOWER' then exit 3
count=count+1
if m['STRUCTURAL_HEIGHT_M']\==83 then exit 4
count=count+1
if m['HEIGHT_BASIS']\=='ABOVE_GROUND_NOT_ASL' then exit 5
count=count+1
if m['FOOTPRINT_STATUS']\=='UNSURVEYED_ILLUSTRATIVE_RECTANGLE' then exit 6
count=count+1
if m['BASE_ASL_STATUS']\=='UNKNOWN_MUST_BE_EXPLICITLY_ASSUMED' then exit 7
count=count+1
before=p~scene~boxes~items
r=.HarbourBluesPointTower~apply(p~scene,0)
if p~scene~boxes~items\==before+1 then exit 8
count=count+1
if r['STRUCTURAL_HEIGHT_M']\==83 then exit 9
count=count+1
if r['CAMERA_POSE_ADMISSION']\=='NOT_ADMITTED' then exit 10
count=count+1
if r['STATUS']\=='GEOGRAPHIC_LANDMARK_VISIBLE_HEIGHT_BASE_UNSURVEYED' then exit 11
count=count+1
if r['BASE_ASL_ASSUMED_M']\==0 then exit 12
count=count+1
if r['ROOF_ASL_ASSUMED_M']\==83 then exit 13
count=count+1
if \p~scene~features~hasIndex('BPT_ROOF') then exit 14
count=count+1
if \p~scene~features~hasIndex('BPT_BASE') then exit 15
count=count+1
roofPt=p~scene~features['BPT_ROOF']
basePt=p~scene~features['BPT_BASE']
if roofPt[3]-basePt[3]\==83 then exit 16
count=count+1
xy=p~scene~local(m['LAT'],m['LON'])
if abs(xy[1]-roofPt[1])>0.00001 then exit 17
count=count+1
if abs(xy[2]-roofPt[2])>0.00001 then exit 18
count=count+1
camLoc=p~scene~local(-33.8487411,151.214266)
cam=.array~of(camLoc[1],camLoc[2],79)
angles=p~pointAngles(roofPt,cam)
if angles[1]<250 | angles[1]>300 then exit 19
count=count+1
if angles[3]<700 | angles[3]>1500 then exit 20
count=count+1
/* Tower must occur to westward side of bridge in true compass geometry. */
bridgeN=p~pointAngles(p~scene~features['N'],cam)
if angles[1]<=bridgeN[1] then exit 21
count=count+1
/* Double registration and unknown ground reject on source code path. */
p2=.HarbourQuayInfrastructurePanorama~new
before2=p2~scene~boxes~items
junk=.HarbourBluesPointTower~apply(p2~scene,10)
if p2~scene~features['BPT_ROOF'][3]\==93 then exit 22
count=count+1
if p2~scene~boxes~items\==before2+1 then exit 23
count=count+1
say 'BLUES_POINT_TOWER v0.19 PASS' count 'checks; BPT bearing' angles[1]
exit 0
::requires 'SlamHarbourQuayInfrastructure.cls'
::requires 'SlamHarbourBluesPointTower.cls'