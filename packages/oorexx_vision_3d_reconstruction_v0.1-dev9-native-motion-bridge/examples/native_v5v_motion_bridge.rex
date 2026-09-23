/* Minimal dev9 example: every source frame participates in the motion loop.
 * A real source supplies VisionSurface objects at its native timestamps.
 */
tracker=.VisionNativeLineTracker~new(.VisionNativeLineTrackerConfig~new(5,2.5,3,4))
loop=.VisionNativeMotionLoop~new('camera-A',.VisionNativeCadencePolicy~new(30,1.6,.true),tracker)

do f=0 to 5
  s=.VisionSurface~new(55,98,5,32)
  s~timestamp=f/30
  /* synthetic moving structural band; qualification only */
  do y=15 to 80
    s~put(20+f,y,31)
  end
  result=loop~process(s,f)
  if result~stepConstraint\==.nil then say f result~descriptor~motionKind result~stepConstraint~maxDistanceM
end
::requires 'Vision3DNativeMotion.cls'
::requires 'Vision.cls'
