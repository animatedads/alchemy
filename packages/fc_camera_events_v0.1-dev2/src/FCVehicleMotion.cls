/*
 * FCVehicleMotion.cls
 * FC fixed-camera road-motion event analysis for ooRexx.
 *
 * Timing authority is the media file itself.  All public event times are
 * normalized decoded-video PTS offsets from the first decoded video frame.
 * No filename timestamp, wall clock, cross-file edge map or audio correction
 * is used to manufacture event time.
 *
 * The decoder boundary and photometric normalization follow the direct
 * Foreign Runtime / FFmpeg approach established by Camera Behaviour v0.56.
 */

::class FCVehicleMotionVersion public
::constant VERSION '0.1-dev2'
::constant EVENT_SCHEMA 'FC_CAR_MOTION_EVENT_V1'
::constant SAMPLE_SCHEMA 'FC_ROAD_MOTION_SAMPLE_V1'
::constant SCENE_SCHEMA 'FC_CAMERA_SCENE_SAMPLE_V1'
::constant WINDOW_SCHEMA 'FC_WINDOW_STATE_INTERVAL_V1'
::constant REFLECTION_SCHEMA 'FC_ROOM_REFLECTION_EVENT_V1'
::constant CAMERA_EVENT_SCHEMA 'FC_CAMERA_EVENT_V1'
::constant RUN_SCHEMA 'FC_CAMERA_RUN_V2'


::class FCVehicleMotionConfig public
::attribute gridColumns get
::attribute gridRows get
::attribute sampleEveryFrames get
::attribute changeThreshold get
::attribute minimumChangedCells get
::attribute minimumSampleScore get
::attribute maximumGapMs get
::attribute minimumEventSamples get
::attribute minimumEventDurationMs get
::attribute maximumEventDurationMs get
::attribute minimumHorizontalSpan get
::attribute minimumPathLength get
::attribute minimumConfidence get
::attribute windowOpenRatioMaximum get
::attribute windowClosedRatioMinimum get
::attribute windowPersistenceSamples get
::attribute reflectionEdgeThreshold get
::attribute reflectionMinimumEdgeMean get
::attribute reflectionMinimumEdgeFraction get
::attribute reflectionMinimumConfidence get
::attribute reflectionPersistenceSamples get

::method init
  expose gridColumns gridRows sampleEveryFrames changeThreshold minimumChangedCells minimumSampleScore maximumGapMs minimumEventSamples minimumEventDurationMs maximumEventDurationMs minimumHorizontalSpan minimumPathLength minimumConfidence windowOpenRatioMaximum windowClosedRatioMinimum windowPersistenceSamples reflectionEdgeThreshold reflectionMinimumEdgeMean reflectionMinimumEdgeFraction reflectionMinimumConfidence reflectionPersistenceSamples
  use arg columns,rows,sampleEvery,threshold,minCells,minScore,maxGap,minSamples,minDuration,maxDuration,minHorizontal,minPath,minConfidence
  if arg(1,'O') then columns = 32
  if arg(2,'O') then rows = 18
  if arg(3,'O') then sampleEvery = 8
  if arg(4,'O') then threshold = 10
  if arg(5,'O') then minCells = 2
  if arg(6,'O') then minScore = 24
  if arg(7,'O') then maxGap = 1350
  if arg(8,'O') then minSamples = 2
  if arg(9,'O') then minDuration = 450
  if arg(10,'O') then maxDuration = 18000
  if arg(11,'O') then minHorizontal = 1.25
  if arg(12,'O') then minPath = 1.0
  if arg(13,'O') then minConfidence = 0.55

  if columns < 8 then columns = 8
  if rows < 6 then rows = 6
  if sampleEvery < 1 then sampleEvery = 1
  if threshold < 1 then threshold = 1
  if minCells < 1 then minCells = 1
  if minScore < 0 then minScore = 0
  if maxGap < 0 then maxGap = 0
  if minSamples < 1 then minSamples = 1
  if minDuration < 0 then minDuration = 0
  if maxDuration < minDuration then maxDuration = minDuration
  if minHorizontal < 0 then minHorizontal = 0
  if minPath < 0 then minPath = 0
  if minConfidence < 0 then minConfidence = 0
  if minConfidence > 1 then minConfidence = 1

  gridColumns = columns
  gridRows = rows
  sampleEveryFrames = sampleEvery
  changeThreshold = threshold
  minimumChangedCells = minCells
  minimumSampleScore = minScore
  maximumGapMs = maxGap
  minimumEventSamples = minSamples
  minimumEventDurationMs = minDuration
  maximumEventDurationMs = maxDuration
  minimumHorizontalSpan = minHorizontal
  minimumPathLength = minPath
  minimumConfidence = minConfidence

  /* FC physical-state probes.  These are deliberately conservative and are
     evaluated independently from traffic motion. */
  windowOpenRatioMaximum = 0.78
  windowClosedRatioMinimum = 0.88
  windowPersistenceSamples = 4
  reflectionEdgeThreshold = 12
  reflectionMinimumEdgeMean = 10
  reflectionMinimumEdgeFraction = 0.25
  reflectionMinimumConfidence = 0.70
  reflectionPersistenceSamples = 3

::method trafficSlitCell
  /* User-annotated FC traffic sight line (2023-10-10 framing).  The camera
     moved between recordings, so this slit supplements rather than replaces
     the later lower-road mask below. */
  use arg column,row
  x = (column - 0.5) / self~gridColumns
  y = (row - 0.5) / self~gridRows
  if x < 0.08 | x > 0.64 then return .false
  centreY = 1.017 - (0.777 * x)
  if abs(y - centreY) <= 0.065 then return .true
  return .false

::method windowProbeCell
  /* User-annotated blue diagonal window-state strip.  The useful state
     evidence is immediately inside that edge: OPEN exposes the dark interior
     gap, while CLOSED exposes the glass / reflected scene.  The +0.055
     normalized shift was checked against the supplied open-day and
     closed-night reference images. */
  use arg column,row
  x = (column - 0.5) / self~gridColumns
  y = (row - 0.5) / self~gridRows
  if y < 0.50 | y > 0.97 then return .false
  centreX = 1.186 - (0.357 * y)
  if abs(x - centreX) <= 0.045 then return .true
  return .false

::method reflectionCell
  /* Upper exterior/glass field.  Outdoors this is largely low-texture sky;
     with the window closed at night the room reflection creates persistent
     structure here.  Exclude the FC OSD in the upper-left. */
  use arg column,row
  x = (column - 0.5) / self~gridColumns
  y = (row - 0.5) / self~gridRows
  if x < 0.05 | x > 0.80 | y < 0.03 | y > 0.42 then return .false
  if x < 0.34 & y < 0.14 then return .false
  return .true

::method roadCell
  /* FC Front Castle camera: fixed road corridor only.  Coordinates are in
     normalized grid space so 32x18 is the default, not a hard pixel crop.

     The mask intentionally excludes the upper-left tree canopy and the
     far-right balcony/column.  It retains the roadway visible through the
     railings, because moving vehicles remain photometrically observable there.
  */
  use arg column,row
  c = (column - 0.5) / self~gridColumns
  r = (row - 0.5) / self~gridRows
  if self~trafficSlitCell(column,row) then return .true
  if r < 0.615 | r > 0.955 then return .false
  if c < 0.0 | c > 0.665 then return .false
  /* upper-left canopy exclusion */
  if r < 0.735 & c < 0.305 then return .false
  /* narrowing upper road edge toward the right */
  if r < 0.68 & c > 0.50 then return .false
  return .true

::method compactText
  return 'FCMC1|G=' || self~gridColumns || 'x' || self~gridRows || '|STEP=' || self~sampleEveryFrames || '|TH=' || self~changeThreshold || '|MINCELLS=' || self~minimumChangedCells || '|MINSCORE=' || self~minimumSampleScore || '|GAPMS=' || self~maximumGapMs || '|MINSAMPLES=' || self~minimumEventSamples || '|DUR=' || self~minimumEventDurationMs || '-' || self~maximumEventDurationMs || '|HSPAN=' || self~minimumHorizontalSpan || '|PATH=' || self~minimumPathLength || '|CONF=' || self~minimumConfidence || '|WOPEN=' || self~windowOpenRatioMaximum || '|WCLOSED=' || self~windowClosedRatioMinimum || '|WPERSIST=' || self~windowPersistenceSamples || '|REFDELTA=' || self~reflectionEdgeThreshold || '|REFMEAN=' || self~reflectionMinimumEdgeMean || '|REFFRAC=' || self~reflectionMinimumEdgeFraction || '|REFCONF=' || self~reflectionMinimumConfidence


::class FCRoadMotionSample public
::attribute comparisonIndex get
::attribute previousMs get
::attribute timeMs get
::attribute pts get
::attribute changedCells get
::attribute score get
::attribute maximumDelta get
::attribute centroidX get
::attribute centroidY get
::attribute left get
::attribute top get
::attribute right get
::attribute bottom get
::attribute trafficSlitChangedCells get
::attribute trafficSlitScore get

::method init
  expose comparisonIndex previousMs timeMs pts changedCells score maximumDelta centroidX centroidY left top right bottom trafficSlitChangedCells trafficSlitScore
  use arg sampleIndex,priorMs,currentMs,framePts,count,totalScore,maxDelta,cx,cy,x1,y1,x2,y2
  comparisonIndex = sampleIndex
  previousMs = priorMs
  timeMs = currentMs
  pts = framePts
  changedCells = count
  score = totalScore
  maximumDelta = maxDelta
  centroidX = cx
  centroidY = cy
  left = x1
  top = y1
  right = x2
  bottom = y2
  trafficSlitChangedCells = 0
  trafficSlitScore = 0

::method setTrafficSlitEvidence
  expose trafficSlitChangedCells trafficSlitScore
  use arg count,totalScore
  trafficSlitChangedCells = count
  trafficSlitScore = totalScore

::method compactText
  return self~comparisonIndex || ':' || self~previousMs || '-' || self~timeMs || ':' || self~changedCells || ':' || self~score || ':' || self~maximumDelta || ':' || self~centroidX || ',' || self~centroidY || ':' || self~left || ',' || self~top || '-' || self~right || ',' || self~bottom || ':SLIT=' || self~trafficSlitChangedCells || '/' || self~trafficSlitScore


::class FCRoadMotionEpisode public
::attribute id get
::attribute samples get
::attribute startMs get
::attribute peakMs get
::attribute endMs get
::attribute durationMs get
::attribute sampleCount get
::attribute maximumChangedCells get
::attribute maximumDelta get
::attribute maximumScore get
::attribute startX get
::attribute endX get
::attribute horizontalDisplacement get
::attribute pathLength get
::attribute left get
::attribute top get
::attribute right get
::attribute bottom get
::attribute horizontalSpan get
::attribute verticalSpan get
::attribute direction get
::attribute directionCoherence get
::attribute confidence get
::attribute classification get
::attribute admitted get
::attribute trafficSlitSamples get
::attribute maximumTrafficSlitChangedCells get
::attribute trafficSlitScore get
::attribute trafficSlitContact get

::method init
  expose id samples startMs peakMs endMs durationMs sampleCount maximumChangedCells maximumDelta maximumScore startX endX horizontalDisplacement pathLength left top right bottom horizontalSpan verticalSpan direction directionCoherence confidence classification admitted trafficSlitSamples maximumTrafficSlitChangedCells trafficSlitScore trafficSlitContact
  use arg eventId,sampleArray,config
  numeric digits 30
  id = eventId
  samples = .array~new
  do sample over sampleArray
    samples~append(sample)
  end

  startMs = 0
  peakMs = 0
  endMs = 0
  durationMs = 0
  sampleCount = samples~items
  maximumChangedCells = 0
  maximumDelta = 0
  maximumScore = 0
  startX = 0
  endX = 0
  horizontalDisplacement = 0
  pathLength = 0
  left = 0
  top = 0
  right = 0
  bottom = 0
  horizontalSpan = 0
  verticalSpan = 0
  direction = 'UNCERTAIN'
  directionCoherence = 0
  confidence = 0
  classification = 'ROAD_MOTION_UNCERTAIN'
  admitted = .false
  trafficSlitSamples = 0
  maximumTrafficSlitChangedCells = 0
  trafficSlitScore = 0
  trafficSlitContact = .false
  if sampleCount = 0 then return

  first = samples[1]
  last = samples[sampleCount]
  startMs = first~previousMs
  endMs = last~timeMs
  durationMs = endMs - startMs
  startX = first~centroidX
  endX = last~centroidX
  horizontalDisplacement = endX - startX
  left = first~left
  top = first~top
  right = first~right
  bottom = first~bottom

  positive = 0
  negative = 0
  movingSteps = 0
  previous = .nil
  do sample over samples
    if sample~trafficSlitChangedCells > 0 then do
      trafficSlitSamples = trafficSlitSamples + 1
      trafficSlitContact = .true
    end
    if sample~trafficSlitChangedCells > maximumTrafficSlitChangedCells then maximumTrafficSlitChangedCells = sample~trafficSlitChangedCells
    trafficSlitScore = trafficSlitScore + sample~trafficSlitScore
    if sample~changedCells > maximumChangedCells then maximumChangedCells = sample~changedCells
    if sample~maximumDelta > maximumDelta then maximumDelta = sample~maximumDelta
    if sample~score > maximumScore then do
      maximumScore = sample~score
      peakMs = sample~timeMs
    end
    if sample~left < left then left = sample~left
    if sample~top < top then top = sample~top
    if sample~right > right then right = sample~right
    if sample~bottom > bottom then bottom = sample~bottom
    if previous \== .nil then do
      dx = sample~centroidX - previous~centroidX
      dy = sample~centroidY - previous~centroidY
      pathLength = pathLength + abs(dx) + abs(dy)
      if abs(dx) >= 0.20 then do
        movingSteps = movingSteps + 1
        if dx > 0 then positive = positive + 1
        else negative = negative + 1
      end
    end
    previous = sample
  end

  horizontalSpan = right - left + 1
  verticalSpan = bottom - top + 1
  if movingSteps > 0 then do
    if positive >= negative then do
      direction = 'LEFT_TO_RIGHT'
      directionCoherence = positive / movingSteps
    end
    else do
      direction = 'RIGHT_TO_LEFT'
      directionCoherence = negative / movingSteps
    end
  end

  /* Evidence-weighted confidence.  This is a fixed-camera motion classifier,
     not object identity and not licence-plate recognition. */
  points = 0
  if sampleCount >= config~minimumEventSamples then points = points + 0.20
  if sampleCount >= config~minimumEventSamples + 1 then points = points + 0.10
  if durationMs >= config~minimumEventDurationMs & durationMs <= config~maximumEventDurationMs then points = points + 0.10
  if horizontalSpan >= config~minimumHorizontalSpan then points = points + 0.15
  if pathLength >= config~minimumPathLength then points = points + 0.15
  if maximumChangedCells >= config~minimumChangedCells + 1 then points = points + 0.10
  if maximumDelta >= config~changeThreshold * 1.5 then points = points + 0.10
  if directionCoherence >= 0.60 then points = points + 0.10
  confidence = points
  if confidence > 1 then confidence = 1

  /* The user-identified red sight line is the traffic anchor.  The wider
     road mask supplies trajectory context, but an admitted vehicle event must
     actually touch the thin traffic slit at least once.  This rejects motion
     from trees, rail shadows and other lower-frame activity outside the road
     aperture. */
  if sampleCount >= config~minimumEventSamples &,
     durationMs >= config~minimumEventDurationMs &,
     durationMs <= config~maximumEventDurationMs &,
     horizontalSpan >= config~minimumHorizontalSpan &,
     pathLength >= config~minimumPathLength &,
     trafficSlitContact &,
     confidence >= config~minimumConfidence then do
    admitted = .true
    classification = 'CAR_MOTION'
  end

::method compactText
  return 'FCME1|ID=' || self~id || '|T=' || self~startMs || '-' || self~endMs || '|P=' || self~peakMs || '|N=' || self~sampleCount || '|D=' || self~direction || '|DC=' || self~directionCoherence || '|DX=' || self~horizontalDisplacement || '|PATH=' || self~pathLength || '|BOX=' || self~left || ',' || self~top || '-' || self~right || ',' || self~bottom || '|MC=' || self~maximumChangedCells || '|MD=' || self~maximumDelta || '|MS=' || self~maximumScore || '|SLIT=' || self~trafficSlitContact || '/' || self~trafficSlitSamples || '/' || self~trafficSlitScore || '|C=' || self~confidence || '|A=' || self~admitted || '|K=' || self~classification


::class FCSceneFrameSample public
::attribute sampleIndex get
::attribute previousMs get
::attribute timeMs get
::attribute pts get
::attribute globalMean get
::attribute windowMean get
::attribute windowRatio get
::attribute windowState get
::attribute windowConfidence get
::attribute reflectionEdgeMean get
::attribute reflectionEdgeFraction get
::attribute reflectionScore get
::attribute reflectionPresent get

::method init
  expose sampleIndex previousMs timeMs pts globalMean windowMean windowRatio windowState windowConfidence reflectionEdgeMean reflectionEdgeFraction reflectionScore reflectionPresent
  use arg idx,priorMs,currentMs,framePts,gMean,wMean,wRatio,wState,wConfidence,rEdgeMean,rEdgeFraction,rScore,rPresent
  sampleIndex = idx
  previousMs = priorMs
  timeMs = currentMs
  pts = framePts
  globalMean = gMean
  windowMean = wMean
  windowRatio = wRatio
  windowState = wState
  windowConfidence = wConfidence
  reflectionEdgeMean = rEdgeMean
  reflectionEdgeFraction = rEdgeFraction
  reflectionScore = rScore
  reflectionPresent = rPresent

::method compactText
  return 'FCS1|I=' || self~sampleIndex || '|T=' || self~timeMs || '|G=' || self~globalMean || '|W=' || self~windowMean || '|WR=' || self~windowRatio || '|WS=' || self~windowState || '|WC=' || self~windowConfidence || '|RE=' || self~reflectionEdgeMean || '|RF=' || self~reflectionEdgeFraction || '|RS=' || self~reflectionScore || '|RP=' || self~reflectionPresent


::class FCWindowStateInterval public
::attribute id get
::attribute state get
::attribute startMs get
::attribute endMs get
::attribute durationMs get
::attribute sampleCount get
::attribute confidence get
::attribute meanWindowRatio get
::attribute meanReflectionScore get
::attribute maximumReflectionScore get

::method init
  expose id state startMs endMs durationMs sampleCount confidence meanWindowRatio meanReflectionScore maximumReflectionScore
  use arg intervalId,stateName,samples
  id = intervalId
  state = stateName
  startMs = 0
  endMs = 0
  durationMs = 0
  sampleCount = 0
  confidence = 0
  meanWindowRatio = 0
  meanReflectionScore = 0
  maximumReflectionScore = 0
  if samples == .nil | samples~items = 0 then return
  sampleCount = samples~items
  startMs = samples[1]~previousMs
  endMs = samples[sampleCount]~timeMs
  durationMs = endMs - startMs
  totalConfidence = 0
  totalRatio = 0
  totalReflection = 0
  do sample over samples
    totalConfidence = totalConfidence + sample~windowConfidence
    totalRatio = totalRatio + sample~windowRatio
    totalReflection = totalReflection + sample~reflectionScore
    if sample~reflectionScore > maximumReflectionScore then maximumReflectionScore = sample~reflectionScore
  end
  confidence = totalConfidence / sampleCount
  meanWindowRatio = totalRatio / sampleCount
  meanReflectionScore = totalReflection / sampleCount

::method compactText
  return 'FCW1|ID=' || self~id || '|S=' || self~state || '|T=' || self~startMs || '-' || self~endMs || '|N=' || self~sampleCount || '|C=' || self~confidence || '|WR=' || self~meanWindowRatio || '|RS=' || self~meanReflectionScore || '|RM=' || self~maximumReflectionScore


::class FCRoomReflectionEpisode public
::attribute id get
::attribute startMs get
::attribute peakMs get
::attribute endMs get
::attribute durationMs get
::attribute sampleCount get
::attribute confidence get
::attribute maximumScore get
::attribute meanScore get

::method init
  expose id startMs peakMs endMs durationMs sampleCount confidence maximumScore meanScore
  use arg episodeId,samples
  id = episodeId
  startMs = 0
  peakMs = 0
  endMs = 0
  durationMs = 0
  sampleCount = 0
  confidence = 0
  maximumScore = 0
  meanScore = 0
  if samples == .nil | samples~items = 0 then return
  sampleCount = samples~items
  startMs = samples[1]~previousMs
  endMs = samples[sampleCount]~timeMs
  durationMs = endMs - startMs
  total = 0
  do sample over samples
    total = total + sample~reflectionScore
    if sample~reflectionScore > maximumScore then do
      maximumScore = sample~reflectionScore
      peakMs = sample~timeMs
    end
  end
  meanScore = total / sampleCount
  confidence = meanScore
  if confidence > 1 then confidence = 1

::method compactText
  return 'FCR1|ID=' || self~id || '|T=' || self~startMs || '-' || self~endMs || '|P=' || self~peakMs || '|N=' || self~sampleCount || '|C=' || self~confidence || '|MAX=' || self~maximumScore


::class FCVehicleMotionResult public
::attribute sourcePath get
::attribute sourceName get
::attribute config get
::attribute frameCount get
::attribute sampledFrameCount get
::attribute comparisonCount get
::attribute firstPts get
::attribute lastPts get
::attribute timeBaseNum get
::attribute timeBaseDen get
::attribute lastRelativeMs get
::attribute status get
::attribute events get
::attribute uncertainEvents get
::attribute allEpisodes get
::attribute activeSamples get
::attribute sceneSamples get
::attribute windowIntervals get
::attribute reflectionEvents get

::method init
  expose sourcePath sourceName config frameCount sampledFrameCount comparisonCount firstPts lastPts timeBaseNum timeBaseDen lastRelativeMs status events uncertainEvents allEpisodes activeSamples sceneSamples windowIntervals reflectionEvents
  use arg path,name,cfg
  sourcePath = path
  sourceName = name
  config = cfg
  frameCount = 0
  sampledFrameCount = 0
  comparisonCount = 0
  firstPts = 0
  lastPts = 0
  timeBaseNum = 0
  timeBaseDen = 1
  lastRelativeMs = 0
  status = 'INIT'
  events = .array~new
  uncertainEvents = .array~new
  allEpisodes = .array~new
  activeSamples = .array~new
  sceneSamples = .array~new
  windowIntervals = .array~new
  reflectionEvents = .array~new

::method setTiming
  expose firstPts lastPts timeBaseNum timeBaseDen lastRelativeMs
  use arg originPts,finalPts,num,den,relativeMs
  firstPts = originPts
  lastPts = finalPts
  timeBaseNum = num
  timeBaseDen = den
  lastRelativeMs = relativeMs

::method setCounts
  expose frameCount sampledFrameCount comparisonCount
  use arg frames,sampled,comparisons
  frameCount = frames
  sampledFrameCount = sampled
  comparisonCount = comparisons

::method setStatus
  expose status
  use arg newStatus
  status = newStatus

::method addActiveSample
  expose activeSamples
  use arg sample
  activeSamples~append(sample)

::method addEpisode
  expose allEpisodes events uncertainEvents
  use arg episode
  allEpisodes~append(episode)
  if episode~admitted then events~append(episode)
  else uncertainEvents~append(episode)

::method addSceneSample
  expose sceneSamples
  use arg sample
  sceneSamples~append(sample)

::method addWindowInterval
  expose windowIntervals
  use arg interval
  windowIntervals~append(interval)

::method addReflectionEvent
  expose reflectionEvents
  use arg event
  reflectionEvents~append(event)

::method windowIntervalCount
  expose windowIntervals
  return windowIntervals~items

::method reflectionEventCount
  expose reflectionEvents
  return reflectionEvents~items

::method eventCount
  expose events
  return events~items

::method uncertainCount
  expose uncertainEvents
  return uncertainEvents~items

::method episodeCount
  expose allEpisodes
  return allEpisodes~items

::method compactText
  return 'FCMR2|STATUS=' || self~status || '|F=' || self~frameCount || '|SF=' || self~sampledFrameCount || '|CMP=' || self~comparisonCount || '|AS=' || self~activeSamples~items || '|E=' || self~eventCount || '|U=' || self~uncertainCount || '|SCENE=' || self~sceneSamples~items || '|WIN=' || self~windowIntervalCount || '|REF=' || self~reflectionEventCount || '|MS=' || self~lastRelativeMs || '|TB=' || self~timeBaseNum || '/' || self~timeBaseDen


::class FCVehicleMotionAnalyzer public
::attribute sourcePath get
::attribute config get
::attribute formatBridgePath get
::attribute codecBridgePath get
::attribute utilBridgePath get

::method init
  expose sourcePath config formatBridgePath codecBridgePath utilBridgePath
  use arg path,cfg,formatBridge,codecBridge,utilBridge
  if arg(1,'O') | path == '' then raise syntax 88.900 array('FCVehicleMotionAnalyzer requires an MP4 path')
  if arg(2,'O') | cfg == .nil then cfg = .FCVehicleMotionConfig~new
  if arg(3,'O') | formatBridge == '' then formatBridge = 'camera_ffmpeg_avformat.bridge.json'
  if arg(4,'O') | codecBridge == '' then codecBridge = 'camera_ffmpeg_avcodec.bridge.json'
  if arg(5,'O') | utilBridge == '' then utilBridge = 'camera_ffmpeg_avutil.bridge.json'
  sourcePath = path
  config = cfg
  formatBridgePath = formatBridge
  codecBridgePath = codecBridge
  utilBridgePath = utilBridge

::method baseName private
  use arg path
  name = path
  last = 0
  do i = 1 to name~length
    ch = name~substr(i,1)
    if ch = '/' | ch = '\\' then last = i
  end
  if last > 0 then name = name~substr(last + 1)
  return name

::method samplePlane private
  use arg plane,width,height,lineSize,columns,rows
  samples = .array~new
  fractions = .array~of(0.25,0.5,0.75)
  do r = 1 to rows
    do c = 1 to columns
      total = 0
      pointCount = 0
      do fy over fractions
        y = trunc((((r - 1) + fy) * height) / rows)
        if y < 0 then y = 0
        if y >= height then y = height - 1
        do fx over fractions
          x = trunc((((c - 1) + fx) * width) / columns)
          if x < 0 then x = 0
          if x >= width then x = width - 1
          offset = (y * lineSize) + x + 1
          total = total + c2d(plane~substr(offset,1))
          pointCount = pointCount + 1
        end
      end
      samples~append(total / pointCount)
    end
  end
  return samples

::method assessSceneSamples
  /* Public, deterministic scene-state assessment over one already-sampled
     luminance grid.  This is intentionally decoder-independent so the
     classifier can be unit-qualified without fabricating media timestamps. */
  numeric digits 30
  use arg samples,sampleIndex,previousMs,currentMs,framePts
  cfg = self~config
  if samples == .nil | samples~items = 0 then return .nil

  globalTotal = 0
  do value over samples
    globalTotal = globalTotal + value
  end
  globalMean = globalTotal / samples~items

  windowTotal = 0
  windowCount = 0
  do r = 1 to cfg~gridRows
    do c = 1 to cfg~gridColumns
      if \cfg~windowProbeCell(c,r) then iterate
      i = ((r - 1) * cfg~gridColumns) + c
      windowTotal = windowTotal + samples[i]
      windowCount = windowCount + 1
    end
  end
  if windowCount > 0 then windowMean = windowTotal / windowCount
  else windowMean = globalMean
  if globalMean > 0 then windowRatio = windowMean / globalMean
  else windowRatio = 1

  windowState = 'UNKNOWN'
  windowConfidence = 0
  if windowRatio <= cfg~windowOpenRatioMaximum then do
    windowState = 'OPEN'
    span = cfg~windowOpenRatioMaximum
    if span <= 0 then span = 1
    windowConfidence = 0.55 + (0.45 * ((cfg~windowOpenRatioMaximum - windowRatio) / span))
  end
  else if windowRatio >= cfg~windowClosedRatioMinimum then do
    windowState = 'CLOSED'
    span = 1.35 - cfg~windowClosedRatioMinimum
    if span <= 0 then span = 0.47
    windowConfidence = 0.55 + (0.45 * ((windowRatio - cfg~windowClosedRatioMinimum) / span))
  end
  if windowConfidence < 0 then windowConfidence = 0
  if windowConfidence > 1 then windowConfidence = 1

  edgeTotal = 0
  edgeCount = 0
  strongEdges = 0
  do r = 1 to cfg~gridRows
    do c = 1 to cfg~gridColumns
      if \cfg~reflectionCell(c,r) then iterate
      i = ((r - 1) * cfg~gridColumns) + c
      if c < cfg~gridColumns & cfg~reflectionCell(c + 1,r) then do
        j = ((r - 1) * cfg~gridColumns) + c + 1
        delta = abs(samples[i] - samples[j])
        edgeTotal = edgeTotal + delta
        edgeCount = edgeCount + 1
        if delta >= cfg~reflectionEdgeThreshold then strongEdges = strongEdges + 1
      end
      if r < cfg~gridRows & cfg~reflectionCell(c,r + 1) then do
        j = (r * cfg~gridColumns) + c
        delta = abs(samples[i] - samples[j])
        edgeTotal = edgeTotal + delta
        edgeCount = edgeCount + 1
        if delta >= cfg~reflectionEdgeThreshold then strongEdges = strongEdges + 1
      end
    end
  end

  reflectionEdgeMean = 0
  reflectionEdgeFraction = 0
  if edgeCount > 0 then do
    reflectionEdgeMean = edgeTotal / edgeCount
    reflectionEdgeFraction = strongEdges / edgeCount
  end

  meanEvidence = 0
  fractionEvidence = 0
  if cfg~reflectionMinimumEdgeMean > 0 then meanEvidence = reflectionEdgeMean / cfg~reflectionMinimumEdgeMean
  if cfg~reflectionMinimumEdgeFraction > 0 then fractionEvidence = reflectionEdgeFraction / cfg~reflectionMinimumEdgeFraction
  if meanEvidence > 1 then meanEvidence = 1
  if fractionEvidence > 1 then fractionEvidence = 1
  rawReflectionScore = (meanEvidence + fractionEvidence) / 2

  /* Texture alone is not called a room reflection.  The glass must first be
     classified CLOSED.  This prevents exterior daytime structure from being
     mislabeled merely because it has many edges. */
  if windowState = 'CLOSED' then reflectionScore = rawReflectionScore
  else reflectionScore = 0

  reflectionPresent = .false
  if windowState = 'CLOSED' &,
     reflectionEdgeMean >= cfg~reflectionMinimumEdgeMean &,
     reflectionEdgeFraction >= cfg~reflectionMinimumEdgeFraction &,
     reflectionScore >= cfg~reflectionMinimumConfidence then reflectionPresent = .true

  return .FCSceneFrameSample~new(sampleIndex,previousMs,currentMs,framePts,globalMean,windowMean,windowRatio,windowState,windowConfidence,reflectionEdgeMean,reflectionEdgeFraction,reflectionScore,reflectionPresent)


::method buildWindowIntervals private
  use arg sceneSamples,analysis
  cfg = self~config
  if sceneSamples == .nil | sceneSamples~items = 0 then return 0

  current = .array~new
  currentState = ''
  intervalNo = 0
  do sample over sceneSamples
    state = sample~windowState
    if state = 'UNKNOWN' then do
      if current~items > 0 then do
        if current~items >= cfg~windowPersistenceSamples then do
          intervalNo = intervalNo + 1
          id = 'FCW' || right(intervalNo,5,'0')
          analysis~addWindowInterval(.FCWindowStateInterval~new(id,currentState,current))
        end
        current = .array~new
        currentState = ''
      end
      iterate
    end

    if currentState = '' then currentState = state
    if state \= currentState then do
      if current~items >= cfg~windowPersistenceSamples then do
        intervalNo = intervalNo + 1
        id = 'FCW' || right(intervalNo,5,'0')
        analysis~addWindowInterval(.FCWindowStateInterval~new(id,currentState,current))
      end
      current = .array~new
      currentState = state
    end
    current~append(sample)
  end

  if current~items >= cfg~windowPersistenceSamples then do
    intervalNo = intervalNo + 1
    id = 'FCW' || right(intervalNo,5,'0')
    analysis~addWindowInterval(.FCWindowStateInterval~new(id,currentState,current))
  end
  return intervalNo


::method buildReflectionEpisodes private
  use arg sceneSamples,analysis
  cfg = self~config
  if sceneSamples == .nil | sceneSamples~items = 0 then return 0

  current = .array~new
  eventNo = 0
  do sample over sceneSamples
    if sample~reflectionPresent then current~append(sample)
    else do
      if current~items >= cfg~reflectionPersistenceSamples then do
        eventNo = eventNo + 1
        id = 'FCR' || right(eventNo,5,'0')
        analysis~addReflectionEvent(.FCRoomReflectionEpisode~new(id,current))
      end
      current = .array~new
    end
  end
  if current~items >= cfg~reflectionPersistenceSamples then do
    eventNo = eventNo + 1
    id = 'FCR' || right(eventNo,5,'0')
    analysis~addReflectionEvent(.FCRoomReflectionEpisode~new(id,current))
  end
  return eventNo


::method roadMotionSample private
  numeric digits 30
  use arg previous,current,comparisonIndex,previousMs,currentMs,framePts
  cfg = self~config
  if previous == .nil | current == .nil then return .nil
  if previous~items \= current~items then return .nil

  previousMean = 0
  currentMean = 0
  do i = 1 to current~items
    previousMean = previousMean + previous[i]
    currentMean = currentMean + current[i]
  end
  if current~items > 0 then do
    previousMean = previousMean / current~items
    currentMean = currentMean / current~items
  end

  changed = 0
  totalScore = 0
  maximumDelta = 0
  weightedX = 0
  weightedY = 0
  trafficSlitChangedCells = 0
  trafficSlitScore = 0
  left = cfg~gridColumns + 1
  right = 0
  top = cfg~gridRows + 1
  bottom = 0

  do r = 1 to cfg~gridRows
    do c = 1 to cfg~gridColumns
      if \cfg~roadCell(c,r) then iterate
      i = ((r - 1) * cfg~gridColumns) + c
      previousResidual = previous[i] - previousMean
      currentResidual = current[i] - currentMean
      delta = abs(currentResidual - previousResidual)
      if delta >= cfg~changeThreshold then do
        changed = changed + 1
        totalScore = totalScore + delta
        if delta > maximumDelta then maximumDelta = delta
        weightedX = weightedX + (c * delta)
        weightedY = weightedY + (r * delta)
        if cfg~trafficSlitCell(c,r) then do
          trafficSlitChangedCells = trafficSlitChangedCells + 1
          trafficSlitScore = trafficSlitScore + delta
        end
        if c < left then left = c
        if c > right then right = c
        if r < top then top = r
        if r > bottom then bottom = r
      end
    end
  end

  if changed < cfg~minimumChangedCells then return .nil
  if totalScore < cfg~minimumSampleScore then return .nil
  if totalScore <= 0 then return .nil
  centroidX = weightedX / totalScore
  centroidY = weightedY / totalScore
  motionSample = .FCRoadMotionSample~new(comparisonIndex,previousMs,currentMs,framePts,changed,totalScore,maximumDelta,centroidX,centroidY,left,top,right,bottom)
  motionSample~setTrafficSlitEvidence(trafficSlitChangedCells,trafficSlitScore)
  return motionSample

::method buildEpisodes private
  use arg activeSamples,analysis
  cfg = self~config
  current = .array~new
  eventNo = 0
  previous = .nil

  do sample over activeSamples
    startNew = .false
    if previous \== .nil then do
      gap = sample~previousMs - previous~timeMs
      if gap > cfg~maximumGapMs then startNew = .true
    end
    if startNew & current~items > 0 then do
      eventNo = eventNo + 1
      id = 'FCM' || right(eventNo,5,'0')
      analysis~addEpisode(.FCRoadMotionEpisode~new(id,current,cfg))
      current = .array~new
    end
    current~append(sample)
    previous = sample
  end
  if current~items > 0 then do
    eventNo = eventNo + 1
    id = 'FCM' || right(eventNo,5,'0')
    analysis~addEpisode(.FCRoadMotionEpisode~new(id,current,cfg))
  end

::method analyze
  expose sourcePath config formatBridgePath codecBridgePath utilBridgePath
  numeric digits 30
  analysis = .FCVehicleMotionResult~new(sourcePath,self~baseName(sourcePath),config)
  if stream(sourcePath,'C','QUERY EXISTS') == '' then do
    analysis~setStatus('SOURCE_NOT_FOUND')
    return analysis
  end

  formatLibrary = .nil
  codecLibrary = .nil
  utilLibrary = .nil
  context = .nil
  packet = .nil
  frame = .nil
  packetView = .nil
  frameView = .nil
  formatView = .nil
  streamView = .nil
  codecParameters = .nil
  codecContext = .nil
  decoder = .nil

  formatLibrary = .foreign~load(formatBridgePath)
  codecLibrary = .foreign~load(codecBridgePath)
  utilLibrary = .foreign~load(utilBridgePath)

  openResult = formatLibrary~open_input(.foreign~out,sourcePath,.nil,.nil)
  if openResult~returnValue <> 0 then do
    analysis~setStatus('OPEN_FAILED')
    formatLibrary~close
    codecLibrary~close
    utilLibrary~close
    return analysis
  end
  context = openResult~out('context')
  streamInfoStatus = formatLibrary~find_stream_info(context,.nil)
  if streamInfoStatus < 0 then do
    analysis~setStatus('STREAM_INFO_FAILED')
    context~close
    formatLibrary~close
    codecLibrary~close
    utilLibrary~close
    return analysis
  end

  best = formatLibrary~find_best_stream_decoder(context,0,-1,-1,.foreign~out,0)
  if \best~isA(.ForeignResult) then do
    analysis~setStatus('VIDEO_STREAM_FAILED')
    context~close
    formatLibrary~close
    codecLibrary~close
    utilLibrary~close
    return analysis
  end
  selectedStream = best~returnValue
  if selectedStream < 0 then do
    analysis~setStatus('NO_VIDEO_STREAM')
    context~close
    formatLibrary~close
    codecLibrary~close
    utilLibrary~close
    return analysis
  end
  decoder = best~out('decoder')

  formatView = formatLibrary~structView('AVFormatContext',context)
  streamsAddress = formatView~get('streams')
  streamAddress = .foreign~pointerAt(streamsAddress,selectedStream)
  streamView = formatLibrary~structView('AVStream',streamAddress)
  timeBaseNum = streamView~get('time_base_num')
  timeBaseDen = streamView~get('time_base_den')
  if timeBaseDen = 0 then timeBaseDen = 1
  codecParameters = codecLibrary~structView('AVCodecParameters',streamView~get('codecpar'))

  codecContext = codecLibrary~alloc_context(decoder)
  parameterStatus = codecLibrary~parameters_to_context(codecContext,codecParameters)
  if parameterStatus < 0 then do
    analysis~setStatus('CODEC_PARAMETERS_FAILED')
    codecParameters~close; streamView~close; formatView~close; codecContext~close; decoder~close
    context~close; formatLibrary~close; codecLibrary~close; utilLibrary~close
    return analysis
  end
  openCodecStatus = codecLibrary~open_codec(codecContext,decoder,.nil)
  if openCodecStatus < 0 then do
    analysis~setStatus('CODEC_OPEN_FAILED')
    codecParameters~close; streamView~close; formatView~close; codecContext~close; decoder~close
    context~close; formatLibrary~close; codecLibrary~close; utilLibrary~close
    return analysis
  end

  packet = codecLibrary~packet_alloc
  packetView = codecLibrary~structView('AVPacket',packet)
  frame = utilLibrary~frame_alloc
  frameView = utilLibrary~structView('AVFrame',frame)

  frameCount = 0
  sampledFrameCount = 0
  comparisonCount = 0
  previousSamples = .nil
  previousMs = 0
  originPtsSet = .false
  originPts = 0
  lastPts = 0
  lastRelativeMs = 0
  activeSamples = .array~new

  done = .false
  do while \done
    readStatus = formatLibrary~read_frame(context,packet)
    if readStatus < 0 then leave
    if packetView~get('stream_index') = selectedStream then do
      sendStatus = codecLibrary~send_packet(codecContext,packet)
      if sendStatus >= 0 then do forever
        receiveStatus = codecLibrary~receive_frame(codecContext,frame)
        if receiveStatus < 0 then leave
        frameCount = frameCount + 1
        framePts = frameView~get('pts')
        if \originPtsSet then do
          originPts = framePts
          originPtsSet = .true
        end
        lastPts = framePts
        lastRelativeMs = (framePts - originPts) * timeBaseNum * 1000 / timeBaseDen

        if ((frameCount - 1) // config~sampleEveryFrames) = 0 then do
          width = frameView~get('width')
          height = frameView~get('height')
          lineSize = frameView~get('linesize0')
          lumaAddress = frameView~get('data0')
          if width > 0 & height > 0 & lineSize > 0 & lumaAddress \= 0 then do
            plane = .foreign~peekBytes(lumaAddress,lineSize * height)
            samples = self~samplePlane(plane,width,height,lineSize,config~gridColumns,config~gridRows)
            sampledFrameCount = sampledFrameCount + 1
            currentMs = lastRelativeMs
            scene = self~assessSceneSamples(samples,sampledFrameCount,previousMs,currentMs,framePts)
            if scene \== .nil then analysis~addSceneSample(scene)
            if previousSamples \== .nil then do
              comparisonCount = comparisonCount + 1
              motion = self~roadMotionSample(previousSamples,samples,comparisonCount,previousMs,currentMs,framePts)
              if motion \== .nil then do
                activeSamples~append(motion)
                analysis~addActiveSample(motion)
              end
            end
            previousSamples = samples
            previousMs = currentMs
          end
        end
        utilLibrary~frame_unref(frame)
      end
    end
    codecLibrary~packet_unref(packet)
  end

  ignoredFlush = codecLibrary~send_packet(codecContext,.nil)
  do forever
    receiveStatus = codecLibrary~receive_frame(codecContext,frame)
    if receiveStatus < 0 then leave
    frameCount = frameCount + 1
    framePts = frameView~get('pts')
    if \originPtsSet then do
      originPts = framePts
      originPtsSet = .true
    end
    lastPts = framePts
    lastRelativeMs = (framePts - originPts) * timeBaseNum * 1000 / timeBaseDen

    if ((frameCount - 1) // config~sampleEveryFrames) = 0 then do
      width = frameView~get('width')
      height = frameView~get('height')
      lineSize = frameView~get('linesize0')
      lumaAddress = frameView~get('data0')
      if width > 0 & height > 0 & lineSize > 0 & lumaAddress \= 0 then do
        plane = .foreign~peekBytes(lumaAddress,lineSize * height)
        samples = self~samplePlane(plane,width,height,lineSize,config~gridColumns,config~gridRows)
        sampledFrameCount = sampledFrameCount + 1
        currentMs = lastRelativeMs
        scene = self~assessSceneSamples(samples,sampledFrameCount,previousMs,currentMs,framePts)
        if scene \== .nil then analysis~addSceneSample(scene)
        if previousSamples \== .nil then do
          comparisonCount = comparisonCount + 1
          motion = self~roadMotionSample(previousSamples,samples,comparisonCount,previousMs,currentMs,framePts)
          if motion \== .nil then do
            activeSamples~append(motion)
            analysis~addActiveSample(motion)
          end
        end
        previousSamples = samples
        previousMs = currentMs
      end
    end
    utilLibrary~frame_unref(frame)
  end

  packetView~close
  packet~close
  frameView~close
  frame~close
  codecParameters~close
  streamView~close
  formatView~close
  codecContext~close
  decoder~close
  context~close
  utilLibrary~close
  codecLibrary~close
  formatLibrary~close

  analysis~setCounts(frameCount,sampledFrameCount,comparisonCount)
  if originPtsSet then analysis~setTiming(originPts,lastPts,timeBaseNum,timeBaseDen,lastRelativeMs)
  self~buildEpisodes(activeSamples,analysis)
  self~buildWindowIntervals(analysis~sceneSamples,analysis)
  self~buildReflectionEpisodes(analysis~sceneSamples,analysis)
  analysis~setStatus('OK')
  return analysis

::method formatTimeMs class
  numeric digits 30
  use arg milliseconds
  if milliseconds < 0 then milliseconds = 0
  totalMs = trunc(milliseconds + 0.5)
  hours = totalMs % 3600000
  remain = totalMs // 3600000
  minutes = remain % 60000
  remain = remain // 60000
  seconds = remain % 1000
  ms = remain // 1000
  return right(hours,2,'0') || ':' || right(minutes,2,'0') || ':' || right(seconds,2,'0') || '.' || right(ms,3,'0')

::method tsvSafe class
  use arg text
  text = text~changestr('09'x,' ')
  text = text~changestr('0A'x,' ')
  text = text~changestr('0D'x,' ')
  return text

::method writeOutputs class
  numeric digits 30
  use arg analysis,outputPrefix
  if analysis == .nil then raise syntax 88.900 array('writeOutputs requires an analysis result')
  if outputPrefix == '' then raise syntax 88.900 array('writeOutputs requires an output prefix')
  tab = '09'x
  eventPath = outputPrefix || '.events.tsv'
  samplePath = outputPrefix || '.samples.tsv'
  scenePath = outputPrefix || '.scene.tsv'
  windowPath = outputPrefix || '.window.tsv'
  reflectionPath = outputPrefix || '.reflections.tsv'
  cameraEventPath = outputPrefix || '.camera_events.tsv'
  runPath = outputPrefix || '.run.tsv'

  call stream eventPath,'C','OPEN WRITE REPLACE'
  call lineout eventPath,'schema' || tab || 'source_file' || tab || 'event_id' || tab || 'class' || tab || 'start_ms' || tab || 'start_hms' || tab || 'peak_ms' || tab || 'peak_hms' || tab || 'end_ms' || tab || 'end_hms' || tab || 'duration_ms' || tab || 'direction' || tab || 'confidence' || tab || 'samples' || tab || 'max_changed_cells' || tab || 'max_delta' || tab || 'max_score' || tab || 'horizontal_displacement' || tab || 'path_length' || tab || 'left_cell' || tab || 'top_cell' || tab || 'right_cell' || tab || 'bottom_cell' || tab || 'direction_coherence'
  do event over analysis~events
    call lineout eventPath,.FCVehicleMotionVersion~EVENT_SCHEMA || tab || self~tsvSafe(analysis~sourceName) || tab || event~id || tab || event~classification || tab || trunc(event~startMs+0.5) || tab || self~formatTimeMs(event~startMs) || tab || trunc(event~peakMs+0.5) || tab || self~formatTimeMs(event~peakMs) || tab || trunc(event~endMs+0.5) || tab || self~formatTimeMs(event~endMs) || tab || trunc(event~durationMs+0.5) || tab || event~direction || tab || event~confidence || tab || event~sampleCount || tab || event~maximumChangedCells || tab || event~maximumDelta || tab || event~maximumScore || tab || event~horizontalDisplacement || tab || event~pathLength || tab || event~left || tab || event~top || tab || event~right || tab || event~bottom || tab || event~directionCoherence
  end
  call stream eventPath,'C','CLOSE'

  call stream samplePath,'C','OPEN WRITE REPLACE'
  call lineout samplePath,'schema' || tab || 'source_file' || tab || 'comparison' || tab || 'previous_ms' || tab || 'time_ms' || tab || 'time_hms' || tab || 'pts' || tab || 'changed_cells' || tab || 'score' || tab || 'max_delta' || tab || 'centroid_x' || tab || 'centroid_y' || tab || 'left_cell' || tab || 'top_cell' || tab || 'right_cell' || tab || 'bottom_cell'
  do sample over analysis~activeSamples
    call lineout samplePath,.FCVehicleMotionVersion~SAMPLE_SCHEMA || tab || self~tsvSafe(analysis~sourceName) || tab || sample~comparisonIndex || tab || trunc(sample~previousMs+0.5) || tab || trunc(sample~timeMs+0.5) || tab || self~formatTimeMs(sample~timeMs) || tab || sample~pts || tab || sample~changedCells || tab || sample~score || tab || sample~maximumDelta || tab || sample~centroidX || tab || sample~centroidY || tab || sample~left || tab || sample~top || tab || sample~right || tab || sample~bottom
  end
  call stream samplePath,'C','CLOSE'

  call stream scenePath,'C','OPEN WRITE REPLACE'
  call lineout scenePath,'schema' || tab || 'source_file' || tab || 'sample' || tab || 'previous_ms' || tab || 'time_ms' || tab || 'time_hms' || tab || 'pts' || tab || 'global_mean' || tab || 'window_mean' || tab || 'window_ratio' || tab || 'window_state' || tab || 'window_confidence' || tab || 'reflection_edge_mean' || tab || 'reflection_edge_fraction' || tab || 'reflection_score' || tab || 'reflection_present'
  do sample over analysis~sceneSamples
    call lineout scenePath,.FCVehicleMotionVersion~SCENE_SCHEMA || tab || self~tsvSafe(analysis~sourceName) || tab || sample~sampleIndex || tab || trunc(sample~previousMs+0.5) || tab || trunc(sample~timeMs+0.5) || tab || self~formatTimeMs(sample~timeMs) || tab || sample~pts || tab || sample~globalMean || tab || sample~windowMean || tab || sample~windowRatio || tab || sample~windowState || tab || sample~windowConfidence || tab || sample~reflectionEdgeMean || tab || sample~reflectionEdgeFraction || tab || sample~reflectionScore || tab || sample~reflectionPresent
  end
  call stream scenePath,'C','CLOSE'

  call stream windowPath,'C','OPEN WRITE REPLACE'
  call lineout windowPath,'schema' || tab || 'source_file' || tab || 'interval_id' || tab || 'state' || tab || 'start_ms' || tab || 'start_hms' || tab || 'end_ms' || tab || 'end_hms' || tab || 'duration_ms' || tab || 'samples' || tab || 'confidence' || tab || 'mean_window_ratio' || tab || 'mean_reflection_score' || tab || 'max_reflection_score'
  do interval over analysis~windowIntervals
    call lineout windowPath,.FCVehicleMotionVersion~WINDOW_SCHEMA || tab || self~tsvSafe(analysis~sourceName) || tab || interval~id || tab || interval~state || tab || trunc(interval~startMs+0.5) || tab || self~formatTimeMs(interval~startMs) || tab || trunc(interval~endMs+0.5) || tab || self~formatTimeMs(interval~endMs) || tab || trunc(interval~durationMs+0.5) || tab || interval~sampleCount || tab || interval~confidence || tab || interval~meanWindowRatio || tab || interval~meanReflectionScore || tab || interval~maximumReflectionScore
  end
  call stream windowPath,'C','CLOSE'

  call stream reflectionPath,'C','OPEN WRITE REPLACE'
  call lineout reflectionPath,'schema' || tab || 'source_file' || tab || 'event_id' || tab || 'class' || tab || 'start_ms' || tab || 'start_hms' || tab || 'peak_ms' || tab || 'peak_hms' || tab || 'end_ms' || tab || 'end_hms' || tab || 'duration_ms' || tab || 'samples' || tab || 'confidence' || tab || 'mean_score' || tab || 'max_score'
  do event over analysis~reflectionEvents
    call lineout reflectionPath,.FCVehicleMotionVersion~REFLECTION_SCHEMA || tab || self~tsvSafe(analysis~sourceName) || tab || event~id || tab || 'ROOM_REFLECTION_VISIBLE' || tab || trunc(event~startMs+0.5) || tab || self~formatTimeMs(event~startMs) || tab || trunc(event~peakMs+0.5) || tab || self~formatTimeMs(event~peakMs) || tab || trunc(event~endMs+0.5) || tab || self~formatTimeMs(event~endMs) || tab || trunc(event~durationMs+0.5) || tab || event~sampleCount || tab || event~confidence || tab || event~meanScore || tab || event~maximumScore
  end
  call stream reflectionPath,'C','CLOSE'

  /* One merge-friendly event stream.  Rows are sorted by file-relative start
     time; detailed per-family evidence remains in the family TSVs above. */
  merged = .array~new
  do event over analysis~events
    row = .FCVehicleMotionVersion~CAMERA_EVENT_SCHEMA || tab || self~tsvSafe(analysis~sourceName) || tab || event~id || tab || 'TRAFFIC_MOTION' || tab || trunc(event~startMs+0.5) || tab || self~formatTimeMs(event~startMs) || tab || trunc(event~peakMs+0.5) || tab || self~formatTimeMs(event~peakMs) || tab || trunc(event~endMs+0.5) || tab || self~formatTimeMs(event~endMs) || tab || trunc(event~durationMs+0.5) || tab || event~confidence || tab || event~direction || tab || ('CAR_MOTION;SLIT_CONTACT=' || event~trafficSlitContact) || tab || ('BOX=' || event~left || ',' || event~top || '-' || event~right || ',' || event~bottom) || tab || ('PATH=' || event~pathLength || ';SLIT_SAMPLES=' || event~trafficSlitSamples || ';SLIT_SCORE=' || event~trafficSlitScore)
    merged~append(right(trunc(event~startMs+0.5),12,'0') || tab || row)
  end
  do interval over analysis~windowIntervals
    eventClass = 'WINDOW_' || interval~state
    row = .FCVehicleMotionVersion~CAMERA_EVENT_SCHEMA || tab || self~tsvSafe(analysis~sourceName) || tab || interval~id || tab || eventClass || tab || trunc(interval~startMs+0.5) || tab || self~formatTimeMs(interval~startMs) || tab || trunc(interval~startMs+0.5) || tab || self~formatTimeMs(interval~startMs) || tab || trunc(interval~endMs+0.5) || tab || self~formatTimeMs(interval~endMs) || tab || trunc(interval~durationMs+0.5) || tab || interval~confidence || tab || 'NA' || tab || ('RATIO=' || interval~meanWindowRatio) || tab || ('REFLECTION=' || interval~meanReflectionScore) || tab || ('SAMPLES=' || interval~sampleCount)
    merged~append(right(trunc(interval~startMs+0.5),12,'0') || tab || row)
  end
  do event over analysis~reflectionEvents
    row = .FCVehicleMotionVersion~CAMERA_EVENT_SCHEMA || tab || self~tsvSafe(analysis~sourceName) || tab || event~id || tab || 'ROOM_REFLECTION_VISIBLE' || tab || trunc(event~startMs+0.5) || tab || self~formatTimeMs(event~startMs) || tab || trunc(event~peakMs+0.5) || tab || self~formatTimeMs(event~peakMs) || tab || trunc(event~endMs+0.5) || tab || self~formatTimeMs(event~endMs) || tab || trunc(event~durationMs+0.5) || tab || event~confidence || tab || 'NA' || tab || ('MEAN=' || event~meanScore) || tab || ('MAX=' || event~maximumScore) || tab || ('SAMPLES=' || event~sampleCount)
    merged~append(right(trunc(event~startMs+0.5),12,'0') || tab || row)
  end
  merged~sort
  call stream cameraEventPath,'C','OPEN WRITE REPLACE'
  call lineout cameraEventPath,'schema' || tab || 'source_file' || tab || 'event_id' || tab || 'event_class' || tab || 'start_ms' || tab || 'start_hms' || tab || 'peak_ms' || tab || 'peak_hms' || tab || 'end_ms' || tab || 'end_hms' || tab || 'duration_ms' || tab || 'confidence' || tab || 'direction' || tab || 'detail_1' || tab || 'detail_2' || tab || 'detail_3'
  do line over merged
    splitAt = line~pos(tab)
    call lineout cameraEventPath,line~substr(splitAt + 1)
  end
  call stream cameraEventPath,'C','CLOSE'

  call stream runPath,'C','OPEN WRITE REPLACE'
  call lineout runPath,'schema' || tab || 'version' || tab || 'status' || tab || 'source_path' || tab || 'source_file' || tab || 'frame_count' || tab || 'sampled_frames' || tab || 'comparisons' || tab || 'active_samples' || tab || 'traffic_events' || tab || 'uncertain_episodes' || tab || 'scene_samples' || tab || 'window_intervals' || tab || 'reflection_events' || tab || 'first_pts' || tab || 'last_pts' || tab || 'time_base_num' || tab || 'time_base_den' || tab || 'last_relative_ms' || tab || 'config'
  call lineout runPath,.FCVehicleMotionVersion~RUN_SCHEMA || tab || .FCVehicleMotionVersion~VERSION || tab || analysis~status || tab || self~tsvSafe(analysis~sourcePath) || tab || self~tsvSafe(analysis~sourceName) || tab || analysis~frameCount || tab || analysis~sampledFrameCount || tab || analysis~comparisonCount || tab || analysis~activeSamples~items || tab || analysis~eventCount || tab || analysis~uncertainCount || tab || analysis~sceneSamples~items || tab || analysis~windowIntervalCount || tab || analysis~reflectionEventCount || tab || analysis~firstPts || tab || analysis~lastPts || tab || analysis~timeBaseNum || tab || analysis~timeBaseDen || tab || trunc(analysis~lastRelativeMs+0.5) || tab || analysis~config~compactText
  call stream runPath,'C','CLOSE'

  return .array~of(cameraEventPath,eventPath,samplePath,scenePath,windowPath,reflectionPath,runPath)

::requires 'foreign.cls'
