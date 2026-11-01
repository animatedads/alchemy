/* Power SLAM v0.11 structural vocabulary qualification. */
numeric digits 20
checks=0
s=.HarbourScene~new
v=.HarbourBridgeSemantics~facts
f=.HarbourBridgeSemantics~frame(s)
call check v['PYLON_COUNT']=4,'four ornamental pylon towers represented'
call check v['TRUSS_COUNT']=2,'two arch trusses represented'
call check v['TRUSS_CENTRE_SPACING_M']=30,'truss spacing 30m centre-to-centre'
call check v['DECK_WIDTH_M']=49,'bridge deck width 49m'
call check v['ABUTMENT_BASE_WIDTH_M']=58,'abutment base width specified distinctly'
call check v['ABUTMENT_BASE_LENGTH_M']=49,'abutment base length specified distinctly'
call check v['PYLON_TOP_ASL_M']=89,'pylon top 89m ASL'
call check v['PYLON_LOOKOUT_ASL_M']=87,'southeast lookout deck 87m ASL'
call check v['MAIN_ARCH_SPAN_M']=503,'main arch span 503m'
call check .HarbourBridgeSemantics~structureKind('PYLON')=='DECORATIVE_MASONRY_TOWER_ABOVE_DECK','pylons begin at deck level'
call check .HarbourBridgeSemantics~structureKind('ABUTMENT')=='STRUCTURAL_SUPPORT_AND_ARCH_BEARING_REACTION','abutment takes arch forces'
call check .HarbourBridgeSemantics~structureKind('ARCH')=='STRUCTURAL_STEEL_TRUSSES','arch not confused with roadway'
call check .HarbourBridgeSemantics~referenceKind('USER_SE')=='UNVERIFIED_UNTYPED_POINT','Gemini coordinate classified untyped'
call check .HarbourBridgeSemantics~referenceKind('PHOTO_LOOKOUT')=='CAMERA_GPS_NOT_SURVEYED_PYLON_CENTRE','geotag not a surveyed pylon centre'
call check .HarbourBridgeSemantics~referenceKind('OSM_SOUTH_BUILDING')=='MAPPED_ABUTMENT_BUILDING_CENTRE','OSM building centroid not a pylon centre'
call check .HarbourBridgeSemantics~referenceKind('TFNSW_SOUTH_ACCESS')=='ACCESS_POINT_NOT_PYLON_CENTRE','official access point is not tower centroid'
call check .HarbourBridgeSemantics~requiresSurveyForPose('USER_SE'),'user SE blocked as pylon centre'
call check .HarbourBridgeSemantics~requiresSurveyForPose('PHOTO_LOOKOUT'),'photo GPS blocked as pylon centre'
call check .HarbourBridgeSemantics~requiresSurveyForPose('OSM_SOUTH_BUILDING'),'building centre blocked as pylon centre'
call check f['DECK_HALF_WIDTH_M']=24.5,'deck half width'
call check f['TRUSS_HALF_SPACING_M']=15,'truss half separation'
call check f['DECK_HALF_WIDTH_M']>f['TRUSS_HALF_SPACING_M'],'deck not conflated with structural truss separation'
call check f['AXIS_LENGTH_M']>550 & f['AXIS_LENGTH_M']<580,'proxy centre-line length is non-span 565m'
call check abs((f['AXIS_UNIT_E']**2+f['AXIS_UNIT_N']**2)-1)<0.0001,'axis unit normalised'
call check abs(f['AXIS_UNIT_E']*f['CROSS_UNIT_E']+f['AXIS_UNIT_N']*f['CROSS_UNIT_N'])<0.0001,'across unit perpendicular to axis'
call check f['FIT_ADMISSION']=='BLOCKED_UNTYPED_PYLON_CENTRES','camera fit remains blocked pending tower-centre mapping'
call check f['PYLON_XY_STATUS']=='UNRESOLVED_FOUR_INDIVIDUAL_CENTRES','unknown remains unknown'
say 'BRIDGE SEMANTICS PASS ('checks' checks) STATUS=' f['FIT_ADMISSION']
exit 0
check:
 use arg ok, label
 if \ok then do
   say 'FAIL' label
   exit 3
 end
 checks+=1
 say 'PASS' label
 return
::requires 'SlamHarbourBridgeSemantics.cls'