/* dev8 example: native-frame pose-cloud propagation.
 * The geometry below is synthetic qualification geometry, not the user's flat.
 */
floor=.VisionAccessibleFloor~new
floor~addRegion(.VisionFloorPolygon~new('demo',.array~of(.array~of(0,0),.array~of(2,0),.array~of(2,5),.array~of(0,5))))
solver=.VisionPoseCloudSolver~new
seed=.array~of(.VisionCameraPoseCandidate~new('camera-A',0,0,1,.5,90,1,'demo-seed'))
cloud=solver~seedFromPoses('camera-A',0,0,seed)
config=.VisionPoseCloudConfig~new(3,3,3,80)
policy=.VisionCameraMotionPolicy~new(3,360)

do frame=1 to 30
  timestamp=frame/30
  /* Example evidence envelope: about 1.5 m/s forward with small heading noise. */
  step=.VisionCameraStepConstraint~new('camera-A',frame,timestamp,.03,.07,.05,-2,2,0,-6,6,0,.9,'synthetic-native-motion')
  cloud=solver~propagate(cloud,step,floor,policy,config)
  say frame cloud~items cloud~best~pose~x cloud~best~pose~y cloud~best~pose~headingDeg
  if cloud~items=0 then leave
end

::requires 'Vision3DPoseCloud.cls'
