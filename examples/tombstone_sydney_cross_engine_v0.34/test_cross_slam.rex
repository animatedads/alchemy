/* Native ooRexx 5.3.0 r13196: cross-engine source evidence qualification. */
numeric digits 18
checks=0
r=.CrossSlamEvidence~new
call check r~register('MASK','RASTER_SEGMENTATION','97ff5a02e63f6a9b72b44cd3e13d4a879f60d56bd3be38f07b11162ef6008d6b',458,336,'SCREEN_RASTER_UNREGISTERED','CLASS_SEMANTICS_UNVERIFIED'),'mask preserved'
call check r~register('MOSAIC','SATELLITE_TILE_MOSAIC','36712bffa18f620c2aff1513e3aa1b2641bf901f43bf6406bf4ba08ad13ff521',1200,814,'COMPOSITE_SCREEN_UNREGISTERED','TILE_GEOTRANSFORMS_MISSING'),'tile mosaic preserved'
call check r~register('NORTH','MODEL_360_PANORAMA','a257e0b1784d24dade0d42c9c7e9010e5240388ec3b037db6f7adc72354de477',2048,512,'MODEL_BEARING_CANVAS','CAMERA_POSE_HYPOTHESIS'),'north 360 prototype registered'
call check r~register('CAFE','MODEL_360_PANORAMA','b779bebb0d1372e1fef7d83c4390f709a6da3c99330309ce3cfb5d02095fb602',2048,512,'MODEL_BEARING_CANVAS','CAMERA_POSE_HYPOTHESIS'),'Cafe 360 prototype registered'
call check r~register('V5V_CAM3','V5V_VIDEO','c3bea629be6f054bafe08d50d03e259f894a97ddeae089dd69d77da0985cae7e',80,45,'V5V_IMAGE_LATTICE_80x45','OBSERVED_UNTESTED'),'actual V5V indexed source registered'
call check r~sources~items=5,'five distinct typed source identities'
p=r~imagePoint('MASK',144,200)
call check p['X']=144 & p['WORLD']='BLOCKED_NO_REGISTRATION','mask screen pixel cannot be geolocated'
q=r~imagePoint('MOSAIC',1000,500)
call check q['COORD']='COMPOSITE_SCREEN_UNREGISTERED','satellite screenshot not a geotransform'
a=r~imageBox('MOSAIC',100,200,400,500)
b=r~imageBox('MOSAIC',300,400,600,600)
call check r~screenOverlap('MOSAIC',a,b)=10000,'tile display screen overlap valid'
call check .CrossSlamEvidence~circularSeparation(358,2)=4,'360-degree seam has 4-degree gap'
call check .CrossSlamEvidence~circularSeparation(4,356)=8,'reverse seam has 8-degree gap'
call check .CrossSlamEvidence~circularSeparation(180,0)=180,'opposite bearings remain opposite'
call check .CrossSlamEvidence~bearingSectorContains(350,10,0),'wrapped bearing interval admits zero'
call check .CrossSlamEvidence~bearingSectorContains(350,10,355),'wrapped bearing interval admits right side'
call check \.CrossSlamEvidence~bearingSectorContains(350,10,90),'wrapped sector does not admit 90'
call check .CrossSlamEvidence~bearingSectorContains(45,60,52),'ordinary bearing sector still works'
label=r~panoramaObservation('CAFE',355)
call check label['CAMERA_RAY']='BLOCKED_UNSURVEYED_POSE','Café plot model label not surveyed viewing ray'
label=r~panoramaObservation('NORTH',210)
call check label['STATE']='ILLUSTRATIVE_MODEL_HYPOTHESIS','79m model plot remains hypothetical'
call check r~sourceToWorld('MOSAIC','V5V_CAM3')='BLOCKED_NO_QUALIFIED_TRANSFORM','satellite-mosaic-to-camera world blocked'
call check r~sourceToWorld('NORTH','V5V_CAM3')='BLOCKED_NO_QUALIFIED_TRANSFORM','north PTZ 3D rendering not camera registration'
call check r~sourceToWorld('CAFE','V5V_CAM3')='BLOCKED_NO_QUALIFIED_TRANSFORM','same venue does not certify same optical centre'
l=r~linkCandidate('V5V_CAM3','CAFE','OBSERVED_UNTESTED')
call check l['IDENTITY']='UNVERIFIED' & l['WORLD']='BLOCKED_NO_QUALIFIED_TRANSFORM','cross-engine hypothesis cannot acquire verified ferry identity'
say 'CROSS SLAM INTEGRATION TEST PASS' checks 'checks.'
say 'SOURCE_COORD_SPACES=5; ALL_REAL_WORLD_GEOMETRY=BLOCKED; WORLD_FERRY=UNVERIFIED'
exit 0
check: procedure expose checks
 use strict arg ok,label
 if \ok then do
  say 'FAIL' label
  exit 9
 end
 checks=checks+1
 return
::requires 'CrossSlamEvidence.cls'
