tracker=.VisionNativeLineTracker~new(.VisionNativeLineTrackerConfig~new(4,2.5,4,10))
loop=.VisionNativeMotionLoop~new('cam-A',.VisionNativeCadencePolicy~new(30,1.6,.true),tracker,.VisionCameraProjectionHint~new(32,70),.VisionCameraMotionPolicy~new(3,360))

do f=0 to 2
  s=.VisionSurface~new(32,24,5,32)
  s~timestamp=f/30
  do y=2 to 21
    s~put(10+f,y,31); s~put(11+f,y,31)
  end
  r=loop~process(s,f)
  if f=0 then do
    if r~stepConstraint\==.nil then do; say 'FAIL first frame emitted constraint'; exit 1; end
  end
  else do
    if r~stepConstraint==.nil then do; say 'FAIL missing step constraint'; exit 1; end
    if r~stepConstraint~maxDistanceM>0.1000001 then do; say 'FAIL physical speed envelope'; exit 1; end
  end
end
say 'PASS native motion loop frame-to-frame'
::requires 'Vision3DNativeMotion.cls'
::requires 'Vision.cls'
