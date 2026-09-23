ev=.VisionFrameMotionEvidence~new('cam',1,1/30)
ev~addLineDelta(.VisionTrackedLineDelta~new('L1',2,0,0,1.08,1))
ev~addLineDelta(.VisionTrackedLineDelta~new('L2',5,0,0,1.10,1))
ev~addLineDelta(.VisionTrackedLineDelta~new('L3',9,0,0,1.09,1))
ev~addLineDelta(.VisionTrackedLineDelta~new('L4',3,0,0,1.07,1))
d=.VisionNativeMotionInterpreter~new~interpret(ev)
if d~expansion<=0 then do; say 'FAIL expansion'; exit 1; end
if d~parallaxSpreadPx<=0 then do; say 'FAIL parallax spread'; exit 1; end
if d~motionKind<>'FORWARD_WITH_PARALLAX' then do; say 'FAIL kind' d~motionKind; exit 1; end
say 'PASS native motion interpreter' d~motionKind d~expansion d~parallaxSpreadPx
::requires 'Vision3DNativeMotion.cls'
