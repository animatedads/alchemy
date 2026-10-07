numeric digits 20
::requires '../rexx/SurveyBundle.cls'
spec=.XCoverCameraSpecifications~byId('XCOVERPRO')
main=.SurveyCamera~new('PAIR01_MAIN',.nil,1.60,60,1152,1536,spec,'MAIN')
ultra=.SurveyCamera~new('PAIR01_ULTRAWIDE',.nil,1.60,60,1152,1536,spec,'ULTRAWIDE')
rig=.SurveyCameraRig~new('XCOVERPRO_REAR','user measured 10 mm vertical module separation')
rig~addUnit(.SurveyCameraUnit~new('MAIN',spec),'0','0','0')
rig~addUnit(.SurveyCameraUnit~new('ULTRAWIDE',spec),'0','0.010','0')
station=.SurveyRigStation~new('PAIR01',rig,0,0,1.60,0,0,0)
station~placeCamera(main,'MAIN'); station~placeCamera(ultra,'ULTRAWIDE')
rayMain=.SurveyCameraGeometry~pixelRay(main,576,768)
rayUltra=.SurveyCameraGeometry~pixelRay(ultra,576,768)
say 'MAIN origin:' rayMain~origin~x rayMain~origin~y rayMain~origin~z
say 'ULTRAWIDE origin:' rayUltra~origin~x rayUltra~origin~y rayUltra~origin~z
say 'Both centre rays are parallel until calibration evidence says otherwise.'
