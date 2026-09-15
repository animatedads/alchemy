say 'FC CAMERA EVENTS LOGIC TEST START'
cfg=.FCVehicleMotionConfig~new(32,18,8,10,2,24,1350,2,450,18000,1.25,1.0,0.55)

/* Synthetic left-to-right car-like episode. */
s=.array~new
m=.FCRoadMotionSample~new(1,0,533,100,4,80,28,8.0,14.0,7,13,9,15); m~setTrafficSlitEvidence(1,20); s~append(m)
m=.FCRoadMotionSample~new(2,533,1066,108,5,105,31,10.2,14.1,9,13,12,15); m~setTrafficSlitEvidence(1,25); s~append(m)
m=.FCRoadMotionSample~new(3,1066,1599,116,4,92,29,12.8,14.1,11,13,14,15); m~setTrafficSlitEvidence(1,22); s~append(m)
e=.FCRoadMotionEpisode~new('FCM00001',s,cfg)
call assertTrue 'moving episode admitted',e~admitted
call assertEqual 'moving classification','CAR_MOTION',e~classification
call assertEqual 'direction','LEFT_TO_RIGHT',e~direction
call assertEqual 'start from prior sample',0,e~startMs
call assertEqual 'end from current sample',1599,e~endMs
call assertTrue 'confidence threshold',e~confidence>=0.55

/* Static/flicker evidence must not become a car. */
s2=.array~new
s2~append(.FCRoadMotionSample~new(1,0,533,100,3,60,22,10.0,14.0,10,14,10,14))
s2~append(.FCRoadMotionSample~new(2,533,1066,108,3,62,23,10.1,14.0,10,14,10,14))
e2=.FCRoadMotionEpisode~new('FCM00002',s2,cfg)
call assertTrue 'static episode rejected',\e2~admitted
call assertEqual 'static classification','ROAD_MOTION_UNCERTAIN',e2~classification

/* Synthetic right-to-left episode qualifies independently. */
s3=.array~new
m=.FCRoadMotionSample~new(1,0,533,100,4,80,28,15.0,14.0,13,13,16,15); m~setTrafficSlitEvidence(1,20); s3~append(m)
m=.FCRoadMotionSample~new(2,533,1066,108,5,105,31,12.5,14.1,11,13,14,15); m~setTrafficSlitEvidence(1,25); s3~append(m)
m=.FCRoadMotionSample~new(3,1066,1599,116,4,92,29,9.5,14.1,8,13,11,15); m~setTrafficSlitEvidence(1,22); s3~append(m)
e3=.FCRoadMotionEpisode~new('FCM00003',s3,cfg)
call assertTrue 'reverse moving episode admitted',e3~admitted
call assertEqual 'reverse direction','RIGHT_TO_LEFT',e3~direction

/* Time formatter is file-relative presentation only. */
call assertEqual 'zero time','00:00:00.000',.FCVehicleMotionAnalyzer~formatTimeMs(0)
call assertEqual 'minute time','00:01:02.345',.FCVehicleMotionAnalyzer~formatTimeMs(62345)
call assertEqual 'hour time','01:01:01.007',.FCVehicleMotionAnalyzer~formatTimeMs(3661007)
call assertEqual 'sample end time','00:28:11.927',.FCVehicleMotionAnalyzer~formatTimeMs(1691926.8)

/* FC masks: both legacy road and user-marked red traffic slit are active. */
call assertTrue 'road cell accepted',cfg~roadCell(16,14)
call assertTrue 'traffic slit accepted',cfg~trafficSlitCell(18,11)
call assertTrue 'traffic slit contributes to road',cfg~roadCell(18,11)
call assertTrue 'upper tree rejected',\cfg~roadCell(4,12)
call assertTrue 'far right rejected',\cfg~roadCell(30,15)

/* Window / reflection state is assessed from scene evidence, not wall-clock. */
analyzer=.FCVehicleMotionAnalyzer~new('/tmp/not-opened.mp4',cfg)

openGrid=.array~new
do i=1 to cfg~gridColumns*cfg~gridRows
  openGrid~append(100)
end
do r=1 to cfg~gridRows
  do c=1 to cfg~gridColumns
    if cfg~windowProbeCell(c,r) then openGrid[((r-1)*cfg~gridColumns)+c]=45
  end
end
openSample=analyzer~assessSceneSamples(openGrid,1,0,533,100)
call assertEqual 'open window state','OPEN',openSample~windowState
call assertTrue 'open window confidence',openSample~windowConfidence>=0.70
call assertTrue 'open cannot be reflection',\openSample~reflectionPresent

closedPlain=.array~new
do i=1 to cfg~gridColumns*cfg~gridRows
  closedPlain~append(100)
end
do r=1 to cfg~gridRows
  do c=1 to cfg~gridColumns
    if cfg~windowProbeCell(c,r) then closedPlain[((r-1)*cfg~gridColumns)+c]=125
  end
end
closedPlainSample=analyzer~assessSceneSamples(closedPlain,2,533,1066,108)
call assertEqual 'closed plain state','CLOSED',closedPlainSample~windowState
call assertTrue 'closed plain no reflection',\closedPlainSample~reflectionPresent

closedReflect=.array~new
do i=1 to cfg~gridColumns*cfg~gridRows
  closedReflect~append(100)
end
do r=1 to cfg~gridRows
  do c=1 to cfg~gridColumns
    idx=((r-1)*cfg~gridColumns)+c
    if cfg~reflectionCell(c,r) then do
      if ((c+r)//2)=0 then closedReflect[idx]=70
      else closedReflect[idx]=135
    end
  end
end
do r=1 to cfg~gridRows
  do c=1 to cfg~gridColumns
    if cfg~windowProbeCell(c,r) then closedReflect[((r-1)*cfg~gridColumns)+c]=145
  end
end
closedReflectSample=analyzer~assessSceneSamples(closedReflect,3,1066,1599,116)
call assertEqual 'closed reflected state','CLOSED',closedReflectSample~windowState
call assertTrue 'closed reflection admitted',closedReflectSample~reflectionPresent
call assertTrue 'reflection confidence',closedReflectSample~reflectionScore>=cfg~reflectionMinimumConfidence

say 'PASS FC camera events logic assertions=25'
exit 0

assertEqual: procedure
  use arg label,expected,actual
  if expected == actual then return
  say 'ASSERT FAILED:' label
  say ' expected:' expected
  say ' actual:  ' actual
  exit 1

assertTrue: procedure
  use arg label,actual
  if actual then return
  say 'ASSERT FAILED:' label
  exit 1

::requires 'FCVehicleMotion.cls'
