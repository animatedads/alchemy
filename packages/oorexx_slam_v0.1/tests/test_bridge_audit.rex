/* Power SLAM v0.10 independently grounded coordinate rejection checks. */
numeric digits 20
checks=0
s=.HarbourScene~new
u=.HarbourBridgeAudit~userCoordinates
ext=.HarbourBridgeAudit~externalCoordinates
q=.HarbourBridgeAudit~qualify(s)
call check u~items=4,'four independently labelled unverified candidates'
call check ext~items=6,'six independently sourced geographic controls'
call check q['LOOKOUT_PHOTO_AGREEMENT_M']<7,'photographer from actual pylon within 7m of OSM lookout'
call check q['SE_PHOTO_M']>155 & q['SE_PHOTO_M']<170,'proposed southeast is >155m from geotagged pylon photographer'
call check q['SE_OSM_LOOKOUT_M']>160 & q['SE_OSM_LOOKOUT_M']<175,'proposed southeast >160m from OSM lookout'
call check q['SE_TFNSW_M']>200 & q['SE_TFNSW_M']<220,'proposed southeast >200m from official southern pylon access'
call check q['SE_OSM_BUILDING_M']>170 & q['SE_OSM_BUILDING_M']<190,'proposed southeast >170m from OSM southern building'
call check q['OSM_BUILDING_AXIS_M']>550 & q['OSM_BUILDING_AXIS_M']<580,'independent north/south building centres ~565m apart'
call check q['SOUTH_PAIR_M']>50 & q['SOUTH_PAIR_M']<55,'user south pair about 52m'
call check q['NORTH_PAIR_M']>50 & q['NORTH_PAIR_M']<55,'user north pair about 52m'
call check q['LONG_EDGE_E_M']>450 & q['LONG_EDGE_E_M']<480,'user eastern pair longitudinal length'
call check q['LONG_EDGE_W_M']>450 & q['LONG_EDGE_W_M']<480,'user western pair longitudinal length'
call check q['PAIR_AXIS_DOT']>0.6 & q['PAIR_AXIS_DOT']<0.8,'user transverse pair actually strongly skewed to bridge long axis'
call check q['TRANSVERSE_COMPONENT_M']<42 & q['TRANSVERSE_COMPONENT_M']>30,'user pair transverse component around 37m'
call check q['ALONG_AXIS_COMPONENT_M']>30 & q['ALONG_AXIS_COMPONENT_M']<42,'user pair has spurious >30m longitudinal component'
call check q['STATUS']=='REJECTED_BRIDGE_GEOMETRY','invalid coordinates NOT admitted to camera fitting'
call check q['REASONS']~items=3,'all independently failed gates retained'
call check .HarbourBridgeAudit~provenance~pos('NOT_CENTROID')>0,'no access/POI point promoted to pylon centre'
call check .HarbourBridgeAudit~provenance~pos('UNVERIFIED')>0,'user input stays hypothesis'
say 'BRIDGE COORDINATE AUDIT PASS ('checks' checks); STATUS='q['STATUS']
say 'USER SE -> GEOTAGGED PYLON PHOTO:' q['SE_PHOTO_M'] 'm'
say 'USER SE -> SOUTH PYLON TfNSW ACCESS:' q['SE_TFNSW_M'] 'm'
say 'USER PAIR AXIS DOT:'q['PAIR_AXIS_DOT']
exit 0
check:
 use arg ok,label
 if \ok then do
   say 'FAIL' label
   exit 3
 end
 checks=checks+1
 say 'PASS' label
 return
::requires 'SlamHarbourBridgeAudit.cls'