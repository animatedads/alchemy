/* Bridge from direct decoded luminance primitives into Camera's existing
   generic track/vector/peer-outlier semantics. */

/* Conservative quality assessment for clip-local luminance primitives.
   This is not semantic recognition. It decides only whether a coarse temporal
   region track is coherent enough to enter peer-relative motion comparison. */

::class CameraLumaPrimitiveQuality public
::attribute trackId get
::attribute observationCount get
::attribute pathLength get
::attribute movingStepCount get
::attribute stationaryStepCount get
::attribute reversalCount get
::attribute edgeContactCount get
::attribute edgeShare get
::attribute minimumCellCount get
::attribute maximumCellCount get
::attribute sizeRatio get
::attribute score get
::attribute admitted get
::attribute reason get

::method init
  expose trackId observationCount pathLength movingStepCount stationaryStepCount reversalCount edgeContactCount edgeShare minimumCellCount maximumCellCount sizeRatio score admitted reason
  use arg lumaTrack,gridColumns,gridRows,minimumObservations,minimumScore

  if arg(2,'O') then gridColumns = 16
  if arg(3,'O') then gridRows = 9
  if arg(4,'O') then minimumObservations = 2
  if arg(5,'O') then minimumScore = 4

  trackId = ''
  observationCount = 0
  pathLength = 0
  movingStepCount = 0
  stationaryStepCount = 0
  reversalCount = 0
  edgeContactCount = 0
  edgeShare = 0
  minimumCellCount = 0
  maximumCellCount = 0
  sizeRatio = 0
  score = 0
  admitted = .false
  reason = 'NO_TRACK'

  if lumaTrack == .nil then return

  trackId = lumaTrack~id
  observationCount = lumaTrack~observationCount
  pathLength = lumaTrack~pathLength
  regions = lumaTrack~regions

  if regions~items > 0 then do
    minimumCellCount = regions[1]~cellCount
    maximumCellCount = regions[1]~cellCount
  end

  previous = .nil
  previousDx = 0
  previousDy = 0
  do region over regions
    if region~cellCount < minimumCellCount then minimumCellCount = region~cellCount
    if region~cellCount > maximumCellCount then maximumCellCount = region~cellCount

    if region~left <= 1 | region~top <= 1 | region~right >= gridColumns | region~bottom >= gridRows then edgeContactCount = edgeContactCount + 1

    if previous \== .nil then do
      dx = region~centerX - previous~centerX
      dy = region~centerY - previous~centerY
      if dx = 0 & dy = 0 then stationaryStepCount = stationaryStepCount + 1
      else movingStepCount = movingStepCount + 1

      if previousDx \= 0 & dx \= 0 then if sign(previousDx) \= sign(dx) then reversalCount = reversalCount + 1
      if previousDy \= 0 & dy \= 0 then if sign(previousDy) \= sign(dy) then reversalCount = reversalCount + 1
      previousDx = dx
      previousDy = dy
    end
    previous = region
  end

  if observationCount > 0 then edgeShare = edgeContactCount / observationCount
  if minimumCellCount > 0 then sizeRatio = maximumCellCount / minimumCellCount

  /* Evidence points deliberately favour persistence and coherent movement.
     No single feature can independently admit a primitive. */
  score = 0
  if observationCount >= minimumObservations then score = score + 1
  if observationCount >= 3 then score = score + 1
  if movingStepCount >= 1 then score = score + 1
  if movingStepCount >= stationaryStepCount then score = score + 1
  if reversalCount <= 1 then score = score + 1
  if edgeShare <= 0.5 then score = score + 1
  if sizeRatio > 0 & sizeRatio <= 4 then score = score + 1

  if observationCount < minimumObservations then reason = 'TOO_SHORT'
  else if movingStepCount = 0 then reason = 'STATIC_FRAGMENT'
  else if edgeShare > 0.75 then reason = 'EDGE_DOMINATED'
  else if sizeRatio > 6 then reason = 'SIZE_UNSTABLE'
  else if reversalCount > 3 then reason = 'DIRECTION_UNSTABLE'
  else if score < minimumScore then reason = 'LOW_COHERENCE'
  else do
    admitted = .true
    reason = 'ADMIT'
  end

::method compactText
  return 'CLQ1|ID=' || self~trackId || '|N=' || self~observationCount || '|PL=' || self~pathLength || '|MV=' || self~movingStepCount || '|ST=' || self~stationaryStepCount || '|RV=' || self~reversalCount || '|EC=' || self~edgeContactCount || '|ES=' || self~edgeShare || '|SZ=' || self~minimumCellCount || '-' || self~maximumCellCount || '|SR=' || self~sizeRatio || '|SC=' || self~score || '|A=' || self~admitted || '|R=' || self~reason


::class CameraLumaPrimitiveQualitySet public
::attribute totalCount get
::attribute admittedCount get
::attribute rejectedCount get

::method init
  expose totalCount admittedCount rejectedCount assessments
  use arg temporalTrackSet,gridColumns,gridRows,minimumObservations,minimumScore
  totalCount = 0
  admittedCount = 0
  rejectedCount = 0
  assessments = .array~new
  if temporalTrackSet == .nil then return

  do track over temporalTrackSet~tracks
    quality = .CameraLumaPrimitiveQuality~new(track,gridColumns,gridRows,minimumObservations,minimumScore)
    assessments~append(quality)
    totalCount = totalCount + 1
    if quality~admitted then admittedCount = admittedCount + 1
    else rejectedCount = rejectedCount + 1
  end

::method assessments
  expose assessments
  out = .array~new
  do assessment over assessments
    out~append(assessment)
  end
  return out

::method assessment
  expose assessments
  use arg trackId
  do assessment over assessments
    if assessment~trackId == trackId then return assessment
  end
  return .nil

::method admittedIds
  expose assessments
  out = .array~new
  do assessment over assessments
    if assessment~admitted then out~append(assessment~trackId)
  end
  return out

::method compactText
  expose assessments
  tokens = .array~new
  do assessment over assessments
    tokens~append(assessment~trackId || ':' || assessment~score || ':' || assessment~reason)
  end
  tokens~sort
  body = ''
  do token over tokens
    if body == '' then body = token
    else body = body || ';' || token
  end
  return 'CLQS1|N=' || self~totalCount || '|A=' || self~admittedCount || '|R=' || self~rejectedCount || '|Q=' || body


::class CameraSegmentPeerAssessment public
::attribute segmentId get
::attribute generation get
::attribute vectorCount get
::attribute peerOutliers get

::method init
  expose segmentId generation vectorCount peerOutliers
  use arg id,generationId,count,outliers
  segmentId=id
  generation=generationId
  vectorCount=count
  peerOutliers=outliers

::method compactText
  return 'CSPO1|ID=' || self~segmentId || '|G=' || self~generation || '|V=' || self~vectorCount || '|' || self~peerOutliers~compactText


::class CameraLumaBehaviourBridge public

::method toCameraTrack class
  use arg lumaTrack,gridWidth,gridHeight,sampleSeconds
  if lumaTrack == .nil then return .nil
  if arg(2,'O') then gridWidth = 1
  if arg(3,'O') then gridHeight = 1
  if arg(4,'O') then sampleSeconds = 1
  if gridWidth <= 0 then gridWidth = 1
  if gridHeight <= 0 then gridHeight = 1
  if sampleSeconds <= 0 then sampleSeconds = 1

  track = .CameraTrack~new(lumaTrack~id)
  track~objectType = .CameraConstant~OBJECT_UNKNOWN
  regions = lumaTrack~regions
  do region over regions
    x = (region~left - 1) * gridWidth
    y = (region~top - 1) * gridHeight
    width = (region~right - region~left + 1) * gridWidth
    height = (region~bottom - region~top + 1) * gridHeight
    timestamp = region~sampleIndex * sampleSeconds
    box = .CameraBox~new('LUMA-' || lumaTrack~id || '-' || region~sampleIndex,x,y,width,height)
    observation = .CameraObservation~new(timestamp,box,1,1)
    ignored = track~addObservation(observation)
  end
  return track

::method tracks class
  use arg temporalTrackSet,gridWidth,gridHeight,sampleSeconds,minimumObservations
  if arg(5,'O') then minimumObservations = 2
  out = .array~new
  if temporalTrackSet == .nil then return out
  do lumaTrack over temporalTrackSet~tracks
    if lumaTrack~observationCount < minimumObservations then iterate
    converted = self~toCameraTrack(lumaTrack,gridWidth,gridHeight,sampleSeconds)
    if converted \== .nil then out~append(converted)
  end
  return out

::method behaviourVectors class
  use arg temporalTrackSet,gridWidth,gridHeight,sampleSeconds,minimumObservations
  if arg(5,'O') then minimumObservations = 2
  tracks = self~tracks(temporalTrackSet,gridWidth,gridHeight,sampleSeconds,minimumObservations)
  out = .array~new
  do track over tracks
    if track~pointCount < 2 then iterate
    out~append(.CameraTrackBehaviourVector~new(track))
  end
  return out

::method peerOutliers class
  use arg temporalTrackSet,gridWidth,gridHeight,sampleSeconds,minimumObservations,minimumPeers,scoreThreshold,minimumShiftedFeatures
  if arg(5,'O') then minimumObservations = 2
  if arg(6,'O') then minimumPeers = .CameraConstant~PEER_OUTLIER_MINIMUM_PEERS
  if arg(7,'O') then scoreThreshold = .CameraConstant~PEER_OUTLIER_SCORE_THRESHOLD
  if arg(8,'O') then minimumShiftedFeatures = .CameraConstant~PEER_OUTLIER_SHIFTED_FEATURES
  tracks = self~tracks(temporalTrackSet,gridWidth,gridHeight,sampleSeconds,minimumObservations)
  return .CameraPeerOutlierModel~assessTracks(tracks,minimumPeers,scoreThreshold,minimumShiftedFeatures)

::method quality class
  use arg temporalTrackSet,gridColumns,gridRows,minimumObservations,minimumScore
  if arg(2,'O') then gridColumns = 16
  if arg(3,'O') then gridRows = 9
  if arg(4,'O') then minimumObservations = 2
  if arg(5,'O') then minimumScore = 4
  return .CameraLumaPrimitiveQualitySet~new(temporalTrackSet,gridColumns,gridRows,minimumObservations,minimumScore)

::method qualifiedTracks class
  use arg temporalTrackSet,gridWidth,gridHeight,sampleSeconds,gridColumns,gridRows,minimumObservations,minimumScore
  if arg(5,'O') then gridColumns = 16
  if arg(6,'O') then gridRows = 9
  if arg(7,'O') then minimumObservations = 2
  if arg(8,'O') then minimumScore = 4

  qualitySet = self~quality(temporalTrackSet,gridColumns,gridRows,minimumObservations,minimumScore)
  out = .array~new
  if temporalTrackSet == .nil then return out
  do lumaTrack over temporalTrackSet~tracks
    assessment = qualitySet~assessment(lumaTrack~id)
    if assessment == .nil then iterate
    if \assessment~admitted then iterate
    converted = self~toCameraTrack(lumaTrack,gridWidth,gridHeight,sampleSeconds)
    if converted \== .nil then out~append(converted)
  end
  return out

::method qualifiedBehaviourVectors class
  use arg temporalTrackSet,gridWidth,gridHeight,sampleSeconds,gridColumns,gridRows,minimumObservations,minimumScore
  tracks = self~qualifiedTracks(temporalTrackSet,gridWidth,gridHeight,sampleSeconds,gridColumns,gridRows,minimumObservations,minimumScore)
  out = .array~new
  do track over tracks
    if track~pointCount < 2 then iterate
    out~append(.CameraTrackBehaviourVector~new(track))
  end
  return out

::method qualifiedPeerOutliers class
  use arg temporalTrackSet,gridWidth,gridHeight,sampleSeconds,gridColumns,gridRows,minimumObservations,minimumScore,minimumPeers,scoreThreshold,minimumShiftedFeatures
  if arg(9,'O') then minimumPeers = .CameraConstant~PEER_OUTLIER_MINIMUM_PEERS
  if arg(10,'O') then scoreThreshold = .CameraConstant~PEER_OUTLIER_SCORE_THRESHOLD
  if arg(11,'O') then minimumShiftedFeatures = .CameraConstant~PEER_OUTLIER_SHIFTED_FEATURES
  tracks = self~qualifiedTracks(temporalTrackSet,gridWidth,gridHeight,sampleSeconds,gridColumns,gridRows,minimumObservations,minimumScore)
  return .CameraPeerOutlierModel~assessTracks(tracks,minimumPeers,scoreThreshold,minimumShiftedFeatures)

::method segmentedPeerOutliers class
  use arg segmentedAnalysis,gridWidth,gridHeight,sampleSeconds,gridColumns,gridRows,minimumObservations,minimumScore,minimumPeers,scoreThreshold,minimumShiftedFeatures
  if arg(2,'O') then gridWidth=40
  if arg(3,'O') then gridHeight=40
  if arg(4,'O') then sampleSeconds=1
  if arg(5,'O') then gridColumns=16
  if arg(6,'O') then gridRows=9
  if arg(7,'O') then minimumObservations=2
  if arg(8,'O') then minimumScore=4
  if arg(9,'O') then minimumPeers=.CameraConstant~PEER_OUTLIER_MINIMUM_PEERS
  if arg(10,'O') then scoreThreshold=.CameraConstant~PEER_OUTLIER_SCORE_THRESHOLD
  if arg(11,'O') then minimumShiftedFeatures=.CameraConstant~PEER_OUTLIER_SHIFTED_FEATURES

  out=.array~new
  if segmentedAnalysis==.nil then return out
  do segment over segmentedAnalysis~segments
    vectors=self~qualifiedBehaviourVectors(segment~trackSet,gridWidth,gridHeight,sampleSeconds,gridColumns,gridRows,minimumObservations,minimumScore)
    peers=self~qualifiedPeerOutliers(segment~trackSet,gridWidth,gridHeight,sampleSeconds,gridColumns,gridRows,minimumObservations,minimumScore,minimumPeers,scoreThreshold,minimumShiftedFeatures)
    out~append(.CameraSegmentPeerAssessment~new(segment~id,segment~generation,vectors~items,peers))
  end
  return out

::requires 'CameraCore.cls'
::requires 'CameraFFmpegMediaSource.cls'
