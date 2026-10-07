numeric digits 20
spec=.XCoverCameraSpecifications~byId('XCOVERPRO')
rig=.SurveyCameraRig~new('XCOVERPRO_REAR','rear dual-camera rig; measured by user')
rig~addUnit(.SurveyCameraUnit~new('MAIN',spec,'main rear'),'0','0','0')
rig~addUnit(.SurveyCameraUnit~new('ULTRAWIDE',spec,'ultra-wide rear'),'0','0.010','0')
if abs(rig~baseline('MAIN','ULTRAWIDE')-0.010)>0.0000001 then do; say 'FAIL baseline'; exit 1; end
station=.SurveyRigStation~new('PAIR01',rig,10,5,1.60,0,0,0)
p1=station~cameraPosition('MAIN'); p2=station~cameraPosition('ULTRAWIDE')
if abs(p2~z-p1~z-0.010)>0.0000001 then do; say 'FAIL vertical placement'; exit 1; end
say 'PASS rigid camera rig 10 mm vertical baseline'
::requires '../rexx/PhotoObservation.cls'
