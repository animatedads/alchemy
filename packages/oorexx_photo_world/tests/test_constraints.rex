numeric digits 20
spec=.XCoverCameraSpecifications~byId('XCOVERPRO')
rig=.SurveyCameraRig~new('XCOVERPRO_REAR')
rig~addUnit(.SurveyCameraUnit~new('MAIN',spec),'0','0','0')
rig~addUnit(.SurveyCameraUnit~new('ULTRAWIDE',spec),'0','0.010','0')
station=.SurveyRigStation~new('PAIR01',rig,0,0,1.60)
cs=.SurveyConstraintSet~new
cs~add(.SurveySameStationConstraint~new('PAIR01_BASELINE',station,'MAIN','ULTRAWIDE','0.010'))
if cs~weightedRms>0.0000001 then do; say 'FAIL constraint RMS' cs~weightedRms; exit 1; end
say 'PASS explicit rigid-station constraint'
::requires '../rexx/SurveyConstraints.cls'
