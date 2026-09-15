/* AudioCore.cls - layered, view-selected audio evidence model v0.14 */

::class AudioConstant public
::constant PACKAGE_VERSION '0.20'
::constant ELEMENT_RAW 'RAW_FEED'
::constant ELEMENT_TRACK 'TRACK'
::constant ELEMENT_DERIVED 'DERIVED'
::constant VIEW_SPEECH 'SPEECH'
::constant VIEW_TRANSCRIPT 'TRANSCRIPT'
::constant VIEW_SCENE 'SCENE'
::constant VIEW_SPEAKER 'SPEAKER'
::constant VIEW_SPEAKER_EMBEDDING 'SPEAKER_EMBEDDING'
::constant VIEW_MUSIC_FINGERPRINT 'MUSIC_FINGERPRINT'
::constant VIEW_PROSODY 'PROSODY'
::constant VIEW_PITCH 'PITCH'
::constant VIEW_SPATIAL 'SPATIAL'
::constant VIEW_SIGNAL 'SIGNAL'
::constant VIEW_EVENT 'EVENT'
::constant VIEW_PROCESSING 'PROCESSING'
::constant VIEW_CUSTOM 'CUSTOM'

::class AudioUtil public
::method copyArray class
  use arg source
  target = .array~new
  if source == .nil then return target
  do item over source
    target~append(item)
  end
  return target

::method copyDirectory class
  use arg source
  target = .directory~new
  if source == .nil then return target
  supplier = source~supplier
  do while supplier~available
    target[supplier~index] = supplier~item
    supplier~next
  end
  return target

::method canonicalDirectory class
  use arg source
  if source == .nil then return ''
  lines = .array~new
  supplier = source~supplier
  do while supplier~available
    lines~append(supplier~index || '=' || supplier~item)
    supplier~next
  end
  lines~sort
  return self~joinArray(lines, ';')

::method idsText class
  use arg source
  if source == .nil then return ''
  a = self~copyArray(source)
  a~sort
  return self~joinArray(a, ',')

::method joinArray class
  use arg source, separator
  if source == .nil then return ''
  textValue = ''
  first = .true
  do item over source
    if \ first then textValue = textValue || separator
    textValue = textValue || item
    first = .false
  end
  return textValue


::class AudioSourceGroup public
::attribute id
::attribute description
::attribute memberHints
::attribute spatialHint
::attribute confidence
::attribute assessor
::attribute attributes

::method init
  expose id description memberHints spatialHint confidence assessor attributes
  use arg id, description, memberHints, spatialHint, confidence, assessor, attributes
  if arg(2,'O') then description = ''
  if arg(3,'O') then memberHints = .array~new
  if arg(4,'O') then spatialHint = ''
  if arg(5,'O') then confidence = 0
  if arg(6,'O') then assessor = ''
  if arg(7,'O') then attributes = .directory~new
  self~id = id
  self~description = description
  self~memberHints = .AudioUtil~copyArray(memberHints)
  self~spatialHint = spatialHint
  self~confidence = confidence
  self~assessor = assessor
  self~attributes = .AudioUtil~copyDirectory(attributes)

::method canonicalText
  return 'SOURCE_GROUP=' || self~id || '|description=' || self~description || '|members=' || .AudioUtil~idsText(self~memberHints) || '|spatial=' || self~spatialHint || '|confidence=' || self~confidence || '|assessor=' || self~assessor || '|attributes=' || .AudioUtil~canonicalDirectory(self~attributes)


::class AudioElement public
::attribute id
::attribute elementKind
::attribute mediaKind
::attribute durationMs
::attribute uri
::attribute description
::attribute parentIds
::attribute metadata
::attribute processingStepId

::method init
  expose id elementKind mediaKind durationMs uri description parentIds metadata processingStepId
  use arg id, elementKind, mediaKind, durationMs, uri, description, parentIds, metadata, processingStepId
  if arg(3,'O') then mediaKind = 'AUDIO'
  if arg(4,'O') then durationMs = 0
  if arg(5,'O') then uri = ''
  if arg(6,'O') then description = ''
  if arg(7,'O') then parentIds = .array~new
  if arg(8,'O') then metadata = .directory~new
  if arg(9,'O') then processingStepId = ''
  self~id = id
  self~elementKind = elementKind
  self~mediaKind = mediaKind
  self~durationMs = durationMs
  self~uri = uri
  self~description = description
  self~parentIds = .AudioUtil~copyArray(parentIds)
  self~metadata = .AudioUtil~copyDirectory(metadata)
  self~processingStepId = processingStepId

::method canonicalText
  return 'ELEMENT=' || self~id || '|kind=' || self~elementKind || '|media=' || self~mediaKind || '|durationMs=' || self~durationMs || '|uri=' || self~uri || '|parents=' || .AudioUtil~idsText(self~parentIds) || '|step=' || self~processingStepId || '|meta=' || .AudioUtil~canonicalDirectory(self~metadata)


::class AudioProcessingStep public
::attribute id
::attribute technique
::attribute family
::attribute inputIds
::attribute outputId
::attribute parameters
::attribute confidence
::attribute assessor
::attribute notes
::attribute startMs
::attribute endMs

::method init
  expose id technique family inputIds outputId parameters confidence assessor notes startMs endMs
  use arg id, technique, family, inputIds, outputId, parameters, confidence, assessor, notes, startMs, endMs
  if arg(3,'O') then family = 'OTHER'
  if arg(4,'O') then inputIds = .array~new
  if arg(6,'O') then parameters = .directory~new
  if arg(7,'O') then confidence = 1
  if arg(8,'O') then assessor = ''
  if arg(9,'O') then notes = ''
  if arg(10,'O') then startMs = 0
  if arg(11,'O') then endMs = -1
  self~id = id
  self~technique = technique
  self~family = family
  self~inputIds = .AudioUtil~copyArray(inputIds)
  self~outputId = outputId
  self~parameters = .AudioUtil~copyDirectory(parameters)
  self~confidence = confidence
  self~assessor = assessor
  self~notes = notes
  self~startMs = startMs
  self~endMs = endMs

::method canonicalText
  return 'PROCESS=' || self~id || '|family=' || self~family || '|technique=' || self~technique || '|inputs=' || .AudioUtil~idsText(self~inputIds) || '|output=' || self~outputId || '|startMs=' || self~startMs || '|endMs=' || self~endMs || '|confidence=' || self~confidence || '|parameters=' || .AudioUtil~canonicalDirectory(self~parameters) || '|assessor=' || self~assessor || '|notes=' || self~notes


::class AudioBoundary public
::attribute id
::attribute viewId
::attribute startMs
::attribute endMs
::attribute boundaryKind
::attribute label
::attribute confidence
::attribute assessor
::attribute sourceElementIds
::attribute attributes
::attribute evidence

::method init
  expose id viewId startMs endMs boundaryKind label confidence assessor sourceElementIds attributes evidence
  use arg id, viewId, startMs, endMs, boundaryKind, label, confidence, assessor, sourceElementIds, attributes, evidence
  if arg(5,'O') then boundaryKind = 'ASSESSMENT'
  if arg(6,'O') then label = ''
  if arg(7,'O') then confidence = 0
  if arg(8,'O') then assessor = ''
  if arg(9,'O') then sourceElementIds = .array~new
  if arg(10,'O') then attributes = .directory~new
  if arg(11,'O') then evidence = ''
  if endMs < startMs then raise syntax 93.900 array('Audio boundary end precedes start')
  self~id = id
  self~viewId = viewId
  self~startMs = startMs
  self~endMs = endMs
  self~boundaryKind = boundaryKind
  self~label = label
  self~confidence = confidence
  self~assessor = assessor
  self~sourceElementIds = .AudioUtil~copyArray(sourceElementIds)
  self~attributes = .AudioUtil~copyDirectory(attributes)
  self~evidence = evidence

::method durationMs
  return self~endMs - self~startMs

::method intersects
  use arg cutStartMs, cutEndMs
  return self~endMs > cutStartMs & self~startMs < cutEndMs

::method canonicalText
  return 'BOUNDARY=' || self~id || '|view=' || self~viewId || '|startMs=' || self~startMs || '|endMs=' || self~endMs || '|kind=' || self~boundaryKind || '|label=' || self~label || '|confidence=' || self~confidence || '|assessor=' || self~assessor || '|sources=' || .AudioUtil~idsText(self~sourceElementIds) || '|attributes=' || .AudioUtil~canonicalDirectory(self~attributes) || '|evidence=' || self~evidence


::class AudioView public
::attribute id
::attribute viewKind
::attribute description
::attribute methodology
::attribute attributes
::attribute sourceGroupId
::attribute hypothesisSetId
::attribute alternativeRank
::attribute focusDescription

::method init
  expose id viewKind description methodology attributes sourceGroupId hypothesisSetId alternativeRank focusDescription boundaries
  use arg id, viewKind, description, methodology, attributes, sourceGroupId, hypothesisSetId, alternativeRank, focusDescription
  if arg(2,'O') then viewKind = .AudioConstant~VIEW_CUSTOM
  if arg(3,'O') then description = ''
  if arg(4,'O') then methodology = ''
  if arg(5,'O') then attributes = .directory~new
  if arg(6,'O') then sourceGroupId = ''
  if arg(7,'O') then hypothesisSetId = ''
  if arg(8,'O') then alternativeRank = 0
  if arg(9,'O') then focusDescription = ''
  self~id = id
  self~viewKind = viewKind
  self~description = description
  self~methodology = methodology
  self~attributes = .AudioUtil~copyDirectory(attributes)
  self~sourceGroupId = sourceGroupId
  self~hypothesisSetId = hypothesisSetId
  self~alternativeRank = alternativeRank
  self~focusDescription = focusDescription
  boundaries = .array~new

::method addBoundary
  expose boundaries
  use arg boundary
  if boundary == .nil then return boundaries~items
  if boundary~viewId \= self~id then raise syntax 93.900 array('Boundary belongs to different view')
  boundaries~append(boundary)
  return boundaries~items

::method boundaries
  expose boundaries
  return .AudioUtil~copyArray(boundaries)

::method boundaryCount
  expose boundaries
  return boundaries~items

::method intersecting
  expose boundaries
  use arg cutStartMs, cutEndMs
  output = .array~new
  do boundary over boundaries
    if boundary~intersects(cutStartMs, cutEndMs) then output~append(boundary)
  end
  return output

::method canonicalText
  expose boundaries
  lines = .array~new
  lines~append('VIEW=' || self~id || '|kind=' || self~viewKind || '|methodology=' || self~methodology || '|sourceGroup=' || self~sourceGroupId || '|hypothesisSet=' || self~hypothesisSetId || '|alternativeRank=' || self~alternativeRank || '|focus=' || self~focusDescription || '|attributes=' || .AudioUtil~canonicalDirectory(self~attributes))
  bLines = .array~new
  do boundary over boundaries
    bLines~append(boundary~canonicalText)
  end
  bLines~sort
  do line over bLines
    lines~append(line)
  end
  return lines~makeString('L')


::class AudioCutElement public
::attribute viewId
::attribute boundaryId
::attribute boundaryKind
::attribute label
::attribute confidence
::attribute originalStartMs
::attribute originalEndMs
::attribute clippedStartMs
::attribute clippedEndMs
::attribute cutRelativeStartMs
::attribute cutRelativeEndMs
::attribute boundaryOffsetStartMs
::attribute boundaryOffsetEndMs
::attribute sourceElementIds
::attribute attributes
::attribute evidence

::method init
  expose viewId boundaryId boundaryKind label confidence originalStartMs originalEndMs clippedStartMs clippedEndMs cutRelativeStartMs cutRelativeEndMs boundaryOffsetStartMs boundaryOffsetEndMs sourceElementIds attributes evidence
  use arg boundary, cutStartMs, cutEndMs
  viewId = boundary~viewId
  boundaryId = boundary~id
  boundaryKind = boundary~boundaryKind
  label = boundary~label
  confidence = boundary~confidence
  originalStartMs = boundary~startMs
  originalEndMs = boundary~endMs
  clippedStartMs = max(boundary~startMs, cutStartMs)
  clippedEndMs = min(boundary~endMs, cutEndMs)
  cutRelativeStartMs = clippedStartMs - cutStartMs
  cutRelativeEndMs = clippedEndMs - cutStartMs
  boundaryOffsetStartMs = clippedStartMs - boundary~startMs
  boundaryOffsetEndMs = clippedEndMs - boundary~startMs
  sourceElementIds = .AudioUtil~copyArray(boundary~sourceElementIds)
  attributes = .AudioUtil~copyDirectory(boundary~attributes)
  evidence = boundary~evidence

::method canonicalText
  return 'CUT_ELEMENT=' || self~viewId || ':' || self~boundaryId || '|original=' || self~originalStartMs || '-' || self~originalEndMs || '|clipped=' || self~clippedStartMs || '-' || self~clippedEndMs || '|relative=' || self~cutRelativeStartMs || '-' || self~cutRelativeEndMs || '|offset=' || self~boundaryOffsetStartMs || '-' || self~boundaryOffsetEndMs || '|label=' || self~label || '|confidence=' || self~confidence


::class AudioPitchObservation public
::attribute id
::attribute seriesId
::attribute viewId
::attribute timeMs
::attribute hz
::attribute confidence
::attribute voicedProbability
::attribute method
::attribute sourceElementIds
::attribute attributes

::method init
  expose id seriesId viewId timeMs hz confidence voicedProbability method sourceElementIds attributes
  use arg id, seriesId, viewId, timeMs, hz, confidence, voicedProbability, method, sourceElementIds, attributes
  if arg(6,'O') then confidence = 0
  if arg(7,'O') then voicedProbability = -1
  if arg(8,'O') then method = ''
  if arg(9,'O') then sourceElementIds = .array~new
  if arg(10,'O') then attributes = .directory~new
  self~id = id
  self~seriesId = seriesId
  self~viewId = viewId
  self~timeMs = timeMs
  self~hz = hz
  self~confidence = confidence
  self~voicedProbability = voicedProbability
  self~method = method
  self~sourceElementIds = .AudioUtil~copyArray(sourceElementIds)
  self~attributes = .AudioUtil~copyDirectory(attributes)

::method canonicalText
  return 'PITCH_OBSERVATION=' || self~id || '|series=' || self~seriesId || '|view=' || self~viewId || '|timeMs=' || self~timeMs || '|hz=' || self~hz || '|confidence=' || self~confidence || '|voicedProbability=' || self~voicedProbability || '|method=' || self~method || '|sources=' || .AudioUtil~idsText(self~sourceElementIds) || '|attributes=' || .AudioUtil~canonicalDirectory(self~attributes)


::class AudioPitchSeries public
::attribute id
::attribute viewId
::attribute method
::attribute description
::attribute attributes

::method init
  expose id viewId method description attributes observations
  use arg id, viewId, method, description, attributes
  if arg(3,'O') then method = ''
  if arg(4,'O') then description = ''
  if arg(5,'O') then attributes = .directory~new
  self~id = id
  self~viewId = viewId
  self~method = method
  self~description = description
  self~attributes = .AudioUtil~copyDirectory(attributes)
  observations = .array~new

::method addObservation
  expose observations
  use arg observation
  if observation == .nil then return observations~items
  if observation~seriesId \= self~id then raise syntax 93.900 array('Pitch observation belongs to different series')
  if observation~viewId \= self~viewId then raise syntax 93.900 array('Pitch observation belongs to different view')
  observations~append(observation)
  return observations~items

::method observations
  expose observations
  return .AudioUtil~copyArray(observations)

::method observationsBetween
  expose observations
  use arg startMs, endMs
  output = .array~new
  do observation over observations
    if observation~timeMs >= startMs & observation~timeMs < endMs then output~append(observation)
  end
  return output

::method canonicalText
  expose observations
  lines = .array~new
  lines~append('PITCH_SERIES=' || self~id || '|view=' || self~viewId || '|method=' || self~method || '|description=' || self~description || '|attributes=' || .AudioUtil~canonicalDirectory(self~attributes))
  oLines = .array~new
  do observation over observations
    oLines~append(observation~canonicalText)
  end
  oLines~sort
  do line over oLines
    lines~append(line)
  end
  return lines~makeString('L')


::class AudioPitchCutObservation public
::attribute seriesId
::attribute observationId
::attribute viewId
::attribute absoluteTimeMs
::attribute cutRelativeTimeMs
::attribute hz
::attribute confidence
::attribute voicedProbability
::attribute method
::attribute sourceElementIds
::attribute attributes

::method init
  expose seriesId observationId viewId absoluteTimeMs cutRelativeTimeMs hz confidence voicedProbability method sourceElementIds attributes
  use arg observation, cutStartMs
  seriesId = observation~seriesId
  observationId = observation~id
  viewId = observation~viewId
  absoluteTimeMs = observation~timeMs
  cutRelativeTimeMs = observation~timeMs - cutStartMs
  hz = observation~hz
  confidence = observation~confidence
  voicedProbability = observation~voicedProbability
  method = observation~method
  sourceElementIds = .AudioUtil~copyArray(observation~sourceElementIds)
  attributes = .AudioUtil~copyDirectory(observation~attributes)

::method canonicalText
  return 'PITCH_CUT=' || self~viewId || ':' || self~seriesId || ':' || self~observationId || '|absoluteMs=' || self~absoluteTimeMs || '|relativeMs=' || self~cutRelativeTimeMs || '|hz=' || self~hz || '|confidence=' || self~confidence || '|voicedProbability=' || self~voicedProbability || '|method=' || self~method


::class AudioSpeakerModel public
::attribute id
::attribute provider
::attribute family
::attribute source
::attribute modelRevision
::attribute embeddingDimension
::attribute sampleRateHz
::attribute channelPolicy
::attribute preprocessing
::attribute scoreMetric
::attribute defaultThreshold
::attribute attributes

::method init
  expose id provider family source modelRevision embeddingDimension sampleRateHz channelPolicy preprocessing scoreMetric defaultThreshold attributes
  use arg id, provider, family, source, modelRevision, embeddingDimension, sampleRateHz, channelPolicy, preprocessing, scoreMetric, defaultThreshold, attributes
  if arg(2,'O') then provider = ''
  if arg(3,'O') then family = ''
  if arg(4,'O') then source = ''
  if arg(5,'O') then modelRevision = ''
  if arg(6,'O') then embeddingDimension = 0
  if arg(7,'O') then sampleRateHz = 0
  if arg(8,'O') then channelPolicy = ''
  if arg(9,'O') then preprocessing = .directory~new
  if arg(10,'O') then scoreMetric = 'COSINE_SIMILARITY'
  if arg(11,'O') then defaultThreshold = ''
  if arg(12,'O') then attributes = .directory~new
  self~id = id
  self~provider = provider
  self~family = family
  self~source = source
  self~modelRevision = modelRevision
  self~embeddingDimension = embeddingDimension
  self~sampleRateHz = sampleRateHz
  self~channelPolicy = channelPolicy
  self~preprocessing = .AudioUtil~copyDirectory(preprocessing)
  self~scoreMetric = scoreMetric
  self~defaultThreshold = defaultThreshold
  self~attributes = .AudioUtil~copyDirectory(attributes)

::method canonicalText
  return 'SPEAKER_MODEL=' || self~id || '|provider=' || self~provider || '|family=' || self~family || '|source=' || self~source || '|revision=' || self~modelRevision || '|dimension=' || self~embeddingDimension || '|sampleRateHz=' || self~sampleRateHz || '|channelPolicy=' || self~channelPolicy || '|metric=' || self~scoreMetric || '|defaultThreshold=' || self~defaultThreshold || '|preprocessing=' || .AudioUtil~canonicalDirectory(self~preprocessing) || '|attributes=' || .AudioUtil~canonicalDirectory(self~attributes)


::class AudioSpeakerEmbedding public
::attribute id
::attribute viewId
::attribute modelId
::attribute startMs
::attribute endMs
::attribute sourceElementIds
::attribute sourceGroupId
::attribute vector
::attribute qualityConfidence
::attribute speechDurationMs
::attribute extractionMethod
::attribute preprocessingHash
::attribute attributes

::method init
  expose id viewId modelId startMs endMs sourceElementIds sourceGroupId vector qualityConfidence speechDurationMs extractionMethod preprocessingHash attributes
  use arg id, viewId, modelId, startMs, endMs, sourceElementIds, sourceGroupId, vector, qualityConfidence, speechDurationMs, extractionMethod, preprocessingHash, attributes
  if arg(6,'O') then sourceElementIds = .array~new
  if arg(7,'O') then sourceGroupId = ''
  if arg(8,'O') then vector = .array~new
  if arg(9,'O') then qualityConfidence = 0
  if arg(10,'O') then speechDurationMs = endMs-startMs
  if arg(11,'O') then extractionMethod = ''
  if arg(12,'O') then preprocessingHash = ''
  if arg(13,'O') then attributes = .directory~new
  self~id = id
  self~viewId = viewId
  self~modelId = modelId
  self~startMs = startMs
  self~endMs = endMs
  self~sourceElementIds = .AudioUtil~copyArray(sourceElementIds)
  self~sourceGroupId = sourceGroupId
  self~vector = .AudioUtil~copyArray(vector)
  self~qualityConfidence = qualityConfidence
  self~speechDurationMs = speechDurationMs
  self~extractionMethod = extractionMethod
  self~preprocessingHash = preprocessingHash
  self~attributes = .AudioUtil~copyDirectory(attributes)

::method dimension
  return self~vector~items

::method intersects
  use arg cutStartMs, cutEndMs
  return self~startMs < cutEndMs & self~endMs > cutStartMs

::method canonicalText
  return 'SPEAKER_EMBEDDING=' || self~id || '|view=' || self~viewId || '|model=' || self~modelId || '|time=' || self~startMs || '-' || self~endMs || '|sources=' || .AudioUtil~idsText(self~sourceElementIds) || '|sourceGroup=' || self~sourceGroupId || '|dimension=' || self~dimension || '|vector=' || .AudioUtil~joinArray(self~vector, ',') || '|quality=' || self~qualityConfidence || '|speechDurationMs=' || self~speechDurationMs || '|method=' || self~extractionMethod || '|preprocessingHash=' || self~preprocessingHash || '|attributes=' || .AudioUtil~canonicalDirectory(self~attributes)


::class AudioSpeakerComparison public
::attribute id
::attribute viewId
::attribute modelId
::attribute embeddingAId
::attribute embeddingBId
::attribute score
::attribute metric
::attribute threshold
::attribute decision
::attribute calibratedProbability
::attribute confidence
::attribute attributes

::method init
  expose id viewId modelId embeddingAId embeddingBId score metric threshold decision calibratedProbability confidence attributes
  use arg id, viewId, modelId, embeddingAId, embeddingBId, score, metric, threshold, decision, calibratedProbability, confidence, attributes
  if arg(7,'O') then metric = 'COSINE_SIMILARITY'
  if arg(8,'O') then threshold = ''
  if arg(9,'O') then decision = 'UNASSESSED'
  if arg(10,'O') then calibratedProbability = ''
  if arg(11,'O') then confidence = 0
  if arg(12,'O') then attributes = .directory~new
  self~id = id
  self~viewId = viewId
  self~modelId = modelId
  self~embeddingAId = embeddingAId
  self~embeddingBId = embeddingBId
  self~score = score
  self~metric = metric
  self~threshold = threshold
  self~decision = decision
  self~calibratedProbability = calibratedProbability
  self~confidence = confidence
  self~attributes = .AudioUtil~copyDirectory(attributes)

::method canonicalText
  return 'SPEAKER_COMPARE=' || self~id || '|view=' || self~viewId || '|model=' || self~modelId || '|a=' || self~embeddingAId || '|b=' || self~embeddingBId || '|score=' || self~score || '|metric=' || self~metric || '|threshold=' || self~threshold || '|decision=' || self~decision || '|calibratedProbability=' || self~calibratedProbability || '|confidence=' || self~confidence || '|attributes=' || .AudioUtil~canonicalDirectory(self~attributes)


::class AudioSpeakerCutEmbedding public
::attribute embeddingId
::attribute viewId
::attribute modelId
::attribute originalStartMs
::attribute originalEndMs
::attribute clippedStartMs
::attribute clippedEndMs
::attribute cutRelativeStartMs
::attribute cutRelativeEndMs
::attribute embeddingOffsetStartMs
::attribute embeddingOffsetEndMs
::attribute sourceGroupId
::attribute qualityConfidence
::attribute dimension
::attribute preprocessingHash

::method init
  expose embeddingId viewId modelId originalStartMs originalEndMs clippedStartMs clippedEndMs cutRelativeStartMs cutRelativeEndMs embeddingOffsetStartMs embeddingOffsetEndMs sourceGroupId qualityConfidence dimension preprocessingHash
  use arg embedding, cutStartMs, cutEndMs
  embeddingId = embedding~id
  viewId = embedding~viewId
  modelId = embedding~modelId
  originalStartMs = embedding~startMs
  originalEndMs = embedding~endMs
  clippedStartMs = max(embedding~startMs, cutStartMs)
  clippedEndMs = min(embedding~endMs, cutEndMs)
  cutRelativeStartMs = clippedStartMs-cutStartMs
  cutRelativeEndMs = clippedEndMs-cutStartMs
  embeddingOffsetStartMs = clippedStartMs-embedding~startMs
  embeddingOffsetEndMs = clippedEndMs-embedding~startMs
  sourceGroupId = embedding~sourceGroupId
  qualityConfidence = embedding~qualityConfidence
  dimension = embedding~dimension
  preprocessingHash = embedding~preprocessingHash

::method canonicalText
  return 'SPEAKER_CUT=' || self~viewId || ':' || self~embeddingId || '|model=' || self~modelId || '|original=' || self~originalStartMs || '-' || self~originalEndMs || '|clipped=' || self~clippedStartMs || '-' || self~clippedEndMs || '|relative=' || self~cutRelativeStartMs || '-' || self~cutRelativeEndMs || '|offset=' || self~embeddingOffsetStartMs || '-' || self~embeddingOffsetEndMs || '|sourceGroup=' || self~sourceGroupId || '|quality=' || self~qualityConfidence || '|dimension=' || self~dimension || '|preprocessingHash=' || self~preprocessingHash


::class AudioFingerprintModel public
::attribute id
::attribute provider
::attribute algorithm
::attribute implementation
::attribute algorithmRevision
::attribute expectedSampleRateHz
::attribute preprocessing
::attribute attributes

::method init
  expose id provider algorithm implementation algorithmRevision expectedSampleRateHz preprocessing attributes
  use arg id, provider, algorithm, implementation, algorithmRevision, expectedSampleRateHz, preprocessing, attributes
  if arg(2,'O') then provider = ''
  if arg(3,'O') then algorithm = ''
  if arg(4,'O') then implementation = ''
  if arg(5,'O') then algorithmRevision = ''
  if arg(6,'O') then expectedSampleRateHz = 0
  if arg(7,'O') then preprocessing = .directory~new
  if arg(8,'O') then attributes = .directory~new
  self~id = id
  self~provider = provider
  self~algorithm = algorithm
  self~implementation = implementation
  self~algorithmRevision = algorithmRevision
  self~expectedSampleRateHz = expectedSampleRateHz
  self~preprocessing = .AudioUtil~copyDirectory(preprocessing)
  self~attributes = .AudioUtil~copyDirectory(attributes)

::method canonicalText
  return 'FINGERPRINT_MODEL=' || self~id || '|provider=' || self~provider || '|algorithm=' || self~algorithm || '|implementation=' || self~implementation || '|revision=' || self~algorithmRevision || '|sampleRateHz=' || self~expectedSampleRateHz || '|preprocessing=' || .AudioUtil~canonicalDirectory(self~preprocessing) || '|attributes=' || .AudioUtil~canonicalDirectory(self~attributes)


::class AudioMusicFingerprint public
::attribute id
::attribute viewId
::attribute modelId
::attribute startMs
::attribute endMs
::attribute sourceElementIds
::attribute fingerprint
::attribute fingerprintEncoding
::attribute durationSeconds
::attribute qualityConfidence
::attribute preprocessingHash
::attribute attributes

::method init
  expose id viewId modelId startMs endMs sourceElementIds fingerprint fingerprintEncoding durationSeconds qualityConfidence preprocessingHash attributes
  use arg id, viewId, modelId, startMs, endMs, sourceElementIds, fingerprint, fingerprintEncoding, durationSeconds, qualityConfidence, preprocessingHash, attributes
  if arg(6,'O') then sourceElementIds = .array~new
  if arg(8,'O') then fingerprintEncoding = ''
  if arg(9,'O') then durationSeconds = (endMs-startMs)/1000
  if arg(10,'O') then qualityConfidence = 0
  if arg(11,'O') then preprocessingHash = ''
  if arg(12,'O') then attributes = .directory~new
  if endMs < startMs then raise syntax 93.900 array('Music fingerprint end precedes start')
  self~id = id
  self~viewId = viewId
  self~modelId = modelId
  self~startMs = startMs
  self~endMs = endMs
  self~sourceElementIds = .AudioUtil~copyArray(sourceElementIds)
  self~fingerprint = fingerprint
  self~fingerprintEncoding = fingerprintEncoding
  self~durationSeconds = durationSeconds
  self~qualityConfidence = qualityConfidence
  self~preprocessingHash = preprocessingHash
  self~attributes = .AudioUtil~copyDirectory(attributes)

::method intersects
  use arg cutStartMs, cutEndMs
  return self~startMs < cutEndMs & self~endMs > cutStartMs

::method canonicalText
  return 'MUSIC_FINGERPRINT=' || self~id || '|view=' || self~viewId || '|model=' || self~modelId || '|time=' || self~startMs || '-' || self~endMs || '|durationSeconds=' || self~durationSeconds || '|encoding=' || self~fingerprintEncoding || '|fingerprint=' || self~fingerprint || '|quality=' || self~qualityConfidence || '|preprocessingHash=' || self~preprocessingHash || '|sources=' || .AudioUtil~idsText(self~sourceElementIds) || '|attributes=' || .AudioUtil~canonicalDirectory(self~attributes)


::class AudioMusicIdentification public
::attribute id
::attribute viewId
::attribute fingerprintId
::attribute provider
::attribute providerRevision
::attribute score
::attribute decision
::attribute acoustidTrackId
::attribute recordingIds
::attribute releaseIds
::attribute queryMetadata
::attribute responseHash
::attribute confidence
::attribute attributes

::method init
  expose id viewId fingerprintId provider providerRevision score decision acoustidTrackId recordingIds releaseIds queryMetadata responseHash confidence attributes
  use arg id, viewId, fingerprintId, provider, providerRevision, score, decision, acoustidTrackId, recordingIds, releaseIds, queryMetadata, responseHash, confidence, attributes
  if arg(4,'O') then provider = ''
  if arg(5,'O') then providerRevision = ''
  if arg(6,'O') then score = ''
  if arg(7,'O') then decision = 'UNASSESSED'
  if arg(8,'O') then acoustidTrackId = ''
  if arg(9,'O') then recordingIds = .array~new
  if arg(10,'O') then releaseIds = .array~new
  if arg(11,'O') then queryMetadata = .directory~new
  if arg(12,'O') then responseHash = ''
  if arg(13,'O') then confidence = 0
  if arg(14,'O') then attributes = .directory~new
  self~id = id
  self~viewId = viewId
  self~fingerprintId = fingerprintId
  self~provider = provider
  self~providerRevision = providerRevision
  self~score = score
  self~decision = decision
  self~acoustidTrackId = acoustidTrackId
  self~recordingIds = .AudioUtil~copyArray(recordingIds)
  self~releaseIds = .AudioUtil~copyArray(releaseIds)
  self~queryMetadata = .AudioUtil~copyDirectory(queryMetadata)
  self~responseHash = responseHash
  self~confidence = confidence
  self~attributes = .AudioUtil~copyDirectory(attributes)

::method canonicalText
  return 'MUSIC_IDENTIFICATION=' || self~id || '|view=' || self~viewId || '|fingerprint=' || self~fingerprintId || '|provider=' || self~provider || '|providerRevision=' || self~providerRevision || '|score=' || self~score || '|decision=' || self~decision || '|trackId=' || self~acoustidTrackId || '|recordingIds=' || .AudioUtil~idsText(self~recordingIds) || '|releaseIds=' || .AudioUtil~idsText(self~releaseIds) || '|query=' || .AudioUtil~canonicalDirectory(self~queryMetadata) || '|responseHash=' || self~responseHash || '|confidence=' || self~confidence || '|attributes=' || .AudioUtil~canonicalDirectory(self~attributes)


::class AudioMusicFingerprintCut public
::attribute fingerprintId
::attribute viewId
::attribute modelId
::attribute originalStartMs
::attribute originalEndMs
::attribute clippedStartMs
::attribute clippedEndMs
::attribute cutRelativeStartMs
::attribute cutRelativeEndMs
::attribute fingerprintOffsetStartMs
::attribute fingerprintOffsetEndMs
::attribute durationSeconds
::attribute qualityConfidence
::attribute preprocessingHash

::method init
  expose fingerprintId viewId modelId originalStartMs originalEndMs clippedStartMs clippedEndMs cutRelativeStartMs cutRelativeEndMs fingerprintOffsetStartMs fingerprintOffsetEndMs durationSeconds qualityConfidence preprocessingHash
  use arg fp, cutStartMs, cutEndMs
  fingerprintId = fp~id
  viewId = fp~viewId
  modelId = fp~modelId
  originalStartMs = fp~startMs
  originalEndMs = fp~endMs
  clippedStartMs = max(fp~startMs, cutStartMs)
  clippedEndMs = min(fp~endMs, cutEndMs)
  cutRelativeStartMs = clippedStartMs-cutStartMs
  cutRelativeEndMs = clippedEndMs-cutStartMs
  fingerprintOffsetStartMs = clippedStartMs-fp~startMs
  fingerprintOffsetEndMs = clippedEndMs-fp~startMs
  durationSeconds = fp~durationSeconds
  qualityConfidence = fp~qualityConfidence
  preprocessingHash = fp~preprocessingHash

::method canonicalText
  return 'MUSIC_FINGERPRINT_CUT=' || self~viewId || ':' || self~fingerprintId || '|model=' || self~modelId || '|original=' || self~originalStartMs || '-' || self~originalEndMs || '|clipped=' || self~clippedStartMs || '-' || self~clippedEndMs || '|relative=' || self~cutRelativeStartMs || '-' || self~cutRelativeEndMs || '|offset=' || self~fingerprintOffsetStartMs || '-' || self~fingerprintOffsetEndMs || '|quality=' || self~qualityConfidence || '|preprocessingHash=' || self~preprocessingHash


::class AudioCutView public
::attribute viewId
::attribute viewKind

::method init
  expose viewId viewKind elements pitchObservations speakerEmbeddings musicFingerprints
  use arg view
  viewId = view~id
  viewKind = view~viewKind
  elements = .array~new
  pitchObservations = .array~new
  speakerEmbeddings = .array~new
  musicFingerprints = .array~new

::method add
  expose elements
  use arg element
  elements~append(element)
  return elements~items

::method elements
  expose elements
  return .AudioUtil~copyArray(elements)

::method elementCount
  expose elements
  return elements~items

::method addPitchObservation
  expose pitchObservations
  use arg observation
  pitchObservations~append(observation)
  return pitchObservations~items

::method pitchObservations
  expose pitchObservations
  return .AudioUtil~copyArray(pitchObservations)

::method pitchObservationCount
  expose pitchObservations
  return pitchObservations~items

::method addSpeakerEmbedding
  expose speakerEmbeddings
  use arg embedding
  speakerEmbeddings~append(embedding)
  return speakerEmbeddings~items

::method speakerEmbeddings
  expose speakerEmbeddings
  return .AudioUtil~copyArray(speakerEmbeddings)

::method speakerEmbeddingCount
  expose speakerEmbeddings
  return speakerEmbeddings~items

::method addMusicFingerprint
  expose musicFingerprints
  use arg fingerprint
  musicFingerprints~append(fingerprint)
  return musicFingerprints~items

::method musicFingerprints
  expose musicFingerprints
  return .AudioUtil~copyArray(musicFingerprints)

::method musicFingerprintCount
  expose musicFingerprints
  return musicFingerprints~items


::class AudioThroughCut public
::attribute startMs
::attribute endMs
::attribute selectedViewId

::method init
  expose startMs endMs selectedViewId views
  use arg startMs, endMs, selectedViewId
  if arg(3,'O') then selectedViewId = ''
  if endMs < startMs then raise syntax 93.900 array('Cut end precedes start')
  self~startMs = startMs
  self~endMs = endMs
  self~selectedViewId = selectedViewId
  views = .directory~new

::method addView
  expose views
  use arg cutView
  views[cutView~viewId] = cutView
  return views~items

::method view
  expose views
  use arg viewId
  if views~hasIndex(viewId) then return views[viewId]
  return .nil

::method views
  expose views
  return .AudioUtil~copyDirectory(views)

::method viewCount
  expose views
  return views~items

::method allElements
  expose views
  output = .array~new
  supplier = views~supplier
  do while supplier~available
    cutView = supplier~item
    supplier~next
    do item over cutView~elements
      output~append(item)
    end
  end
  return output

::method canonicalText
  expose views
  lines = .array~new
  lines~append('THROUGH_CUT=' || self~startMs || '-' || self~endMs || '|selected=' || self~selectedViewId)
  eLines = .array~new
  do item over self~allElements
    eLines~append(item~canonicalText)
  end
  eLines~sort
  do line over eLines
    lines~append(line)
  end
  return lines~makeString('L')


::class AudioFragment public
::attribute id
::attribute startMs
::attribute endMs
::attribute overlapLeftMs
::attribute overlapRightMs
::attribute sourceElementIds
::attribute attributes

::method init
  expose id startMs endMs overlapLeftMs overlapRightMs sourceElementIds attributes
  use arg id, startMs, endMs, overlapLeftMs, overlapRightMs, sourceElementIds, attributes
  if arg(4,'O') then overlapLeftMs = 0
  if arg(5,'O') then overlapRightMs = 0
  if arg(6,'O') then sourceElementIds = .array~new
  if arg(7,'O') then attributes = .directory~new
  if endMs < startMs then raise syntax 93.900 array('Audio fragment end precedes start')
  self~id = id
  self~startMs = startMs
  self~endMs = endMs
  self~overlapLeftMs = overlapLeftMs
  self~overlapRightMs = overlapRightMs
  self~sourceElementIds = .AudioUtil~copyArray(sourceElementIds)
  self~attributes = .AudioUtil~copyDirectory(attributes)

::method durationMs
  return self~endMs - self~startMs

::method intersects
  use arg s, e
  return self~endMs > s & self~startMs < e

::method canonicalText
  return 'FRAGMENT=' || self~id || '|startMs=' || self~startMs || '|endMs=' || self~endMs || '|overlapLeftMs=' || self~overlapLeftMs || '|overlapRightMs=' || self~overlapRightMs || '|sources=' || .AudioUtil~idsText(self~sourceElementIds) || '|attributes=' || .AudioUtil~canonicalDirectory(self~attributes)

::class AudioFragmentation public
::attribute id
::attribute strategy
::attribute description
::attribute attributes

::method init
  expose id strategy description attributes fragments
  use arg id, strategy, description, attributes
  if arg(2,'O') then strategy = 'CUSTOM'
  if arg(3,'O') then description = ''
  if arg(4,'O') then attributes = .directory~new
  self~id = id
  self~strategy = strategy
  self~description = description
  self~attributes = .AudioUtil~copyDirectory(attributes)
  fragments = .array~new

::method addFragment
  expose fragments
  use arg fragment
  fragments~append(fragment)
  return fragments~items

::method fragments
  expose fragments
  return .AudioUtil~copyArray(fragments)

::method intersecting
  expose fragments
  use arg s, e
  out=.array~new
  do f over fragments
    if f~intersects(s,e) then out~append(f)
  end
  return out

::method canonicalText
  expose fragments
  lines=.array~new
  lines~append('FRAGMENTATION=' || self~id || '|strategy=' || self~strategy || '|description=' || self~description || '|attributes=' || .AudioUtil~canonicalDirectory(self~attributes))
  fLines=.array~new
  do f over fragments
    fLines~append(f~canonicalText)
  end
  fLines~sort
  do line over fLines
    lines~append(line)
  end
  return lines~makeString('L')

::class AudioFragmentComparison public
::attribute id
::attribute fragmentationIdA
::attribute fragmentIdA
::attribute fragmentationIdB
::attribute fragmentIdB
::attribute startMs
::attribute endMs
::attribute relation
::attribute score
::attribute attributes

::method init
  expose id fragmentationIdA fragmentIdA fragmentationIdB fragmentIdB startMs endMs relation score attributes
  use arg id, fragmentationIdA, fragmentIdA, fragmentationIdB, fragmentIdB, startMs, endMs, relation, score, attributes
  if arg(8,'O') then relation='OVERLAP'
  if arg(9,'O') then score=0
  if arg(10,'O') then attributes=.directory~new
  self~id=id
  self~fragmentationIdA=fragmentationIdA
  self~fragmentIdA=fragmentIdA
  self~fragmentationIdB=fragmentationIdB
  self~fragmentIdB=fragmentIdB
  self~startMs=startMs
  self~endMs=endMs
  self~relation=relation
  self~score=score
  self~attributes=.AudioUtil~copyDirectory(attributes)

::method canonicalText
  return 'FRAGMENT_COMPARE=' || self~id || '|a=' || self~fragmentationIdA || ':' || self~fragmentIdA || '|b=' || self~fragmentationIdB || ':' || self~fragmentIdB || '|startMs=' || self~startMs || '|endMs=' || self~endMs || '|relation=' || self~relation || '|score=' || self~score || '|attributes=' || .AudioUtil~canonicalDirectory(self~attributes)


::class AudioRecording public
::attribute id
::attribute durationMs
::attribute selectedViewId

::method init
  expose id durationMs selectedViewId elements processingSteps views sourceGroups fragmentations fragmentComparisons pitchSeries speakerModels speakerEmbeddings speakerComparisons fingerprintModels musicFingerprints musicIdentifications
  use arg id, durationMs
  if arg(2,'O') then durationMs = 0
  self~id = id
  self~durationMs = durationMs
  selectedViewId = ''
  elements = .directory~new
  processingSteps = .directory~new
  views = .directory~new
  sourceGroups = .directory~new
  fragmentations = .directory~new
  fragmentComparisons = .array~new
  pitchSeries = .directory~new
  speakerModels = .directory~new
  speakerEmbeddings = .directory~new
  speakerComparisons = .array~new
  fingerprintModels = .directory~new
  musicFingerprints = .directory~new
  musicIdentifications = .array~new

::method addSourceGroup
  expose sourceGroups
  use arg group
  if group == .nil then return sourceGroups~items
  sourceGroups[group~id] = group
  return sourceGroups~items

::method createSourceGroup
  use arg id, description, memberHints, spatialHint, confidence, assessor, attributes
  group = .AudioSourceGroup~new(id, description, memberHints, spatialHint, confidence, assessor, attributes)
  self~addSourceGroup(group)
  return group

::method sourceGroup
  expose sourceGroups
  use arg id
  if sourceGroups~hasIndex(id) then return sourceGroups[id]
  return .nil

::method sourceGroups
  expose sourceGroups
  return .AudioUtil~copyDirectory(sourceGroups)

::method addElement
  expose elements
  use arg element
  if element == .nil then return elements~items
  elements[element~id] = element
  return elements~items

::method addRawFeed
  use arg id, durationMs, uri, description, metadata
  parents = .array~new
  element = .AudioElement~new(id, .AudioConstant~ELEMENT_RAW, 'AUDIO', durationMs, uri, description, parents, metadata, '')
  self~addElement(element)
  return element

::method addTrack
  use arg id, durationMs, uri, description, parentIds, metadata
  element = .AudioElement~new(id, .AudioConstant~ELEMENT_TRACK, 'AUDIO', durationMs, uri, description, parentIds, metadata, '')
  self~addElement(element)
  return element

::method addDerived
  expose processingSteps
  use arg id, durationMs, uri, description, parentIds, metadata, stepId, technique, family, parameters, confidence, assessor, notes, startMs, endMs
  if arg(15,'O') then endMs = -1
  element = .AudioElement~new(id, .AudioConstant~ELEMENT_DERIVED, 'AUDIO', durationMs, uri, description, parentIds, metadata, stepId)
  self~addElement(element)
  step = .AudioProcessingStep~new(stepId, technique, family, parentIds, id, parameters, confidence, assessor, notes, startMs, endMs)
  processingSteps[stepId] = step
  return element

::method element
  expose elements
  use arg id
  if elements~hasIndex(id) then return elements[id]
  return .nil

::method processingStep
  expose processingSteps
  use arg id
  if processingSteps~hasIndex(id) then return processingSteps[id]
  return .nil

::method processingSteps
  expose processingSteps
  return .AudioUtil~copyDirectory(processingSteps)

::method lineageOf
  expose elements
  use arg elementId
  output = .array~new
  visited = .set~new
  ignored = self~appendLineage(elementId, output, visited)
  return output

::method appendLineage private
  expose elements
  use arg elementId, output, visited
  if visited~hasIndex(elementId) then return .true
  visited[elementId] = elementId
  if \ elements~hasIndex(elementId) then return .true
  element = elements[elementId]
  do parentId over element~parentIds
    ignored = self~appendLineage(parentId, output, visited)
  end
  output~append(element)
  return .true

::method addView
  expose views selectedViewId
  use arg view
  views[view~id] = view
  if selectedViewId = '' then selectedViewId = view~id
  return views~items

::method createView
  use arg id, viewKind, description, methodology, attributes, sourceGroupId, hypothesisSetId, alternativeRank, focusDescription
  if arg(6,'O') then sourceGroupId = ''
  if arg(7,'O') then hypothesisSetId = ''
  if arg(8,'O') then alternativeRank = 0
  if arg(9,'O') then focusDescription = ''
  view = .AudioView~new(id, viewKind, description, methodology, attributes, sourceGroupId, hypothesisSetId, alternativeRank, focusDescription)
  self~addView(view)
  return view

::method createTranscriptView
  use arg id, description, methodology, sourceGroupId, hypothesisSetId, alternativeRank, focusDescription, attributes
  if arg(8,'O') then attributes = .directory~new
  return self~createView(id, .AudioConstant~VIEW_TRANSCRIPT, description, methodology, attributes, sourceGroupId, hypothesisSetId, alternativeRank, focusDescription)

::method createSpeakerEmbeddingView
  use arg id, description, methodology, sourceGroupId, hypothesisSetId, alternativeRank, focusDescription, attributes
  if arg(8,'O') then attributes = .directory~new
  return self~createView(id, .AudioConstant~VIEW_SPEAKER_EMBEDDING, description, methodology, attributes, sourceGroupId, hypothesisSetId, alternativeRank, focusDescription)

::method addSpeakerModel
  expose speakerModels
  use arg model
  if model == .nil then return speakerModels~items
  speakerModels[model~id] = model
  return speakerModels~items

::method createSpeakerModel
  use arg id, provider, family, source, modelRevision, embeddingDimension, sampleRateHz, channelPolicy, preprocessing, scoreMetric, defaultThreshold, attributes
  model = .AudioSpeakerModel~new(id, provider, family, source, modelRevision, embeddingDimension, sampleRateHz, channelPolicy, preprocessing, scoreMetric, defaultThreshold, attributes)
  self~addSpeakerModel(model)
  return model

::method speakerModel
  expose speakerModels
  use arg id
  if speakerModels~hasIndex(id) then return speakerModels[id]
  return .nil

::method speakerModels
  expose speakerModels
  return .AudioUtil~copyDirectory(speakerModels)

::method addSpeakerEmbedding
  expose views speakerModels speakerEmbeddings
  use arg id, viewId, modelId, startMs, endMs, sourceElementIds, sourceGroupId, vector, qualityConfidence, speechDurationMs, extractionMethod, preprocessingHash, attributes
  if \ views~hasIndex(viewId) then raise syntax 93.900 array('Unknown speaker embedding view')
  if views[viewId]~viewKind \= .AudioConstant~VIEW_SPEAKER_EMBEDDING then raise syntax 93.900 array('View is not a speaker embedding view')
  if \ speakerModels~hasIndex(modelId) then raise syntax 93.900 array('Unknown speaker model')
  if arg(13,'O') then attributes = .directory~new
  embedding = .AudioSpeakerEmbedding~new(id, viewId, modelId, startMs, endMs, sourceElementIds, sourceGroupId, vector, qualityConfidence, speechDurationMs, extractionMethod, preprocessingHash, attributes)
  model = speakerModels[modelId]
  if model~embeddingDimension > 0 & embedding~dimension \= model~embeddingDimension then raise syntax 93.900 array('Speaker embedding dimension does not match model')
  speakerEmbeddings[id] = embedding
  attrs = .AudioUtil~copyDirectory(attributes)
  attrs['embedding_id'] = id
  attrs['model_id'] = modelId
  attrs['source_group_id'] = sourceGroupId
  attrs['dimension'] = embedding~dimension
  attrs['extraction_method'] = extractionMethod
  attrs['preprocessing_hash'] = preprocessingHash
  self~addBoundary(viewId, 'BOUNDARY-' || id, startMs, endMs, 'SPEAKER_EMBEDDING', 'speaker embedding ' || id, qualityConfidence, extractionMethod, sourceElementIds, attrs, '')
  return embedding

::method speakerEmbedding
  expose speakerEmbeddings
  use arg id
  if speakerEmbeddings~hasIndex(id) then return speakerEmbeddings[id]
  return .nil

::method speakerEmbeddings
  expose speakerEmbeddings
  return .AudioUtil~copyDirectory(speakerEmbeddings)

::method addSpeakerComparison
  expose views speakerModels speakerEmbeddings speakerComparisons
  use arg id, viewId, modelId, embeddingAId, embeddingBId, score, metric, threshold, decision, calibratedProbability, confidence, attributes
  if \ views~hasIndex(viewId) then raise syntax 93.900 array('Unknown speaker embedding view')
  if \ speakerModels~hasIndex(modelId) then raise syntax 93.900 array('Unknown speaker model')
  if \ speakerEmbeddings~hasIndex(embeddingAId) | \ speakerEmbeddings~hasIndex(embeddingBId) then raise syntax 93.900 array('Unknown speaker embedding in comparison')
  if arg(12,'O') then attributes = .directory~new
  comparison = .AudioSpeakerComparison~new(id, viewId, modelId, embeddingAId, embeddingBId, score, metric, threshold, decision, calibratedProbability, confidence, attributes)
  speakerComparisons~append(comparison)
  return comparison

::method speakerComparisons
  expose speakerComparisons
  return .AudioUtil~copyArray(speakerComparisons)

::method createMusicFingerprintView
  use arg id, description, methodology, sourceGroupId, hypothesisSetId, alternativeRank, focusDescription, attributes
  if arg(8,'O') then attributes = .directory~new
  return self~createView(id, .AudioConstant~VIEW_MUSIC_FINGERPRINT, description, methodology, attributes, sourceGroupId, hypothesisSetId, alternativeRank, focusDescription)

::method addFingerprintModel
  expose fingerprintModels
  use arg model
  if model == .nil then return fingerprintModels~items
  fingerprintModels[model~id] = model
  return fingerprintModels~items

::method createFingerprintModel
  use arg id, provider, algorithm, implementation, algorithmRevision, expectedSampleRateHz, preprocessing, attributes
  model = .AudioFingerprintModel~new(id, provider, algorithm, implementation, algorithmRevision, expectedSampleRateHz, preprocessing, attributes)
  self~addFingerprintModel(model)
  return model

::method fingerprintModel
  expose fingerprintModels
  use arg id
  if fingerprintModels~hasIndex(id) then return fingerprintModels[id]
  return .nil

::method fingerprintModels
  expose fingerprintModels
  return .AudioUtil~copyDirectory(fingerprintModels)

::method addMusicFingerprint
  expose views fingerprintModels musicFingerprints
  use arg id, viewId, modelId, startMs, endMs, sourceElementIds, fingerprint, fingerprintEncoding, durationSeconds, qualityConfidence, preprocessingHash, attributes
  if \ views~hasIndex(viewId) then raise syntax 93.900 array('Unknown music fingerprint view')
  if views[viewId]~viewKind \= .AudioConstant~VIEW_MUSIC_FINGERPRINT then raise syntax 93.900 array('View is not a music fingerprint view')
  if \ fingerprintModels~hasIndex(modelId) then raise syntax 93.900 array('Unknown fingerprint model')
  if arg(12,'O') then attributes = .directory~new
  fp = .AudioMusicFingerprint~new(id, viewId, modelId, startMs, endMs, sourceElementIds, fingerprint, fingerprintEncoding, durationSeconds, qualityConfidence, preprocessingHash, attributes)
  musicFingerprints[id] = fp
  attrs = .AudioUtil~copyDirectory(attributes)
  attrs['fingerprint_id'] = id
  attrs['model_id'] = modelId
  attrs['fingerprint_encoding'] = fingerprintEncoding
  attrs['preprocessing_hash'] = preprocessingHash
  self~addBoundary(viewId, 'BOUNDARY-' || id, startMs, endMs, 'MUSIC_FINGERPRINT', 'music fingerprint ' || id, qualityConfidence, modelId, sourceElementIds, attrs, '')
  return fp

::method musicFingerprint
  expose musicFingerprints
  use arg id
  if musicFingerprints~hasIndex(id) then return musicFingerprints[id]
  return .nil

::method musicFingerprints
  expose musicFingerprints
  return .AudioUtil~copyDirectory(musicFingerprints)

::method addMusicIdentification
  expose views musicFingerprints musicIdentifications
  use arg id, viewId, fingerprintId, provider, providerRevision, score, decision, acoustidTrackId, recordingIds, releaseIds, queryMetadata, responseHash, confidence, attributes
  if \ views~hasIndex(viewId) then raise syntax 93.900 array('Unknown music fingerprint view')
  if \ musicFingerprints~hasIndex(fingerprintId) then raise syntax 93.900 array('Unknown fingerprint for music identification')
  if arg(14,'O') then attributes = .directory~new
  identification = .AudioMusicIdentification~new(id, viewId, fingerprintId, provider, providerRevision, score, decision, acoustidTrackId, recordingIds, releaseIds, queryMetadata, responseHash, confidence, attributes)
  musicIdentifications~append(identification)
  return identification

::method musicIdentifications
  expose musicIdentifications
  return .AudioUtil~copyArray(musicIdentifications)

::method createPitchView
  use arg id, description, methodology, sourceGroupId, hypothesisSetId, alternativeRank, focusDescription, attributes
  if arg(8,'O') then attributes = .directory~new
  return self~createView(id, .AudioConstant~VIEW_PITCH, description, methodology, attributes, sourceGroupId, hypothesisSetId, alternativeRank, focusDescription)

::method createPitchSeries
  expose views pitchSeries
  use arg id, viewId, method, description, attributes
  if \ views~hasIndex(viewId) then raise syntax 93.900 array('Unknown audio pitch view')
  if views[viewId]~viewKind \= .AudioConstant~VIEW_PITCH then raise syntax 93.900 array('View is not a pitch view')
  if arg(5,'O') then attributes = .directory~new
  series = .AudioPitchSeries~new(id, viewId, method, description, attributes)
  pitchSeries[id] = series
  return series

::method pitchSeries
  expose pitchSeries
  return .AudioUtil~copyDirectory(pitchSeries)

::method pitchSeriesById
  expose pitchSeries
  use arg id
  if pitchSeries~hasIndex(id) then return pitchSeries[id]
  return .nil

::method addPitchObservation
  expose pitchSeries
  use arg seriesId, observationId, timeMs, hz, confidence, voicedProbability, method, sourceElementIds, attributes
  if \ pitchSeries~hasIndex(seriesId) then raise syntax 93.900 array('Unknown pitch series')
  series = pitchSeries[seriesId]
  if arg(7,'O') then method = series~method
  if arg(8,'O') then sourceElementIds = .array~new
  if arg(9,'O') then attributes = .directory~new
  observation = .AudioPitchObservation~new(observationId, seriesId, series~viewId, timeMs, hz, confidence, voicedProbability, method, sourceElementIds, attributes)
  series~addObservation(observation)
  return observation

::method addPitchBoundary
  expose views
  use arg viewId, boundaryId, startMs, endMs, label, medianHz, minHz, maxHz, confidence, assessor, sourceElementIds, contour, voicedFraction, attributes, evidence
  if \ views~hasIndex(viewId) then raise syntax 93.900 array('Unknown audio pitch view')
  if views[viewId]~viewKind \= .AudioConstant~VIEW_PITCH then raise syntax 93.900 array('View is not a pitch view')
  if arg(14,'O') then attributes = .directory~new
  attrs = .AudioUtil~copyDirectory(attributes)
  if \ arg(6,'O') then attrs['median_hz'] = medianHz
  if \ arg(7,'O') then attrs['min_hz'] = minHz
  if \ arg(8,'O') then attrs['max_hz'] = maxHz
  if \ arg(12,'O') then attrs['contour'] = contour
  if \ arg(13,'O') then attrs['voiced_fraction'] = voicedFraction
  return self~addBoundary(viewId, boundaryId, startMs, endMs, 'PITCH_ASSESSMENT', label, confidence, assessor, sourceElementIds, attrs, evidence)

::method addTranscriptBoundary
  expose views
  use arg viewId, boundaryId, startMs, endMs, textValue, confidence, assessor, sourceElementIds, speakerGroupId, lexicalAlternativeSetId, attributes, evidence
  if \ views~hasIndex(viewId) then raise syntax 93.900 array('Unknown audio transcript view')
  if views[viewId]~viewKind \= .AudioConstant~VIEW_TRANSCRIPT then raise syntax 93.900 array('View is not a transcript view')
  if arg(11,'O') then attributes = .directory~new
  attrs = .AudioUtil~copyDirectory(attributes)
  if \ arg(9,'O') then attrs['speaker_group_id'] = speakerGroupId
  if \ arg(10,'O') then attrs['lexical_alternative_set_id'] = lexicalAlternativeSetId
  return self~addBoundary(viewId, boundaryId, startMs, endMs, 'TRANSCRIPT_SEGMENT', textValue, confidence, assessor, sourceElementIds, attrs, evidence)

::method view
  expose views
  use arg id
  if views~hasIndex(id) then return views[id]
  return .nil

::method views
  expose views
  return .AudioUtil~copyDirectory(views)

::method selectView
  expose views selectedViewId
  use arg id
  if \ views~hasIndex(id) then return .false
  selectedViewId = id
  return .true

::method selectedView
  expose views selectedViewId
  if selectedViewId = '' then return .nil
  if views~hasIndex(selectedViewId) then return views[selectedViewId]
  return .nil

::method addBoundary
  expose views
  use arg viewId, boundaryId, startMs, endMs, boundaryKind, label, confidence, assessor, sourceElementIds, attributes, evidence
  if \ views~hasIndex(viewId) then raise syntax 93.900 array('Unknown audio view')
  boundary = .AudioBoundary~new(boundaryId, viewId, startMs, endMs, boundaryKind, label, confidence, assessor, sourceElementIds, attributes, evidence)
  views[viewId]~addBoundary(boundary)
  return boundary

::method selectedCut
  expose selectedViewId
  use arg startMs, endMs
  ids = .array~new
  if selectedViewId \= '' then ids~append(selectedViewId)
  return self~throughCut(startMs, endMs, ids)

::method throughCut
  expose views selectedViewId pitchSeries speakerEmbeddings musicFingerprints
  use arg startMs, endMs, viewIds
  cut = .AudioThroughCut~new(startMs, endMs, selectedViewId)
  if arg(3,'O') | viewIds == .nil then do
    ids = .array~new
    supplier = views~supplier
    do while supplier~available
      ids~append(supplier~index)
      supplier~next
    end
  end
  else ids = .AudioUtil~copyArray(viewIds)
  ids~sort
  do viewId over ids
    if \ views~hasIndex(viewId) then iterate
    view = views[viewId]
    cutView = .AudioCutView~new(view)
    do boundary over view~intersecting(startMs, endMs)
      cutView~add(.AudioCutElement~new(boundary, startMs, endMs))
    end
    if view~viewKind = .AudioConstant~VIEW_PITCH then do
      supplier = pitchSeries~supplier
      do while supplier~available
        series = supplier~item
        supplier~next
        if series~viewId \= viewId then iterate
        do observation over series~observationsBetween(startMs, endMs)
          cutView~addPitchObservation(.AudioPitchCutObservation~new(observation, startMs))
        end
      end
    end
    if view~viewKind = .AudioConstant~VIEW_SPEAKER_EMBEDDING then do
      supplier = speakerEmbeddings~supplier
      do while supplier~available
        embedding = supplier~item
        supplier~next
        if embedding~viewId \= viewId then iterate
        if embedding~intersects(startMs, endMs) then cutView~addSpeakerEmbedding(.AudioSpeakerCutEmbedding~new(embedding, startMs, endMs))
      end
    end
    if view~viewKind = .AudioConstant~VIEW_MUSIC_FINGERPRINT then do
      supplier = musicFingerprints~supplier
      do while supplier~available
        fp = supplier~item
        supplier~next
        if fp~viewId \= viewId then iterate
        if fp~intersects(startMs, endMs) then cutView~addMusicFingerprint(.AudioMusicFingerprintCut~new(fp, startMs, endMs))
      end
    end
    cut~addView(cutView)
  end
  return cut

::method addFragmentation
  expose fragmentations
  use arg fragmentation
  fragmentations[fragmentation~id] = fragmentation
  return fragmentations~items

::method createFragmentation
  use arg id, strategy, description, attributes
  if arg(4,'O') then attributes = .directory~new
  f=.AudioFragmentation~new(id,strategy,description,attributes)
  self~addFragmentation(f)
  return f

::method fragmentation
  expose fragmentations
  use arg id
  if fragmentations~hasIndex(id) then return fragmentations[id]
  return .nil

::method fragmentations
  expose fragmentations
  return .AudioUtil~copyDirectory(fragmentations)

::method addFragmentComparison
  expose fragmentComparisons
  use arg comparison
  fragmentComparisons~append(comparison)
  return fragmentComparisons~items

::method fragmentComparisons
  expose fragmentComparisons
  return .AudioUtil~copyArray(fragmentComparisons)

::method compareFragmentations
  expose fragmentComparisons
  use arg fragmentationIdA, fragmentationIdB, minOverlapMs
  if arg(3,'O') then minOverlapMs=1
  a=self~fragmentation(fragmentationIdA)
  b=self~fragmentation(fragmentationIdB)
  out=.array~new
  if a == .nil | b == .nil then return out
  seq=0
  do fa over a~fragments
    do fb over b~fragments
      s=max(fa~startMs,fb~startMs)
      e=min(fa~endMs,fb~endMs)
      if e-s >= minOverlapMs then do
        seq=seq+1
        denom=min(fa~durationMs,fb~durationMs)
        score=0
        if denom > 0 then score=(e-s)/denom
        c=.AudioFragmentComparison~new(fragmentationIdA || '-' || fragmentationIdB || '-' || seq, fragmentationIdA, fa~id, fragmentationIdB, fb~id, s, e, 'OVERLAP', score)
        out~append(c)
        fragmentComparisons~append(c)
      end
    end
  end
  return out

::method canonicalText
  expose elements processingSteps views sourceGroups selectedViewId fragmentations fragmentComparisons pitchSeries speakerModels speakerEmbeddings speakerComparisons
  lines = .array~new
  lines~append('AUDIO=' || self~id || '|durationMs=' || self~durationMs || '|selected=' || selectedViewId || '|version=' || .AudioConstant~PACKAGE_VERSION)
  all = .array~new
  supplier = sourceGroups~supplier
  do while supplier~available
    all~append(supplier~item~canonicalText)
    supplier~next
  end
  supplier = elements~supplier
  do while supplier~available
    all~append(supplier~item~canonicalText)
    supplier~next
  end
  supplier = processingSteps~supplier
  do while supplier~available
    all~append(supplier~item~canonicalText)
    supplier~next
  end
  supplier = views~supplier
  do while supplier~available
    all~append(supplier~item~canonicalText)
    supplier~next
  end
  supplier = pitchSeries~supplier
  do while supplier~available
    all~append(supplier~item~canonicalText)
    supplier~next
  end
  supplier = speakerModels~supplier
  do while supplier~available
    all~append(supplier~item~canonicalText)
    supplier~next
  end
  supplier = speakerEmbeddings~supplier
  do while supplier~available
    all~append(supplier~item~canonicalText)
    supplier~next
  end
  do comparison over speakerComparisons
    all~append(comparison~canonicalText)
  end
  supplier = fragmentations~supplier
  do while supplier~available
    all~append(supplier~item~canonicalText)
    supplier~next
  end
  do comparison over fragmentComparisons
    all~append(comparison~canonicalText)
  end
  all~sort
  do line over all
    lines~append(line)
  end
  return lines~makeString('L')
