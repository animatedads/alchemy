/* Contract example. Real frame evidence comes from the V5V/Vision motion
 * extractor.  The path solver consumes native timestamps; it does not assume
 * a resampled 5 fps timeline. */
policy=.VisionCameraMotionPolicy~new(3,360)
path=.VisionCameraPathHypothesis~new('bodycam-A')
floor=.VisionAccessibleFloor~new
floor~addRegion(.VisionFloorPolygon~new('accessible',.array~of(.array~of(0,0),.array~of(2,0),.array~of(2,5),.array~of(0,5))))

dt=1/30
path~append(.VisionCameraPoseCandidate~new('bodycam-A',0,0,1,0.5,0),floor,policy)
path~append(.VisionCameraPoseCandidate~new('bodycam-A',1,dt,1,0.57,2),floor,policy)
path~append(.VisionCameraPoseCandidate~new('bodycam-A',2,2*dt,1,0.64,4),floor,policy)
say 'poses:' path~poses~items 'valid:' path~valid 'findings:' path~findings~items
::requires 'Vision3DCameraPath.cls'
