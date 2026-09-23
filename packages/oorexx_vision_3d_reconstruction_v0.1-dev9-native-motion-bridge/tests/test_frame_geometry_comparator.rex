a=.VisionFrameGeometry~new(0)
b=.VisionFrameGeometry~new(1/30)
a~addItem(.VisionTrackedImageItem~new('shoe',10,20,.9))
b~addItem(.VisionTrackedImageItem~new('shoe',12,23,.9))
a~addLine(.VisionTrackedImageLine~new('wall',0,10,20,10,0,1))
b~addLine(.VisionTrackedImageLine~new('wall',1,11,23,11,0,1))
ev=.VisionFrameGeometryComparator~new~compare(a,b,'cam',1)
if ev~motionVectors~items<>1 then do; say 'FAIL item vector'; exit 1; end
if ev~lineDeltas~items<>1 then do; say 'FAIL line delta'; exit 1; end
if ev~motionVectors[1]~dx<>2 | ev~motionVectors[1]~dy<>3 then do; say 'FAIL displacement'; exit 1; end
if ev~lineDeltas[1]~lengthRatio<=1 then do; say 'FAIL line scale'; exit 1; end
say 'PASS native frame geometry comparator'
::requires 'Vision3DCameraPath.cls'
