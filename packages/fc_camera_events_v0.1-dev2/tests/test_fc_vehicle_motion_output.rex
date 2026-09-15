say 'FC CAMERA EVENTS OUTPUT TEST START'
base='/tmp/fc_camera_events_output_test'
do suffix over .array~of('.camera_events.tsv','.events.tsv','.samples.tsv','.scene.tsv','.window.tsv','.reflections.tsv','.run.tsv')
  call SysFileDelete base || suffix
end
cfg=.FCVehicleMotionConfig~new
analysis=.FCVehicleMotionResult~new('/tmp/example.mp4','example.mp4',cfg)
analysis~setStatus('OK')
analysis~setCounts(100,13,12)
analysis~setTiming(9000,99000,1,90000,1000)

/* traffic/car event */
s=.array~new
m1=.FCRoadMotionSample~new(1,0,533,57000,4,80,28,8.0,14.0,7,13,9,15)
m2=.FCRoadMotionSample~new(2,533,1066,105000,5,105,31,10.2,14.1,9,13,12,15)
m1~setTrafficSlitEvidence(1,20); m2~setTrafficSlitEvidence(1,25)
s~append(m1); s~append(m2)
analysis~addActiveSample(m1); analysis~addActiveSample(m2)
e=.FCRoadMotionEpisode~new('FCM00001',s,cfg)
analysis~addEpisode(e)

/* stable open window interval */
ws=.array~new
do i=1 to 4
  sample=.FCSceneFrameSample~new(i,(i-1)*533,i*533,9000+i,100,50,0.50,'OPEN',0.90,4,0.05,0.20,.false)
  ws~append(sample)
  analysis~addSceneSample(sample)
end
analysis~addWindowInterval(.FCWindowStateInterval~new('FCW00001','OPEN',ws))

/* reflection event */
rs=.array~new
do i=5 to 7
  sample=.FCSceneFrameSample~new(i,(i-1)*533,i*533,9000+i,100,110,1.10,'CLOSED',0.85,18,0.45,0.95,.true)
  rs~append(sample)
  analysis~addSceneSample(sample)
end
analysis~addReflectionEvent(.FCRoomReflectionEpisode~new('FCR00001',rs))

paths=.FCVehicleMotionAnalyzer~writeOutputs(analysis,base)
call assertEqual 'seven output paths',7,paths~items

/* Returned order: unified, car, motion samples, scene, window, reflection, run. */
do i=1 to paths~items
  call assertTrue 'output exists ' || i,stream(paths[i],'C','QUERY EXISTS')\==''
end

csv=.CsvStream~new(paths[2],.false); csv~delimiter='09'x; csv~open('read')
header=csv~csvLineIn; row=csv~csvLineIn; csv~close
call assertEqual 'car event header width',24,header~items
call assertEqual 'car event row width',24,row~items
call assertEqual 'car event schema',.FCVehicleMotionVersion~EVENT_SCHEMA,row[1]
call assertEqual 'car class','CAR_MOTION',row[4]
call assertEqual 'file relative start','0',row[5]
call assertEqual 'file relative hms','00:00:00.000',row[6]

csv=.CsvStream~new(paths[4],.false); csv~delimiter='09'x; csv~open('read')
sceneHeader=csv~csvLineIn; sceneRow=csv~csvLineIn; csv~close
call assertEqual 'scene header width',16,sceneHeader~items
call assertEqual 'scene schema',.FCVehicleMotionVersion~SCENE_SCHEMA,sceneRow[1]
call assertEqual 'scene state','OPEN',sceneRow[11]

csv=.CsvStream~new(paths[5],.false); csv~delimiter='09'x; csv~open('read')
windowHeader=csv~csvLineIn; windowRow=csv~csvLineIn; csv~close
call assertEqual 'window header width',14,windowHeader~items
call assertEqual 'window schema',.FCVehicleMotionVersion~WINDOW_SCHEMA,windowRow[1]
call assertEqual 'window state','OPEN',windowRow[4]

csv=.CsvStream~new(paths[6],.false); csv~delimiter='09'x; csv~open('read')
reflectionHeader=csv~csvLineIn; reflectionRow=csv~csvLineIn; csv~close
call assertEqual 'reflection header width',15,reflectionHeader~items
call assertEqual 'reflection schema',.FCVehicleMotionVersion~REFLECTION_SCHEMA,reflectionRow[1]
call assertEqual 'reflection class','ROOM_REFLECTION_VISIBLE',reflectionRow[4]

csv=.CsvStream~new(paths[1],.false); csv~delimiter='09'x; csv~open('read')
cameraHeader=csv~csvLineIn
cameraRow1=csv~csvLineIn
cameraRow2=csv~csvLineIn
cameraRow3=csv~csvLineIn
csv~close
call assertEqual 'unified header width',16,cameraHeader~items
call assertEqual 'unified schema',.FCVehicleMotionVersion~CAMERA_EVENT_SCHEMA,cameraRow1[1]
call assertEqual 'unified starts at zero','0',cameraRow1[5]
call assertTrue 'unified contains traffic',cameraRow1[4]='TRAFFIC_MOTION' | cameraRow2[4]='TRAFFIC_MOTION' | cameraRow3[4]='TRAFFIC_MOTION'
call assertTrue 'unified contains window',cameraRow1[4]='WINDOW_OPEN' | cameraRow2[4]='WINDOW_OPEN' | cameraRow3[4]='WINDOW_OPEN'
call assertTrue 'unified contains reflection',cameraRow1[4]='ROOM_REFLECTION_VISIBLE' | cameraRow2[4]='ROOM_REFLECTION_VISIBLE' | cameraRow3[4]='ROOM_REFLECTION_VISIBLE'

say 'PASS FC camera events output assertions=29'
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
::requires 'csvStream.cls'
