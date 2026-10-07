/* Same-location XCover Pro calibration pair supplied 2026-09-27.
   Both stored images: 1152 x 1536 portrait.
   User measurement: rear optical centres differ by 10 mm vertically.
   Which module is physically upper is not yet asserted, so the sign below is
   a coordinate convention for calibration and may be inverted without moving
   the survey station. */
numeric digits 20
::requires '../rexx/PhotoObservation.cls'

spec=.XCoverCameraSpecifications~byId('XCOVERPRO')
rig=.SurveyCameraRig~new('XCOVERPRO_REAR_PAIR','rig calibration pair; 10 mm measured vertical separation')
main=.SurveyCameraUnit~new('MAIN',spec,'25 MP main rear')
ultra=.SurveyCameraUnit~new('ULTRAWIDE',spec,'8 MP 123-degree ultra-wide rear')
rig~addUnit(main,0,0,0)
rig~addUnit(ultra,0,0.010,0)
station=.SurveyRigStation~new('PAIR_1000061224_1225',rig,0,0,1.60,0,0,0,'same photographer station')

cMain=.SurveyCamera~new('PAIR_MAIN',.nil,1.60,60,1152,1536,spec,'MAIN')
cUltra=.SurveyCamera~new('PAIR_ULTRA',.nil,1.61,60,1152,1536,spec,'ULTRAWIDE')
station~placeCamera(cMain,'MAIN'); station~placeCamera(cUltra,'ULTRAWIDE')

/* Assignment from visible FOV: 1224 is the wider image, 1225 the main image. */
pWide=.SurveyPhotoObservation~new('1000061224',1152,1536,cUltra,ultra,.nil,'1000061224.jpg','same-location calibration pair','0.95')
pMain=.SurveyPhotoObservation~new('1000061225',1152,1536,cMain,main,.nil,'1000061225.jpg','same-location calibration pair','0.95')

say 'station='station~id ' baseline_m='rig~baseline('MAIN','ULTRAWIDE')
say pWide~id pWide~camera~lensId 'z='pWide~camera~pose~position~z 'diagFov='pWide~lensSpecification~nominalFov
say pMain~id pMain~camera~lensId 'z='pMain~camera~pose~position~z 'diagFov='pMain~lensSpecification~nominalFov
