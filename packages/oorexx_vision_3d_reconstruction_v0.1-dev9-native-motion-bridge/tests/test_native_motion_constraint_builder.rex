ev=.VisionFrameMotionEvidence~new('cam',1,1/30,4,0,0,0,.9)
d=.VisionNativeMotionDescriptor~new(4,0,0,.05,2,8,.9,'FORWARD_WITH_PARALLAX')
proj=.VisionCameraProjectionHint~new(100,70)
c=.VisionNativeMotionConstraintBuilder~new~build(ev,d,0,proj,.VisionCameraMotionPolicy~new(3,360))
if c~maxDistanceM>0.1000001 then do; say 'FAIL speed-derived max distance' c~maxDistanceM; exit 1; end
if c~minTurnDeg< -12.000001 | c~maxTurnDeg>12.000001 then do; say 'FAIL angular envelope' c~minTurnDeg c~maxTurnDeg; exit 1; end
if c~minBearingOffsetDeg<>-40 | c~maxBearingOffsetDeg<>40 then do; say 'FAIL forward bearing envelope'; exit 1; end
say 'PASS native motion constraint builder maxD=' c~maxDistanceM 'turn=' c~minTurnDeg c~maxTurnDeg
::requires 'Vision3DNativeMotion.cls'
