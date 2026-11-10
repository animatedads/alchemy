/* SLAM450 v0.2: non-linear, loop-closing visual learner.
 * Pilot knows only its onboard raster, indexed target shade, its own past
 * camera observations and an optional fixed-camera raster at steps 5,10,15...
 * All coordinates/course regions remain in simulator-owned ORACLE CSVs.
 */
numeric digits 16
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
parse arg prefix seed mode maxFrames policy windChoice windArchive
if prefix=='' then prefix='slam450_v2'
if seed=='' then seed=45042
if mode=='' then mode='LOOP'
if maxFrames=='' then maxFrames=900
if policy=='' then policy=prefix||'_steering.txt'
if windChoice=='' then windChoice='CALM'
windChoice=windChoice~upper
useWind=(windChoice=='WIND')
world=.Slam450World~new(seed,mode,useWind)
camera=.Slam450Camera~new(world)
mem=.Slam450VisualMemory~new(48)
fixedMem=.Slam450VisualMemory~new(20)
if windArchive=='' then windArchive=''
pilot=.Slam450LearningPilot~new(mem,policy,windArchive)
localizer=.Slam450PoseGuesser~new(world~scene)
fixed=.Slam450FixedCameraNetwork~new(world)
truth=prefix||'_truth_ORACLE_ONLY.csv'
course=prefix||'_course_ORACLE_ONLY.csv'
poseFile=prefix||'_estimated.csv'
feedFile=prefix||'_fixed_requests.csv'
memFile=prefix||'_visual_memory.csv'
windSensorsFile=prefix||'_wind_sensors.csv'
windIdeasFile=prefix||'_wind_ideas.csv'
windOracleFile=prefix||'_wind_ORACLE_ONLY.csv'
if useWind then do
  call lineout windSensorsFile,'step,flight_level,pitot_forward_mps,pitot_status,cup_airspeed_mps,sail'
  call lineout windIdeasFile,'step,flight_level,idea,confidence,gust_trend,visual_drift_evidence'
  call lineout windOracleFile,'step,flight_level,bearing_deg,gust_mps,east_mps,north_mps,min_mps,max_mps'
end
call lineout truth,'step,x_east_m,y_north_m,z_m,yaw_deg,active_target,status,range_to_target_m,step_displacement_m'
call lineout poseFile,'step,status,x_east_m,y_north_m,z_m,yaw_deg,visible_landmarks,bearing_rms_deg'
call lineout feedFile,'step,camera,result,reason,craft_in_frame,current_target_in_frame'
call lineout memFile,'step,active_target,recognition,source_step,source_tag,score,slots,steering_response,steering_updates'
call lineout course,'target,region,x_east_m,y_north_m,z_m,shade,side_m,model_version'
say 'SLAM450_V2 START' mode seed 'MODEL_POWER_SLAM_V0.40'
do i=1 to 5
  target=world~targets[i]
  call lineout course,i||','||world~courseAreas[i]||','||target[1]||','||target[2]||','||target[3]||','||i||',2,0.40'
  say 'ORACLE TARGET' i world~courseAreas[i] 'XYZ' target[1] target[2] target[3]
end
views=fixed~views;feedIndex=0;prior=.nil
lastTarget=1
frameNumber=0
do frameNumber=0 to maxFrames-1
  if world~status\=='RUNNING' then leave
  frame=camera~render(720,181)
  if frameNumber=0 then camera~writePPM(frame,prefix||'_start.ppm')
  if frameNumber//25=0 then do
    est=localizer~guess(frame,prior)
    if est['STATUS']=='IMAGE_BEARING_ESTIMATE' then do
      prior=est
      call lineout poseFile,frameNumber||',IMAGE_BEARING_ESTIMATE,'||est['X']||','||est['Y']||','||est['Z']||','||est['YAW']||','||est['VISIBLE']||','||est['BEARING_RMS_DEG']
    end
    else call lineout poseFile,frameNumber||','||est['STATUS']||',,,,,,'||est['VISIBLE']||','
  end
  if world~steps>0 & world~steps//5=0 then do
    feedIndex+=1
    cameraID=views[1+((feedIndex-1)//views~items)]
    answer=fixed~request(cameraID)
    if answer['STATUS']=='GRANTED' then do
      img=answer['FRAME']
      v=(.Slam450Vision~new)~observe(img,'V')
      t=(.Slam450Vision~new)~observe(img,world~active)
      seenV=0;seenT=0
      if v\==.nil then seenV=1
      if t\==.nil then seenT=1
      ignoredMemory=fixedMem~ingest(img,world~steps,cameraID,'FIXED_CAMERA_IMAGE')
      /* Fixed image contributes to the learner's observation record only.
       * It is not an oracle to the aircraft's 3D location. */
      ignored=pilot~consultFixedCamera(cameraID,img,world~active)
      call lineout feedFile,world~steps||','||cameraID||',GRANTED,ONE_FIXED_PANORAMA,'||seenV||','||seenT
    end
    else call lineout feedFile,world~steps||','||cameraID||',DENIED,'||answer['REASON']||',,'
  end
  active=world~active
  command=pilot~control(frame,active)
  last=mem~lastMatch
  if frameNumber//5=0 | active\==lastTarget then do
    call lineout memFile,world~steps||','||active||','||last['STATUS']||','||last['MATCH_STEP']||','||last['MATCH_TAG']||','||last['SCORE']||','||mem~slots~items||','||pilot~learnedYawResponse||','||pilot~responseUpdates
  end
  start=world~pose
  side=0
  if command~items>=4 then side=command[4]
  flightStatus=world~step(command[1],command[2],command[3],side)
  if useWind & flightStatus\=='COLLISION' then do
    packet=world~lastSensorPacket
    idea=pilot~ingestWind(world~steps,packet,pilot~lastVisualEvidence)
    hidden=world~lastWindTruth
    call lineout windSensorsFile,world~steps||','||packet['FLIGHT_LEVEL']||','||packet['PITOT_FORWARD_MPS']||','||packet['PITOT_STATUS']||','||packet['CUP_AIRSPEED_MPS']||','||packet['SAIL']
    call lineout windIdeasFile,world~steps||','||idea['LEVEL']||','||idea['IDEA']||','||idea['CONFIDENCE']||','||idea['GUST_TREND']||','||idea['VISUAL_DRIFT_EVIDENCE']
    call lineout windOracleFile,world~steps||','||hidden['LEVEL']||','||hidden['BEARING_DEG']||','||hidden['GUST_MPS']||','||hidden['EAST_MPS']||','||hidden['NORTH_MPS']||','||hidden['MIN_MPS']||','||hidden['MAX_MPS']
  end
  if world~active>active then do
    pinned=mem~pinFrame(frame,world~steps,active)
    say 'VISUAL MEMORY PINNED STAGE' active 'STEP' world~steps
  end
  finish=world~pose
  delta=world~distance(start,finish)
  range=0
  if world~active<=5 then range=world~distance(finish,world~targets[world~active])
  call lineout truth,world~steps||','||finish[1]||','||finish[2]||','||finish[3]||','||finish[4]||','||world~active||','||flightStatus||','||range||','||delta
  lastTarget=world~active
  if flightStatus\=='RUNNING' then leave
end
camera~writePPM(camera~render(720,181),prefix||'_end.ppm')
/* Persist limited image-only milestone descriptors; NO real XYZ here. */
pinFile=prefix||'_pinned_image_signatures.csv'
numberPinned=mem~savePinned(pinFile)
if useWind then savedWind=pilot~windMemory~saveObservations(prefix||'_wind_memory_bounded.csv')
if mem~pins~hasIndex('T1') & mem~pins~hasIndex('T5') then do
  score=mem~similarity(mem~pins['T1']['SIGNATURE'],mem~pins['T5']['SIGNATURE'])
  say 'LOOP_VISUAL_REVISIT T1_vs_T5 angular_score' score '(not XYZ proof)'
end
previous=pilot~savePolicy(policy)
if useWind then do
  do out over .array~of(windSensorsFile,windIdeasFile,windOracleFile)
    call stream out,'C','CLOSE'
  end
end
do out over .array~of(truth,course,poseFile,feedFile,memFile)
  call stream out,'C','CLOSE'
end
say 'SLAM450_V2 RESULT' world~status 'TARGET' world~active 'STEPS' world~steps 'FEEDS' fixed~grantCount 'MEMORY' mem~slots~items 'REVISITS' mem~revisits 'YAW_EST' pilot~learnedYawResponse 'UPDATES' pilot~responseUpdates 'HIT' world~lastHit 'WIND' windChoice
if world~status=='COMPLETE' then exit 0
if world~status=='COLLISION' then exit 4
exit 5
::requires 'Slam450Learning.cls'
