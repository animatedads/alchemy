numeric digits 20
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
p=.HarbourOperaWestWalk~new
checks=0
call require p~scene~boxes~items=7+18+2, 'expected scene base count'
state=.HarbourBridgeRoofPins~apply(p~scene)
call require state['STATUS']=='ROOF_PIN_LAYOUT_CONSISTENT_NOT_SURVEYED','roof geometry admitted provisionally'
bridge=.HarbourBridgeVertical~apply(p~scene)
call require bridge['STATUS']=='CORRECTED_CONTINUITY_GEOMETRY_UNSURVEYED','corrected bridge loaded'
tower=.HarbourBluesPointTower~apply(p~scene,0)
call require tower['STATUS']=='GEOGRAPHIC_LANDMARK_VISIBLE_HEIGHT_BASE_UNSURVEYED','tower loaded'
call require p~scene~boxes~items=30,'30 total boxes'
call require p~orientOperaBox=='OPERA_AXIS_NORTH_SOUTH_UNSURVEYED','Opera box explicitly reoriented'
q=p~qualifyWalk
call require q['DISTANCE_WEST_OF_FACE_M']>5,'camera outside corrected box west face'
call require q['DISTANCE_WEST_OF_FACE_M']<35,'camera near western face'
call require q['STATUS']=='WEST_OF_CORRECTED_OPERA_BOX_NOT_GEOREGISTERED_LAND','land admission cautious'
cam=p~siteCamera('OPERA_WEST_WALK')
call require cam[3]==7,'camera ground level provisional'
call require p~scene~features~hasIndex('BPT_ROOF'),'landmark feature preserved'
call require p~scene~features~hasIndex('CAHILL_C'),'quay feature preserved'
call require p~scene~features~hasIndex('N_DECK'),'bridge feature preserved'
call require p~scene~features~hasIndex('S_DECK'),'bridge south feature preserved'
call require p~scene~features~hasIndex('O'),'opera centre feature preserved'
call require p~scene~features~hasIndex('T'),'salesforce feature preserved'
call require p~pointAngles(p~scene~features['BPT_ROOF'],cam)[1]>180,'tower in west hemisphere'
call require p~pointAngles(p~scene~features['N'],cam)[1]>180,'bridge north in west hemisphere'
call require p~pointAngles(p~scene~features['S'],cam)[1]>180,'bridge south in west hemisphere'
call require p~pointAngles(p~scene~features['O'],cam)[1]<180,'opera east hemisphere'
call require tower['CAMERA_POSE_ADMISSION']=='NOT_ADMITTED','no camera pose admission'
say 'OPERA_WEST_WALK PASS' checks 'checks'
exit 0
require:
  use arg condition,explanation
  if \condition then do
    say 'FAIL' explanation
    exit 1
  end
  checks+=1
  return
::requires 'SlamHarbourOperaWestWalk.cls'