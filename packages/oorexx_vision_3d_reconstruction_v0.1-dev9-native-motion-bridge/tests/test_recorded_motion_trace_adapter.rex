row=.directory~new
row['frame_index']=1; row['timestamp']=1/30; row['dt']=1/30
row['dx']=1.5; row['dy']=0.2; row['rotation_deg']=0.3; row['scale']=1.04
row['flow_spread']=.8; row['confidence']=.9
c=.VisionRecordedMotionTraceAdapter~new~constraintFromRow('A',row,.nil,.VisionCameraMotionPolicy~new(3,360))
if c~frameIndex<>1 then do; say 'FAIL frame index'; exit 1; end
if c~maxDistanceM>0.1000001 then do; say 'FAIL speed ceiling'; exit 1; end
if pos('FORWARD_WITH_PARALLAX',c~evidence)=0 then do; say 'FAIL classification' c~evidence; exit 1; end
say 'PASS recorded motion trace adapter'
::requires 'Vision3DNativeMotion.cls'
