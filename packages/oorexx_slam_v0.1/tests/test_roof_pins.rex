/* Power SLAM v0.12 roof-pin qualification, NOT camera calibration. */
numeric digits 20
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
checks=0
s=.HarbourScene~new
p=.HarbourBridgeRoofPins~coordinates
f=.HarbourBridgeRoofPins~frame(s)
old=.HarbourBridgeAudit~userCoordinates
call check p['NW'][1]=-33.849759,'northwest latitude copied exactly'
call check p['NE'][2]=151.212276,'northeast longitude copied exactly'
call check p['SW'][2]=151.209068,'southwest longitude copied exactly'
call check p['SE'][1]=-33.854422,'southeast latitude copied exactly'
call check f['N_CROSS_M']>39 & f['N_CROSS_M']<41,'north pair approx 39.7 m'
call check f['S_CROSS_M']>39 & f['S_CROSS_M']<41,'south pair approx 40.1 m'
call check abs(f['N_CROSS_M']-f['S_CROSS_M'])<1,'pair separation agreement within 1 m'
call check f['W_LONG_M']>564 & f['W_LONG_M']<567,'western axis approx 565m'
call check f['E_LONG_M']>563 & f['E_LONG_M']<566,'eastern axis approx 564m'
call check abs(f['W_LONG_M']-f['E_LONG_M'])<2,'long edge agreement within 2m'
call check f['N_PAIR_AXIS_M']<5,'northern transverse pair almost orthogonal'
call check f['S_PAIR_AXIS_M']<5,'southern transverse pair almost orthogonal'
call check f['PARALLEL_DOT']>0.999,'northern and southern pair directions parallel'
call check abs(f['UX']*f['VX']+f['UY']*f['VY'])<0.00001,'orthogonal model frame'
call check f['STATUS']=='ROOF_PIN_LAYOUT_CONSISTENT_NOT_SURVEYED','consistent geometry not marked as surveyed'
call check .HarbourBridgeRoofPins~sourceClass=='GOOGLE_EARTH_USER_DROPPED_PIN_ON_VISIBLE_ROOF_NON_SURVEYED','photographic pin provenance preserved'
call check .HarbourBridgeRoofPins~screenshot('NW')=='1000066729.jpg','NW evidence image indexed'
call check .HarbourBridgeRoofPins~screenshot('SE')=='1000066732.jpg','SE evidence image indexed'
call check .HarbourBridgeRoofPins~cameraAdmission=='PROVISIONAL_PHOTO_FIT_ONLY_ROOF_PIN_SEMANTICS','camera use marked provisional'
oldS=s~local(old['SE'][1],old['SE'][2]);newS=s~local(p['SE'][1],p['SE'][2]);distance=HSqrt((oldS[1]-newS[1])**2+(oldS[2]-newS[2])**2)
call check distance>150,'Gemini SE coordinate differs from pinned roof by >150m'
count=s~boxes~items
f2=.HarbourBridgeRoofPins~apply(s)
call check s~boxes~items=count,'replace 4 old pylons and deck with 4 photographed pylon proxies and deck'
call check s~features['SE'][3]=89,'pylon-top height retained'
call check s~features['S_DECK'][3]=50,'deck altitude separate from tower top'
call check s~features['ARCH_CROWN'][3]=134,'arch crown distinct from pylon'
call check abs(s~features['S'][1]-f2['S_MID'][1])<0.00001,'southern midpoint updated'
call check abs(s~features['N'][2]-f2['N_MID'][2])<0.00001,'northern midpoint updated'
call check s~features~hasIndex('SE_ROOF_PIN'),'individual photographic feature tracked'
call check s~features~hasIndex('NW_ROOF_PIN'),'all four individually tracked'
call check .HarbourBridgeSemantics~structureKind('PYLON')=='DECORATIVE_MASONRY_TOWER_ABOVE_DECK','pylon identity kept distinct from arch/deck'
say 'ROOF PIN QUALIFICATION PASS ('checks' checks) STATUS=' f['STATUS']
say 'N/S transverse metres:' f['N_CROSS_M'] f['S_CROSS_M']
say 'W/E long metres:' f['W_LONG_M'] f['E_LONG_M']
say 'Gemini south-east distance to user visual roof pin:' distance
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
::requires 'SlamHarbourRoofPins.cls'