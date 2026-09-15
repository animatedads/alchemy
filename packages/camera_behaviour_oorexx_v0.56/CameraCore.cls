/* CameraCore.cls - behavioural scene model core for ooRexx 5.3 - v0.37 */

::class CameraConstant public
::constant CHANGE_NONE             0
::constant CHANGE_PHOTOMETRIC      1
::constant CHANGE_STRUCTURAL       2
::constant CHANGE_MIXED            3

::constant REGION_STATIC           10
::constant REGION_DYNAMIC_NORMAL   11
::constant REGION_ACTIVE           12

::constant TRACK_NEW               20
::constant TRACK_ACTIVE            21
::constant TRACK_ENDED             22
::constant TRACK_OCCLUDED          23

::constant ENV_UNKNOWN             30
::constant ENV_NIGHT_ARTIFICIAL    31
::constant ENV_DAY_DIFFUSE         32
::constant ENV_DAY_DIRECT_SHADOW   33

::constant ENV_INFERENCE_UNKNOWN      34
::constant ENV_INFERENCE_PROFILE      35
::constant ENV_INFERENCE_PROTOTYPE    36

::constant OBJECT_UNKNOWN          40
::constant OBJECT_NARROW_MOVER     41
::constant OBJECT_BROAD_MOVER      42

::constant EVENT_ENTER             50
::constant EVENT_MOVE              51
::constant EVENT_STOP              52
::constant EVENT_EXIT              53
::constant EVENT_LIGHT             54
::constant EVENT_APPROACH          55
::constant EVENT_SEPARATE          56
::constant EVENT_REVERSE           57
::constant EVENT_CLOSE             58
::constant EVENT_DEVIATE           59

::constant ROUTE_NEW               60
::constant ROUTE_KNOWN             61

::constant ENCODING_LITERAL        70
::constant ENCODING_ROUTE          71

::constant ZONE_NEW                80
::constant ZONE_KNOWN              81

::constant TOKEN_EVENT_RECORD      90
::constant TOKEN_END_STREAM        91
::constant TOKEN_EPISODE_RECORD    92

::constant BEHAVIOUR_EVENT_VOCABULARY 10

::constant DIRECTION_STATIONARY       100
::constant DIRECTION_LEFT             101
::constant DIRECTION_RIGHT            102
::constant DIRECTION_UP               103
::constant DIRECTION_DOWN             104

::constant BASELINE_INSUFFICIENT       110
::constant BASELINE_WITHIN              111
::constant BASELINE_ELEVATED            112

::constant DAY_UNKNOWN                  120
::constant DAY_WEEKDAY                  121
::constant DAY_WEEKEND                  122

::constant EPISODE_NEW                   130
::constant EPISODE_KNOWN                 131

::constant MOTIF_NEW                      140
::constant MOTIF_KNOWN                    141

::constant TRANSITION_NEW                 150
::constant TRANSITION_KNOWN               151

::constant CONDITION_INSUFFICIENT            160
::constant CONDITION_EXPECTED                161
::constant CONDITION_SHIFTED                 162

::constant TREND_STABLE                        170
::constant TREND_RISING                        171
::constant TREND_FALLING                       172

::constant CONDITION_PHASE_INSUFFICIENT         180
::constant CONDITION_PHASE_STABLE               181
::constant CONDITION_PHASE_EMERGING             182
::constant CONDITION_PHASE_PERSISTENT           183
::constant CONDITION_PHASE_RECOVERING           184

::constant CONDITION_REGIME_OPEN                  190
::constant CONDITION_REGIME_CLOSED                191

::constant CONDITION_REGIME_CLASS_NEW              200
::constant CONDITION_REGIME_CLASS_KNOWN            201
::constant CURRENT_CONDITION_SNAPSHOT_VERSION       '1'
::constant MATERIALIZED_STATE_SNAPSHOT_VERSION      '1'
::constant SPATIAL_RELATION_ENCODING_VERSION       '1'
::constant SPATIAL_TOKEN_ANCHOR                     'A'
::constant SPATIAL_TOKEN_DELTA                      'D'
::constant SPATIAL_TOKEN_REGION                     'R'
::constant SPATIAL_PRIMITIVE_NEW                   210
::constant SPATIAL_PRIMITIVE_KNOWN                 211
::constant SPATIAL_MATCH_NEW                       220
::constant SPATIAL_MATCH_KNOWN                     221
::constant SPATIAL_MATCH_UNMATCHED                 222
::constant GENERATION_PUBLISHED                    230
::constant GENERATION_SUPERSEDED                   231
::constant LEARNED_GENERATION_VERSION              '6'
::constant ASSESSMENT_SIGNATURE_VERSION            '1'
::constant PEER_OUTLIER_VERSION                    '1'
::constant PEER_OUTLIER_MINIMUM_PEERS              3
::constant PEER_OUTLIER_SCORE_THRESHOLD             3
::constant PEER_OUTLIER_SHIFTED_FEATURES            2
::constant PRODUCTION_IDENTITY_VERSION             '1'
::constant ASSESSMENT_CONTRACT_ID                  'METHOD:ASSESSSUMMARYATGENERATION'
::constant ASSESSMENT_CONTRACT_REVISION            1
::constant ASSESSMENT_CONTRACT_SHAPE               'CAMERA-ASSESS-GENERATION/0.1'
::constant SIGNATURE_TREND_VERSION                 '1'
::constant SIGNATURE_TREND_MINIMUM_SAMPLES         3
::constant SIGNATURE_TREND_DELTA_THRESHOLD         16
::constant SIGNATURE_TREND_PHASE_STABLE          240
::constant SIGNATURE_TREND_PHASE_EMERGING        241
::constant SIGNATURE_TREND_PHASE_PERSISTENT      242
::constant SIGNATURE_TREND_PHASE_RECOVERING      243
::constant SIGNATURE_TREND_REGIME_OPEN           244
::constant SIGNATURE_TREND_REGIME_CLOSED         245
::constant DISCLOSURE_PUBLIC                      'PUBLIC'
::constant DISCLOSURE_CUSTOMER                    'CUSTOMER'
::constant DISCLOSURE_INTERNAL                    'INTERNAL'
::constant DISCLOSURE_FULL                        'FULL'
::constant CAMERA_PACKAGE_VERSION                  '0.45'



::class CameraMath public
::method sqrt class
  use arg value
  if value <= 0 then return 0
  guess = value
  if guess < 1 then guess = 1
  do 24
    nextGuess = (guess + (value / guess)) / 2
    if abs(nextGuess - guess) < 0.0000001 then return nextGuess
    guess = nextGuess
  end
  return guess


::method log2 class
  use arg value
  if value <= 0 then return -999999

  exponent = 0
  mantissa = value
  do while mantissa >= 2
    mantissa = mantissa / 2
    exponent = exponent + 1
  end
  do while mantissa < 1
    mantissa = mantissa * 2
    exponent = exponent - 1
  end

  /* ln(mantissa) using 2*(z + z^3/3 + z^5/5 + ...), then / ln(2). */
  z = (mantissa - 1) / (mantissa + 1)
  zSquared = z * z
  term = z
  lnMantissa = 0
  denominator = 1
  do seriesIndex = 1 to 18
    lnMantissa = lnMantissa + (term / denominator)
    term = term * zSquared
    denominator = denominator + 2
  end
  lnMantissa = lnMantissa * 2
  return exponent + (lnMantissa / 0.69314718055994530942)

::method surpriseBits class
  use arg probability
  if probability <= 0 then return 32
  if probability >= 1 then return 0
  bits = 0 - self~log2(probability)
  if bits < 0 then return 0
  return bits

::method quantizeUnit class
  use arg value
  if value < 0 then value = 0
  if value > 1 then value = 1
  return trunc((value * 255) + 0.5)

::method pointToSegmentDistance class
  use arg px, py, ax, ay, bx, by
  dx = bx - ax
  dy = by - ay
  lengthSquared = (dx * dx) + (dy * dy)
  if lengthSquared <= 0 then do
    qx = px - ax
    qy = py - ay
    return self~sqrt((qx * qx) + (qy * qy))
  end

  projection = (((px - ax) * dx) + ((py - ay) * dy)) / lengthSquared
  if projection < 0 then projection = 0
  if projection > 1 then projection = 1
  nearestX = ax + (projection * dx)
  nearestY = ay + (projection * dy)
  qx = px - nearestX
  qy = py - nearestY
  return self~sqrt((qx * qx) + (qy * qy))


::class CameraBox public
::attribute id
::attribute x
::attribute y
::attribute width
::attribute height
::attribute parent
::attribute state

::method init
  expose children
  use arg id, x, y, width, height, parent
  if arg(6, 'O') then parent = .nil

  self~id = id
  self~x = x
  self~y = y
  self~width = width
  self~height = height
  self~parent = parent
  self~state = .CameraConstant~REGION_STATIC
  children = .array~new

  if parent \== .nil then parent~addChild(self)

::method children
  expose children
  return children

::method addChild
  expose children
  use arg child
  if child == .nil then return 0
  children~append(child)
  return children~items

::method area
  return self~width * self~height

::method centreX
  return self~x + (self~width / 2)

::method centreY
  return self~y + (self~height / 2)

::method containsPoint
  use arg px, py
  if px < self~x then return .false
  if py < self~y then return .false
  if px >= self~x + self~width then return .false
  if py >= self~y + self~height then return .false
  return .true

::method containsBox
  use arg other
  if other == .nil then return .false
  if other~x < self~x then return .false
  if other~y < self~y then return .false
  if other~x + other~width > self~x + self~width then return .false
  if other~y + other~height > self~y + self~height then return .false
  return .true

::method pathId
  if self~parent == .nil then return self~id
  return self~parent~pathId || '/' || self~id

::method deepestContainingBox
  expose children
  use arg other
  if other == .nil then return .nil
  if \self~containsBox(other) then return .nil

  best = self
  do child over children
    candidate = child~deepestContainingBox(other)
    if candidate \== .nil then do
      if candidate~area < best~area then best = candidate
      else if candidate~area = best~area then do
        if candidate~pathId < best~pathId then best = candidate
      end
    end
  end
  return best

::method geometryKey
  return self~x || ',' || self~y || ',' || self~width || ',' || self~height

::method centreDistanceTo
  use arg other
  if other == .nil then return 999999999
  dx = self~centreX - other~centreX
  dy = self~centreY - other~centreY
  return .CameraMath~sqrt(dx * dx + dy * dy)

::method sizeDifferenceTo
  use arg other
  if other == .nil then return 1
  maxWidth = self~width
  if other~width > maxWidth then maxWidth = other~width
  maxHeight = self~height
  if other~height > maxHeight then maxHeight = other~height
  if maxWidth = 0 then widthPart = 0
  else widthPart = abs(self~width - other~width) / maxWidth
  if maxHeight = 0 then heightPart = 0
  else heightPart = abs(self~height - other~height) / maxHeight
  return (widthPart + heightPart) / 2

::method intersectionArea
  use arg other
  if other == .nil then return 0

  left = self~x
  if other~x > left then left = other~x
  top = self~y
  if other~y > top then top = other~y

  right = self~x + self~width
  otherRight = other~x + other~width
  if otherRight < right then right = otherRight

  bottom = self~y + self~height
  otherBottom = other~y + other~height
  if otherBottom < bottom then bottom = otherBottom

  iw = right - left
  ih = bottom - top
  if iw <= 0 then return 0
  if ih <= 0 then return 0
  return iw * ih

::method iou
  use arg other
  intersection = self~intersectionArea(other)
  if intersection <= 0 then return 0
  union = self~area + other~area - intersection
  if union <= 0 then return 0
  return intersection / union


::class CameraObservation public
::attribute timestamp
::attribute box
::attribute luminanceDelta
::attribute structureDelta
::attribute changeType

::method init
  use arg timestamp, box, luminanceDelta, structureDelta
  self~timestamp = timestamp
  self~box = box
  self~luminanceDelta = luminanceDelta
  self~structureDelta = structureDelta
  self~changeType = self~classify

::method classify
  /* Initial deterministic thresholds. They become camera parameters later. */
  lum = self~luminanceDelta
  structural = self~structureDelta

  if structural < 0.10 then do
    if lum >= 0.20 then return .CameraConstant~CHANGE_PHOTOMETRIC
    return .CameraConstant~CHANGE_NONE
  end

  if lum >= 0.20 then return .CameraConstant~CHANGE_MIXED
  return .CameraConstant~CHANGE_STRUCTURAL

::method isMoverCandidate
  t = self~changeType
  if t = .CameraConstant~CHANGE_STRUCTURAL then return .true
  if t = .CameraConstant~CHANGE_MIXED then return .true
  return .false



::class CameraSpatialRelationSnapshot public
::attribute version get
::attribute timestamp get
::attribute regionId get
::attribute regionPath get
::attribute centreX get
::attribute centreY get
::attribute width get
::attribute height get

::method init
  expose version timestamp regionId regionPath centreX centreY width height
  use arg sourceTimestamp, region, box
  version = .CameraConstant~SPATIAL_RELATION_ENCODING_VERSION
  timestamp = sourceTimestamp
  if region == .nil then do
    regionId = ''
    regionPath = ''
    centreX = 0
    centreY = 0
    width = 0
    height = 0
    return
  end

  regionId = region~id
  regionPath = region~pathId

  if region~width <= 0 then relativeCentreX = 0
  else relativeCentreX = (box~centreX - region~x) / region~width
  if region~height <= 0 then relativeCentreY = 0
  else relativeCentreY = (box~centreY - region~y) / region~height
  if region~width <= 0 then relativeWidth = 0
  else relativeWidth = box~width / region~width
  if region~height <= 0 then relativeHeight = 0
  else relativeHeight = box~height / region~height

  centreX = .CameraMath~quantizeUnit(relativeCentreX)
  centreY = .CameraMath~quantizeUnit(relativeCentreY)
  width = .CameraMath~quantizeUnit(relativeWidth)
  height = .CameraMath~quantizeUnit(relativeHeight)

::method canonicalText
  return self~timestamp || '|' || self~regionPath || '|' || self~centreX || ',' || self~centreY || ',' || self~width || ',' || self~height


::class CameraSpatialRelationToken public
::attribute kind get
::attribute deltaTime get
::attribute regionPath get
::attribute centreX get
::attribute centreY get
::attribute width get
::attribute height get

::method init
  expose kind deltaTime regionPath centreX centreY width height
  use arg sourceKind, sourceDeltaTime, sourceRegionPath, sourceCentreX, sourceCentreY, sourceWidth, sourceHeight
  kind = sourceKind
  deltaTime = sourceDeltaTime
  regionPath = sourceRegionPath
  centreX = sourceCentreX
  centreY = sourceCentreY
  width = sourceWidth
  height = sourceHeight

::method canonicalText
  if self~kind == .CameraConstant~SPATIAL_TOKEN_DELTA then do
    return self~kind || '|' || self~deltaTime || '|' || self~centreX || ',' || self~centreY || ',' || self~width || ',' || self~height
  end
  return self~kind || '|' || self~deltaTime || '|' || self~regionPath || '|' || self~centreX || ',' || self~centreY || ',' || self~width || ',' || self~height


::class CameraRelativeTrackEncoding public
::attribute version get
::attribute trackId get
::attribute sampleCount get
::attribute regionTransitionCount get
::attribute firstTimestamp get
::attribute lastTimestamp get
::attribute sourceEncodingId get

::method init
  expose version trackId sampleCount regionTransitionCount firstTimestamp lastTimestamp sourceEncodingId relations tokens
  use arg track, rootRegion
  version = .CameraConstant~SPATIAL_RELATION_ENCODING_VERSION
  trackId = ''
  sampleCount = 0
  regionTransitionCount = 0
  firstTimestamp = -1
  lastTimestamp = -1
  sourceEncodingId = ''
  relations = .array~new
  tokens = .array~new

  if track == .nil then return
  trackId = track~id
  previousRelation = .nil
  do point over track~points
    region = rootRegion
    if rootRegion \== .nil then do
      contained = rootRegion~deepestContainingBox(point~box)
      if contained \== .nil then region = contained
    end

    relation = .CameraSpatialRelationSnapshot~new(point~timestamp, region, point~box)
    if firstTimestamp < 0 then firstTimestamp = point~timestamp
    lastTimestamp = point~timestamp
    relations~append(relation)
    sampleCount = sampleCount + 1

    if previousRelation == .nil then do
      token = .CameraSpatialRelationToken~new(.CameraConstant~SPATIAL_TOKEN_ANCHOR, 0, relation~regionPath, relation~centreX, relation~centreY, relation~width, relation~height)
    end
    else do
      deltaTime = point~timestamp - previousRelation~timestamp
      if deltaTime < 0 then deltaTime = deltaTime + 86400
      if relation~regionPath == previousRelation~regionPath then do
        token = .CameraSpatialRelationToken~new(.CameraConstant~SPATIAL_TOKEN_DELTA, deltaTime, '', relation~centreX - previousRelation~centreX, relation~centreY - previousRelation~centreY, relation~width - previousRelation~width, relation~height - previousRelation~height)
      end
      else do
        regionTransitionCount = regionTransitionCount + 1
        token = .CameraSpatialRelationToken~new(.CameraConstant~SPATIAL_TOKEN_REGION, deltaTime, relation~regionPath, relation~centreX, relation~centreY, relation~width, relation~height)
      end
    end
    tokens~append(token)
    previousRelation = relation
  end
  if trackId \= '' then sourceEncodingId = trackId || '@' || firstTimestamp || ':' || sampleCount

::method structureSignature
  expose tokens
  signature = ''
  do token over tokens
    if token~kind == .CameraConstant~SPATIAL_TOKEN_DELTA then piece = token~kind
    else piece = token~kind || '@' || token~regionPath
    if signature == '' then signature = piece
    else signature = signature || '>' || piece
  end
  return signature

::method residualTo
  expose tokens
  use arg other
  if other == .nil then return 999999
  if self~structureSignature \== other~structureSignature then return 999999
  otherTokens = other~tokens
  if tokens~items \= otherTokens~items then return 999999
  if tokens~items = 0 then return 0
  maximumResidual = 0
  do tokenIndex = 1 to tokens~items
    left = tokens[tokenIndex]
    right = otherTokens[tokenIndex]
    coordinateResidual = abs(left~centreX - right~centreX) + abs(left~centreY - right~centreY) + abs(left~width - right~width) + abs(left~height - right~height)
    timeResidual = abs(left~deltaTime - right~deltaTime)
    tokenResidual = (coordinateResidual / 1020) + (timeResidual / 60)
    if tokenResidual > maximumResidual then maximumResidual = tokenResidual
  end
  return maximumResidual

::method relations
  expose relations
  copy = .array~new
  do relation over relations
    copy~append(relation)
  end
  return copy

::method tokens
  expose tokens
  copy = .array~new
  do token over tokens
    copy~append(token)
  end
  return copy

::method canonicalText
  expose tokens
  lines = .array~new
  lines~append('SPATIAL_RELATION_VERSION=' || self~version)
  lines~append('TRACK=' || self~trackId)
  lines~append('SAMPLES=' || self~sampleCount)
  lines~append('REGION_TRANSITIONS=' || self~regionTransitionCount)
  lines~append('SOURCE_ENCODING_ID=' || self~sourceEncodingId)
  lines~append('STRUCTURE=' || self~structureSignature)
  do token over tokens
    lines~append('TOKEN=' || token~canonicalText)
  end
  return lines~makeString('L')



::class CameraSpatialPrimitiveMatch public
::attribute sourceEncodingId get
::attribute sourceTrackId get
::attribute primitiveId get
::attribute residual get
::attribute state get
::attribute structureSignature get
::attribute sampleCount get
::attribute regionTransitionCount get
::attribute firstTimestamp get
::attribute lastTimestamp get

::method init
  expose sourceEncodingId sourceTrackId primitiveId residual state structureSignature sampleCount regionTransitionCount firstTimestamp lastTimestamp
  use arg encoding, primitive, residualArg, stateArg
  sourceEncodingId = encoding~sourceEncodingId
  sourceTrackId = encoding~trackId
  primitiveId = primitive~id
  residual = residualArg
  state = stateArg
  structureSignature = encoding~structureSignature
  sampleCount = encoding~sampleCount
  regionTransitionCount = encoding~regionTransitionCount
  firstTimestamp = encoding~firstTimestamp
  lastTimestamp = encoding~lastTimestamp

::method evidenceText
  return 'source=' || self~sourceEncodingId || '|track=' || self~sourceTrackId || '|primitive=' || self~primitiveId || '|residual=' || self~residual || '|state=' || self~state || '|structure=' || self~structureSignature || '|samples=' || self~sampleCount || '|regions=' || self~regionTransitionCount || '|first=' || self~firstTimestamp || '|last=' || self~lastTimestamp

::method canonicalText
  return self~evidenceText


::class CameraSpatialBehaviourPrimitive public
::attribute id get
::attribute structureSignature get
::attribute sampleCount get
::attribute totalResidual get
::attribute maximumResidual get
::attribute state get
::attribute prototypeEncoding get

::method init
  expose id structureSignature sampleCount totalResidual maximumResidual state prototypeEncoding
  use arg idArg, encoding
  id = idArg
  structureSignature = encoding~structureSignature
  sampleCount = 1
  totalResidual = 0
  maximumResidual = 0
  state = .CameraConstant~SPATIAL_PRIMITIVE_NEW
  prototypeEncoding = encoding

::method observe
  expose sampleCount totalResidual maximumResidual state
  use arg encoding
  residual = self~prototypeEncoding~residualTo(encoding)
  if residual >= 999999 then return residual
  sampleCount = sampleCount + 1
  totalResidual = totalResidual + residual
  if residual > maximumResidual then maximumResidual = residual
  if sampleCount >= 2 then state = .CameraConstant~SPATIAL_PRIMITIVE_KNOWN
  return residual

::method meanResidual
  expose sampleCount totalResidual
  if sampleCount <= 1 then return 0
  return totalResidual / (sampleCount - 1)

::method canonicalText
  return 'primitive=' || self~id || '|structure=' || self~structureSignature || '|samples=' || self~sampleCount || '|meanResidual=' || self~meanResidual || '|maxResidual=' || self~maximumResidual || '|state=' || self~state


::class CameraSpatialPrimitiveModel public
::attribute matchTolerance

::method init
  expose primitives nextPrimitiveNumber
  use arg matchTolerance
  if arg(1, 'O') then matchTolerance = 0.12
  self~matchTolerance = matchTolerance
  primitives = .array~new
  nextPrimitiveNumber = 1

::method primitives
  expose primitives
  copy = .array~new
  do primitive over primitives
    copy~append(primitive)
  end
  return copy

::method primitiveCount
  expose primitives
  return primitives~items

::method bestPrimitive
  expose primitives
  use arg encoding
  best = .nil
  bestResidual = 999999
  do primitive over primitives
    if primitive~structureSignature == encoding~structureSignature then do
      residual = primitive~prototypeEncoding~residualTo(encoding)
      if residual < bestResidual then do
        bestResidual = residual
        best = primitive
      end
    end
  end
  if best == .nil then return .nil
  if bestResidual > self~matchTolerance then return .nil
  return best

::method learn
  expose primitives nextPrimitiveNumber
  use arg encoding
  if encoding == .nil then return .nil

  primitive = self~bestPrimitive(encoding)
  if primitive == .nil then do
    primitive = .CameraSpatialBehaviourPrimitive~new('SBP' || nextPrimitiveNumber, encoding)
    nextPrimitiveNumber = nextPrimitiveNumber + 1
    primitives~append(primitive)
    return .CameraSpatialPrimitiveMatch~new(encoding, primitive, 0, .CameraConstant~SPATIAL_MATCH_NEW)
  end

  residual = primitive~observe(encoding)
  return .CameraSpatialPrimitiveMatch~new(encoding, primitive, residual, .CameraConstant~SPATIAL_MATCH_KNOWN)

::method canonicalText
  expose primitives
  lines = .array~new
  do primitive over primitives
    lines~append(primitive~canonicalText)
  end
  lines~sort
  return lines~makeString('L')



::class CameraSpatialPrimitiveSnapshot public
::attribute id get
::attribute structureSignature get
::attribute sampleCount get
::attribute meanResidual get
::attribute maximumResidual get
::attribute state get
::attribute prototypeEncoding get

::method init
  expose id structureSignature sampleCount meanResidual maximumResidual state prototypeEncoding
  use arg primitive
  id = primitive~id
  structureSignature = primitive~structureSignature
  sampleCount = primitive~sampleCount
  meanResidual = primitive~meanResidual
  maximumResidual = primitive~maximumResidual
  state = primitive~state
  prototypeEncoding = primitive~prototypeEncoding

::method canonicalText
  return 'primitive=' || self~id || '|structure=' || self~structureSignature || '|samples=' || self~sampleCount || '|meanResidual=' || self~meanResidual || '|maxResidual=' || self~maximumResidual || '|state=' || self~state || '|prototype=' || self~prototypeEncoding~sourceEncodingId


::class CameraGenerationPrimitiveMatch public
::attribute generationId get
::attribute sourceEncodingId get
::attribute sourceTrackId get
::attribute primitiveId get
::attribute residual get
::attribute state get
::attribute structureSignature get
::attribute firstTimestamp get
::attribute lastTimestamp get

::method init
  expose generationId sourceEncodingId sourceTrackId primitiveId residual state structureSignature firstTimestamp lastTimestamp
  use arg generationIdArg, encoding, primitiveIdArg, residualArg, stateArg
  generationId = generationIdArg
  sourceEncodingId = encoding~sourceEncodingId
  sourceTrackId = encoding~trackId
  primitiveId = primitiveIdArg
  residual = residualArg
  state = stateArg
  structureSignature = encoding~structureSignature
  firstTimestamp = encoding~firstTimestamp
  lastTimestamp = encoding~lastTimestamp

::method evidenceText
  return 'generation=' || self~generationId || '|source=' || self~sourceEncodingId || '|track=' || self~sourceTrackId || '|primitive=' || self~primitiveId || '|residual=' || self~residual || '|state=' || self~state || '|structure=' || self~structureSignature || '|first=' || self~firstTimestamp || '|last=' || self~lastTimestamp

::method canonicalText
  return self~evidenceText


::class CameraTokenDictionarySnapshot public

::method init
  expose tokenEntries
  use arg dictionary
  tokenEntries = .array~new
  source = dictionary~entries
  indexes = source~allIndexes
  indexes~sort
  do token over indexes
    tokenEntries~append(.CameraNamedWeightSnapshot~new(token, source[token]))
  end

::method count
  expose tokenEntries
  return tokenEntries~items

::method tokenForText
  expose tokenEntries
  use arg wantedText
  do entry over tokenEntries
    if entry~weight == wantedText then return entry~name
  end
  return 0

::method textForToken
  expose tokenEntries
  use arg wantedToken
  do entry over tokenEntries
    if entry~name == wantedToken then return entry~weight
  end
  return ''

::method entries
  expose tokenEntries
  copy = .array~new
  do entry over tokenEntries
    copy~append(entry)
  end
  return copy

::method canonicalText
  expose tokenEntries
  lines = .array~new
  do entry over tokenEntries
    lines~append('TOKEN=' || entry~name || '|text=' || entry~weight)
  end
  lines~sort
  return lines~makeString('L')


::class CameraEventGrammarSnapshot public
::attribute stopDistance get
::attribute closeDistance get
::attribute approachDelta get
::attribute separationDelta get
::attribute routeDeviationThreshold get

::method init
  expose stopDistance closeDistance approachDelta separationDelta routeDeviationThreshold
  use arg grammar
  stopDistance = grammar~stopDistance
  closeDistance = grammar~closeDistance
  approachDelta = grammar~approachDelta
  separationDelta = grammar~separationDelta
  routeDeviationThreshold = grammar~routeDeviationThreshold

::method canonicalText
  return 'stop=' || self~stopDistance || '|close=' || self~closeDistance || '|approach=' || self~approachDelta || '|separation=' || self~separationDelta || '|routeDeviation=' || self~routeDeviationThreshold


::class CameraConditionMemorySnapshot public
::attribute windowSeconds get
::attribute minimumTransitions get
::attribute shiftedExcessBits get
::attribute metricElevatedZ get
::attribute metricStrongZ get
::attribute minimumElevatedMetrics get
::attribute metricTrendDelta get
::attribute minimumTrendSamples get
::attribute persistenceMinimum get
::attribute recoveryMinimum get

::method init
  expose windowSeconds minimumTransitions shiftedExcessBits metricElevatedZ metricStrongZ minimumElevatedMetrics metricTrendDelta minimumTrendSamples persistenceMinimum recoveryMinimum completedRegimeSnapshots regimeClassSnapshots
  use arg model
  windowSeconds = model~windowSeconds
  minimumTransitions = model~minimumTransitions
  shiftedExcessBits = model~shiftedExcessBits
  metricElevatedZ = model~metricElevatedZ
  metricStrongZ = model~metricStrongZ
  minimumElevatedMetrics = model~minimumElevatedMetrics
  metricTrendDelta = model~metricTrendDelta
  minimumTrendSamples = model~minimumTrendSamples
  persistenceMinimum = model~persistenceMinimum
  recoveryMinimum = model~recoveryMinimum

  completedRegimeSnapshots = .array~new
  do regime over model~completedRegimes
    completedRegimeSnapshots~append(.CameraConditionRegimeSnapshot~new(regime))
  end

  regimeClassSnapshots = .array~new
  supplier = model~regimeClasses~supplier
  do while supplier~available
    regimeClass = supplier~item
    supplier~next
    regimeClassSnapshots~append(.CameraConditionRegimeClassSnapshot~new(regimeClass))
  end

::method completedRegimeCount
  expose completedRegimeSnapshots
  return completedRegimeSnapshots~items

::method regimeClassCount
  expose regimeClassSnapshots
  return regimeClassSnapshots~items

::method completedRegimes
  expose completedRegimeSnapshots
  copy = .array~new
  do item over completedRegimeSnapshots
    copy~append(item)
  end
  return copy

::method regimeClasses
  expose regimeClassSnapshots
  copy = .array~new
  do item over regimeClassSnapshots
    copy~append(item)
  end
  return copy

::method regimeClass
  expose regimeClassSnapshots
  use arg classId
  do item over regimeClassSnapshots
    if item~id == classId then return item
  end
  return .nil

::method canonicalText
  expose completedRegimeSnapshots regimeClassSnapshots
  lines = .array~new
  lines~append('CONFIG=window:' || self~windowSeconds || '|minimumTransitions:' || self~minimumTransitions || '|shiftedExcess:' || self~shiftedExcessBits || '|metricElevated:' || self~metricElevatedZ || '|metricStrong:' || self~metricStrongZ || '|minimumElevated:' || self~minimumElevatedMetrics || '|trendDelta:' || self~metricTrendDelta || '|trendSamples:' || self~minimumTrendSamples || '|persistence:' || self~persistenceMinimum || '|recovery:' || self~recoveryMinimum)
  regimeLines = .array~new
  do item over completedRegimeSnapshots
    regimeLines~append(item~canonicalText)
  end
  regimeLines~sort
  do value over regimeLines
    lines~append('REGIME=' || value)
  end
  classLines = .array~new
  do item over regimeClassSnapshots
    classLines~append(item~canonicalText)
  end
  classLines~sort
  do value over classLines
    lines~append('REGIME_CLASS=' || value)
  end
  return lines~makeString('L')


::class CameraZoneSnapshot public
::attribute id get
::attribute sampleCount get
::attribute meanX get
::attribute meanY get

::method init
  expose id sampleCount meanX meanY
  use arg zone
  id = zone~id
  sampleCount = zone~sampleCount
  meanX = zone~meanX
  meanY = zone~meanY

::method canonicalText
  return self~id || '|samples=' || self~sampleCount || '|mean=' || self~meanX || ',' || self~meanY


::class CameraSequencePatternSnapshot public
::attribute id get
::attribute sequenceKey get
::attribute sampleCount get
::attribute family get

::method init
  expose id sequenceKey sampleCount family
  use arg familyArg, pattern
  family = familyArg
  id = pattern~id
  sequenceKey = pattern~sequenceKey
  sampleCount = pattern~sampleCount

::method canonicalText
  return self~family || '|' || self~id || '|sequence=' || self~sequenceKey || '|samples=' || self~sampleCount


::class CameraCalendarContextSnapshot public
::attribute dayClass get
::attribute sampleCount get
::attribute behaviourModel get

::method init
  expose dayClass sampleCount behaviourModel
  use arg dayClassArg, sampleCountArg, sourceModel
  dayClass = dayClassArg
  sampleCount = sampleCountArg
  behaviourModel = .CameraBehaviourModelSnapshot~new(sourceModel)

::method canonicalText
  lines = .array~new
  lines~append('DAY_CLASS=' || self~dayClass || '|samples=' || self~sampleCount)
  do modelLine over self~behaviourModel~canonicalText~makeArray
    lines~append(modelLine)
  end
  return lines~makeString('L')


::class CameraCalendarBehaviourSnapshot public

::method init
  expose contextSnapshots
  use arg calendarModel
  contextSnapshots = .array~new
  supplier = calendarModel~models~supplier
  do while supplier~available
    sourceModel = supplier~item
    dayKey = supplier~index
    supplier~next
    sampleCount = calendarModel~contextSampleCount(dayKey)
    contextSnapshots~append(.CameraCalendarContextSnapshot~new(dayKey, sampleCount, sourceModel))
  end

::method contextCount
  expose contextSnapshots
  return contextSnapshots~items

::method contexts
  expose contextSnapshots
  copy = .array~new
  do context over contextSnapshots
    copy~append(context)
  end
  return copy

::method contextSampleCount
  use arg dayClass
  context = self~context(dayClass)
  if context == .nil then return 0
  return context~sampleCount

::method metricEstimate
  use arg dayClass, secondOfDay, metricName
  context = self~context(dayClass)
  if context == .nil then return .CameraScalarDistribution~new
  return context~behaviourModel~metricEstimate(secondOfDay, metricName)

::method context
  expose contextSnapshots
  use arg dayClass
  wanted = dayClass~string
  do context over contextSnapshots
    if context~dayClass~string == wanted then return context
  end
  return .nil

::method canonicalText
  expose contextSnapshots
  texts = .array~new
  do context over contextSnapshots
    texts~append(context~canonicalText)
  end
  texts~sort
  return texts~makeString('L')


::class CameraScalarDistributionSnapshot public
::attribute weightTotal get
::attribute weightedSum get
::attribute weightedSquareSum get
::attribute sampleCount get
::attribute mean get
::attribute variance get
::attribute standardDeviation get

::method init
  expose weightTotal weightedSum weightedSquareSum sampleCount mean variance standardDeviation
  use arg distribution
  weightTotal = distribution~weightTotal
  weightedSum = distribution~weightedSum
  weightedSquareSum = distribution~weightedSquareSum
  sampleCount = distribution~sampleCount
  mean = distribution~mean
  variance = distribution~variance
  standardDeviation = distribution~standardDeviation

::method zScore
  use arg value
  if self~standardDeviation <= 0 then do
    if value = self~mean then return 0
    if value > self~mean then return 999999
    return -999999
  end
  return (value - self~mean) / self~standardDeviation

::method canonicalText
  return 'weight=' || self~weightTotal || '|sum=' || self~weightedSum || '|square=' || self~weightedSquareSum || '|samples=' || self~sampleCount || '|mean=' || self~mean || '|variance=' || self~variance || '|sd=' || self~standardDeviation


::class CameraNamedWeightSnapshot public
::attribute name get
::attribute weight get

::method init
  expose name weight
  use arg nameArg, weightArg
  name = nameArg
  weight = weightArg

::method canonicalText
  return self~name || '=' || self~weight


::class CameraNamedDistributionSnapshot public
::attribute name get
::attribute distribution get

::method init
  expose name distribution
  use arg nameArg, sourceDistribution
  name = nameArg
  distribution = .CameraScalarDistributionSnapshot~new(sourceDistribution)

::method canonicalText
  return self~name || '|' || self~distribution~canonicalText


::class CameraBehaviourWindowSnapshot public
::attribute centreSecond get
::attribute halfWidth get
::attribute observations get
::attribute weightedObservations get
::attribute routeWeightTotal get
::attribute eventWeightTotal get
::attribute episodeWeightTotal get
::attribute motifWeightTotal get
::attribute transitionWeightTotal get

::method init
  expose centreSecond halfWidth observations weightedObservations routeWeightTotal eventWeightTotal episodeWeightTotal motifWeightTotal transitionWeightTotal routeWeightSnapshots eventWeightSnapshots episodeWeightSnapshots motifWeightSnapshots transitionWeightSnapshots zoneEventWeightSnapshots metricSnapshots
  use arg window
  centreSecond = window~centreSecond
  halfWidth = window~halfWidth
  observations = window~observations
  weightedObservations = window~weightedObservations
  routeWeightTotal = window~routeWeightTotal
  eventWeightTotal = window~eventWeightTotal
  episodeWeightTotal = window~episodeWeightTotal
  motifWeightTotal = window~motifWeightTotal
  transitionWeightTotal = window~transitionWeightTotal

  routeWeightSnapshots = self~freezeWeights(window~routeWeights)
  eventWeightSnapshots = self~freezeWeights(window~eventWeights)
  episodeWeightSnapshots = self~freezeWeights(window~episodeWeights)
  motifWeightSnapshots = self~freezeWeights(window~motifWeights)
  transitionWeightSnapshots = self~freezeWeights(window~transitionWeights)
  zoneEventWeightSnapshots = self~freezeWeights(window~zoneEventWeights)
  metricSnapshots = self~freezeDistributions(window~metrics)

::method freezeWeights private
  use arg source
  frozen = .array~new
  supplier = source~supplier
  do while supplier~available
    value = supplier~item
    name = supplier~index
    supplier~next
    frozen~append(.CameraNamedWeightSnapshot~new(name, value))
  end
  return frozen

::method freezeDistributions private
  use arg source
  frozen = .array~new
  supplier = source~supplier
  do while supplier~available
    distribution = supplier~item
    name = supplier~index
    supplier~next
    frozen~append(.CameraNamedDistributionSnapshot~new(name, distribution))
  end
  return frozen

::method weightFor
  use arg secondOfDay
  distance = abs(secondOfDay - self~centreSecond)
  if distance > 43200 then distance = 86400 - distance
  if distance > self~halfWidth then return 0
  if self~halfWidth <= 0 then return 1
  return 1 - (distance / self~halfWidth)

::method metric
  expose metricSnapshots
  use arg wanted
  do item over metricSnapshots
    if item~name == wanted then return item~distribution
  end
  return .nil

::method weightForName
  use arg family, wanted
  select
    when family == 'ROUTE' then source = self~routeWeights
    when family == 'EVENT' then source = self~eventWeights
    when family == 'EPISODE' then source = self~episodeWeights
    when family == 'MOTIF' then source = self~motifWeights
    when family == 'TRANSITION' then source = self~transitionWeights
    when family == 'ZONE_EVENT' then source = self~zoneEventWeights
    otherwise return 0
  end
  do item over source
    if item~name == wanted then return item~weight
  end
  return 0

::method routeWeights
  expose routeWeightSnapshots
  return self~copyArray(routeWeightSnapshots)

::method eventWeights
  expose eventWeightSnapshots
  return self~copyArray(eventWeightSnapshots)

::method episodeWeights
  expose episodeWeightSnapshots
  return self~copyArray(episodeWeightSnapshots)

::method motifWeights
  expose motifWeightSnapshots
  return self~copyArray(motifWeightSnapshots)

::method transitionWeights
  expose transitionWeightSnapshots
  return self~copyArray(transitionWeightSnapshots)

::method zoneEventWeights
  expose zoneEventWeightSnapshots
  return self~copyArray(zoneEventWeightSnapshots)

::method metrics
  expose metricSnapshots
  return self~copyArray(metricSnapshots)

::method copyArray private
  use arg source
  copy = .array~new
  do item over source
    copy~append(item)
  end
  return copy

::method canonicalText
  expose routeWeightSnapshots eventWeightSnapshots episodeWeightSnapshots motifWeightSnapshots transitionWeightSnapshots zoneEventWeightSnapshots metricSnapshots
  lines = .array~new
  lines~append('WINDOW=' || self~centreSecond || '|half=' || self~halfWidth || '|obs=' || self~observations || '|weighted=' || self~weightedObservations)
  lines~append('TOTALS=route:' || self~routeWeightTotal || '|event:' || self~eventWeightTotal || '|episode:' || self~episodeWeightTotal || '|motif:' || self~motifWeightTotal || '|transition:' || self~transitionWeightTotal)
  ignoredCount = self~appendCanonical(lines, 'ROUTE_WEIGHT=', routeWeightSnapshots)
  ignoredCount = self~appendCanonical(lines, 'EVENT_WEIGHT=', eventWeightSnapshots)
  ignoredCount = self~appendCanonical(lines, 'EPISODE_WEIGHT=', episodeWeightSnapshots)
  ignoredCount = self~appendCanonical(lines, 'MOTIF_WEIGHT=', motifWeightSnapshots)
  ignoredCount = self~appendCanonical(lines, 'TRANSITION_WEIGHT=', transitionWeightSnapshots)
  ignoredCount = self~appendCanonical(lines, 'ZONE_EVENT_WEIGHT=', zoneEventWeightSnapshots)
  ignoredCount = self~appendCanonical(lines, 'METRIC=', metricSnapshots)
  return lines~makeString('L')

::method appendCanonical private
  use arg lines, prefix, source
  values = .array~new
  do item over source
    values~append(item~canonicalText)
  end
  values~sort
  do value over values
    lines~append(prefix || value)
  end
  return values~items


::class CameraBehaviourModelSnapshot public

::method init
  expose windowSnapshots
  use arg behaviour
  windowSnapshots = .array~new
  do window over behaviour~windows
    windowSnapshots~append(.CameraBehaviourWindowSnapshot~new(window))
  end

::method windowCount
  expose windowSnapshots
  return windowSnapshots~items

::method windows
  expose windowSnapshots
  copy = .array~new
  do window over windowSnapshots
    copy~append(window)
  end
  return copy

::method metricEstimate
  expose windowSnapshots
  use arg secondOfDay, metricName
  estimate = .CameraScalarDistribution~new
  do window over windowSnapshots
    windowWeight = window~weightFor(secondOfDay)
    if windowWeight <= 0 then iterate
    distribution = window~metric(metricName)
    if distribution == .nil then iterate
    if distribution~weightTotal <= 0 then iterate
    effectiveWeight = distribution~weightTotal * windowWeight
    estimate~weightTotal = estimate~weightTotal + effectiveWeight
    estimate~weightedSum = estimate~weightedSum + (distribution~mean * effectiveWeight)
    estimate~weightedSquareSum = estimate~weightedSquareSum + ((distribution~variance + (distribution~mean * distribution~mean)) * effectiveWeight)
    estimate~sampleCount = estimate~sampleCount + distribution~sampleCount
  end
  return estimate

::method windowAtCentre
  expose windowSnapshots
  use arg centreSecond
  do window over windowSnapshots
    if window~centreSecond = centreSecond then return window
  end
  return .nil

::method canonicalText
  expose windowSnapshots
  lines = .array~new
  windowTexts = .array~new
  do window over windowSnapshots
    windowTexts~append(window~canonicalText)
  end
  windowTexts~sort
  do windowText over windowTexts
    lines~append(windowText)
  end
  return lines~makeString('L')


::class CameraEnvironmentProfileSnapshot public
::attribute code get
::attribute structuralThreshold get
::attribute photometricThreshold get
::attribute backgroundLuma get
::attribute backgroundStructure get

::method init
  expose code structuralThreshold photometricThreshold backgroundLuma backgroundStructure metricSnapshots signatureMetricSnapshots
  use arg profile
  code = profile~code
  structuralThreshold = profile~structuralThreshold
  photometricThreshold = profile~photometricThreshold
  backgroundLuma = .CameraScalarDistributionSnapshot~new(profile~backgroundLuma)
  backgroundStructure = .CameraScalarDistributionSnapshot~new(profile~backgroundStructure)
  metricSnapshots = self~freezeDistributions(profile~metrics)
  signatureMetricSnapshots = self~freezeDistributions(profile~signatureMetrics)

::method freezeDistributions private
  use arg source
  frozen = .array~new
  supplier = source~supplier
  do while supplier~available
    distribution = supplier~item
    name = supplier~index
    supplier~next
    frozen~append(.CameraNamedDistributionSnapshot~new(name, distribution))
  end
  return frozen

::method metric
  expose metricSnapshots
  use arg wanted
  do item over metricSnapshots
    if item~name == wanted then return item~distribution
  end
  return .nil

::method signatureMetric
  expose signatureMetricSnapshots
  use arg wanted
  do item over signatureMetricSnapshots
    if item~name == wanted then return item~distribution
  end
  return .nil

::method canonicalText
  expose metricSnapshots signatureMetricSnapshots
  lines = .array~new
  lines~append('ENV=' || self~code || '|structuralThreshold=' || self~structuralThreshold || '|photometricThreshold=' || self~photometricThreshold)
  lines~append('BACKGROUND_LUMA=' || self~backgroundLuma~canonicalText)
  lines~append('BACKGROUND_STRUCTURE=' || self~backgroundStructure~canonicalText)
  metricLines = .array~new
  do item over metricSnapshots
    metricLines~append(item~canonicalText)
  end
  metricLines~sort
  do metricLine over metricLines
    lines~append('METRIC=' || metricLine)
  end
  signatureLines = .array~new
  do item over signatureMetricSnapshots
    signatureLines~append(item~canonicalText)
  end
  signatureLines~sort
  do signatureLine over signatureLines
    lines~append('SIGNATURE=' || signatureLine)
  end
  return lines~makeString('L')


::class CameraEnvironmentModelSnapshot public

::method init
  expose profileSnapshots
  use arg environmentModel
  profileSnapshots = .array~new
  supplier = environmentModel~profiles~supplier
  do while supplier~available
    profile = supplier~item
    supplier~next
    profileSnapshots~append(.CameraEnvironmentProfileSnapshot~new(profile))
  end

::method profileCount
  expose profileSnapshots
  return profileSnapshots~items

::method profiles
  expose profileSnapshots
  copy = .array~new
  do profile over profileSnapshots
    copy~append(profile)
  end
  return copy

::method metricEstimate
  use arg environmentCode, metricName
  profile = self~profile(environmentCode)
  if profile == .nil then return .CameraScalarDistribution~new
  distribution = profile~metric(metricName)
  if distribution == .nil then return .CameraScalarDistribution~new
  estimate = .CameraScalarDistribution~new
  estimate~weightTotal = distribution~weightTotal
  estimate~weightedSum = distribution~weightedSum
  estimate~weightedSquareSum = distribution~weightedSquareSum
  estimate~sampleCount = distribution~sampleCount
  return estimate

::method profile
  expose profileSnapshots
  use arg environmentCode
  do profile over profileSnapshots
    if profile~code = environmentCode then return profile
  end
  return .nil

::method canonicalText
  expose profileSnapshots
  lines = .array~new
  profileTexts = .array~new
  do profile over profileSnapshots
    profileTexts~append(profile~canonicalText)
  end
  profileTexts~sort
  do profileText over profileTexts
    lines~append(profileText)
  end
  return lines~makeString('L')


::class CameraRegionSnapshot public
::attribute id get
::attribute path get
::attribute x get
::attribute y get
::attribute width get
::attribute height get
::attribute state get

::method init
  expose id path x y width height state childSnapshots
  use arg region
  id = region~id
  path = region~pathId
  x = region~x
  y = region~y
  width = region~width
  height = region~height
  state = region~state
  childSnapshots = .array~new
  do child over region~children
    childSnapshots~append(.CameraRegionSnapshot~new(child))
  end

::method children
  expose childSnapshots
  copy = .array~new
  do child over childSnapshots
    copy~append(child)
  end
  return copy

::method nodeCount
  expose childSnapshots
  count = 1
  do child over childSnapshots
    count = count + child~nodeCount
  end
  return count

::method region
  expose childSnapshots
  use arg wantedPath
  if self~path == wantedPath then return self
  do child over childSnapshots
    found = child~region(wantedPath)
    if found \== .nil then return found
  end
  return .nil

::method canonicalText
  expose childSnapshots
  lines = .array~new
  lines~append('REGION=' || self~path || '|' || self~x || ',' || self~y || ',' || self~width || ',' || self~height || '|state=' || self~state)
  childLines = .array~new
  do child over childSnapshots
    childText = child~canonicalText
    do childLine over childText~makeArray
      childLines~append(childLine)
    end
  end
  childLines~sort
  do childLine over childLines
    lines~append(childLine)
  end
  return lines~makeString('L')


::class CameraRouteSnapshot public
::attribute id get
::attribute sampleCount get
::attribute meanEntryX get
::attribute meanEntryY get
::attribute meanMidX get
::attribute meanMidY get
::attribute meanExitX get
::attribute meanExitY get
::attribute meanDuration get
::attribute meanLength get

::method init
  expose id sampleCount meanEntryX meanEntryY meanMidX meanMidY meanExitX meanExitY meanDuration meanLength
  use arg route
  id = route~id
  sampleCount = route~sampleCount
  meanEntryX = route~meanEntryX
  meanEntryY = route~meanEntryY
  meanMidX = route~meanMidX
  meanMidY = route~meanMidY
  meanExitX = route~meanExitX
  meanExitY = route~meanExitY
  meanDuration = route~meanDuration
  meanLength = route~meanLength

::method canonicalText
  return self~id || '|samples=' || self~sampleCount || '|entry=' || self~meanEntryX || ',' || self~meanEntryY || '|mid=' || self~meanMidX || ',' || self~meanMidY || '|exit=' || self~meanExitX || ',' || self~meanExitY || '|duration=' || self~meanDuration || '|length=' || self~meanLength


::class CameraTransitionSnapshot public
::attribute id get
::attribute fromMotifId get
::attribute toMotifId get
::attribute sampleCount get
::attribute transitionKey get

::method init
  expose id fromMotifId toMotifId sampleCount transitionKey
  use arg transition
  id = transition~id
  fromMotifId = transition~fromMotifId
  toMotifId = transition~toMotifId
  sampleCount = transition~sampleCount
  transitionKey = transition~transitionKey

::method canonicalText
  return self~id || '|key=' || self~transitionKey || '|from=' || self~fromMotifId || '|to=' || self~toMotifId || '|samples=' || self~sampleCount


::class CameraLearnedGeneration subclass AlchemyObject public
::attribute version get
::attribute id get
::attribute publishedAt get
::attribute state get
::attribute matchTolerance get
::attribute sceneGeometry get
::attribute behaviourModel get
::attribute environmentModel get
::attribute calendarBehaviour get
::attribute tokenDictionary get
::attribute eventGrammar get
::attribute conditionMemory get

::method init
  expose version id publishedAt state matchTolerance sceneGeometry behaviourModel environmentModel calendarBehaviour tokenDictionary eventGrammar conditionMemory primitiveSnapshots routeSnapshots transitionSnapshots zoneSnapshots episodeSnapshots motifSnapshots
  use arg idArg, timestamp, camera
  version = .CameraConstant~LEARNED_GENERATION_VERSION
  id = idArg
  publishedAt = timestamp
  state = .CameraConstant~GENERATION_PUBLISHED
  matchTolerance = camera~spatialPrimitiveModel~matchTolerance

  meta = .directory~new
  meta["PURPOSE"] = "Immutable learned-world generation for fixed-camera behavioural assessment"
  meta["PACKAGE"] = "camera_behaviour_oorexx"
  meta["PACKAGE_VERSION"] = .CameraConstant~CAMERA_PACKAGE_VERSION
  meta["AUTHORSHIP"] = "OpenAI / The Architect"
  meta["STANDARDS"] = "ALCHEMY-HOUSE-OBJECT-0.8; deterministic fixed-camera behavioural evidence"
  meta["DESIGN_LIMITATIONS"] = "Camera produces behavioural evidence and learned-world state; it does not grant operational authority or identify people."
  meta["OBJECT_KIND"] = "LEARNED_GENERATION"
  self~init:super(meta)
  self~registerExternalRequirement("library", "alchemy_objects", "v0.8", .true)
  self~registerStateVariable("id", "CUSTOMER", "stable learned generation identifier")
  self~registerStateVariable("publishedAt", "CUSTOMER", "generation publication timestamp")
  self~registerStateVariable("state", "CUSTOMER", "generation lifecycle state")
  self~registerStateVariable("version", "CUSTOMER", "learned generation schema version")
  self~registerStateVariable("matchTolerance", "INTERNAL", "spatial primitive residual match tolerance")
  self~registerMethodContract("MATCH", "read-only spatial primitive match against this frozen generation", .array~of("ENCODING"), "ANY", .false, "TRUE", "CUSTOMER", "NORMAL", "READ", "NONE")
  self~registerMethodContract("SEMANTICCANONICALTEXT", "canonical semantic identity for the frozen learned world", .array~new, "STRING", .false, "TRUE", "CUSTOMER", "NORMAL", "READ", "NONE")
  self~registerInstrumentationPoint("CAMERA.GENERATION.MATCH", "spatial encoding evaluated against immutable generation", .true, "ALL", "INTERNAL")
  self~registerInstrumentationPoint("CAMERA.GENERATION.SUPERSEDE", "generation superseded for current use without changing semantic content", .true, "ALL", "CUSTOMER")
  ignoredRelationship = self~recordRelationship("GENERATED_BY", camera, "camera model that published this immutable learned world", "CUSTOMER")

  sceneGeometry = .CameraRegionSnapshot~new(camera~rootRegion)
  behaviourModel = .CameraBehaviourModelSnapshot~new(camera~behaviour)
  environmentModel = .CameraEnvironmentModelSnapshot~new(camera~environmentModel)
  calendarBehaviour = .CameraCalendarBehaviourSnapshot~new(camera~calendarBehaviour)
  tokenDictionary = .CameraTokenDictionarySnapshot~new(camera~tokenDictionary)
  eventGrammar = .CameraEventGrammarSnapshot~new(camera~eventGrammar)
  conditionMemory = .CameraConditionMemorySnapshot~new(camera~currentConditionModel)

  primitiveSnapshots = .array~new
  do primitive over camera~spatialPrimitiveModel~primitives
    primitiveSnapshots~append(.CameraSpatialPrimitiveSnapshot~new(primitive))
  end

  routeSnapshots = .array~new
  routeSupplier = camera~routeModel~routes~supplier
  do while routeSupplier~available
    route = routeSupplier~item
    routeSupplier~next
    routeSnapshots~append(.CameraRouteSnapshot~new(route))
  end

  zoneSnapshots = .array~new
  zoneSupplier = camera~spatialModel~zones~zones~supplier
  do while zoneSupplier~available
    zone = zoneSupplier~item
    zoneSupplier~next
    zoneSnapshots~append(.CameraZoneSnapshot~new(zone))
  end

  episodeSnapshots = .array~new
  episodeSupplier = camera~episodeModel~episodes~supplier
  do while episodeSupplier~available
    episode = episodeSupplier~item
    episodeSupplier~next
    episodeSnapshots~append(.CameraSequencePatternSnapshot~new('EPISODE', episode))
  end

  motifSnapshots = .array~new
  motifSupplier = camera~motifModel~motifs~supplier
  do while motifSupplier~available
    motif = motifSupplier~item
    motifSupplier~next
    motifSnapshots~append(.CameraSequencePatternSnapshot~new('MOTIF', motif))
  end

  transitionSnapshots = .array~new
  transitionSupplier = camera~transitionModel~transitions~supplier
  do while transitionSupplier~available
    transition = transitionSupplier~item
    transitionSupplier~next
    transitionSnapshots~append(.CameraTransitionSnapshot~new(transition))
  end

::method primitiveCount
  expose primitiveSnapshots
  return primitiveSnapshots~items

::method routeCount
  expose routeSnapshots
  return routeSnapshots~items

::method transitionCount
  expose transitionSnapshots
  return transitionSnapshots~items

::method regionCount
  return self~sceneGeometry~nodeCount

::method behaviourWindowCount
  return self~behaviourModel~windowCount

::method environmentProfileCount
  return self~environmentModel~profileCount

::method calendarContextCount
  return self~calendarBehaviour~contextCount

::method zoneCount
  expose zoneSnapshots
  return zoneSnapshots~items

::method episodeCount
  expose episodeSnapshots
  return episodeSnapshots~items

::method motifCount
  expose motifSnapshots
  return motifSnapshots~items

::method tokenCount
  return self~tokenDictionary~count

::method completedConditionRegimeCount
  return self~conditionMemory~completedRegimeCount

::method conditionRegimeClassCount
  return self~conditionMemory~regimeClassCount

::method primitives
  expose primitiveSnapshots
  copy = .array~new
  do primitive over primitiveSnapshots
    copy~append(primitive)
  end
  return copy

::method routes
  expose routeSnapshots
  copy = .array~new
  do route over routeSnapshots
    copy~append(route)
  end
  return copy

::method transitions
  expose transitionSnapshots
  copy = .array~new
  do transition over transitionSnapshots
    copy~append(transition)
  end
  return copy

::method zones
  expose zoneSnapshots
  copy = .array~new
  do item over zoneSnapshots
    copy~append(item)
  end
  return copy

::method episodes
  expose episodeSnapshots
  copy = .array~new
  do item over episodeSnapshots
    copy~append(item)
  end
  return copy

::method motifs
  expose motifSnapshots
  copy = .array~new
  do item over motifSnapshots
    copy~append(item)
  end
  return copy

::method zone
  expose zoneSnapshots
  use arg zoneId
  do item over zoneSnapshots
    if item~id == zoneId then return item
  end
  return .nil

::method episode
  expose episodeSnapshots
  use arg episodeId
  do item over episodeSnapshots
    if item~id == episodeId then return item
  end
  return .nil

::method motif
  expose motifSnapshots
  use arg motifId
  do item over motifSnapshots
    if item~id == motifId then return item
  end
  return .nil

::method primitive
  expose primitiveSnapshots
  use arg primitiveId
  do primitive over primitiveSnapshots
    if primitive~id == primitiveId then return primitive
  end
  return .nil

::method route
  expose routeSnapshots
  use arg routeId
  do route over routeSnapshots
    if route~id == routeId then return route
  end
  return .nil

::method transition
  expose transitionSnapshots
  use arg transitionId
  do transition over transitionSnapshots
    if transition~id == transitionId then return transition
  end
  return .nil

::method supersede
  expose state
  state = .CameraConstant~GENERATION_SUPERSEDED
  evidence = .directory~new
  evidence["generation_id"] = self~id
  evidence["state"] = state
  ignoredEvent = self~alchemyInstrument("CAMERA.GENERATION.SUPERSEDE", evidence)
  return state

::method match
  expose primitiveSnapshots matchTolerance
  use arg encoding
  if encoding == .nil then return .nil

  best = .nil
  bestResidual = 999999
  do primitive over primitiveSnapshots
    if primitive~structureSignature == encoding~structureSignature then do
      residual = primitive~prototypeEncoding~residualTo(encoding)
      if residual < bestResidual then do
        bestResidual = residual
        best = primitive
      end
    end
  end

  if best == .nil then matchResult = .CameraGenerationPrimitiveMatch~new(self~id, encoding, '', 999999, .CameraConstant~SPATIAL_MATCH_UNMATCHED)
  else if bestResidual > matchTolerance then matchResult = .CameraGenerationPrimitiveMatch~new(self~id, encoding, '', bestResidual, .CameraConstant~SPATIAL_MATCH_UNMATCHED)
  else matchResult = .CameraGenerationPrimitiveMatch~new(self~id, encoding, best~id, bestResidual, .CameraConstant~SPATIAL_MATCH_KNOWN)
  evidence = .directory~new
  evidence["generation_id"] = self~id
  evidence["source_encoding_id"] = encoding~sourceEncodingId
  evidence["primitive_id"] = matchResult~primitiveId
  evidence["residual"] = matchResult~residual
  evidence["state"] = matchResult~state
  ignoredEvent = self~alchemyInstrument("CAMERA.GENERATION.MATCH", evidence)
  return matchResult

::method semanticCanonicalText
  expose primitiveSnapshots routeSnapshots transitionSnapshots zoneSnapshots episodeSnapshots motifSnapshots
  lines = .array~new
  lines~append('LEARNED_GENERATION_VERSION=' || self~version)
  lines~append('GENERATION_ID=' || self~id)
  lines~append('PUBLISHED_AT=' || self~publishedAt)
  lines~append('MATCH_TOLERANCE=' || self~matchTolerance)
  lines~append('SCENE_BEGIN')
  sceneLines = self~sceneGeometry~canonicalText~makeArray
  do sceneLine over sceneLines
    lines~append(sceneLine)
  end
  lines~append('SCENE_END')
  lines~append('BEHAVIOUR_BEGIN')
  behaviourLines = self~behaviourModel~canonicalText~makeArray
  do behaviourLine over behaviourLines
    lines~append(behaviourLine)
  end
  lines~append('BEHAVIOUR_END')
  lines~append('ENVIRONMENT_BEGIN')
  environmentLines = self~environmentModel~canonicalText~makeArray
  do environmentLine over environmentLines
    lines~append(environmentLine)
  end
  lines~append('ENVIRONMENT_END')
  lines~append('CALENDAR_BEGIN')
  do calendarLine over self~calendarBehaviour~canonicalText~makeArray
    lines~append(calendarLine)
  end
  lines~append('CALENDAR_END')
  lines~append('TOKEN_DICTIONARY_BEGIN')
  do tokenLine over self~tokenDictionary~canonicalText~makeArray
    lines~append(tokenLine)
  end
  lines~append('TOKEN_DICTIONARY_END')
  lines~append('EVENT_GRAMMAR=' || self~eventGrammar~canonicalText)
  lines~append('CONDITION_MEMORY_BEGIN')
  do conditionLine over self~conditionMemory~canonicalText~makeArray
    lines~append(conditionLine)
  end
  lines~append('CONDITION_MEMORY_END')

  zoneLines = .array~new
  do zone over zoneSnapshots
    zoneLines~append(zone~canonicalText)
  end
  zoneLines~sort
  do zoneLine over zoneLines
    lines~append('ZONE=' || zoneLine)
  end

  episodeLines = .array~new
  do episode over episodeSnapshots
    episodeLines~append(episode~canonicalText)
  end
  episodeLines~sort
  do episodeLine over episodeLines
    lines~append('EPISODE=' || episodeLine)
  end

  motifLines = .array~new
  do motif over motifSnapshots
    motifLines~append(motif~canonicalText)
  end
  motifLines~sort
  do motifLine over motifLines
    lines~append('MOTIF=' || motifLine)
  end

  primitiveLines = .array~new
  do primitive over primitiveSnapshots
    primitiveLines~append(primitive~canonicalText)
  end
  primitiveLines~sort
  do primitiveLine over primitiveLines
    lines~append('PRIMITIVE=' || primitiveLine)
  end

  routeLines = .array~new
  do route over routeSnapshots
    routeLines~append(route~canonicalText)
  end
  routeLines~sort
  do routeLine over routeLines
    lines~append('ROUTE=' || routeLine)
  end

  transitionLines = .array~new
  do transition over transitionSnapshots
    transitionLines~append(transition~canonicalText)
  end
  transitionLines~sort
  do transitionLine over transitionLines
    lines~append('TRANSITION=' || transitionLine)
  end

  return lines~makeString('L')

::method canonicalText
  /* Lifecycle state is intentionally not part of semantic content identity. */
  return self~semanticCanonicalText


::class CameraLearnedGenerationRegistry public

::method init
  expose generations nextGenerationNumber currentGeneration
  generations = .directory~new
  nextGenerationNumber = 1
  currentGeneration = .nil

::method publish
  expose generations nextGenerationNumber currentGeneration
  use arg timestamp, camera
  if camera == .nil then return .nil
  if currentGeneration \== .nil then oldState = currentGeneration~supersede
  generationId = 'G' || nextGenerationNumber
  nextGenerationNumber = nextGenerationNumber + 1
  generation = .CameraLearnedGeneration~new(generationId, timestamp, camera)
  generations[generationId] = generation
  currentGeneration = generation
  return generation

::method currentGeneration
  expose currentGeneration
  return currentGeneration

::method generation
  expose generations
  use arg generationId
  if generations~hasIndex(generationId) then return generations[generationId]
  return .nil

::method generations
  expose generations
  ids = generations~allIndexes
  ids~sort
  copy = .array~new
  do generationId over ids
    copy~append(generations[generationId])
  end
  return copy

::method generationCount
  expose generations
  return generations~items


::class CameraTrackPoint public
::attribute timestamp
::attribute box

::method init
  use arg timestamp, box
  self~timestamp = timestamp
  self~box = box


::class CameraTrack public
::attribute id
::attribute state
::attribute objectType
::attribute routeId
::attribute missedFrames
::attribute routeLearningState
::attribute descriptionBits
::attribute temporalRouteBits
::attribute entryZoneId
::attribute exitZoneId
::attribute routeTubeResidual
::attribute routeDeviationTimestamp
::attribute spatialDescriptionBits

::method init
  expose points
  use arg id
  self~id = id
  self~state = .CameraConstant~TRACK_NEW
  self~objectType = .CameraConstant~OBJECT_UNKNOWN
  self~routeId = ''
  self~missedFrames = 0
  self~routeLearningState = .CameraConstant~ROUTE_NEW
  self~descriptionBits = 0
  self~temporalRouteBits = 0
  self~entryZoneId = ''
  self~exitZoneId = ''
  self~routeTubeResidual = 0
  self~routeDeviationTimestamp = 0
  self~spatialDescriptionBits = 0
  points = .array~new

::method points
  expose points
  return points

::method addObservation
  expose points
  use arg observation
  if observation == .nil then return 0
  p = .CameraTrackPoint~new(observation~timestamp, observation~box)
  points~append(p)
  self~state = .CameraConstant~TRACK_ACTIVE
  self~missedFrames = 0
  return points~items

::method pointCount
  expose points
  return points~items

::method firstPoint
  expose points
  if points~items = 0 then return .nil
  return points[1]

::method lastPoint
  expose points
  if points~items = 0 then return .nil
  return points[points~items]

::method previousPoint
  expose points
  if points~items < 2 then return .nil
  return points[points~items - 1]

::method displacementX
  a = self~firstPoint
  b = self~lastPoint
  if a == .nil then return 0
  if b == .nil then return 0
  return b~box~centreX - a~box~centreX

::method displacementY
  a = self~firstPoint
  b = self~lastPoint
  if a == .nil then return 0
  if b == .nil then return 0
  return b~box~centreY - a~box~centreY

::method forwardDelta
  use arg earlier, later
  d = later - earlier
  if d < 0 then d = d + 86400
  return d

::method velocityX
  previous = self~previousPoint
  last = self~lastPoint
  if previous == .nil then return 0
  if last == .nil then return 0
  dt = self~forwardDelta(previous~timestamp, last~timestamp)
  if dt <= 0 then return 0
  return (last~box~centreX - previous~box~centreX) / dt

::method velocityY
  previous = self~previousPoint
  last = self~lastPoint
  if previous == .nil then return 0
  if last == .nil then return 0
  dt = self~forwardDelta(previous~timestamp, last~timestamp)
  if dt <= 0 then return 0
  return (last~box~centreY - previous~box~centreY) / dt

::method predictCentreX
  use arg timestamp
  last = self~lastPoint
  if last == .nil then return 0
  dt = self~forwardDelta(last~timestamp, timestamp)
  return last~box~centreX + self~velocityX * dt

::method predictCentreY
  use arg timestamp
  last = self~lastPoint
  if last == .nil then return 0
  dt = self~forwardDelta(last~timestamp, timestamp)
  return last~box~centreY + self~velocityY * dt

::method associationScore
  use arg observation, maxGapSeconds
  if observation == .nil then return -1
  if arg(2, 'O') then maxGapSeconds = 3

  last = self~lastPoint
  if last == .nil then return -1
  if self~state = .CameraConstant~TRACK_ENDED then return -1

  dt = self~forwardDelta(last~timestamp, observation~timestamp)
  if dt > maxGapSeconds then return -1

  predictedX = self~predictCentreX(observation~timestamp)
  predictedY = self~predictCentreY(observation~timestamp)
  dx = observation~box~centreX - predictedX
  dy = observation~box~centreY - predictedY
  distance = .CameraMath~sqrt(dx * dx + dy * dy)

  gate = last~box~width
  if last~box~height > gate then gate = last~box~height
  gate = gate * 2
  if gate < 30 then gate = 30

  speedX = self~velocityX
  speedY = self~velocityY
  speed = .CameraMath~sqrt(speedX * speedX + speedY * speedY)
  gate = gate + speed * dt

  if distance > gate then return -1

  sizePenalty = last~box~sizeDifferenceTo(observation~box)
  if sizePenalty > 0.75 then return -1

  distancePenalty = distance / gate
  score = 1 - (0.75 * distancePenalty) - (0.25 * sizePenalty)
  return score

::method trajectoryLength
  expose points
  if points~items < 2 then return 0
  total = 0
  previousPoint = points[1]
  do pointIndex = 2 to points~items
    currentPoint = points[pointIndex]
    dx = currentPoint~box~centreX - previousPoint~box~centreX
    dy = currentPoint~box~centreY - previousPoint~box~centreY
    total = total + .CameraMath~sqrt(dx * dx + dy * dy)
    previousPoint = currentPoint
  end
  return total

::method duration
  first = self~firstPoint
  last = self~lastPoint
  if first == .nil then return 0
  if last == .nil then return 0
  return self~forwardDelta(first~timestamp, last~timestamp)

::method midpoint
  expose points
  if points~items = 0 then return .nil
  midpointIndex = (points~items + 1) % 2
  if midpointIndex < 1 then midpointIndex = 1
  return points[midpointIndex]

::method spatialRelationEncoding
  use arg rootRegion
  return .CameraRelativeTrackEncoding~new(self, rootRegion)

::method markMissed
  use arg maxMissedFrames
  if arg(1, 'O') then maxMissedFrames = 2
  self~missedFrames = self~missedFrames + 1
  if self~missedFrames > maxMissedFrames then do
    self~state = .CameraConstant~TRACK_ENDED
    return self~state
  end
  self~state = .CameraConstant~TRACK_OCCLUDED
  return self~state

::method endTrack
  self~state = .CameraConstant~TRACK_ENDED
  return self~state


::class CameraTrackAssociator public
::attribute maxGapSeconds
::attribute maxMissedFrames
::attribute minimumScore

::method init
  use arg maxGapSeconds, maxMissedFrames, minimumScore
  if arg(1, 'O') then maxGapSeconds = 3
  if arg(2, 'O') then maxMissedFrames = 2
  if arg(3, 'O') then minimumScore = 0.15
  self~maxGapSeconds = maxGapSeconds
  self~maxMissedFrames = maxMissedFrames
  self~minimumScore = minimumScore

::method bestTrack
  use arg tracks, observation, claimedIds
  if tracks == .nil then return .nil
  if observation == .nil then return .nil
  if arg(3, 'O') then claimedIds = .set~new

  best = .nil
  bestScore = self~minimumScore

  supplier = tracks~supplier
  do while supplier~available
    track = supplier~item
    supplier~next

    if track~state = .CameraConstant~TRACK_ENDED then iterate
    if claimedIds~hasIndex(track~id) then iterate

    score = track~associationScore(observation, self~maxGapSeconds)
    if score >= bestScore then do
      bestScore = score
      best = track
    end
  end
  return best


::class CameraRoute public
::attribute id
::attribute sampleCount
::attribute meanEntryX
::attribute meanEntryY
::attribute meanMidX
::attribute meanMidY
::attribute meanExitX
::attribute meanExitY
::attribute meanDuration
::attribute meanLength

::method init
  use arg id
  self~id = id
  self~sampleCount = 0
  self~meanEntryX = 0
  self~meanEntryY = 0
  self~meanMidX = 0
  self~meanMidY = 0
  self~meanExitX = 0
  self~meanExitY = 0
  self~meanDuration = 0
  self~meanLength = 0

::method observeTrack
  use arg track
  if track == .nil then return 0
  firstPoint = track~firstPoint
  middlePoint = track~midpoint
  lastPoint = track~lastPoint
  if firstPoint == .nil then return 0
  if middlePoint == .nil then return 0
  if lastPoint == .nil then return 0

  oldCount = self~sampleCount
  newCount = oldCount + 1
  self~meanEntryX = self~updatedMean(self~meanEntryX, oldCount, firstPoint~box~centreX, newCount)
  self~meanEntryY = self~updatedMean(self~meanEntryY, oldCount, firstPoint~box~centreY, newCount)
  self~meanMidX = self~updatedMean(self~meanMidX, oldCount, middlePoint~box~centreX, newCount)
  self~meanMidY = self~updatedMean(self~meanMidY, oldCount, middlePoint~box~centreY, newCount)
  self~meanExitX = self~updatedMean(self~meanExitX, oldCount, lastPoint~box~centreX, newCount)
  self~meanExitY = self~updatedMean(self~meanExitY, oldCount, lastPoint~box~centreY, newCount)
  self~meanDuration = self~updatedMean(self~meanDuration, oldCount, track~duration, newCount)
  self~meanLength = self~updatedMean(self~meanLength, oldCount, track~trajectoryLength, newCount)
  self~sampleCount = newCount
  return newCount

::method updatedMean private
  use arg oldMean, oldCount, newValue, newCount
  if newCount <= 1 then return newValue
  return ((oldMean * oldCount) + newValue) / newCount

::method endpointResidual
  use arg track
  if track == .nil then return 999999999
  firstPoint = track~firstPoint
  lastPoint = track~lastPoint
  if firstPoint == .nil then return 999999999
  if lastPoint == .nil then return 999999999
  entryDx = firstPoint~box~centreX - self~meanEntryX
  entryDy = firstPoint~box~centreY - self~meanEntryY
  exitDx = lastPoint~box~centreX - self~meanExitX
  exitDy = lastPoint~box~centreY - self~meanExitY
  entryDistance = .CameraMath~sqrt(entryDx * entryDx + entryDy * entryDy)
  exitDistance = .CameraMath~sqrt(exitDx * exitDx + exitDy * exitDy)
  return (entryDistance + exitDistance) / 2

::method shapeResidual
  use arg track
  if track == .nil then return 999999999
  middlePoint = track~midpoint
  if middlePoint == .nil then return 999999999
  dx = middlePoint~box~centreX - self~meanMidX
  dy = middlePoint~box~centreY - self~meanMidY
  return .CameraMath~sqrt(dx * dx + dy * dy)

::method matchResidual
  use arg track
  endpointPart = self~endpointResidual(track)
  shapePart = self~shapeResidual(track)
  return (endpointPart * 0.7) + (shapePart * 0.3)

::method tubeResidual
  use arg track
  if track == .nil then return 999999999
  if track~pointCount = 0 then return 999999999

  totalResidual = 0
  maximumResidual = 0
  do trackPoint over track~points
    px = trackPoint~box~centreX
    py = trackPoint~box~centreY
    firstSegment = .CameraMath~pointToSegmentDistance(px, py, self~meanEntryX, self~meanEntryY, self~meanMidX, self~meanMidY)
    secondSegment = .CameraMath~pointToSegmentDistance(px, py, self~meanMidX, self~meanMidY, self~meanExitX, self~meanExitY)
    pointResidual = firstSegment
    if secondSegment < pointResidual then pointResidual = secondSegment
    totalResidual = totalResidual + pointResidual
    if pointResidual > maximumResidual then maximumResidual = pointResidual
  end

  meanResidual = totalResidual / track~pointCount
  return (maximumResidual * 0.75) + (meanResidual * 0.25)

::method maximumTubeResidualTimestamp
  use arg track
  if track == .nil then return 0
  if track~pointCount = 0 then return 0
  maximumResidual = -1
  maximumTimestamp = 0
  do trackPoint over track~points
    px = trackPoint~box~centreX
    py = trackPoint~box~centreY
    firstSegment = .CameraMath~pointToSegmentDistance(px, py, self~meanEntryX, self~meanEntryY, self~meanMidX, self~meanMidY)
    secondSegment = .CameraMath~pointToSegmentDistance(px, py, self~meanMidX, self~meanMidY, self~meanExitX, self~meanExitY)
    pointResidual = firstSegment
    if secondSegment < pointResidual then pointResidual = secondSegment
    if pointResidual > maximumResidual then do
      maximumResidual = pointResidual
      maximumTimestamp = trackPoint~timestamp
    end
  end
  return maximumTimestamp


::class CameraTrackEncoding public
::attribute encodingType
::attribute routeId
::attribute literalBits
::attribute residualBits
::attribute totalBits
::attribute knownRoute

::method init
  use arg encodingType, routeId, literalBits, residualBits, knownRoute
  if arg(2, 'O') then routeId = ''
  if arg(3, 'O') then literalBits = 0
  if arg(4, 'O') then residualBits = 0
  if arg(5, 'O') then knownRoute = .false
  self~encodingType = encodingType
  self~routeId = routeId
  self~literalBits = literalBits
  self~residualBits = residualBits
  self~totalBits = literalBits + residualBits
  self~knownRoute = knownRoute


::class CameraRouteModel public
::attribute matchTolerance
::attribute minimumTrackPoints

::method init
  expose routes nextRouteNumber
  use arg matchTolerance, minimumTrackPoints
  if arg(1, 'O') then matchTolerance = 45
  if arg(2, 'O') then minimumTrackPoints = 3
  self~matchTolerance = matchTolerance
  self~minimumTrackPoints = minimumTrackPoints
  routes = .directory~new
  nextRouteNumber = 1

::method routes
  expose routes
  return routes

::method routeCount
  expose routes
  return routes~items

::method bestRoute
  expose routes
  use arg track
  if track == .nil then return .nil
  bestRoute = .nil
  bestResidual = self~matchTolerance
  routeSupplier = routes~supplier
  do while routeSupplier~available
    routeCandidate = routeSupplier~item
    routeSupplier~next
    residual = routeCandidate~matchResidual(track)
    if residual <= bestResidual then do
      bestResidual = residual
      bestRoute = routeCandidate
    end
  end
  return bestRoute

::method literalEncoding
  use arg track
  pointCount = track~pointCount
  literalBits = 32 + (pointCount * 32)
  return .CameraTrackEncoding~new(.CameraConstant~ENCODING_LITERAL, '', literalBits, 0, .false)

::method routeEncoding
  use arg track, route
  residual = route~matchResidual(track)
  /* Initial cost model: route token + quantised residual burden. */
  routeBits = 24
  residualBits = residual * 2
  return .CameraTrackEncoding~new(.CameraConstant~ENCODING_ROUTE, route~id, routeBits, residualBits, .true)

::method learnTrack
  expose routes nextRouteNumber
  use arg track
  if track == .nil then return .nil
  if track~pointCount < self~minimumTrackPoints then do
    encoding = self~literalEncoding(track)
    track~descriptionBits = encoding~totalBits
    return encoding
  end

  route = self~bestRoute(track)
  if route == .nil then do
    routeId = 'R' || nextRouteNumber
    nextRouteNumber = nextRouteNumber + 1
    route = .CameraRoute~new(routeId)
    route~observeTrack(track)
    routes[routeId] = route
    track~routeId = routeId
    track~routeLearningState = .CameraConstant~ROUTE_NEW
    track~routeTubeResidual = 0
    track~routeDeviationTimestamp = 0
    encoding = self~literalEncoding(track)
    track~descriptionBits = encoding~totalBits
    return encoding
  end

  encoding = self~routeEncoding(track, route)
  track~routeId = route~id
  track~routeLearningState = .CameraConstant~ROUTE_KNOWN
  track~routeTubeResidual = route~tubeResidual(track)
  track~routeDeviationTimestamp = route~maximumTubeResidualTimestamp(track)
  track~descriptionBits = encoding~totalBits
  route~observeTrack(track)
  return encoding


::method restoreRoute
  expose routes nextRouteNumber
  use arg route
  if route == .nil then return 0
  routes[route~id] = route
  suffix = route~id~substr(2)
  if datatype(suffix, 'W') then do
    candidateNumber = suffix + 1
    if candidateNumber > nextRouteNumber then nextRouteNumber = candidateNumber
  end
  return routes~items


::class CameraZone public
::attribute id
::attribute sampleCount
::attribute meanX
::attribute meanY

::method init
  use arg id
  self~id = id
  self~sampleCount = 0
  self~meanX = 0
  self~meanY = 0

::method observeBox
  use arg box
  if box == .nil then return 0
  oldCount = self~sampleCount
  newCount = oldCount + 1
  if oldCount = 0 then do
    self~meanX = box~centreX
    self~meanY = box~centreY
  end
  else do
    self~meanX = ((self~meanX * oldCount) + box~centreX) / newCount
    self~meanY = ((self~meanY * oldCount) + box~centreY) / newCount
  end
  self~sampleCount = newCount
  return newCount

::method distanceToBox
  use arg box
  if box == .nil then return 999999999
  dx = box~centreX - self~meanX
  dy = box~centreY - self~meanY
  return .CameraMath~sqrt((dx * dx) + (dy * dy))


::class CameraZoneModel public
::attribute matchTolerance

::method init
  expose zones nextZoneNumber
  use arg matchTolerance
  if arg(1, 'O') then matchTolerance = 35
  self~matchTolerance = matchTolerance
  zones = .directory~new
  nextZoneNumber = 1

::method zones
  expose zones
  return zones

::method zoneCount
  expose zones
  return zones~items

::method bestZone
  expose zones
  use arg box
  if box == .nil then return .nil
  nearest = .nil
  nearestDistance = self~matchTolerance
  zoneSupplier = zones~supplier
  do while zoneSupplier~available
    zone = zoneSupplier~item
    zoneSupplier~next
    distance = zone~distanceToBox(box)
    if distance <= nearestDistance then do
      nearestDistance = distance
      nearest = zone
    end
  end
  return nearest

::method learnBox
  expose zones nextZoneNumber
  use arg box
  if box == .nil then return .nil
  zone = self~bestZone(box)
  if zone == .nil then do
    zoneId = 'Z' || nextZoneNumber
    nextZoneNumber = nextZoneNumber + 1
    zone = .CameraZone~new(zoneId)
    zones[zoneId] = zone
  end
  zone~observeBox(box)
  return zone

::method learnTrackEndpoints
  use arg track
  if track == .nil then return 0
  firstPoint = track~firstPoint
  lastPoint = track~lastPoint
  if firstPoint == .nil then return 0
  if lastPoint == .nil then return 0
  entryZone = self~learnBox(firstPoint~box)
  exitZone = self~learnBox(lastPoint~box)
  track~entryZoneId = entryZone~id
  track~exitZoneId = exitZone~id
  return 2

::method pointForTimestamp private
  use arg track, timestamp
  if track == .nil then return .nil
  do trackPoint over track~points
    if trackPoint~timestamp = timestamp then return trackPoint
  end
  return .nil

::method annotateEvents
  use arg track, events, firstIndex, lastIndex
  if track == .nil then return 0
  if events == .nil then return 0
  if firstIndex < 1 then firstIndex = 1
  if lastIndex > events~items then lastIndex = events~items
  if lastIndex < firstIndex then return 0

  annotated = 0
  do eventIndex = firstIndex to lastIndex
    spatialEvent = events[eventIndex]
    eventPoint = self~pointForTimestamp(track, spatialEvent~timestamp)
    if eventPoint == .nil then iterate

    shouldLearn = .false
    if spatialEvent~eventType = .CameraConstant~EVENT_ENTER then shouldLearn = .true
    if spatialEvent~eventType = .CameraConstant~EVENT_EXIT then shouldLearn = .true
    if spatialEvent~eventType = .CameraConstant~EVENT_STOP then shouldLearn = .true
    if spatialEvent~eventType = .CameraConstant~EVENT_REVERSE then shouldLearn = .true
    if spatialEvent~eventType = .CameraConstant~EVENT_CLOSE then shouldLearn = .true
    if spatialEvent~eventType = .CameraConstant~EVENT_DEVIATE then shouldLearn = .true

    if shouldLearn then do
      zone = self~learnBox(eventPoint~box)
      spatialEvent~zoneId = zone~id
      annotated = annotated + 1
    end
    else do
      zone = self~bestZone(eventPoint~box)
      if zone \== .nil then do
        spatialEvent~zoneId = zone~id
        annotated = annotated + 1
      end
    end
  end
  return annotated


::method restoreZone
  expose zones nextZoneNumber
  use arg zone
  if zone == .nil then return 0
  zones[zone~id] = zone
  suffix = zone~id~substr(2)
  if datatype(suffix, 'W') then do
    candidateNumber = suffix + 1
    if candidateNumber > nextZoneNumber then nextZoneNumber = candidateNumber
  end
  return zones~items


::class CameraSpatialModel public
::attribute zones
::attribute routeDeviationThreshold

::method init
  use arg zoneTolerance, routeDeviationThreshold
  if arg(1, 'O') then zoneTolerance = 35
  if arg(2, 'O') then routeDeviationThreshold = 35
  self~zones = .CameraZoneModel~new(zoneTolerance)
  self~routeDeviationThreshold = routeDeviationThreshold

::method learnTrackEndpoints
  use arg track
  return self~zones~learnTrackEndpoints(track)

::method annotateEvents
  use arg track, events, firstIndex, lastIndex
  return self~zones~annotateEvents(track, events, firstIndex, lastIndex)


::class CameraEvent public
::attribute id
::attribute eventType
::attribute timestamp
::attribute trackAId
::attribute trackBId
::attribute value
::attribute detail
::attribute descriptionBits
::attribute zoneId
::attribute routeId
::attribute zoneDescriptionBits
::attribute episodeId
::attribute episodeDescriptionBits
::attribute episodeInstanceId

::method init
  use arg id, eventType, timestamp, trackAId, trackBId, value, detail
  if arg(4, 'O') then trackAId = ''
  if arg(5, 'O') then trackBId = ''
  if arg(6, 'O') then value = 0
  if arg(7, 'O') then detail = ''
  self~id = id
  self~eventType = eventType
  self~timestamp = timestamp
  self~trackAId = trackAId
  self~trackBId = trackBId
  self~value = value
  self~detail = detail
  self~descriptionBits = 0
  self~zoneId = ''
  self~routeId = ''
  self~zoneDescriptionBits = 0
  self~episodeId = ''
  self~episodeDescriptionBits = 0
  self~episodeInstanceId = ''


::class CameraEventGrammar public
::attribute stopDistance
::attribute closeDistance
::attribute approachDelta
::attribute separationDelta
::attribute routeDeviationThreshold

::method init
  expose events nextEventNumber analysedTracks analysedPairs
  use arg stopDistance, closeDistance, approachDelta, separationDelta, routeDeviationThreshold
  if arg(1, 'O') then stopDistance = 2
  if arg(2, 'O') then closeDistance = 55
  if arg(3, 'O') then approachDelta = 20
  if arg(4, 'O') then separationDelta = 20
  if arg(5, 'O') then routeDeviationThreshold = 35
  self~stopDistance = stopDistance
  self~closeDistance = closeDistance
  self~approachDelta = approachDelta
  self~separationDelta = separationDelta
  self~routeDeviationThreshold = routeDeviationThreshold
  events = .array~new
  nextEventNumber = 1
  analysedTracks = .set~new
  analysedPairs = .set~new

::method events
  expose events
  return events

::method eventCount
  expose events
  return events~items

::method countType
  expose events
  use arg eventType
  count = 0
  do event over events
    if event~eventType = eventType then count = count + 1
  end
  return count

::method addEvent private
  expose events nextEventNumber
  use arg eventType, timestamp, trackAId, trackBId, value, detail
  id = 'E' || nextEventNumber
  nextEventNumber = nextEventNumber + 1
  event = .CameraEvent~new(id, eventType, timestamp, trackAId, trackBId, value, detail)
  events~append(event)
  return event

::method analyseTrack
  expose analysedTracks
  use arg track
  if track == .nil then return 0
  if analysedTracks~hasIndex(track~id) then return 0
  if track~pointCount = 0 then return 0

  beforeCount = self~eventCount
  firstPoint = track~firstPoint
  lastPoint = track~lastPoint
  self~addEvent(.CameraConstant~EVENT_ENTER, firstPoint~timestamp, track~id, '', 0, 'track-enter')

  points = track~points
  previousDx = 0
  previousDy = 0
  havePreviousVector = .false

  do pointIndex = 2 to points~items
    earlierPoint = points[pointIndex - 1]
    laterPoint = points[pointIndex]
    dx = laterPoint~box~centreX - earlierPoint~box~centreX
    dy = laterPoint~box~centreY - earlierPoint~box~centreY
    distance = .CameraMath~sqrt(dx * dx + dy * dy)

    if distance <= self~stopDistance then do
      self~addEvent(.CameraConstant~EVENT_STOP, laterPoint~timestamp, track~id, '', distance, 'low-displacement')
    end
    else do
      if havePreviousVector then do
        dotProduct = (previousDx * dx) + (previousDy * dy)
        if dotProduct < 0 then do
          self~addEvent(.CameraConstant~EVENT_REVERSE, laterPoint~timestamp, track~id, '', distance, 'direction-reversal')
        end
      end
      self~addEvent(.CameraConstant~EVENT_MOVE, laterPoint~timestamp, track~id, '', distance, 'segment-move')
      previousDx = dx
      previousDy = dy
      havePreviousVector = .true
    end
  end

  self~addEvent(.CameraConstant~EVENT_EXIT, lastPoint~timestamp, track~id, '', 0, 'track-exit')
  analysedTracks[track~id] = track~id
  return self~eventCount - beforeCount

::method analyseRouteDeviation
  use arg track
  if track == .nil then return 0
  if track~routeId = '' then return 0
  if track~routeLearningState \= .CameraConstant~ROUTE_KNOWN then return 0
  residual = track~routeTubeResidual
  if residual <= self~routeDeviationThreshold then return 0
  deviationTimestamp = track~routeDeviationTimestamp
  if deviationTimestamp = 0 then do
    middlePoint = track~midpoint
    if middlePoint == .nil then return 0
    deviationTimestamp = middlePoint~timestamp
  end
  deviationEvent = self~addEvent(.CameraConstant~EVENT_DEVIATE, deviationTimestamp, track~id, '', residual, 'route-tube-deviation')
  deviationEvent~routeId = track~routeId
  return 1

::method pairKey private
  use arg trackA, trackB
  if trackA~id < trackB~id then return trackA~id || '|' || trackB~id
  return trackB~id || '|' || trackA~id

::method pointAtTimestamp private
  use arg track, timestamp
  do point over track~points
    if point~timestamp = timestamp then return point
  end
  return .nil

::method analysePair
  expose analysedPairs
  use arg trackA, trackB
  if trackA == .nil then return 0
  if trackB == .nil then return 0
  if trackA~id = trackB~id then return 0

  key = self~pairKey(trackA, trackB)
  if analysedPairs~hasIndex(key) then return 0
  analysedPairs[key] = key

  timestamps = .array~new
  distances = .array~new
  do pointA over trackA~points
    pointB = self~pointAtTimestamp(trackB, pointA~timestamp)
    if pointB == .nil then iterate
    dx = pointA~box~centreX - pointB~box~centreX
    dy = pointA~box~centreY - pointB~box~centreY
    distance = .CameraMath~sqrt(dx * dx + dy * dy)
    timestamps~append(pointA~timestamp)
    distances~append(distance)
  end

  if distances~items < 3 then return 0

  minimumIndex = 1
  minimumDistance = distances[1]
  do distanceIndex = 2 to distances~items
    if distances[distanceIndex] < minimumDistance then do
      minimumDistance = distances[distanceIndex]
      minimumIndex = distanceIndex
    end
  end

  beforeCount = self~eventCount
  firstDistance = distances[1]
  lastDistance = distances[distances~items]

  if minimumDistance <= self~closeDistance then do
    if firstDistance - minimumDistance >= self~approachDelta then do
      self~addEvent(.CameraConstant~EVENT_APPROACH, timestamps[minimumIndex], trackA~id, trackB~id, minimumDistance, 'pair-convergence')
    end
    self~addEvent(.CameraConstant~EVENT_CLOSE, timestamps[minimumIndex], trackA~id, trackB~id, minimumDistance, 'pair-close')
    if lastDistance - minimumDistance >= self~separationDelta then do
      self~addEvent(.CameraConstant~EVENT_SEPARATE, timestamps[distances~items], trackA~id, trackB~id, lastDistance, 'pair-divergence')
    end
  end

  return self~eventCount - beforeCount

::method analysePairsForTrack
  use arg track, tracks
  if track == .nil then return 0
  if tracks == .nil then return 0
  added = 0
  supplier = tracks~supplier
  do while supplier~available
    otherTrack = supplier~item
    supplier~next
    if otherTrack~id = track~id then iterate
    if otherTrack~state \= .CameraConstant~TRACK_ENDED then iterate
    added = added + self~analysePair(track, otherTrack)
  end
  return added


::class CameraScalarDistribution public
::attribute weightTotal
::attribute weightedSum
::attribute weightedSquareSum
::attribute sampleCount

::method init
  self~weightTotal = 0
  self~weightedSum = 0
  self~weightedSquareSum = 0
  self~sampleCount = 0

::method observe
  use arg value, weight
  if arg(2, 'O') then weight = 1
  if weight <= 0 then return self~weightTotal
  self~weightTotal = self~weightTotal + weight
  self~weightedSum = self~weightedSum + (value * weight)
  self~weightedSquareSum = self~weightedSquareSum + (value * value * weight)
  self~sampleCount = self~sampleCount + 1
  return self~weightTotal

::method mean
  if self~weightTotal <= 0 then return 0
  return self~weightedSum / self~weightTotal

::method variance
  if self~weightTotal <= 0 then return 0
  meanValue = self~mean
  varianceValue = (self~weightedSquareSum / self~weightTotal) - (meanValue * meanValue)
  if varianceValue < 0 then varianceValue = 0
  return varianceValue

::method standardDeviation
  return .CameraMath~sqrt(self~variance)

::method zScore
  use arg value
  standardDeviation = self~standardDeviation
  if standardDeviation <= 0.000001 then do
    if abs(value - self~mean) <= 0.000001 then return 0
    return value - self~mean
  end
  return (value - self~mean) / standardDeviation

::method restore
  use arg weightTotal, weightedSum, weightedSquareSum, sampleCount
  self~weightTotal = weightTotal
  self~weightedSum = weightedSum
  self~weightedSquareSum = weightedSquareSum
  self~sampleCount = sampleCount
  return self


::class CameraBehaviourWindow public
::attribute centreSecond
::attribute halfWidth
::attribute observations
::attribute weightedObservations
::attribute routeWeightTotal
::attribute eventWeightTotal
::attribute episodeWeightTotal
::attribute motifWeightTotal
::attribute transitionWeightTotal

::method init
  expose routeWeights eventWeights episodeWeights motifWeights transitionWeights zoneEventWeights zoneEventTotals metrics
  use arg centreSecond, halfWidth
  self~centreSecond = centreSecond
  self~halfWidth = halfWidth
  self~observations = 0
  self~weightedObservations = 0
  self~routeWeightTotal = 0
  self~eventWeightTotal = 0
  self~episodeWeightTotal = 0
  self~motifWeightTotal = 0
  self~transitionWeightTotal = 0
  routeWeights = .directory~new
  eventWeights = .directory~new
  episodeWeights = .directory~new
  motifWeights = .directory~new
  transitionWeights = .directory~new
  zoneEventWeights = .directory~new
  zoneEventTotals = .directory~new
  metrics = .directory~new

::method circularDistance
  use arg secondOfDay
  d = abs(secondOfDay - self~centreSecond)
  wrap = 86400 - d
  if wrap < d then d = wrap
  return d

::method weightFor
  use arg secondOfDay
  d = self~circularDistance(secondOfDay)
  if d > self~halfWidth then return 0
  if self~halfWidth = 0 then do
    if d = 0 then return 1
    return 0
  end
  return 1 - (d / self~halfWidth)

::method observe
  use arg secondOfDay
  weight = self~weightFor(secondOfDay)
  if weight <= 0 then return 0
  self~observations = self~observations + 1
  self~weightedObservations = self~weightedObservations + weight
  return weight

::method routeKey private
  use arg routeId
  return 'ROUTE:' || routeId

::method eventKey private
  use arg eventType
  return 'EVENT:' || eventType

::method episodeKey private
  use arg episodeId
  return 'EPISODE:' || episodeId

::method motifKey private
  use arg motifId
  return 'MOTIF:' || motifId

::method transitionKey private
  use arg transitionId
  return 'TRANSITION:' || transitionId

::method observeRoute
  expose routeWeights
  use arg secondOfDay, routeId
  if routeId = '' then return 0
  weight = self~weightFor(secondOfDay)
  if weight <= 0 then return 0
  key = self~routeKey(routeId)
  oldWeight = 0
  if routeWeights~hasIndex(key) then oldWeight = routeWeights[key]
  routeWeights[key] = oldWeight + weight
  self~routeWeightTotal = self~routeWeightTotal + weight
  return weight

::method observeEvent
  expose eventWeights
  use arg secondOfDay, eventType
  weight = self~weightFor(secondOfDay)
  if weight <= 0 then return 0
  key = self~eventKey(eventType)
  oldWeight = 0
  if eventWeights~hasIndex(key) then oldWeight = eventWeights[key]
  eventWeights[key] = oldWeight + weight
  self~eventWeightTotal = self~eventWeightTotal + weight
  return weight

::method observeEpisode
  expose episodeWeights
  use arg secondOfDay, episodeId
  if episodeId = '' then return 0
  weight = self~weightFor(secondOfDay)
  if weight <= 0 then return 0
  key = self~episodeKey(episodeId)
  oldWeight = 0
  if episodeWeights~hasIndex(key) then oldWeight = episodeWeights[key]
  episodeWeights[key] = oldWeight + weight
  self~episodeWeightTotal = self~episodeWeightTotal + weight
  return weight

::method observeMotif
  expose motifWeights
  use arg secondOfDay, motifId
  if motifId = '' then return 0
  weight = self~weightFor(secondOfDay)
  if weight <= 0 then return 0
  key = self~motifKey(motifId)
  oldWeight = 0
  if motifWeights~hasIndex(key) then oldWeight = motifWeights[key]
  motifWeights[key] = oldWeight + weight
  self~motifWeightTotal = self~motifWeightTotal + weight
  return weight

::method observeTransition
  expose transitionWeights
  use arg secondOfDay, transitionId
  if transitionId = '' then return 0
  weight = self~weightFor(secondOfDay)
  if weight <= 0 then return 0
  key = self~transitionKey(transitionId)
  oldWeight = 0
  if transitionWeights~hasIndex(key) then oldWeight = transitionWeights[key]
  transitionWeights[key] = oldWeight + weight
  self~transitionWeightTotal = self~transitionWeightTotal + weight
  return weight

::method routeWeight
  expose routeWeights
  use arg routeId
  key = self~routeKey(routeId)
  if routeWeights~hasIndex(key) then return routeWeights[key]
  return 0

::method eventWeight
  expose eventWeights
  use arg eventType
  key = self~eventKey(eventType)
  if eventWeights~hasIndex(key) then return eventWeights[key]
  return 0

::method episodeWeight
  expose episodeWeights
  use arg episodeId
  key = self~episodeKey(episodeId)
  if episodeWeights~hasIndex(key) then return episodeWeights[key]
  return 0

::method motifWeight
  expose motifWeights
  use arg motifId
  key = self~motifKey(motifId)
  if motifWeights~hasIndex(key) then return motifWeights[key]
  return 0

::method transitionWeight
  expose transitionWeights
  use arg transitionId
  key = self~transitionKey(transitionId)
  if transitionWeights~hasIndex(key) then return transitionWeights[key]
  return 0

::method zoneEventKey private
  use arg zoneId, eventType
  return 'ZONEEVENT:' || zoneId || ':' || eventType

::method zoneTotalKey private
  use arg zoneId
  return 'ZONETOTAL:' || zoneId

::method observeZoneEvent
  expose zoneEventWeights zoneEventTotals
  use arg secondOfDay, zoneId, eventType
  if zoneId = '' then return 0
  weight = self~weightFor(secondOfDay)
  if weight <= 0 then return 0

  key = self~zoneEventKey(zoneId, eventType)
  oldWeight = 0
  if zoneEventWeights~hasIndex(key) then oldWeight = zoneEventWeights[key]
  zoneEventWeights[key] = oldWeight + weight

  totalKey = self~zoneTotalKey(zoneId)
  oldTotal = 0
  if zoneEventTotals~hasIndex(totalKey) then oldTotal = zoneEventTotals[totalKey]
  zoneEventTotals[totalKey] = oldTotal + weight
  return weight

::method zoneEventWeight
  expose zoneEventWeights
  use arg zoneId, eventType
  key = self~zoneEventKey(zoneId, eventType)
  if zoneEventWeights~hasIndex(key) then return zoneEventWeights[key]
  return 0

::method zoneEventTotal
  expose zoneEventTotals
  use arg zoneId
  key = self~zoneTotalKey(zoneId)
  if zoneEventTotals~hasIndex(key) then return zoneEventTotals[key]
  return 0

::method zoneEventProbability
  use arg zoneId, eventType, alpha
  if arg(3, 'O') then alpha = 0.25
  vocabularySize = .CameraConstant~BEHAVIOUR_EVENT_VOCABULARY
  denominator = self~zoneEventTotal(zoneId) + (alpha * vocabularySize)
  if denominator <= 0 then return 1 / vocabularySize
  return (self~zoneEventWeight(zoneId, eventType) + alpha) / denominator

::method routeProbability
  use arg routeId, vocabularySize, alpha
  if arg(2, 'O') then vocabularySize = 1
  if arg(3, 'O') then alpha = 0.25
  if vocabularySize < 1 then vocabularySize = 1
  denominator = self~routeWeightTotal + (alpha * vocabularySize)
  if denominator <= 0 then return 1 / vocabularySize
  return (self~routeWeight(routeId) + alpha) / denominator

::method eventProbability
  use arg eventType, alpha
  if arg(2, 'O') then alpha = 0.25
  vocabularySize = .CameraConstant~BEHAVIOUR_EVENT_VOCABULARY
  denominator = self~eventWeightTotal + (alpha * vocabularySize)
  if denominator <= 0 then return 1 / vocabularySize
  return (self~eventWeight(eventType) + alpha) / denominator

::method episodeProbability
  use arg episodeId, vocabularySize, alpha
  if arg(2, 'O') then vocabularySize = 1
  if arg(3, 'O') then alpha = 0.25
  if vocabularySize < 1 then vocabularySize = 1
  denominator = self~episodeWeightTotal + (alpha * vocabularySize)
  if denominator <= 0 then return 1 / vocabularySize
  return (self~episodeWeight(episodeId) + alpha) / denominator


::method motifProbability
  use arg motifId, vocabularySize, alpha
  if arg(2, 'O') then vocabularySize = 1
  if arg(3, 'O') then alpha = 0.25
  if vocabularySize < 1 then vocabularySize = 1
  denominator = self~motifWeightTotal + (alpha * vocabularySize)
  if denominator <= 0 then return 1 / vocabularySize
  return (self~motifWeight(motifId) + alpha) / denominator

::method transitionProbability
  use arg transitionId, vocabularySize, alpha
  if arg(2, 'O') then vocabularySize = 1
  if arg(3, 'O') then alpha = 0.25
  if vocabularySize < 1 then vocabularySize = 1
  denominator = self~transitionWeightTotal + (alpha * vocabularySize)
  if denominator <= 0 then return 1 / vocabularySize
  return (self~transitionWeight(transitionId) + alpha) / denominator

::method observeMetric
  expose metrics
  use arg secondOfDay, metricName, value
  if metricName = '' then return 0
  weight = self~weightFor(secondOfDay)
  if weight <= 0 then return 0
  if \ metrics~hasIndex(metricName) then metrics[metricName] = .CameraScalarDistribution~new
  metrics[metricName]~observe(value, weight)
  return weight

::method metricDistribution
  expose metrics
  use arg metricName
  if metrics~hasIndex(metricName) then return metrics[metricName]
  return .nil

::method metrics
  expose metrics
  return metrics

::method restoreMetric
  expose metrics
  use arg metricName, weightTotal, weightedSum, weightedSquareSum, sampleCount
  distribution = .CameraScalarDistribution~new
  distribution~restore(weightTotal, weightedSum, weightedSquareSum, sampleCount)
  metrics[metricName] = distribution
  return distribution

::method routeWeights
  expose routeWeights
  return routeWeights

::method eventWeights
  expose eventWeights
  return eventWeights

::method episodeWeights
  expose episodeWeights
  return episodeWeights

::method motifWeights
  expose motifWeights
  return motifWeights

::method transitionWeights
  expose transitionWeights
  return transitionWeights

::method zoneEventWeights
  expose zoneEventWeights
  return zoneEventWeights

::method restoreRouteWeight
  expose routeWeights
  use arg routeId, weight
  key = self~routeKey(routeId)
  routeWeights[key] = weight
  self~routeWeightTotal = self~routeWeightTotal + weight
  return weight

::method restoreEventWeight
  expose eventWeights
  use arg eventType, weight
  key = self~eventKey(eventType)
  eventWeights[key] = weight
  self~eventWeightTotal = self~eventWeightTotal + weight
  return weight

::method restoreEpisodeWeight
  expose episodeWeights
  use arg episodeId, weight
  key = self~episodeKey(episodeId)
  episodeWeights[key] = weight
  self~episodeWeightTotal = self~episodeWeightTotal + weight
  return weight

::method restoreMotifWeight
  expose motifWeights
  use arg motifId, weight
  key = self~motifKey(motifId)
  motifWeights[key] = weight
  self~motifWeightTotal = self~motifWeightTotal + weight
  return weight

::method restoreTransitionWeight
  expose transitionWeights
  use arg transitionId, weight
  key = self~transitionKey(transitionId)
  transitionWeights[key] = weight
  self~transitionWeightTotal = self~transitionWeightTotal + weight
  return weight

::method restoreZoneEventWeight
  expose zoneEventWeights zoneEventTotals
  use arg zoneId, eventType, weight
  key = self~zoneEventKey(zoneId, eventType)
  zoneEventWeights[key] = weight
  totalKey = self~zoneTotalKey(zoneId)
  oldTotal = 0
  if zoneEventTotals~hasIndex(totalKey) then oldTotal = zoneEventTotals[totalKey]
  zoneEventTotals[totalKey] = oldTotal + weight
  return weight


::class CameraEpisode public
::attribute id
::attribute sequenceKey
::attribute sampleCount

::method init
  use arg id, sequenceKey
  self~id = id
  self~sequenceKey = sequenceKey
  self~sampleCount = 0

::method observe
  self~sampleCount = self~sampleCount + 1
  return self~sampleCount


::class CameraEpisodeEncoding public
::attribute episodeId
::attribute sequenceKey
::attribute state
::attribute literalBits
::attribute encodedBits
::attribute savingBits
::attribute timestamp
::attribute temporalBits
::attribute instanceId

::method init
  use arg episodeId, sequenceKey, state, literalBits, encodedBits
  self~episodeId = episodeId
  self~sequenceKey = sequenceKey
  self~state = state
  self~literalBits = literalBits
  self~encodedBits = encodedBits
  self~savingBits = literalBits - encodedBits
  self~timestamp = 0
  self~temporalBits = encodedBits
  self~instanceId = ''


::class CameraEpisodeModel public
::method init
  expose episodes nextEpisodeNumber nextEpisodeInstanceNumber totalSamples
  episodes = .directory~new
  nextEpisodeNumber = 1
  nextEpisodeInstanceNumber = 1
  totalSamples = 0

::method episodes
  expose episodes
  return episodes

::method episodeCount
  expose episodes
  return episodes~items

::method totalSamples
  expose totalSamples
  return totalSamples

::method episodeForSequence
  expose episodes
  use arg sequenceKey
  if episodes~hasIndex(sequenceKey) then return episodes[sequenceKey]
  return .nil

::method episodeForId
  expose episodes
  use arg episodeId
  if episodeId = '' then return .nil
  episodeSupplier = episodes~supplier
  do while episodeSupplier~available
    candidateEpisode = episodeSupplier~item
    episodeSupplier~next
    if candidateEpisode~id = episodeId then return candidateEpisode
  end
  return .nil

::method episodeProbability
  expose episodes totalSamples
  use arg sequenceKey
  vocabularySize = episodes~items + 1
  count = 0
  if episodes~hasIndex(sequenceKey) then count = episodes[sequenceKey]~sampleCount
  return (count + 1) / (totalSamples + vocabularySize)

::method knownDescriptionBits
  use arg sequenceKey
  probability = self~episodeProbability(sequenceKey)
  return 3 + .CameraMath~surpriseBits(probability)

::method learnSequence
  expose episodes nextEpisodeNumber totalSamples
  use arg sequenceKey
  if sequenceKey = '' then return .nil
  if episodes~hasIndex(sequenceKey) then episode = episodes[sequenceKey]
  else do
    episode = .CameraEpisode~new('EP' || nextEpisodeNumber, sequenceKey)
    nextEpisodeNumber = nextEpisodeNumber + 1
    episodes[sequenceKey] = episode
  end
  episode~observe
  totalSamples = totalSamples + 1
  return episode

::method encodeSequence
  expose episodes
  use arg sequenceKey, literalBits
  if sequenceKey = '' then return .CameraEpisodeEncoding~new('', sequenceKey, .CameraConstant~EPISODE_NEW, literalBits, literalBits)
  episode = self~episodeForSequence(sequenceKey)
  if episode == .nil then return .CameraEpisodeEncoding~new('', sequenceKey, .CameraConstant~EPISODE_NEW, literalBits, literalBits)
  if episode~sampleCount < 2 then return .CameraEpisodeEncoding~new(episode~id, sequenceKey, .CameraConstant~EPISODE_NEW, literalBits, literalBits)
  encodedBits = self~knownDescriptionBits(sequenceKey)
  if encodedBits > literalBits then encodedBits = literalBits
  return .CameraEpisodeEncoding~new(episode~id, sequenceKey, .CameraConstant~EPISODE_KNOWN, literalBits, encodedBits)

::method pairKey private
  use arg event
  a = event~trackAId
  b = event~trackBId
  if a = '' | b = '' then return ''
  if a < b then return a || ':' || b
  return b || ':' || a

::method isPairPrimitive private
  use arg eventType
  if eventType = .CameraConstant~EVENT_APPROACH then return .true
  if eventType = .CameraConstant~EVENT_CLOSE then return .true
  if eventType = .CameraConstant~EVENT_SEPARATE then return .true
  return .false

::method recogniseAndLearnRange
  expose nextEpisodeInstanceNumber
  use arg behaviour, events, firstIndex, lastIndex
  encodings = .array~new
  if behaviour == .nil | events == .nil then return encodings
  if firstIndex < 1 then firstIndex = 1
  if lastIndex > events~items then lastIndex = events~items
  if lastIndex < firstIndex then return encodings

  pairSequences = .directory~new
  pairBits = .directory~new
  pairEvents = .directory~new

  do eventIndex = firstIndex to lastIndex
    candidateEvent = events[eventIndex]
    if \self~isPairPrimitive(candidateEvent~eventType) then iterate
    key = self~pairKey(candidateEvent)
    if key = '' then iterate
    if \pairSequences~hasIndex(key) then do
      pairSequences[key] = ''
      pairBits[key] = 0
      pairEvents[key] = .array~new
    end
    sequenceText = pairSequences[key]
    if sequenceText = '' then sequenceText = candidateEvent~eventType
    else sequenceText = sequenceText || ',' || candidateEvent~eventType
    pairSequences[key] = sequenceText
    eventBits = behaviour~eventDescriptionBits(candidateEvent~timestamp, candidateEvent~eventType)
    pairBits[key] = pairBits[key] + eventBits
    pairEvents[key]~append(candidateEvent)
  end

  pairSupplier = pairSequences~supplier
  do while pairSupplier~available
    sequenceKey = pairSupplier~item
    pairId = pairSupplier~index
    pairSupplier~next
    literalBits = pairBits[pairId]
    encoding = self~encodeSequence(sequenceKey, literalBits)
    memberEventsForPair = pairEvents[pairId]
    if memberEventsForPair~items > 0 then encoding~timestamp = memberEventsForPair[1]~timestamp
    episode = self~learnSequence(sequenceKey)
    if episode \== .nil then do
      if encoding~episodeId = '' then encoding~episodeId = episode~id
      encoding~instanceId = 'EI' || nextEpisodeInstanceNumber
      nextEpisodeInstanceNumber = nextEpisodeInstanceNumber + 1
      do memberEvent over pairEvents[pairId]
        memberEvent~episodeId = episode~id
        memberEvent~episodeInstanceId = encoding~instanceId
        memberEvent~episodeDescriptionBits = encoding~encodedBits
      end
    end
    encodings~append(encoding)
  end
  return encodings

::method restoreEpisode
  expose episodes nextEpisodeNumber totalSamples
  use arg episode
  if episode == .nil then return 0
  episodes[episode~sequenceKey] = episode
  totalSamples = totalSamples + episode~sampleCount
  suffix = episode~id~substr(3)
  if datatype(suffix, 'W') then do
    candidateNumber = suffix + 1
    if candidateNumber > nextEpisodeNumber then nextEpisodeNumber = candidateNumber
  end
  return episodes~items


::class CameraMotif public
::attribute id
::attribute sequenceKey
::attribute sampleCount

::method init
  use arg id, sequenceKey
  self~id = id
  self~sequenceKey = sequenceKey
  self~sampleCount = 0

::method observe
  self~sampleCount = self~sampleCount + 1
  return self~sampleCount


::class CameraMotifEncoding public
::attribute motifId
::attribute sequenceKey
::attribute state
::attribute literalBits
::attribute encodedBits
::attribute savingBits
::attribute timestamp

::method init
  use arg motifId, sequenceKey, state, literalBits, encodedBits, timestamp
  if arg(6, 'O') then timestamp = 0
  self~motifId = motifId
  self~sequenceKey = sequenceKey
  self~state = state
  self~literalBits = literalBits
  self~encodedBits = encodedBits
  self~savingBits = literalBits - encodedBits
  self~timestamp = timestamp


::class CameraMotifModel public
::attribute minimumTokens
::attribute maximumTokens
::attribute slidingTokens

::method init
  expose motifs nextMotifNumber totalSamples
  use arg minimumTokens, maximumTokens, slidingTokens
  if arg(1, 'O') then minimumTokens = 3
  if arg(2, 'O') then maximumTokens = 6
  if arg(3, 'O') then slidingTokens = 4
  self~minimumTokens = minimumTokens
  self~maximumTokens = maximumTokens
  self~slidingTokens = slidingTokens
  motifs = .directory~new
  nextMotifNumber = 1
  totalSamples = 0

::method motifs
  expose motifs
  return motifs

::method motifCount
  expose motifs
  return motifs~items

::method totalSamples
  expose totalSamples
  return totalSamples

::method motifForSequence
  expose motifs
  use arg sequenceKey
  if motifs~hasIndex(sequenceKey) then return motifs[sequenceKey]
  return .nil

::method motifForId
  expose motifs
  use arg motifId
  if motifId = '' then return .nil
  motifSupplier = motifs~supplier
  do while motifSupplier~available
    candidateMotif = motifSupplier~item
    motifSupplier~next
    if candidateMotif~id = motifId then return candidateMotif
  end
  return .nil

::method motifProbability
  expose motifs totalSamples
  use arg sequenceKey
  vocabularySize = motifs~items + 1
  count = 0
  if motifs~hasIndex(sequenceKey) then count = motifs[sequenceKey]~sampleCount
  return (count + 1) / (totalSamples + vocabularySize)

::method knownDescriptionBits
  use arg sequenceKey
  return 4 + .CameraMath~surpriseBits(self~motifProbability(sequenceKey))

::method learnSequence
  expose motifs nextMotifNumber totalSamples
  use arg sequenceKey
  if sequenceKey = '' then return .nil
  if motifs~hasIndex(sequenceKey) then motif = motifs[sequenceKey]
  else do
    motif = .CameraMotif~new('M' || nextMotifNumber, sequenceKey)
    nextMotifNumber = nextMotifNumber + 1
    motifs[sequenceKey] = motif
  end
  motif~observe
  totalSamples = totalSamples + 1
  return motif

::method encodeSequence
  use arg sequenceKey, literalBits, timestamp
  if arg(3, 'O') then timestamp = 0
  motif = self~motifForSequence(sequenceKey)
  if motif == .nil then return .CameraMotifEncoding~new('', sequenceKey, .CameraConstant~MOTIF_NEW, literalBits, literalBits, timestamp)
  if motif~sampleCount < 2 then return .CameraMotifEncoding~new(motif~id, sequenceKey, .CameraConstant~MOTIF_NEW, literalBits, literalBits, timestamp)
  encodedBits = self~knownDescriptionBits(sequenceKey)
  if encodedBits > literalBits then encodedBits = literalBits
  return .CameraMotifEncoding~new(motif~id, sequenceKey, .CameraConstant~MOTIF_KNOWN, literalBits, encodedBits, timestamp)

::method eventToken private
  use arg cameraEvent
  if cameraEvent == .nil then return ''
  if cameraEvent~episodeId \= '' then return 'P:' || cameraEvent~episodeId
  token = 'E:' || cameraEvent~eventType
  if cameraEvent~routeId \= '' then token = token || ':R:' || cameraEvent~routeId
  if cameraEvent~zoneId \= '' then token = token || ':Z:' || cameraEvent~zoneId
  return token

::method orderedEvents private
  use arg events
  ordered = .array~new
  if events == .nil then return ordered
  do cameraEvent over events
    inserted = .false
    if ordered~items = 0 then ordered~append(cameraEvent)
    else do
      do orderedIndex = 1 to ordered~items
        if cameraEvent~timestamp < ordered[orderedIndex]~timestamp then do
          ordered~insert(cameraEvent, orderedIndex)
          inserted = .true
          leave
        end
      end
      if \inserted then ordered~append(cameraEvent)
    end
  end
  return ordered

::method tokensForSummary
  use arg summary
  tokens = .array~new
  if summary == .nil then return tokens
  ordered = self~orderedEvents(summary~events)
  lastEpisodeInstance = ''
  do cameraEvent over ordered
    if cameraEvent~episodeId \= '' then do
      instanceKey = cameraEvent~episodeInstanceId
      if instanceKey = '' then instanceKey = cameraEvent~episodeId || ':' || cameraEvent~trackAId || ':' || cameraEvent~trackBId
      if instanceKey = lastEpisodeInstance then iterate
      lastEpisodeInstance = instanceKey
    end
    else lastEpisodeInstance = ''
    token = self~eventToken(cameraEvent)
    if token \= '' then tokens~append(token)
  end
  return tokens

::method sequenceKeyForRange private
  use arg tokens, firstIndex, lastIndex
  sequenceKey = ''
  do tokenIndex = firstIndex to lastIndex
    if sequenceKey = '' then sequenceKey = tokens[tokenIndex]
    else sequenceKey = sequenceKey || '>' || tokens[tokenIndex]
  end
  return sequenceKey

::method literalBitsForRange private
  use arg tokens, firstIndex, lastIndex
  bits = 0
  do tokenIndex = firstIndex to lastIndex
    bits = bits + 8 + (tokens[tokenIndex]~length * 8)
  end
  return bits

::method recogniseAndLearnSummary
  use arg summary
  encodings = .array~new
  if summary == .nil then return encodings
  tokens = self~tokensForSummary(summary)
  tokenCount = tokens~items
  if tokenCount < self~minimumTokens then return encodings

  if tokenCount <= self~maximumTokens then do
    firstIndex = 1
    lastIndex = tokenCount
    sequenceKey = self~sequenceKeyForRange(tokens, firstIndex, lastIndex)
    literalBits = self~literalBitsForRange(tokens, firstIndex, lastIndex)
    encoding = self~encodeSequence(sequenceKey, literalBits, summary~startSecond)
    motif = self~learnSequence(sequenceKey)
    if motif \= .nil then do
      if encoding~motifId = '' then encoding~motifId = motif~id
      summary~addMotifOccurrence(encoding)
    end
    encodings~append(encoding)
    return encodings
  end

  windowLength = self~slidingTokens
  if windowLength < self~minimumTokens then windowLength = self~minimumTokens
  if windowLength > self~maximumTokens then windowLength = self~maximumTokens
  do firstIndex = 1 to tokenCount - windowLength + 1
    lastIndex = firstIndex + windowLength - 1
    sequenceKey = self~sequenceKeyForRange(tokens, firstIndex, lastIndex)
    literalBits = self~literalBitsForRange(tokens, firstIndex, lastIndex)
    encoding = self~encodeSequence(sequenceKey, literalBits, summary~startSecond)
    motif = self~learnSequence(sequenceKey)
    if motif \= .nil then do
      if encoding~motifId = '' then encoding~motifId = motif~id
      summary~addMotifOccurrence(encoding)
    end
    encodings~append(encoding)
  end
  return encodings

::method restoreMotif
  expose motifs nextMotifNumber totalSamples
  use arg motif
  if motif == .nil then return 0
  motifs[motif~sequenceKey] = motif
  totalSamples = totalSamples + motif~sampleCount
  suffix = motif~id~substr(2)
  if datatype(suffix, 'W') then do
    candidateNumber = suffix + 1
    if candidateNumber > nextMotifNumber then nextMotifNumber = candidateNumber
  end
  return motifs~items


::class CameraMotifTransition public
::attribute id
::attribute fromMotifId
::attribute toMotifId
::attribute sampleCount

::method init
  use arg id, fromMotifId, toMotifId
  self~id = id
  self~fromMotifId = fromMotifId
  self~toMotifId = toMotifId
  self~sampleCount = 0

::method transitionKey
  return self~fromMotifId || '>' || self~toMotifId

::method observe
  self~sampleCount = self~sampleCount + 1
  return self~sampleCount


::class CameraMotifTransitionOccurrence public
::attribute transitionId
::attribute fromMotifId
::attribute toMotifId
::attribute timestamp
::attribute descriptionBits

::method init
  use arg transitionId, fromMotifId, toMotifId, timestamp, descriptionBits
  if arg(5, 'O') then descriptionBits = 0
  self~transitionId = transitionId
  self~fromMotifId = fromMotifId
  self~toMotifId = toMotifId
  self~timestamp = timestamp
  self~descriptionBits = descriptionBits


::class CameraMotifTransitionModel public
::method init
  expose transitions nextTransitionNumber totalSamples
  transitions = .directory~new
  nextTransitionNumber = 1
  totalSamples = 0

::method transitions
  expose transitions
  return transitions

::method transitionCount
  expose transitions
  return transitions~items

::method totalSamples
  expose totalSamples
  return totalSamples

::method transitionForKey
  expose transitions
  use arg transitionKey
  if transitions~hasIndex(transitionKey) then return transitions[transitionKey]
  return .nil

::method transitionForId
  expose transitions
  use arg transitionId
  transitionSupplier = transitions~supplier
  do while transitionSupplier~available
    candidateTransition = transitionSupplier~item
    transitionSupplier~next
    if candidateTransition~id = transitionId then return candidateTransition
  end
  return .nil

::method learn
  expose transitions nextTransitionNumber totalSamples
  use arg fromMotifId, toMotifId
  if fromMotifId = '' then return .nil
  if toMotifId = '' then return .nil
  transitionKey = fromMotifId || '>' || toMotifId
  if transitions~hasIndex(transitionKey) then learnedTransition = transitions[transitionKey]
  else do
    learnedTransition = .CameraMotifTransition~new('X' || nextTransitionNumber, fromMotifId, toMotifId)
    nextTransitionNumber = nextTransitionNumber + 1
    transitions[transitionKey] = learnedTransition
  end
  learnedTransition~observe
  totalSamples = totalSamples + 1
  return learnedTransition

::method recogniseAndLearnSummary
  use arg summary
  occurrences = .array~new
  if summary == .nil then return occurrences
  motifs = summary~motifOccurrences
  if motifs~items < 2 then return occurrences
  do motifIndex = 1 to motifs~items - 1
    fromOccurrence = motifs[motifIndex]
    toOccurrence = motifs[motifIndex + 1]
    if fromOccurrence~motifId = '' then iterate
    if toOccurrence~motifId = '' then iterate
    learnedTransition = self~learn(fromOccurrence~motifId, toOccurrence~motifId)
    if learnedTransition == .nil then iterate
    occurrence = .CameraMotifTransitionOccurrence~new(learnedTransition~id, learnedTransition~fromMotifId, learnedTransition~toMotifId, toOccurrence~timestamp)
    summary~addTransitionOccurrence(occurrence)
    occurrences~append(occurrence)
  end
  return occurrences

::method restoreTransition
  expose transitions nextTransitionNumber totalSamples
  use arg learnedTransition
  if learnedTransition == .nil then return 0
  transitions[learnedTransition~transitionKey] = learnedTransition
  totalSamples = totalSamples + learnedTransition~sampleCount
  suffix = learnedTransition~id~substr(2)
  if datatype(suffix, 'W') then do
    candidateNumber = suffix + 1
    if candidateNumber > nextTransitionNumber then nextTransitionNumber = candidateNumber
  end
  return transitions~items


::class CameraBehaviourModel public
::method init
  expose windows
  windows = .array~new

::method windows
  expose windows
  return windows

::method addWindow
  expose windows
  use arg window
  if window == .nil then return 0
  windows~append(window)
  return windows~items

::method installRegularWindows
  expose windows
  use arg intervalSeconds, halfWidth
  if arg(1, 'O') then intervalSeconds = 900
  if arg(2, 'O') then halfWidth = 3600
  if intervalSeconds <= 0 then return 0
  centre = 0
  added = 0
  do while centre < 86400
    windows~append(.CameraBehaviourWindow~new(centre, halfWidth))
    added = added + 1
    centre = centre + intervalSeconds
  end
  return added

::method observe
  expose windows
  use arg secondOfDay
  totalWeight = 0
  do window over windows
    totalWeight = totalWeight + window~observe(secondOfDay)
  end
  return totalWeight

::method observeRoute
  expose windows
  use arg secondOfDay, routeId
  totalWeight = 0
  do window over windows
    totalWeight = totalWeight + window~observeRoute(secondOfDay, routeId)
  end
  return totalWeight

::method observeEvent
  expose windows
  use arg secondOfDay, eventType
  totalWeight = 0
  do window over windows
    totalWeight = totalWeight + window~observeEvent(secondOfDay, eventType)
  end
  return totalWeight

::method observeEpisode
  expose windows
  use arg secondOfDay, episodeId
  totalWeight = 0
  do window over windows
    totalWeight = totalWeight + window~observeEpisode(secondOfDay, episodeId)
  end
  return totalWeight

::method observeMotif
  expose windows
  use arg secondOfDay, motifId
  totalWeight = 0
  do window over windows
    totalWeight = totalWeight + window~observeMotif(secondOfDay, motifId)
  end
  return totalWeight

::method observeTransition
  expose windows
  use arg secondOfDay, transitionId
  totalWeight = 0
  do window over windows
    totalWeight = totalWeight + window~observeTransition(secondOfDay, transitionId)
  end
  return totalWeight

::method routeProbability
  expose windows
  use arg secondOfDay, routeId, vocabularySize
  if arg(3, 'O') then vocabularySize = 1
  if vocabularySize < 1 then vocabularySize = 1
  weightedProbability = 0
  applicableWeight = 0
  do window over windows
    windowWeight = window~weightFor(secondOfDay)
    if windowWeight <= 0 then iterate
    weightedProbability = weightedProbability + (windowWeight * window~routeProbability(routeId, vocabularySize))
    applicableWeight = applicableWeight + windowWeight
  end
  if applicableWeight <= 0 then return 1 / vocabularySize
  return weightedProbability / applicableWeight

::method eventProbability
  expose windows
  use arg secondOfDay, eventType
  weightedProbability = 0
  applicableWeight = 0
  do window over windows
    windowWeight = window~weightFor(secondOfDay)
    if windowWeight <= 0 then iterate
    weightedProbability = weightedProbability + (windowWeight * window~eventProbability(eventType))
    applicableWeight = applicableWeight + windowWeight
  end
  if applicableWeight <= 0 then return 1 / .CameraConstant~BEHAVIOUR_EVENT_VOCABULARY
  return weightedProbability / applicableWeight

::method routeDescriptionBits
  use arg secondOfDay, routeId, vocabularySize
  if arg(3, 'O') then vocabularySize = 1
  probability = self~routeProbability(secondOfDay, routeId, vocabularySize)
  return 4 + .CameraMath~surpriseBits(probability)

::method eventDescriptionBits
  use arg secondOfDay, eventType
  probability = self~eventProbability(secondOfDay, eventType)
  return 4 + .CameraMath~surpriseBits(probability)

::method episodeProbability
  expose windows
  use arg secondOfDay, episodeId, vocabularySize
  if arg(3, 'O') then vocabularySize = 1
  if vocabularySize < 1 then vocabularySize = 1
  weightedProbability = 0
  applicableWeight = 0
  do window over windows
    windowWeight = window~weightFor(secondOfDay)
    if windowWeight <= 0 then iterate
    weightedProbability = weightedProbability + (windowWeight * window~episodeProbability(episodeId, vocabularySize))
    applicableWeight = applicableWeight + windowWeight
  end
  if applicableWeight <= 0 then return 1 / vocabularySize
  return weightedProbability / applicableWeight

::method episodeDescriptionBits
  use arg secondOfDay, episodeId, vocabularySize
  if arg(3, 'O') then vocabularySize = 1
  probability = self~episodeProbability(secondOfDay, episodeId, vocabularySize)
  return 3 + .CameraMath~surpriseBits(probability)

::method motifProbability
  expose windows
  use arg secondOfDay, motifId, vocabularySize
  if arg(3, 'O') then vocabularySize = 1
  if vocabularySize < 1 then vocabularySize = 1
  weightedProbability = 0
  applicableWeight = 0
  do window over windows
    windowWeight = window~weightFor(secondOfDay)
    if windowWeight <= 0 then iterate
    weightedProbability = weightedProbability + (windowWeight * window~motifProbability(motifId, vocabularySize))
    applicableWeight = applicableWeight + windowWeight
  end
  if applicableWeight <= 0 then return 1 / vocabularySize
  return weightedProbability / applicableWeight

::method motifDescriptionBits
  use arg secondOfDay, motifId, vocabularySize
  if arg(3, 'O') then vocabularySize = 1
  probability = self~motifProbability(secondOfDay, motifId, vocabularySize)
  return 4 + .CameraMath~surpriseBits(probability)

::method transitionProbability
  expose windows
  use arg secondOfDay, transitionId, vocabularySize
  if arg(3, 'O') then vocabularySize = 1
  if vocabularySize < 1 then vocabularySize = 1
  weightedProbability = 0
  applicableWeight = 0
  do window over windows
    windowWeight = window~weightFor(secondOfDay)
    if windowWeight <= 0 then iterate
    weightedProbability = weightedProbability + (windowWeight * window~transitionProbability(transitionId, vocabularySize))
    applicableWeight = applicableWeight + windowWeight
  end
  if applicableWeight <= 0 then return 1 / vocabularySize
  return weightedProbability / applicableWeight

::method transitionDescriptionBits
  use arg secondOfDay, transitionId, vocabularySize
  if arg(3, 'O') then vocabularySize = 1
  probability = self~transitionProbability(secondOfDay, transitionId, vocabularySize)
  return 3 + .CameraMath~surpriseBits(probability)

::method observeZoneEvent
  expose windows
  use arg secondOfDay, zoneId, eventType
  totalWeight = 0
  do window over windows
    totalWeight = totalWeight + window~observeZoneEvent(secondOfDay, zoneId, eventType)
  end
  return totalWeight

::method zoneEventProbability
  expose windows
  use arg secondOfDay, zoneId, eventType
  weightedProbability = 0
  applicableWeight = 0
  do window over windows
    windowWeight = window~weightFor(secondOfDay)
    if windowWeight <= 0 then iterate
    weightedProbability = weightedProbability + (windowWeight * window~zoneEventProbability(zoneId, eventType))
    applicableWeight = applicableWeight + windowWeight
  end
  if applicableWeight <= 0 then return 1 / .CameraConstant~BEHAVIOUR_EVENT_VOCABULARY
  return weightedProbability / applicableWeight

::method zoneEventDescriptionBits
  use arg secondOfDay, zoneId, eventType
  probability = self~zoneEventProbability(secondOfDay, zoneId, eventType)
  return 3 + .CameraMath~surpriseBits(probability)

::method eventSequenceDescriptionBits
  use arg secondOfDay, eventTypes
  if eventTypes == .nil then return 0
  totalBits = 0
  do eventType over eventTypes
    totalBits = totalBits + self~eventDescriptionBits(secondOfDay, eventType)
  end
  return totalBits


::method observeMetric
  expose windows
  use arg secondOfDay, metricName, value
  totalWeight = 0
  do window over windows
    totalWeight = totalWeight + window~observeMetric(secondOfDay, metricName, value)
  end
  return totalWeight

::method metricEstimate
  expose windows
  use arg secondOfDay, metricName
  estimate = .CameraScalarDistribution~new
  do window over windows
    windowWeight = window~weightFor(secondOfDay)
    if windowWeight <= 0 then iterate
    distribution = window~metricDistribution(metricName)
    if distribution == .nil then iterate
    if distribution~weightTotal <= 0 then iterate
    /* Window relevance multiplies historical support without duplicating samples. */
    effectiveWeight = distribution~weightTotal * windowWeight
    estimate~weightTotal = estimate~weightTotal + effectiveWeight
    estimate~weightedSum = estimate~weightedSum + (distribution~mean * effectiveWeight)
    estimate~weightedSquareSum = estimate~weightedSquareSum + ((distribution~variance + (distribution~mean * distribution~mean)) * effectiveWeight)
    estimate~sampleCount = estimate~sampleCount + distribution~sampleCount
  end
  return estimate

::class CameraCalendarBehaviourModel public
::method init
  expose models sampleCounts
  models = .directory~new
  sampleCounts = .directory~new

::method models
  expose models
  return models

::method observeSummary
  expose sampleCounts
  use arg dayClass
  if dayClass = .CameraConstant~DAY_UNKNOWN then return 0
  key = dayClass~string
  oldCount = 0
  if sampleCounts~hasIndex(key) then oldCount = sampleCounts[key]
  sampleCounts[key] = oldCount + 1
  return sampleCounts[key]

::method contextSampleCount
  expose sampleCounts
  use arg dayClass
  key = dayClass~string
  if sampleCounts~hasIndex(key) then return sampleCounts[key]
  return 0

::method sampleCounts
  expose sampleCounts
  return sampleCounts

::method restoreSampleCount
  expose sampleCounts
  use arg dayClass, sampleCount
  sampleCounts[dayClass~string] = sampleCount
  return sampleCount

::method modelFor
  expose models
  use arg dayClass, baseModel, createIfMissing
  if arg(3, 'O') then createIfMissing = .true
  if dayClass = .CameraConstant~DAY_UNKNOWN then return .nil
  key = dayClass~string
  if models~hasIndex(key) then return models[key]
  if \ createIfMissing then return .nil

  contextualModel = .CameraBehaviourModel~new
  if baseModel \== .nil then do baseWindow over baseModel~windows
    contextualModel~addWindow(.CameraBehaviourWindow~new(baseWindow~centreSecond, baseWindow~halfWidth))
  end
  models[key] = contextualModel
  return contextualModel

::method observeMetric
  use arg dayClass, baseModel, secondOfDay, metricName, value
  contextualModel = self~modelFor(dayClass, baseModel, .true)
  if contextualModel == .nil then return 0
  return contextualModel~observeMetric(secondOfDay, metricName, value)

::method observeEpisode
  use arg dayClass, baseModel, secondOfDay, episodeId
  contextualModel = self~modelFor(dayClass, baseModel, .true)
  if contextualModel == .nil then return 0
  return contextualModel~observeEpisode(secondOfDay, episodeId)

::method observeMotif
  use arg dayClass, baseModel, secondOfDay, motifId
  contextualModel = self~modelFor(dayClass, baseModel, .true)
  if contextualModel == .nil then return 0
  return contextualModel~observeMotif(secondOfDay, motifId)

::method observeTransition
  use arg dayClass, baseModel, secondOfDay, transitionId
  contextualModel = self~modelFor(dayClass, baseModel, .true)
  if contextualModel == .nil then return 0
  return contextualModel~observeTransition(secondOfDay, transitionId)

::method episodeDescriptionBits
  use arg dayClass, baseModel, secondOfDay, episodeId, vocabularySize, minimumSupport
  if arg(5, 'O') then vocabularySize = 1
  if arg(6, 'O') then minimumSupport = 3
  if self~contextSampleCount(dayClass) < minimumSupport then return baseModel~episodeDescriptionBits(secondOfDay, episodeId, vocabularySize)
  contextualModel = self~modelFor(dayClass, baseModel, .false)
  if contextualModel == .nil then return baseModel~episodeDescriptionBits(secondOfDay, episodeId, vocabularySize)
  return contextualModel~episodeDescriptionBits(secondOfDay, episodeId, vocabularySize)

::method motifDescriptionBits
  use arg dayClass, baseModel, secondOfDay, motifId, vocabularySize, minimumSupport
  if arg(5, 'O') then vocabularySize = 1
  if arg(6, 'O') then minimumSupport = 3
  if self~contextSampleCount(dayClass) < minimumSupport then return baseModel~motifDescriptionBits(secondOfDay, motifId, vocabularySize)
  contextualModel = self~modelFor(dayClass, baseModel, .false)
  if contextualModel == .nil then return baseModel~motifDescriptionBits(secondOfDay, motifId, vocabularySize)
  return contextualModel~motifDescriptionBits(secondOfDay, motifId, vocabularySize)

::method transitionProbability
  use arg dayClass, baseModel, secondOfDay, transitionId, vocabularySize, minimumSupport
  if arg(5, 'O') then vocabularySize = 1
  if arg(6, 'O') then minimumSupport = 3
  if self~contextSampleCount(dayClass) < minimumSupport then return baseModel~transitionProbability(secondOfDay, transitionId, vocabularySize)
  contextualModel = self~modelFor(dayClass, baseModel, .false)
  if contextualModel == .nil then return baseModel~transitionProbability(secondOfDay, transitionId, vocabularySize)
  return contextualModel~transitionProbability(secondOfDay, transitionId, vocabularySize)

::method transitionDescriptionBits
  use arg dayClass, baseModel, secondOfDay, transitionId, vocabularySize, minimumSupport
  if arg(5, 'O') then vocabularySize = 1
  if arg(6, 'O') then minimumSupport = 3
  if self~contextSampleCount(dayClass) < minimumSupport then return baseModel~transitionDescriptionBits(secondOfDay, transitionId, vocabularySize)
  contextualModel = self~modelFor(dayClass, baseModel, .false)
  if contextualModel == .nil then return baseModel~transitionDescriptionBits(secondOfDay, transitionId, vocabularySize)
  return contextualModel~transitionDescriptionBits(secondOfDay, transitionId, vocabularySize)

::method metricEstimate
  use arg dayClass, baseModel, secondOfDay, metricName
  contextualModel = self~modelFor(dayClass, baseModel, .false)
  if contextualModel == .nil then return .CameraScalarDistribution~new
  return contextualModel~metricEstimate(secondOfDay, metricName)

::method restoreMetric
  use arg dayClass, baseModel, centreSecond, metricName, weightTotal, weightedSum, weightedSquareSum, sampleCount
  contextualModel = self~modelFor(dayClass, baseModel, .true)
  if contextualModel == .nil then return 0
  do contextualWindow over contextualModel~windows
    if contextualWindow~centreSecond = centreSecond then do
      contextualWindow~restoreMetric(metricName, weightTotal, weightedSum, weightedSquareSum, sampleCount)
      return 1
    end
  end
  return 0

::method restoreMotifWeight
  use arg dayClass, baseModel, centreSecond, motifId, weightValue
  contextualModel = self~modelFor(dayClass, baseModel, .true)
  if contextualModel == .nil then return 0
  do contextualWindow over contextualModel~windows
    if contextualWindow~centreSecond = centreSecond then do
      contextualWindow~restoreMotifWeight(motifId, weightValue)
      return 1
    end
  end
  return 0

::method restoreTransitionWeight
  use arg dayClass, baseModel, centreSecond, transitionId, weightValue
  contextualModel = self~modelFor(dayClass, baseModel, .true)
  if contextualModel == .nil then return 0
  do contextualWindow over contextualModel~windows
    if contextualWindow~centreSecond = centreSecond then do
      contextualWindow~restoreTransitionWeight(transitionId, weightValue)
      return 1
    end
  end
  return 0

::method restoreEpisodeWeight
  use arg dayClass, baseModel, centreSecond, episodeId, weightValue
  contextualModel = self~modelFor(dayClass, baseModel, .true)
  if contextualModel == .nil then return 0
  do contextualWindow over contextualModel~windows
    if contextualWindow~centreSecond = centreSecond then do
      contextualWindow~restoreEpisodeWeight(episodeId, weightValue)
      return 1
    end
  end
  return 0


::class CameraEnvironmentSignature public
::attribute globalLuma
::attribute localContrast
::attribute shadowFraction
::attribute brightFraction
::attribute structuralNoise

::method init
  use arg globalLuma, localContrast, shadowFraction, brightFraction, structuralNoise
  if arg(1, 'O') then globalLuma = 0
  if arg(2, 'O') then localContrast = 0
  if arg(3, 'O') then shadowFraction = 0
  if arg(4, 'O') then brightFraction = 0
  if arg(5, 'O') then structuralNoise = 0
  self~globalLuma = globalLuma
  self~localContrast = localContrast
  self~shadowFraction = shadowFraction
  self~brightFraction = brightFraction
  self~structuralNoise = structuralNoise

::method distanceTo
  use arg other
  if other == .nil then return 999999
  d1 = self~globalLuma - other~globalLuma
  d2 = self~localContrast - other~localContrast
  d3 = self~shadowFraction - other~shadowFraction
  d4 = self~brightFraction - other~brightFraction
  d5 = self~structuralNoise - other~structuralNoise
  return .CameraMath~sqrt((d1*d1) + (d2*d2) + (d3*d3) + (d4*d4) + (d5*d5))

::class CameraEnvironmentInference public
::attribute code
::attribute confidence
::attribute method
::attribute distance

::method init
  use arg code, confidence, method, distance
  if arg(1, 'O') then code = .CameraConstant~ENV_UNKNOWN
  if arg(2, 'O') then confidence = 0
  if arg(3, 'O') then method = .CameraConstant~ENV_INFERENCE_UNKNOWN
  if arg(4, 'O') then distance = 999999
  self~code = code
  self~confidence = confidence
  self~method = method
  self~distance = distance

::class CameraEnvironmentProfile public
::attribute code
::attribute backgroundLuma
::attribute backgroundStructure

::method init
  expose metrics signatureMetrics
  use arg code
  if arg(1, 'O') then code = .CameraConstant~ENV_UNKNOWN
  self~code = code
  self~backgroundLuma = .CameraScalarDistribution~new
  self~backgroundStructure = .CameraScalarDistribution~new
  metrics = .directory~new
  signatureMetrics = .directory~new

::method defaultStructuralThreshold
  select
    when self~code = .CameraConstant~ENV_NIGHT_ARTIFICIAL then return 0.14
    when self~code = .CameraConstant~ENV_DAY_DIRECT_SHADOW then return 0.16
    otherwise return 0.10
  end

::method defaultPhotometricThreshold
  select
    when self~code = .CameraConstant~ENV_DAY_DIRECT_SHADOW then return 0.24
    otherwise return 0.20
  end

::method structuralThreshold
  threshold = self~defaultStructuralThreshold
  if self~backgroundStructure~sampleCount >= 3 then do
    learned = self~backgroundStructure~mean + (3 * self~backgroundStructure~standardDeviation)
    if learned > threshold then threshold = learned
  end
  if threshold > 0.45 then threshold = 0.45
  return threshold

::method photometricThreshold
  threshold = self~defaultPhotometricThreshold
  if self~backgroundLuma~sampleCount >= 3 then do
    learned = self~backgroundLuma~mean + (3 * self~backgroundLuma~standardDeviation)
    if learned > threshold then threshold = learned
  end
  if threshold > 0.95 then threshold = 0.95
  return threshold

::method classifyObservation
  use arg observation
  if observation == .nil then return .CameraConstant~CHANGE_NONE
  lum = abs(observation~luminanceDelta)
  structural = abs(observation~structureDelta)
  structuralThreshold = self~structuralThreshold
  photometricThreshold = self~photometricThreshold

  if structural < structuralThreshold then do
    if lum >= photometricThreshold then return .CameraConstant~CHANGE_PHOTOMETRIC
    return .CameraConstant~CHANGE_NONE
  end
  if lum >= photometricThreshold then return .CameraConstant~CHANGE_MIXED
  return .CameraConstant~CHANGE_STRUCTURAL

::method observeBackgroundObservation
  use arg observation
  if observation == .nil then return 0
  self~backgroundLuma~observe(abs(observation~luminanceDelta), 1)
  self~backgroundStructure~observe(abs(observation~structureDelta), 1)
  return self~backgroundStructure~sampleCount

::method observeMetric
  expose metrics
  use arg metricName, value
  if metricName = '' then return 0
  if \ metrics~hasIndex(metricName) then metrics[metricName] = .CameraScalarDistribution~new
  metrics[metricName]~observe(value, 1)
  return metrics[metricName]~sampleCount

::method metricDistribution
  expose metrics
  use arg metricName
  if metrics~hasIndex(metricName) then return metrics[metricName]
  return .nil

::method metrics
  expose metrics
  return metrics

::method restoreMetric
  expose metrics
  use arg metricName, weightTotal, weightedSum, weightedSquareSum, sampleCount
  distribution = .CameraScalarDistribution~new
  distribution~restore(weightTotal, weightedSum, weightedSquareSum, sampleCount)
  metrics[metricName] = distribution
  return distribution

::method observeSignature
  expose signatureMetrics
  use arg signature
  if signature == .nil then return 0
  observedSignatureMetric = self~observeSignatureMetric('GLOBAL_LUMA', signature~globalLuma)
  observedSignatureMetric = self~observeSignatureMetric('LOCAL_CONTRAST', signature~localContrast)
  observedSignatureMetric = self~observeSignatureMetric('SHADOW_FRACTION', signature~shadowFraction)
  observedSignatureMetric = self~observeSignatureMetric('BRIGHT_FRACTION', signature~brightFraction)
  observedSignatureMetric = self~observeSignatureMetric('STRUCTURAL_NOISE', signature~structuralNoise)
  return self~signatureSupport

::method observeSignatureMetric private
  expose signatureMetrics
  use arg metricName, value
  if \ signatureMetrics~hasIndex(metricName) then signatureMetrics[metricName] = .CameraScalarDistribution~new
  signatureMetrics[metricName]~observe(value, 1)
  return signatureMetrics[metricName]~sampleCount

::method signatureMetric
  expose signatureMetrics
  use arg metricName
  if signatureMetrics~hasIndex(metricName) then return signatureMetrics[metricName]
  return .nil

::method signatureMetrics
  expose signatureMetrics
  return signatureMetrics

::method signatureSupport
  expose signatureMetrics
  if \ signatureMetrics~hasIndex('GLOBAL_LUMA') then return 0
  return signatureMetrics['GLOBAL_LUMA']~sampleCount

::method meanSignature
  expose signatureMetrics
  if self~signatureSupport = 0 then return .nil
  luma = self~signatureMean('GLOBAL_LUMA')
  contrast = self~signatureMean('LOCAL_CONTRAST')
  shadow = self~signatureMean('SHADOW_FRACTION')
  bright = self~signatureMean('BRIGHT_FRACTION')
  noise = self~signatureMean('STRUCTURAL_NOISE')
  return .CameraEnvironmentSignature~new(luma, contrast, shadow, bright, noise)

::method signatureMean private
  expose signatureMetrics
  use arg metricName
  if \ signatureMetrics~hasIndex(metricName) then return 0
  return signatureMetrics[metricName]~mean

::method signatureDistance
  use arg signature
  meanSignature = self~meanSignature
  if meanSignature == .nil then return 999999
  return meanSignature~distanceTo(signature)

::method restoreSignatureMetric
  expose signatureMetrics
  use arg metricName, weightTotal, weightedSum, weightedSquareSum, sampleCount
  distribution = .CameraScalarDistribution~new
  distribution~restore(weightTotal, weightedSum, weightedSquareSum, sampleCount)
  signatureMetrics[metricName] = distribution
  return distribution


::class CameraEnvironmentModel public
::method init
  expose profiles
  profiles = .directory~new

::method profiles
  expose profiles
  return profiles

::method profileFor
  expose profiles
  use arg environmentCode
  if arg(1, 'O') then environmentCode = .CameraConstant~ENV_UNKNOWN
  key = environmentCode~string
  if \ profiles~hasIndex(key) then profiles[key] = .CameraEnvironmentProfile~new(environmentCode)
  return profiles[key]

::method classifyObservation
  use arg observation, environmentCode
  profile = self~profileFor(environmentCode)
  return profile~classifyObservation(observation)

::method observeBackgroundObservation
  use arg environmentCode, observation
  profile = self~profileFor(environmentCode)
  return profile~observeBackgroundObservation(observation)

::method observeMetric
  use arg environmentCode, metricName, value
  profile = self~profileFor(environmentCode)
  return profile~observeMetric(metricName, value)

::method metricEstimate
  use arg environmentCode, metricName
  profile = self~profileFor(environmentCode)
  distribution = profile~metricDistribution(metricName)
  if distribution == .nil then return .CameraScalarDistribution~new
  return distribution

::method observeSignature
  use arg environmentCode, signature
  if environmentCode = .CameraConstant~ENV_UNKNOWN then return 0
  profile = self~profileFor(environmentCode)
  return profile~observeSignature(signature)

::method prototypeFor
  use arg environmentCode
  select
    when environmentCode = .CameraConstant~ENV_NIGHT_ARTIFICIAL then return .CameraEnvironmentSignature~new(0.25, 0.35, 0.20, 0.10, 0.08)
    when environmentCode = .CameraConstant~ENV_DAY_DIFFUSE then return .CameraEnvironmentSignature~new(0.65, 0.25, 0.15, 0.25, 0.06)
    when environmentCode = .CameraConstant~ENV_DAY_DIRECT_SHADOW then return .CameraEnvironmentSignature~new(0.60, 0.55, 0.45, 0.30, 0.10)
    otherwise return .CameraEnvironmentSignature~new(0.50, 0.30, 0.20, 0.15, 0.08)
  end

::method timePriorPenalty private
  use arg environmentCode, secondOfDay
  if arg(2, 'O') then return 0
  hour = secondOfDay // 86400
  hour = hour / 3600
  /* Deliberately weak clock prior. The measured scene signature remains dominant. */
  if environmentCode = .CameraConstant~ENV_NIGHT_ARTIFICIAL then do
    if hour >= 20 then return 0
    if hour < 6 then return 0
    return 0.20
  end
  if environmentCode = .CameraConstant~ENV_DAY_DIFFUSE then do
    if hour >= 7 then do
      if hour < 19 then return 0
    end
    return 0.15
  end
  if environmentCode = .CameraConstant~ENV_DAY_DIRECT_SHADOW then do
    if hour >= 8 then do
      if hour < 18 then return 0
    end
    return 0.18
  end
  return 0

::method infer
  expose profiles
  use arg signature, secondOfDay
  if signature == .nil then return .CameraEnvironmentInference~new
  candidates = .array~of(.CameraConstant~ENV_NIGHT_ARTIFICIAL, .CameraConstant~ENV_DAY_DIFFUSE, .CameraConstant~ENV_DAY_DIRECT_SHADOW)
  bestCode = .CameraConstant~ENV_UNKNOWN
  bestDistance = 999999
  bestMethod = .CameraConstant~ENV_INFERENCE_UNKNOWN
  do candidateCode over candidates
    profile = self~profileFor(candidateCode)
    if profile~signatureSupport >= 3 then do
      distance = profile~signatureDistance(signature)
      method = .CameraConstant~ENV_INFERENCE_PROFILE
    end
    else do
      prototype = self~prototypeFor(candidateCode)
      distance = prototype~distanceTo(signature)
      method = .CameraConstant~ENV_INFERENCE_PROTOTYPE
    end
    distance = distance + self~timePriorPenalty(candidateCode, secondOfDay)
    if distance < bestDistance then do
      bestDistance = distance
      bestCode = candidateCode
      bestMethod = method
    end
  end
  confidence = 1 / (1 + bestDistance)
  return .CameraEnvironmentInference~new(bestCode, confidence, bestMethod, bestDistance)

::method restoreProfile
  use arg environmentCode
  return self~profileFor(environmentCode)


::class CameraEnvironmentState public
::attribute code
::attribute timestamp
::attribute globalLuma
::attribute localContrast
::attribute shadowState
::attribute inferenceConfidence
::attribute inferenceMethod

::method init
  use arg code, timestamp
  if arg(1, 'O') then code = .CameraConstant~ENV_UNKNOWN
  if arg(2, 'O') then timestamp = 0
  self~code = code
  self~timestamp = timestamp
  self~globalLuma = 0
  self~localContrast = 0
  self~shadowState = ''
  self~inferenceConfidence = 0
  self~inferenceMethod = .CameraConstant~ENV_INFERENCE_UNKNOWN


::class CameraFrameResult public
::attribute timestamp
::attribute photometricCount
::attribute ignoredCount
::attribute moverCount
::attribute matchedCount
::attribute newTrackCount

::method init
  expose assignments
  use arg timestamp
  self~timestamp = timestamp
  self~photometricCount = 0
  self~ignoredCount = 0
  self~moverCount = 0
  self~matchedCount = 0
  self~newTrackCount = 0
  assignments = .array~new

::method assignments
  expose assignments
  return assignments

::method addAssignment
  expose assignments
  use arg track
  if track == .nil then return 0
  assignments~append(track)
  return assignments~items


/* ------------------------------------------------------------------------- */
/* Rolling current-condition model: recent motif-transition rhythm versus     */
/* the time/day-conditioned historical transition grammar.                    */
/* ------------------------------------------------------------------------- */

::class CameraCurrentCondition public
::attribute timestamp
::attribute dayClass
::attribute windowSeconds
::attribute transitionCount
::attribute uniqueTransitionCount
::attribute empiricalEntropyBits
::attribute baselineEntropyBits
::attribute averageContextSurpriseBits
::attribute excessSurpriseBits
::attribute dominantTransitionId
::attribute dominantTransitionShare
::attribute baselineContext
::attribute metricAssessmentCount
::attribute usableMetricCount
::attribute elevatedMetricCount
::attribute strongestMetricName
::attribute strongestMetricZ
::attribute trendingMetricCount
::attribute strongestTrendMetricName
::attribute strongestTrendDelta
::attribute persistencePhase
::attribute shiftedStreak
::attribute expectedStreak
::attribute phaseStartSecond
::attribute activeRegimeId
::attribute state

::method init
  expose metricSignals
  use arg timestamp, dayClass, windowSeconds
  self~timestamp = timestamp
  self~dayClass = dayClass
  self~windowSeconds = windowSeconds
  self~transitionCount = 0
  self~uniqueTransitionCount = 0
  self~empiricalEntropyBits = 0
  self~baselineEntropyBits = 0
  self~averageContextSurpriseBits = 0
  self~excessSurpriseBits = 0
  self~dominantTransitionId = ''
  self~dominantTransitionShare = 0
  self~baselineContext = 'ALL'
  self~metricAssessmentCount = 0
  self~usableMetricCount = 0
  self~elevatedMetricCount = 0
  self~strongestMetricName = ''
  self~strongestMetricZ = 0
  self~trendingMetricCount = 0
  self~strongestTrendMetricName = ''
  self~strongestTrendDelta = 0
  self~persistencePhase = .CameraConstant~CONDITION_PHASE_INSUFFICIENT
  self~shiftedStreak = 0
  self~expectedStreak = 0
  self~phaseStartSecond = timestamp
  self~activeRegimeId = ''
  metricSignals = .directory~new
  self~state = .CameraConstant~CONDITION_INSUFFICIENT

::method metricSignals
  expose metricSignals
  return metricSignals

::method metricSignal
  expose metricSignals
  use arg metricName
  if metricSignals~hasIndex(metricName) then return metricSignals[metricName]
  return .nil

::method addMetricSignal
  expose metricSignals
  use arg signal
  if signal == .nil then return metricSignals~items
  metricSignals[signal~name] = signal
  return metricSignals~items

::method snapshot
  return .CameraCurrentConditionSnapshot~new(self)

::method compactText
  return 'transitions=' || self~transitionCount || '|unique=' || self~uniqueTransitionCount || '|entropy=' || self~empiricalEntropyBits || '|baselineEntropy=' || self~baselineEntropyBits || '|contextSurprise=' || self~averageContextSurpriseBits || '|excess=' || self~excessSurpriseBits || '|dominant=' || self~dominantTransitionId || '|share=' || self~dominantTransitionShare || '|metrics=' || self~usableMetricCount || '|elevated=' || self~elevatedMetricCount || '|strongest=' || self~strongestMetricName || '|z=' || self~strongestMetricZ || '|trending=' || self~trendingMetricCount || '|trendMetric=' || self~strongestTrendMetricName || '|trendDelta=' || self~strongestTrendDelta || '|phase=' || self~persistencePhase || '|shiftedStreak=' || self~shiftedStreak || '|expectedStreak=' || self~expectedStreak || '|phaseStart=' || self~phaseStartSecond || '|regime=' || self~activeRegimeId || '|context=' || self~baselineContext || '|state=' || self~state



::class CameraCurrentConditionSignalSnapshot public
::attribute name get
::attribute sampleCount get
::attribute averageZ get
::attribute maximumAbsoluteZ get
::attribute firstZ get
::attribute lastZ get
::attribute trendDelta get
::attribute trendState get
::attribute elevated get
::attribute baselineContext get

::method init
  expose name sampleCount averageZ maximumAbsoluteZ firstZ lastZ trendDelta trendState elevated baselineContext
  use arg signal
  name = signal~name
  sampleCount = signal~sampleCount
  averageZ = signal~averageZ
  maximumAbsoluteZ = signal~maximumAbsoluteZ
  firstZ = signal~firstZ
  lastZ = signal~lastZ
  trendDelta = signal~trendDelta
  trendState = signal~trendState
  elevated = signal~elevated
  baselineContext = signal~baselineContext

::method canonicalText
  return self~name || '|samples=' || self~sampleCount || '|averageZ=' || self~averageZ || '|maximumAbsoluteZ=' || self~maximumAbsoluteZ || '|firstZ=' || self~firstZ || '|lastZ=' || self~lastZ || '|trendDelta=' || self~trendDelta || '|trendState=' || self~trendState || '|elevated=' || self~elevated || '|baseline=' || self~baselineContext


::class CameraCurrentConditionSnapshot public
::attribute version get
::attribute timestamp get
::attribute dayClass get
::attribute windowSeconds get
::attribute transitionCount get
::attribute uniqueTransitionCount get
::attribute empiricalEntropyBits get
::attribute baselineEntropyBits get
::attribute averageContextSurpriseBits get
::attribute excessSurpriseBits get
::attribute dominantTransitionId get
::attribute dominantTransitionShare get
::attribute baselineContext get
::attribute metricAssessmentCount get
::attribute usableMetricCount get
::attribute elevatedMetricCount get
::attribute strongestMetricName get
::attribute strongestMetricZ get
::attribute trendingMetricCount get
::attribute strongestTrendMetricName get
::attribute strongestTrendDelta get
::attribute persistencePhase get
::attribute shiftedStreak get
::attribute expectedStreak get
::attribute phaseStartSecond get
::attribute activeRegimeId get
::attribute state get

::method init
  expose signalSnapshots version timestamp dayClass windowSeconds transitionCount uniqueTransitionCount empiricalEntropyBits baselineEntropyBits averageContextSurpriseBits excessSurpriseBits dominantTransitionId dominantTransitionShare baselineContext metricAssessmentCount usableMetricCount elevatedMetricCount strongestMetricName strongestMetricZ trendingMetricCount strongestTrendMetricName strongestTrendDelta persistencePhase shiftedStreak expectedStreak phaseStartSecond activeRegimeId state
  use arg condition
  version = .CameraConstant~CURRENT_CONDITION_SNAPSHOT_VERSION
  timestamp = condition~timestamp
  dayClass = condition~dayClass
  windowSeconds = condition~windowSeconds
  transitionCount = condition~transitionCount
  uniqueTransitionCount = condition~uniqueTransitionCount
  empiricalEntropyBits = condition~empiricalEntropyBits
  baselineEntropyBits = condition~baselineEntropyBits
  averageContextSurpriseBits = condition~averageContextSurpriseBits
  excessSurpriseBits = condition~excessSurpriseBits
  dominantTransitionId = condition~dominantTransitionId
  dominantTransitionShare = condition~dominantTransitionShare
  baselineContext = condition~baselineContext
  metricAssessmentCount = condition~metricAssessmentCount
  usableMetricCount = condition~usableMetricCount
  elevatedMetricCount = condition~elevatedMetricCount
  strongestMetricName = condition~strongestMetricName
  strongestMetricZ = condition~strongestMetricZ
  trendingMetricCount = condition~trendingMetricCount
  strongestTrendMetricName = condition~strongestTrendMetricName
  strongestTrendDelta = condition~strongestTrendDelta
  persistencePhase = condition~persistencePhase
  shiftedStreak = condition~shiftedStreak
  expectedStreak = condition~expectedStreak
  phaseStartSecond = condition~phaseStartSecond
  activeRegimeId = condition~activeRegimeId
  state = condition~state
  signalSnapshots = .directory~new
  signalSupplier = condition~metricSignals~supplier
  do while signalSupplier~available
    signal = signalSupplier~item
    signalSupplier~next
    frozenSignal = .CameraCurrentConditionSignalSnapshot~new(signal)
    signalSnapshots[frozenSignal~name] = frozenSignal
  end

::method metricSignals
  expose signalSnapshots
  copy = .directory~new
  signalSupplier = signalSnapshots~supplier
  do while signalSupplier~available
    frozenSignal = signalSupplier~item
    signalName = signalSupplier~index
    signalSupplier~next
    copy[signalName] = frozenSignal
  end
  return copy

::method metricSignal
  expose signalSnapshots
  use arg metricName
  if signalSnapshots~hasIndex(metricName) then return signalSnapshots[metricName]
  return .nil

::method canonicalText
  expose signalSnapshots
  lines = .array~new
  lines~append('SNAPSHOT_VERSION=' || self~version)
  lines~append('TIMESTAMP=' || self~timestamp)
  lines~append('DAY_CLASS=' || self~dayClass)
  lines~append('WINDOW_SECONDS=' || self~windowSeconds)
  lines~append('TRANSITION_COUNT=' || self~transitionCount)
  lines~append('UNIQUE_TRANSITION_COUNT=' || self~uniqueTransitionCount)
  lines~append('EMPIRICAL_ENTROPY_BITS=' || self~empiricalEntropyBits)
  lines~append('BASELINE_ENTROPY_BITS=' || self~baselineEntropyBits)
  lines~append('AVERAGE_CONTEXT_SURPRISE_BITS=' || self~averageContextSurpriseBits)
  lines~append('EXCESS_SURPRISE_BITS=' || self~excessSurpriseBits)
  lines~append('DOMINANT_TRANSITION_ID=' || self~canonicalNullable(self~dominantTransitionId))
  lines~append('DOMINANT_TRANSITION_SHARE=' || self~dominantTransitionShare)
  lines~append('BASELINE_CONTEXT=' || self~baselineContext)
  lines~append('METRIC_ASSESSMENT_COUNT=' || self~metricAssessmentCount)
  lines~append('USABLE_METRIC_COUNT=' || self~usableMetricCount)
  lines~append('ELEVATED_METRIC_COUNT=' || self~elevatedMetricCount)
  lines~append('STRONGEST_METRIC_NAME=' || self~canonicalNullable(self~strongestMetricName))
  lines~append('STRONGEST_METRIC_Z=' || self~strongestMetricZ)
  lines~append('TRENDING_METRIC_COUNT=' || self~trendingMetricCount)
  lines~append('STRONGEST_TREND_METRIC_NAME=' || self~canonicalNullable(self~strongestTrendMetricName))
  lines~append('STRONGEST_TREND_DELTA=' || self~strongestTrendDelta)
  lines~append('PERSISTENCE_PHASE=' || self~persistencePhase)
  lines~append('SHIFTED_STREAK=' || self~shiftedStreak)
  lines~append('EXPECTED_STREAK=' || self~expectedStreak)
  lines~append('PHASE_START_SECOND=' || self~phaseStartSecond)
  lines~append('ACTIVE_REGIME_ID=' || self~canonicalNullable(self~activeRegimeId))
  lines~append('CONDITION_STATE=' || self~state)

  signalLines = .array~new
  signalSupplier = signalSnapshots~supplier
  do while signalSupplier~available
    frozenSignal = signalSupplier~item
    signalSupplier~next
    signalLines~append('SIGNAL=' || frozenSignal~canonicalText)
  end
  signalLines~sort
  do signalLine over signalLines
    lines~append(signalLine)
  end
  return lines~makeString('L')

::method canonicalNullable private
  use arg value
  if value == .nil then return '<NULL>'
  if value == '' then return '<EMPTY>'
  return value



::class CameraConditionRegimeSnapshot public
::attribute id get
::attribute startSecond get
::attribute endSecond get
::attribute state get
::attribute sampleCount get
::attribute peakMetricName get
::attribute peakMetricZ get
::attribute peakExcessSurpriseBits get
::attribute cause get
::attribute signatureKey get
::attribute classId get
::attribute durationSeconds get

::method init
  expose id startSecond endSecond state sampleCount peakMetricName peakMetricZ peakExcessSurpriseBits cause signatureKey classId durationSeconds
  use arg regime
  id = regime~id
  startSecond = regime~startSecond
  endSecond = regime~endSecond
  state = regime~state
  sampleCount = regime~sampleCount
  peakMetricName = regime~peakMetricName
  peakMetricZ = regime~peakMetricZ
  peakExcessSurpriseBits = regime~peakExcessSurpriseBits
  cause = regime~cause
  signatureKey = regime~signatureKey
  classId = regime~classId
  durationSeconds = regime~durationSeconds

::method canonicalText
  return 'REGIME=' || self~id || '|start=' || self~startSecond || '|end=' || self~endSecond || '|duration=' || self~durationSeconds || '|state=' || self~state || '|samples=' || self~sampleCount || '|peakMetric=' || self~canonicalNullable(self~peakMetricName) || '|peakZ=' || self~peakMetricZ || '|peakExcess=' || self~peakExcessSurpriseBits || '|cause=' || self~canonicalNullable(self~cause) || '|signature=' || self~canonicalNullable(self~signatureKey) || '|class=' || self~canonicalNullable(self~classId)

::method canonicalNullable private
  use arg value
  if value == .nil then return '<NULL>'
  if value == '' then return '<EMPTY>'
  return value


::class CameraConditionRegimeClassSnapshot public
::attribute id get
::attribute signatureKey get
::attribute sampleCount get
::attribute totalDurationSeconds get
::attribute meanDurationSeconds get
::attribute maximumAbsolutePeakZ get
::attribute firstStartSecond get
::attribute lastStartSecond get
::attribute state get

::method init
  expose id signatureKey sampleCount totalDurationSeconds meanDurationSeconds maximumAbsolutePeakZ firstStartSecond lastStartSecond state
  use arg regimeClass
  id = regimeClass~id
  signatureKey = regimeClass~signatureKey
  sampleCount = regimeClass~sampleCount
  totalDurationSeconds = regimeClass~totalDurationSeconds
  meanDurationSeconds = regimeClass~meanDurationSeconds
  maximumAbsolutePeakZ = regimeClass~maximumAbsolutePeakZ
  firstStartSecond = regimeClass~firstStartSecond
  lastStartSecond = regimeClass~lastStartSecond
  state = regimeClass~state

::method canonicalText
  return 'REGIME_CLASS=' || self~id || '|signature=' || self~signatureKey || '|samples=' || self~sampleCount || '|totalDuration=' || self~totalDurationSeconds || '|meanDuration=' || self~meanDurationSeconds || '|maxPeakZ=' || self~maximumAbsolutePeakZ || '|first=' || self~firstStartSecond || '|last=' || self~lastStartSecond || '|state=' || self~state


::class CameraMaterializedStateSnapshot public
::attribute version get
::attribute condition get
::attribute activeRegime get

::method init
  expose version condition activeRegime completedRegimeSnapshots regimeClassSnapshots
  use arg sourceCondition, conditionModel
  version = .CameraConstant~MATERIALIZED_STATE_SNAPSHOT_VERSION
  if sourceCondition == .nil then condition = .nil
  else condition = sourceCondition~snapshot

  activeRegime = .nil
  completedRegimeSnapshots = .array~new
  regimeClassSnapshots = .directory~new

  if conditionModel == .nil then return

  active = conditionModel~activeRegime
  if active \== .nil then activeRegime = .CameraConditionRegimeSnapshot~new(active)

  completed = conditionModel~completedRegimes
  do regime over completed
    completedRegimeSnapshots~append(.CameraConditionRegimeSnapshot~new(regime))
  end

  classSupplier = conditionModel~regimeClasses~supplier
  do while classSupplier~available
    regimeClass = classSupplier~item
    signature = classSupplier~index
    classSupplier~next
    regimeClassSnapshots[signature] = .CameraConditionRegimeClassSnapshot~new(regimeClass)
  end

::method completedRegimes
  expose completedRegimeSnapshots
  copy = .array~new
  do regimeSnapshot over completedRegimeSnapshots
    copy~append(regimeSnapshot)
  end
  return copy

::method regimeClasses
  expose regimeClassSnapshots
  copy = .directory~new
  supplier = regimeClassSnapshots~supplier
  do while supplier~available
    regimeClassSnapshot = supplier~item
    signature = supplier~index
    supplier~next
    copy[signature] = regimeClassSnapshot
  end
  return copy

::method regimeClassForSignature
  expose regimeClassSnapshots
  use arg signature
  if regimeClassSnapshots~hasIndex(signature) then return regimeClassSnapshots[signature]
  return .nil

::method canonicalText
  expose completedRegimeSnapshots regimeClassSnapshots
  lines = .array~new
  lines~append('MATERIALIZED_STATE_VERSION=' || self~version)
  if self~condition == .nil then lines~append('CONDITION=<NULL>')
  else do
    lines~append('CONDITION_BEGIN')
    conditionLines = self~condition~canonicalText~makeArray
    do conditionLine over conditionLines
      lines~append(conditionLine)
    end
    lines~append('CONDITION_END')
  end

  if self~activeRegime == .nil then lines~append('ACTIVE_REGIME=<NULL>')
  else lines~append('ACTIVE_' || self~activeRegime~canonicalText)

  regimeLines = .array~new
  do regimeSnapshot over completedRegimeSnapshots
    regimeLines~append(regimeSnapshot~canonicalText)
  end
  regimeLines~sort
  do regimeLine over regimeLines
    lines~append('COMPLETED_' || regimeLine)
  end

  classLines = .array~new
  classSupplier = regimeClassSnapshots~supplier
  do while classSupplier~available
    regimeClassSnapshot = classSupplier~item
    classSupplier~next
    classLines~append(regimeClassSnapshot~canonicalText)
  end
  classLines~sort
  do classLine over classLines
    lines~append(classLine)
  end

  return lines~makeString('L')


::class CameraConditionRegime public
::attribute id
::attribute startSecond
::attribute endSecond
::attribute state
::attribute sampleCount
::attribute peakMetricName
::attribute peakMetricZ
::attribute peakExcessSurpriseBits
::attribute cause
::attribute signatureKey
::attribute classId

::method init
  use arg id, startSecond
  self~id = id
  self~startSecond = startSecond
  self~endSecond = -1
  self~state = .CameraConstant~CONDITION_REGIME_OPEN
  self~sampleCount = 0
  self~peakMetricName = ''
  self~peakMetricZ = 0
  self~peakExcessSurpriseBits = 0
  self~cause = ''
  self~signatureKey = ''
  self~classId = ''

::method observe
  use arg condition
  if condition == .nil then return self~sampleCount
  self~sampleCount = self~sampleCount + 1
  if abs(condition~strongestMetricZ) > abs(self~peakMetricZ) then do
    self~peakMetricName = condition~strongestMetricName
    self~peakMetricZ = condition~strongestMetricZ
  end
  if condition~excessSurpriseBits > self~peakExcessSurpriseBits then self~peakExcessSurpriseBits = condition~excessSurpriseBits
  if self~cause = '' then do
    if condition~elevatedMetricCount > 0 then self~cause = 'METRIC'
    else if condition~trendingMetricCount > 0 then self~cause = 'TREND'
    else if condition~transitionCount > 0 then self~cause = 'TRANSITION'
  end
  return self~sampleCount

::method close
  use arg endSecond
  self~endSecond = endSecond
  self~state = .CameraConstant~CONDITION_REGIME_CLOSED
  return self~durationSeconds

::method durationSeconds
  if self~endSecond < 0 then return -1
  duration = self~endSecond - self~startSecond
  if duration < 0 then duration = duration + 86400
  return duration

::method buildSignatureKey
  direction = 'NONE'
  if self~peakMetricZ > 0 then direction = 'POS'
  else if self~peakMetricZ < 0 then direction = 'NEG'
  metricName = self~peakMetricName
  if metricName = '' then metricName = 'NONE'
  surprise = 'NORMAL'
  if self~peakExcessSurpriseBits > 0 then surprise = 'SURPRISE'
  self~signatureKey = self~cause || '|' || metricName || '|' || direction || '|' || surprise
  return self~signatureKey

::method compactText
  return 'regime=' || self~id || '|start=' || self~startSecond || '|end=' || self~endSecond || '|duration=' || self~durationSeconds || '|samples=' || self~sampleCount || '|peakMetric=' || self~peakMetricName || '|peakZ=' || self~peakMetricZ || '|peakExcess=' || self~peakExcessSurpriseBits || '|cause=' || self~cause || '|signature=' || self~signatureKey || '|class=' || self~classId || '|state=' || self~state


::class CameraConditionRegimeClass public
::attribute id
::attribute signatureKey
::attribute sampleCount
::attribute totalDurationSeconds
::attribute maximumAbsolutePeakZ
::attribute firstStartSecond
::attribute lastStartSecond
::attribute state

::method init
  use arg id, signatureKey
  self~id = id
  self~signatureKey = signatureKey
  self~sampleCount = 0
  self~totalDurationSeconds = 0
  self~maximumAbsolutePeakZ = 0
  self~firstStartSecond = -1
  self~lastStartSecond = -1
  self~state = .CameraConstant~CONDITION_REGIME_CLASS_NEW

::method observe
  use arg regime
  if regime == .nil then return self~sampleCount
  self~sampleCount = self~sampleCount + 1
  duration = regime~durationSeconds
  if duration > 0 then self~totalDurationSeconds = self~totalDurationSeconds + duration
  if abs(regime~peakMetricZ) > self~maximumAbsolutePeakZ then self~maximumAbsolutePeakZ = abs(regime~peakMetricZ)
  if self~firstStartSecond < 0 then self~firstStartSecond = regime~startSecond
  self~lastStartSecond = regime~startSecond
  if self~sampleCount >= 2 then self~state = .CameraConstant~CONDITION_REGIME_CLASS_KNOWN
  return self~sampleCount

::method meanDurationSeconds
  if self~sampleCount <= 0 then return 0
  return self~totalDurationSeconds / self~sampleCount

::method compactText
  return 'class=' || self~id || '|signature=' || self~signatureKey || '|samples=' || self~sampleCount || '|meanDuration=' || self~meanDurationSeconds || '|maxPeakZ=' || self~maximumAbsolutePeakZ || '|first=' || self~firstStartSecond || '|last=' || self~lastStartSecond || '|state=' || self~state


::class CameraConditionMetricOccurrence public
::attribute timestamp
::attribute name
::attribute zScore
::attribute state
::attribute baselineContext

::method init
  use arg timestamp, name, zScore, state, baselineContext
  self~timestamp = timestamp
  self~name = name
  self~zScore = zScore
  self~state = state
  if arg(5, 'O') then baselineContext = 'ALL'
  self~baselineContext = baselineContext


::class CameraConditionMetricSignal public
::attribute name
::attribute sampleCount
::attribute averageZ
::attribute maximumAbsoluteZ
::attribute firstZ
::attribute lastZ
::attribute trendDelta
::attribute trendState
::attribute elevated
::attribute baselineContext

::method init
  use arg name
  self~name = name
  self~sampleCount = 0
  self~averageZ = 0
  self~maximumAbsoluteZ = 0
  self~firstZ = 0
  self~lastZ = 0
  self~trendDelta = 0
  self~trendState = .CameraConstant~TREND_STABLE
  self~elevated = .false
  self~baselineContext = 'ALL'


::class CameraCurrentConditionModel public
::attribute windowSeconds
::attribute minimumTransitions
::attribute shiftedExcessBits
::attribute metricElevatedZ
::attribute metricStrongZ
::attribute minimumElevatedMetrics
::attribute metricTrendDelta
::attribute minimumTrendSamples
::attribute persistenceMinimum
::attribute recoveryMinimum

::method init
  expose recentTransitions recentMetricAssessments conditionPhase shiftedStreak expectedStreak phaseStartSecond lastPhaseTimestamp candidateStartSecond activeRegime completedRegimes nextRegimeNumber regimeClasses nextRegimeClassNumber
  use arg windowSeconds, minimumTransitions, shiftedExcessBits, metricElevatedZ, metricStrongZ, minimumElevatedMetrics, metricTrendDelta, minimumTrendSamples, persistenceMinimum, recoveryMinimum
  if arg(1, 'O') then windowSeconds = 300
  if arg(2, 'O') then minimumTransitions = 4
  if arg(3, 'O') then shiftedExcessBits = 1.5
  if arg(4, 'O') then metricElevatedZ = 2.5
  if arg(5, 'O') then metricStrongZ = 4.0
  if arg(6, 'O') then minimumElevatedMetrics = 2
  if arg(7, 'O') then metricTrendDelta = 2.0
  if arg(8, 'O') then minimumTrendSamples = 3
  if arg(9, 'O') then persistenceMinimum = 3
  if arg(10, 'O') then recoveryMinimum = 2
  self~windowSeconds = windowSeconds
  self~minimumTransitions = minimumTransitions
  self~shiftedExcessBits = shiftedExcessBits
  self~metricElevatedZ = metricElevatedZ
  self~metricStrongZ = metricStrongZ
  self~minimumElevatedMetrics = minimumElevatedMetrics
  self~metricTrendDelta = metricTrendDelta
  self~minimumTrendSamples = minimumTrendSamples
  self~persistenceMinimum = persistenceMinimum
  self~recoveryMinimum = recoveryMinimum
  recentTransitions = .array~new
  recentMetricAssessments = .array~new
  conditionPhase = .CameraConstant~CONDITION_PHASE_INSUFFICIENT
  shiftedStreak = 0
  expectedStreak = 0
  phaseStartSecond = 0
  lastPhaseTimestamp = -1
  candidateStartSecond = -1
  activeRegime = .nil
  completedRegimes = .array~new
  nextRegimeNumber = 1
  regimeClasses = .directory~new
  nextRegimeClassNumber = 1

::method recentTransitions
  expose recentTransitions
  return recentTransitions

::method recentMetricAssessments
  expose recentMetricAssessments
  return recentMetricAssessments

::method activeRegime
  expose activeRegime
  return activeRegime

::method completedRegimes
  expose completedRegimes
  return completedRegimes

::method regimeClasses
  expose regimeClasses
  return regimeClasses

::method regimeClassForSignature
  expose regimeClasses
  use arg signatureKey
  if regimeClasses~hasIndex(signatureKey) then return regimeClasses[signatureKey]
  return .nil

::method classifyRegime private
  expose regimeClasses nextRegimeClassNumber
  use arg regime
  if regime == .nil then return .nil
  signatureKey = regime~buildSignatureKey
  if regimeClasses~hasIndex(signatureKey) then regimeClass = regimeClasses[signatureKey]
  else do
    regimeClass = .CameraConditionRegimeClass~new('CRC' || nextRegimeClassNumber, signatureKey)
    nextRegimeClassNumber = nextRegimeClassNumber + 1
    regimeClasses[signatureKey] = regimeClass
  end
  observedCount = regimeClass~observe(regime)
  regime~classId = regimeClass~id
  return regimeClass

::method clear
  expose recentTransitions recentMetricAssessments conditionPhase shiftedStreak expectedStreak phaseStartSecond lastPhaseTimestamp candidateStartSecond activeRegime completedRegimes nextRegimeNumber regimeClasses nextRegimeClassNumber
  recentTransitions = .array~new
  recentMetricAssessments = .array~new
  conditionPhase = .CameraConstant~CONDITION_PHASE_INSUFFICIENT
  shiftedStreak = 0
  expectedStreak = 0
  phaseStartSecond = 0
  lastPhaseTimestamp = -1
  candidateStartSecond = -1
  activeRegime = .nil
  completedRegimes = .array~new
  nextRegimeNumber = 1
  regimeClasses = .directory~new
  nextRegimeClassNumber = 1
  return 0

::method circularAge private
  use arg nowSecond, thenSecond
  age = nowSecond - thenSecond
  if age < 0 then age = age + 86400
  return age

::method trim private
  expose recentTransitions recentMetricAssessments
  use arg nowSecond
  kept = .array~new
  do transitionOccurrence over recentTransitions
    age = self~circularAge(nowSecond, transitionOccurrence~timestamp)
    if age <= self~windowSeconds then kept~append(transitionOccurrence)
  end
  recentTransitions = kept

  keptMetrics = .array~new
  do metricOccurrence over recentMetricAssessments
    age = self~circularAge(nowSecond, metricOccurrence~timestamp)
    if age <= self~windowSeconds then keptMetrics~append(metricOccurrence)
  end
  recentMetricAssessments = keptMetrics
  return recentTransitions~items

::method observeOccurrence
  expose recentTransitions
  use arg transitionOccurrence
  if transitionOccurrence == .nil then return recentTransitions~items
  if transitionOccurrence~transitionId = '' then return recentTransitions~items
  self~trim(transitionOccurrence~timestamp)
  recentTransitions~append(transitionOccurrence)
  return recentTransitions~items

::method observeSummary
  use arg summary
  if summary == .nil then return 0
  occurrences = summary~transitionOccurrences
  do transitionOccurrence over occurrences
    self~observeOccurrence(transitionOccurrence)
  end
  return occurrences~items

::method observeAssessment
  expose recentMetricAssessments
  use arg assessment, timestamp
  if assessment == .nil then return recentMetricAssessments~items
  if arg(2, 'O') then timestamp = assessment~secondOfDay
  self~trim(timestamp)
  metricSupplier = assessment~metrics~supplier
  do while metricSupplier~available
    metricAssessment = metricSupplier~item
    metricSupplier~next
    if metricAssessment~state \= .CameraConstant~BASELINE_INSUFFICIENT then do
      recentMetricAssessments~append(.CameraConditionMetricOccurrence~new(timestamp, metricAssessment~name, metricAssessment~zScore, metricAssessment~state, metricAssessment~baselineContext))
    end
  end
  return recentMetricAssessments~items

::method aggregateMetricSignals private
  expose recentMetricAssessments
  use arg condition
  sums = .directory~new
  counts = .directory~new
  maxima = .directory~new
  contexts = .directory~new
  firstValues = .directory~new
  lastValues = .directory~new
  do metricOccurrence over recentMetricAssessments
    metricName = metricOccurrence~name
    if sums~hasIndex(metricName) then sums[metricName] = sums[metricName] + metricOccurrence~zScore
    else sums[metricName] = metricOccurrence~zScore
    if counts~hasIndex(metricName) then counts[metricName] = counts[metricName] + 1
    else do
      counts[metricName] = 1
      firstValues[metricName] = metricOccurrence~zScore
    end
    lastValues[metricName] = metricOccurrence~zScore
    absoluteZ = abs(metricOccurrence~zScore)
    if maxima~hasIndex(metricName) then do
      if absoluteZ > maxima[metricName] then maxima[metricName] = absoluteZ
    end
    else maxima[metricName] = absoluteZ
    contexts[metricName] = metricOccurrence~baselineContext
  end

  strongestAbsolute = 0
  strongestTrendAbsolute = 0
  nameSupplier = counts~supplier
  do while nameSupplier~available
    sampleCount = nameSupplier~item
    metricName = nameSupplier~index
    nameSupplier~next
    signal = .CameraConditionMetricSignal~new(metricName)
    signal~sampleCount = sampleCount
    signal~averageZ = sums[metricName] / sampleCount
    signal~maximumAbsoluteZ = maxima[metricName]
    signal~firstZ = firstValues[metricName]
    signal~lastZ = lastValues[metricName]
    signal~trendDelta = signal~lastZ - signal~firstZ
    signal~baselineContext = contexts[metricName]
    if sampleCount >= self~minimumTrendSamples then do
      if signal~trendDelta >= self~metricTrendDelta then signal~trendState = .CameraConstant~TREND_RISING
      else if signal~trendDelta <= -self~metricTrendDelta then signal~trendState = .CameraConstant~TREND_FALLING
    end
    if abs(signal~averageZ) >= self~metricElevatedZ then signal~elevated = .true
    condition~addMetricSignal(signal)
    condition~usableMetricCount = condition~usableMetricCount + 1
    condition~metricAssessmentCount = condition~metricAssessmentCount + sampleCount
    if signal~elevated then condition~elevatedMetricCount = condition~elevatedMetricCount + 1
    if signal~trendState \= .CameraConstant~TREND_STABLE then do
      condition~trendingMetricCount = condition~trendingMetricCount + 1
      if abs(signal~trendDelta) > strongestTrendAbsolute then do
        strongestTrendAbsolute = abs(signal~trendDelta)
        condition~strongestTrendMetricName = metricName
        condition~strongestTrendDelta = signal~trendDelta
      end
    end
    if signal~maximumAbsoluteZ > strongestAbsolute then do
      strongestAbsolute = signal~maximumAbsoluteZ
      condition~strongestMetricName = metricName
      condition~strongestMetricZ = signal~averageZ
    end
  end
  return condition~usableMetricCount

::method applyPersistence private
  expose conditionPhase shiftedStreak expectedStreak phaseStartSecond lastPhaseTimestamp candidateStartSecond activeRegime completedRegimes nextRegimeNumber regimeClasses nextRegimeClassNumber
  use arg condition
  if condition == .nil then return 0

  if condition~state = .CameraConstant~CONDITION_INSUFFICIENT then do
    condition~persistencePhase = .CameraConstant~CONDITION_PHASE_INSUFFICIENT
    condition~shiftedStreak = shiftedStreak
    condition~expectedStreak = expectedStreak
    condition~phaseStartSecond = phaseStartSecond
    if activeRegime \== .nil then condition~activeRegimeId = activeRegime~id
    return condition~persistencePhase
  end

  if condition~timestamp = lastPhaseTimestamp then do
    condition~persistencePhase = conditionPhase
    condition~shiftedStreak = shiftedStreak
    condition~expectedStreak = expectedStreak
    condition~phaseStartSecond = phaseStartSecond
    if activeRegime \== .nil then condition~activeRegimeId = activeRegime~id
    return condition~persistencePhase
  end

  previousPhase = conditionPhase
  if condition~state = .CameraConstant~CONDITION_SHIFTED then do
    shiftedStreak = shiftedStreak + 1
    expectedStreak = 0
    if shiftedStreak = 1 then candidateStartSecond = condition~timestamp
    if conditionPhase = .CameraConstant~CONDITION_PHASE_PERSISTENT then conditionPhase = .CameraConstant~CONDITION_PHASE_PERSISTENT
    else if shiftedStreak >= self~persistenceMinimum then conditionPhase = .CameraConstant~CONDITION_PHASE_PERSISTENT
    else conditionPhase = .CameraConstant~CONDITION_PHASE_EMERGING

    if conditionPhase = .CameraConstant~CONDITION_PHASE_PERSISTENT then do
      if activeRegime == .nil then do
        regimeId = 'CR' || nextRegimeNumber
        nextRegimeNumber = nextRegimeNumber + 1
        regimeStart = candidateStartSecond
        if regimeStart < 0 then regimeStart = condition~timestamp
        activeRegime = .CameraConditionRegime~new(regimeId, regimeStart)
      end
      observedRegimeSamples = activeRegime~observe(condition)
    end
  end
  else do
    expectedStreak = expectedStreak + 1
    shiftedStreak = 0
    wasPersistent = conditionPhase = .CameraConstant~CONDITION_PHASE_PERSISTENT
    if \wasPersistent then wasPersistent = conditionPhase = .CameraConstant~CONDITION_PHASE_RECOVERING
    if wasPersistent then do
      if activeRegime \== .nil then observedRegimeSamples = activeRegime~observe(condition)
      if expectedStreak >= self~recoveryMinimum then do
        conditionPhase = .CameraConstant~CONDITION_PHASE_STABLE
        if activeRegime \== .nil then do
          closedDuration = activeRegime~close(condition~timestamp)
          learnedRegimeClass = self~classifyRegime(activeRegime)
          completedRegimes~append(activeRegime)
          activeRegime = .nil
        end
        candidateStartSecond = -1
      end
      else conditionPhase = .CameraConstant~CONDITION_PHASE_RECOVERING
    end
    else do
      conditionPhase = .CameraConstant~CONDITION_PHASE_STABLE
      candidateStartSecond = -1
    end
  end

  if conditionPhase \= previousPhase then phaseStartSecond = condition~timestamp
  lastPhaseTimestamp = condition~timestamp
  condition~persistencePhase = conditionPhase
  condition~shiftedStreak = shiftedStreak
  condition~expectedStreak = expectedStreak
  condition~phaseStartSecond = phaseStartSecond
  if activeRegime \== .nil then condition~activeRegimeId = activeRegime~id
  return condition~persistencePhase

::method empiricalEntropy private
  use arg counts, totalCount
  if totalCount <= 0 then return 0
  entropy = 0
  countSupplier = counts~supplier
  do while countSupplier~available
    countValue = countSupplier~item
    countSupplier~next
    probability = countValue / totalCount
    if probability > 0 then entropy = entropy + (probability * .CameraMath~surpriseBits(probability))
  end
  return entropy

::method baselineEntropy private
  use arg camera, dayClass, secondOfDay, minimumSupport
  if camera == .nil then return 0
  vocabularySize = camera~transitionModel~transitionCount + 1
  if vocabularySize < 1 then vocabularySize = 1
  entropy = 0
  probabilityTotal = 0
  transitionSupplier = camera~transitionModel~transitions~supplier
  do while transitionSupplier~available
    learnedTransition = transitionSupplier~item
    transitionSupplier~next
    probability = camera~calendarBehaviour~transitionProbability(dayClass, camera~behaviour, secondOfDay, learnedTransition~id, vocabularySize, minimumSupport)
    probabilityTotal = probabilityTotal + probability
    if probability > 0 then entropy = entropy + (probability * .CameraMath~surpriseBits(probability))
  end
  unknownProbability = 1 - probabilityTotal
  if unknownProbability < 0 then unknownProbability = 0
  if unknownProbability > 0 then entropy = entropy + (unknownProbability * .CameraMath~surpriseBits(unknownProbability))
  return entropy

::method currentCondition
  expose recentTransitions recentMetricAssessments
  use arg camera, dayClass, nowSecond, minimumSupport
  if arg(4, 'O') then minimumSupport = 3
  self~trim(nowSecond)
  condition = .CameraCurrentCondition~new(nowSecond, dayClass, self~windowSeconds)
  if camera == .nil then return condition

  counts = .directory~new
  surpriseTotal = 0
  vocabularySize = camera~transitionModel~transitionCount + 1
  if vocabularySize < 1 then vocabularySize = 1

  do transitionOccurrence over recentTransitions
    transitionId = transitionOccurrence~transitionId
    oldCount = 0
    if counts~hasIndex(transitionId) then oldCount = counts[transitionId]
    counts[transitionId] = oldCount + 1
    probability = camera~calendarBehaviour~transitionProbability(dayClass, camera~behaviour, transitionOccurrence~timestamp, transitionId, vocabularySize, minimumSupport)
    surpriseTotal = surpriseTotal + .CameraMath~surpriseBits(probability)
  end

  condition~transitionCount = recentTransitions~items
  condition~uniqueTransitionCount = counts~items
  condition~empiricalEntropyBits = self~empiricalEntropy(counts, condition~transitionCount)
  condition~baselineEntropyBits = self~baselineEntropy(camera, dayClass, nowSecond, minimumSupport)
  if condition~transitionCount > 0 then condition~averageContextSurpriseBits = surpriseTotal / condition~transitionCount
  condition~excessSurpriseBits = condition~averageContextSurpriseBits - condition~baselineEntropyBits

  dominantCount = 0
  dominantId = ''
  countSupplier = counts~supplier
  do while countSupplier~available
    countValue = countSupplier~item
    transitionId = countSupplier~index
    countSupplier~next
    if countValue > dominantCount then do
      dominantCount = countValue
      dominantId = transitionId
    end
  end
  condition~dominantTransitionId = dominantId
  if condition~transitionCount > 0 then condition~dominantTransitionShare = dominantCount / condition~transitionCount

  if camera~calendarBehaviour~contextSampleCount(dayClass) >= minimumSupport then condition~baselineContext = 'DAY:' || dayClass
  else condition~baselineContext = 'ALL'

  self~aggregateMetricSignals(condition)
  hasTransitionSupport = condition~transitionCount >= self~minimumTransitions
  hasMetricSupport = condition~usableMetricCount > 0
  transitionShifted = .false
  if hasTransitionSupport then do
    if condition~excessSurpriseBits > self~shiftedExcessBits then transitionShifted = .true
  end
  metricShifted = .false
  if condition~elevatedMetricCount >= self~minimumElevatedMetrics then metricShifted = .true
  if abs(condition~strongestMetricZ) >= self~metricStrongZ then metricShifted = .true
  trendShifted = condition~trendingMetricCount > 0

  if \hasTransitionSupport & \hasMetricSupport then condition~state = .CameraConstant~CONDITION_INSUFFICIENT
  else if transitionShifted then condition~state = .CameraConstant~CONDITION_SHIFTED
  else if metricShifted then condition~state = .CameraConstant~CONDITION_SHIFTED
  else if trendShifted then condition~state = .CameraConstant~CONDITION_SHIFTED
  else condition~state = .CameraConstant~CONDITION_EXPECTED
  persistenceState = self~applyPersistence(condition)
  return condition

::class CameraModel subclass AlchemyObject public
::attribute id
::attribute rootRegion
::attribute environment
::attribute environmentModel
::attribute behaviour
::attribute calendarBehaviour
::attribute associator
::attribute routeModel
::attribute eventGrammar
::attribute episodeModel
::attribute motifModel
::attribute transitionModel
::attribute currentConditionModel
::attribute spatialModel
::attribute tokenDictionary
::attribute spatialPrimitiveModel
::attribute generationRegistry
::attribute signatureTrendModel
::attribute signatureTrendPersistenceModel

::method init
  expose tracks nextTrackNumber
  use arg id, width, height
  self~id = id
  meta = .directory~new
  meta["PURPOSE"] = "Fixed-camera behavioural scene model with generation-pinned evidence"
  meta["PACKAGE"] = "camera_behaviour_oorexx"
  meta["PACKAGE_VERSION"] = .CameraConstant~CAMERA_PACKAGE_VERSION
  meta["AUTHORSHIP"] = "OpenAI / The Architect"
  meta["STANDARDS"] = "ALCHEMY-HOUSE-OBJECT-0.8; deterministic fixed-camera behavioural evidence"
  meta["DESIGN_LIMITATIONS"] = "Camera produces behavioural evidence and learned-world state; it does not grant operational authority or identify people."
  meta["OBJECT_KIND"] = "CAMERA_MODEL"
  self~init:super(meta)
  self~registerExternalRequirement("library", "alchemy_objects", "v0.8", .true)
  self~registerExternalRequirement("library", "oorexx_crypto", "v0.4", .true)
  self~registerStateVariable("id", "CUSTOMER", "camera model identifier")
  self~registerMethodContract("PUBLISHGENERATION", "freeze current learned world into immutable generation", .array~of("TIMESTAMP"), "CAMERALEARNEDGENERATION", .false, "TRUE", "CUSTOMER", "NORMAL", "MUTATE", "NONE")
  self~registerMethodContract("ASSESSSUMMARYATGENERATION", "assess clip summary against explicitly pinned learned generation", .array~of("SUMMARY", "GENERATION_ID", "MINIMUM_SUPPORT", "ELEVATED_Z"), "CAMERACLIPASSESSMENT", .false, "TRUE", "CUSTOMER", "NORMAL", "READ", "NONE")
  self~registerMethodContract("MATCHSPATIALPRIMITIVE", "match track against explicitly selected immutable generation", .array~of("TRACK", "GENERATION_ID"), "ANY", .false, "TRUE", "CUSTOMER", "NORMAL", "READ", "NONE")
  self~registerMethodContract("LEARNSPATIALPRIMITIVE", "learn recurrent spatial primitive into live model", .array~of("TRACK"), "ANY", .false, "TRUE", "INTERNAL", "NORMAL", "MUTATE", "NONE")
  self~registerMethodContract("MATERIALIZEDSTATE", "materialize immutable current condition/regime state", .array~of("CONDITION"), "CAMERAMATERIALIZEDSTATESNAPSHOT", .false, "TRUE", "CUSTOMER", "NORMAL", "READ", "NONE")
  self~registerMethodContract("PRODUCTIONIDENTITY", "materialize compact implementation/contract identity for retained Camera evidence", .array~new, "CAMERAPRODUCTIONIDENTITY", .false, "TRUE", "CUSTOMER", "NORMAL", "READ", "NONE")
  self~registerMethodContract("OBSERVEASSESSMENTTREND", "feed one generation-pinned assessment signature into overlapping condition-trend windows", .array~of("ASSESSMENT"), "CAMERASIGNATURETRENDSNAPSHOT", .false, "TRUE", "CUSTOMER", "NORMAL", "MUTATE", "NONE")
  self~registerMethodContract("OBSERVEASSESSMENTTRENDSTATE", "apply persistence/recovery state to overlapping compact-signature trend evidence", .array~of("ASSESSMENT"), "CAMERASIGNATURETRENDCONDITION", .false, "TRUE", "CUSTOMER", "NORMAL", "MUTATE", "NONE")
  self~registerInstrumentationPoint("CAMERA.GENERATION.PUBLISH", "immutable learned-world generation published", .true, "ALL", "CUSTOMER")
  self~registerInstrumentationPoint("CAMERA.ASSESSMENT.PINNED", "clip summary assessed against explicit learned generation", .true, "ALL", "CUSTOMER")
  self~registerInstrumentationPoint("CAMERA.TREND.OBSERVE", "compact assessment signature entered overlapping condition-trend model", .true, "ALL", "CUSTOMER")
  /* CAMERA V0.42 EXECUTION PROVENANCE: Alchemy v0.8 wrappers bind each call to */
  /* contract revision/fingerprint, implementation origin, construction and integrity. */
  self~setExecutionEvidencePolicy(128)
  ignoredInstrument = self~instrumentMethod("ASSESSSUMMARYATGENERATION", .true)
  ignoredInstrument = self~instrumentMethod("OBSERVEASSESSMENTTREND", .true)
  ignoredInstrument = self~instrumentMethod("OBSERVEASSESSMENTTRENDSTATE", .true)
  self~rootRegion = .CameraBox~new('ROOT', 0, 0, width, height)
  self~environment = .CameraEnvironmentState~new
  self~environmentModel = .CameraEnvironmentModel~new
  self~behaviour = .CameraBehaviourModel~new
  self~calendarBehaviour = .CameraCalendarBehaviourModel~new
  self~associator = .CameraTrackAssociator~new
  self~routeModel = .CameraRouteModel~new
  self~eventGrammar = .CameraEventGrammar~new
  self~episodeModel = .CameraEpisodeModel~new
  self~motifModel = .CameraMotifModel~new
  self~transitionModel = .CameraMotifTransitionModel~new
  self~currentConditionModel = .CameraCurrentConditionModel~new
  self~spatialModel = .CameraSpatialModel~new
  self~tokenDictionary = .CameraTokenDictionary~new
  self~spatialPrimitiveModel = .CameraSpatialPrimitiveModel~new
  self~generationRegistry = .CameraLearnedGenerationRegistry~new
  self~signatureTrendModel = .CameraSignatureTrendModel~new
  self~signatureTrendPersistenceModel = .CameraSignatureTrendPersistenceModel~new
  tracks = .directory~new
  nextTrackNumber = 1

::method tracks
  expose tracks
  return tracks

::method newTrack
  expose tracks nextTrackNumber
  id = 'T' || nextTrackNumber
  nextTrackNumber = nextTrackNumber + 1
  track = .CameraTrack~new(id)
  tracks[id] = track
  return track

::method activeTrackCount
  expose tracks
  count = 0
  supplier = tracks~supplier
  do while supplier~available
    track = supplier~item
    supplier~next
    if track~state \= .CameraConstant~TRACK_ENDED then count = count + 1
  end
  return count

::method observe
  use arg observation
  if observation == .nil then return .nil

  observation~changeType = self~environmentModel~classifyObservation(observation, self~environment~code)
  if observation~changeType = .CameraConstant~CHANGE_PHOTOMETRIC then do
    self~environmentModel~observeBackgroundObservation(self~environment~code, observation)
    return .CameraConstant~CHANGE_PHOTOMETRIC
  end

  if observation~changeType = .CameraConstant~CHANGE_NONE then do
    self~environmentModel~observeBackgroundObservation(self~environment~code, observation)
    return .CameraConstant~CHANGE_NONE
  end

  if observation~isMoverCandidate then do
    track = self~newTrack
    track~addObservation(observation)
    return track
  end

  return .CameraConstant~CHANGE_NONE

::method learnEndedTrack
  expose tracks
  use arg track
  if track == .nil then return .nil

  encoding = .nil
  if track~routeId = '' then encoding = self~routeModel~learnTrack(track)

  self~spatialModel~learnTrackEndpoints(track)

  routePoint = track~midpoint
  if routePoint == .nil then routePoint = track~firstPoint
  if routePoint \== .nil then do
    /* Include one escape symbol for a route not yet present in the dictionary. */
    routeVocabulary = self~routeModel~routeCount + 1
    track~temporalRouteBits = self~behaviour~routeDescriptionBits(routePoint~timestamp, track~routeId, routeVocabulary)
    self~behaviour~observeRoute(routePoint~timestamp, track~routeId)
  end

  eventStart = self~eventGrammar~eventCount + 1
  self~eventGrammar~analyseTrack(track)
  self~eventGrammar~analyseRouteDeviation(track)
  self~eventGrammar~analysePairsForTrack(track, tracks)
  eventFinish = self~eventGrammar~eventCount

  if eventFinish >= eventStart then do
    self~spatialModel~annotateEvents(track, self~eventGrammar~events, eventStart, eventFinish)
    episodeEncodings = self~episodeModel~recogniseAndLearnRange(self~behaviour, self~eventGrammar~events, eventStart, eventFinish)
    episodeVocabulary = self~episodeModel~episodeCount + 1
    do episodeEncoding over episodeEncodings
      if episodeEncoding~episodeId = '' then iterate
      episodeEncoding~temporalBits = self~behaviour~episodeDescriptionBits(episodeEncoding~timestamp, episodeEncoding~episodeId, episodeVocabulary)
      self~behaviour~observeEpisode(episodeEncoding~timestamp, episodeEncoding~episodeId)
    end
    do eventIndex = eventStart to eventFinish
      derivedEvent = self~eventGrammar~events[eventIndex]
      derivedEvent~routeId = track~routeId
      derivedEvent~descriptionBits = self~behaviour~eventDescriptionBits(derivedEvent~timestamp, derivedEvent~eventType)
      if derivedEvent~zoneId \= '' then do
        derivedEvent~zoneDescriptionBits = self~behaviour~zoneEventDescriptionBits(derivedEvent~timestamp, derivedEvent~zoneId, derivedEvent~eventType)
        derivedEvent~descriptionBits = derivedEvent~descriptionBits + derivedEvent~zoneDescriptionBits
      end
      if derivedEvent~episodeId \= '' then do episodeEncoding over episodeEncodings
        if episodeEncoding~episodeId = derivedEvent~episodeId then do
          derivedEvent~episodeDescriptionBits = episodeEncoding~temporalBits
          leave
        end
      end
      self~behaviour~observeEvent(derivedEvent~timestamp, derivedEvent~eventType)
      if derivedEvent~zoneId \= '' then self~behaviour~observeZoneEvent(derivedEvent~timestamp, derivedEvent~zoneId, derivedEvent~eventType)
    end
  end
  return encoding

::method learnSpatialPrimitive
  use arg track
  if track == .nil then return .nil
  encoding = track~spatialRelationEncoding(self~rootRegion)
  return self~spatialPrimitiveModel~learn(encoding)

::method publishGeneration
  use arg timestamp
  if arg(1, 'O') then timestamp = 0
  generation = self~generationRegistry~publish(timestamp, self)
  if generation \== .nil then do
    ignoredRelationship = self~recordRelationship("PUBLISHED_GENERATION", generation, "immutable learned-world generation", "CUSTOMER")
    evidence = .directory~new
    evidence["camera_id"] = self~id
    evidence["generation_id"] = generation~id
    evidence["published_at"] = generation~publishedAt
    evidence["generation_schema"] = generation~version
    ignoredEvent = self~alchemyInstrument("CAMERA.GENERATION.PUBLISH", evidence)
  end
  return generation

::method productionIdentity
  return .CameraProductionIdentity~new(self)

::method currentGeneration
  return self~generationRegistry~currentGeneration

::method generation
  use arg generationId
  return self~generationRegistry~generation(generationId)

::method assessSummaryAtGeneration
  use arg summary, generationId, minimumSupport, elevatedZ
  if arg(2, 'O') then generationId = ''
  generation = self~generation(generationId)
  if generation == .nil then return .nil
  if arg(3, 'O') then minimumSupport = 3
  if arg(4, 'O') then elevatedZ = 2.5
  assessment = .CameraGenerationClipComparator~assess(generation, summary, minimumSupport, elevatedZ)
  ignoredRelationship = self~recordRelationship("ASSESSED_WITH_GENERATION", generation, "generation used for pinned clip assessment", "CUSTOMER")
  evidence = .directory~new
  evidence["camera_id"] = self~id
  evidence["generation_id"] = generation~id
  if summary \== .nil then evidence["clip_id"] = summary~clipId
  if assessment \== .nil then do
    assessment~productionIdentity = self~productionIdentity
    evidence["elevated_count"] = assessment~elevatedCount
    evidence["producer_token"] = assessment~productionIdentity~compactToken
  end
  ignoredEvent = self~alchemyInstrument("CAMERA.ASSESSMENT.PINNED", evidence)
  return assessment

::method observeAssessmentTrend
  use arg assessment
  if assessment == .nil then return .nil
  signature = assessment~conditionSignature
  snapshot = self~signatureTrendModel~observe(signature)
  eventData = .directory~new
  eventData["generation_id"] = signature~generationId
  eventData["clip_id"] = signature~clipId
  eventData["second_of_day"] = signature~secondOfDay
  eventData["strongest_metric"] = snapshot~strongestMetricName
  eventData["strongest_delta"] = snapshot~strongestDelta
  ignoredEvent = self~alchemyInstrument("CAMERA.TREND.OBSERVE", eventData)
  return snapshot

::method observeAssessmentTrendState
  use arg assessment
  if assessment == .nil then return .nil
  trendSnapshot = self~observeAssessmentTrend(assessment)
  return self~signatureTrendPersistenceModel~observe(trendSnapshot)

::method matchSpatialPrimitive
  use arg track, generationId
  if track == .nil then return .nil
  generation = .nil
  if arg(2, 'O') | generationId == '' then generation = self~generationRegistry~currentGeneration
  else generation = self~generationRegistry~generation(generationId)
  if generation == .nil then return .nil
  encoding = track~spatialRelationEncoding(self~rootRegion)
  return generation~match(encoding)

::method materializedState
  use arg condition
  return .CameraMaterializedStateSnapshot~new(condition, self~currentConditionModel)

::method observeFrame
  expose tracks
  use arg timestamp, observations
  frameResult = .CameraFrameResult~new(timestamp)
  if observations == .nil then observations = .array~new

  claimedIds = .set~new

  do observation over observations
    if observation == .nil then do
      frameResult~ignoredCount = frameResult~ignoredCount + 1
      iterate
    end

    observation~changeType = self~environmentModel~classifyObservation(observation, self~environment~code)
    if observation~changeType = .CameraConstant~CHANGE_PHOTOMETRIC then do
      frameResult~photometricCount = frameResult~photometricCount + 1
      self~environmentModel~observeBackgroundObservation(self~environment~code, observation)
      iterate
    end

    if \ observation~isMoverCandidate then do
      frameResult~ignoredCount = frameResult~ignoredCount + 1
      self~environmentModel~observeBackgroundObservation(self~environment~code, observation)
      iterate
    end

    frameResult~moverCount = frameResult~moverCount + 1
    track = self~associator~bestTrack(tracks, observation, claimedIds)
    if track == .nil then do
      track = self~newTrack
      frameResult~newTrackCount = frameResult~newTrackCount + 1
    end
    else frameResult~matchedCount = frameResult~matchedCount + 1

    track~addObservation(observation)
    claimedIds[track~id] = track~id
    frameResult~addAssignment(track)
  end

  supplier = tracks~supplier
  do while supplier~available
    track = supplier~item
    supplier~next
    if track~state = .CameraConstant~TRACK_ENDED then iterate
    if claimedIds~hasIndex(track~id) then iterate
    newState = track~markMissed(self~associator~maxMissedFrames)
    if newState = .CameraConstant~TRACK_ENDED then self~learnEndedTrack(track)
  end

  return frameResult

::class CameraTokenDictionary public
::method init
  expose textToToken tokenToText nextToken
  textToToken = .directory~new
  tokenToText = .directory~new
  nextToken = 1

::method count
  expose tokenToText
  return tokenToText~items

::method tokenFor
  expose textToToken tokenToText nextToken
  use arg text
  if text = '' then return 0
  if textToToken~hasIndex(text) then return textToToken[text]
  token = nextToken
  nextToken = nextToken + 1
  textToToken[text] = token
  tokenToText[token] = text
  return token

::method textFor
  expose tokenToText
  use arg token
  if token = 0 then return ''
  if tokenToText~hasIndex(token) then return tokenToText[token]
  return ''

::method restoreToken
  expose textToToken tokenToText nextToken
  use arg token, text
  if token < 1 then return 0
  if text = '' then return 0
  textToToken[text] = token
  tokenToText[token] = text
  if token >= nextToken then nextToken = token + 1
  return token

::method entries
  expose tokenToText
  return tokenToText


::class CameraBinaryCodec public
::method encodeUnsigned class
  use arg value
  if value < 0 then value = 0
  value = trunc(value)
  bytes = ''
  do forever
    remainder = value // 128
    value = value % 128
    if value > 0 then remainder = remainder + 128
    bytes = bytes || d2c(remainder)
    if value = 0 then leave
  end
  return bytes

::method decodeUnsigned class
  use arg bytes, startIndex
  if arg(2, 'O') then startIndex = 1
  value = 0
  multiplier = 1
  index = startIndex
  do while index <= bytes~length
    octet = c2d(bytes~substr(index, 1))
    value = value + ((octet // 128) * multiplier)
    index = index + 1
    if octet < 128 then return .array~of(value, index)
    multiplier = multiplier * 128
  end
  return .array~of(value, index)


::class CameraEventToken public
::attribute eventType
::attribute timestamp
::attribute trackAId
::attribute trackBId
::attribute routeId
::attribute zoneId

::method init
  use arg eventType, timestamp, trackAId, trackBId, routeId, zoneId
  self~eventType = eventType
  self~timestamp = timestamp
  self~trackAId = trackAId
  self~trackBId = trackBId
  self~routeId = routeId
  self~zoneId = zoneId


::class CameraEventStream public
::attribute dictionary
::attribute episodeModel
::attribute bytes

::method init
  use arg dictionary, episodeModel
  if arg(1, 'O') then dictionary = .CameraTokenDictionary~new
  if arg(2, 'O') then episodeModel = .nil
  self~dictionary = dictionary
  self~episodeModel = episodeModel
  self~bytes = 'CBT1'

::method appendEvent
  use arg event
  if event == .nil then return self~bytes~length
  data = self~bytes
  data = data || d2c(.CameraConstant~TOKEN_EVENT_RECORD)
  data = data || .CameraBinaryCodec~encodeUnsigned(event~eventType)
  data = data || .CameraBinaryCodec~encodeUnsigned(event~timestamp)
  data = data || .CameraBinaryCodec~encodeUnsigned(self~dictionary~tokenFor('TRACK:' || event~trackAId))
  if event~trackBId = '' then tokenB = 0
  else tokenB = self~dictionary~tokenFor('TRACK:' || event~trackBId)
  data = data || .CameraBinaryCodec~encodeUnsigned(tokenB)
  if event~routeId = '' then routeToken = 0
  else routeToken = self~dictionary~tokenFor('ROUTE:' || event~routeId)
  data = data || .CameraBinaryCodec~encodeUnsigned(routeToken)
  if event~zoneId = '' then zoneToken = 0
  else zoneToken = self~dictionary~tokenFor('ZONE:' || event~zoneId)
  data = data || .CameraBinaryCodec~encodeUnsigned(zoneToken)
  self~bytes = data
  return data~length

::method appendEvents
  use arg events
  if events == .nil then return self~bytes~length
  do streamEvent over events
    self~appendEvent(streamEvent)
  end
  return self~bytes~length

::method appendEpisode
  use arg episode, memberEvents
  if episode == .nil then return 0
  if memberEvents == .nil then return 0
  if memberEvents~items = 0 then return 0

  firstMember = memberEvents[1]
  data = self~bytes
  data = data || d2c(.CameraConstant~TOKEN_EPISODE_RECORD)
  episodeToken = self~dictionary~tokenFor('EPISODE:' || episode~id)
  data = data || .CameraBinaryCodec~encodeUnsigned(episodeToken)
  data = data || .CameraBinaryCodec~encodeUnsigned(memberEvents~items)
  data = data || .CameraBinaryCodec~encodeUnsigned(self~dictionary~tokenFor('TRACK:' || firstMember~trackAId))
  if firstMember~trackBId = '' then tokenB = 0
  else tokenB = self~dictionary~tokenFor('TRACK:' || firstMember~trackBId)
  data = data || .CameraBinaryCodec~encodeUnsigned(tokenB)

  do memberEvent over memberEvents
    data = data || .CameraBinaryCodec~encodeUnsigned(memberEvent~timestamp)
    if memberEvent~routeId = '' then routeToken = 0
    else routeToken = self~dictionary~tokenFor('ROUTE:' || memberEvent~routeId)
    data = data || .CameraBinaryCodec~encodeUnsigned(routeToken)
    if memberEvent~zoneId = '' then zoneToken = 0
    else zoneToken = self~dictionary~tokenFor('ZONE:' || memberEvent~zoneId)
    data = data || .CameraBinaryCodec~encodeUnsigned(zoneToken)
  end
  self~bytes = data
  return data~length

::method appendEventsCompressed
  use arg events, episodeModel
  if arg(2, 'O') then episodeModel = self~episodeModel
  if events == .nil then return self~bytes~length
  if episodeModel == .nil then return self~appendEvents(events)
  if self~bytes = 'CBT1' then self~bytes = 'CBT2'

  eventIndex = 1
  do while eventIndex <= events~items
    candidateEvent = events[eventIndex]
    compressed = .false
    if candidateEvent~episodeId \= '' then do
      episode = episodeModel~episodeForId(candidateEvent~episodeId)
      if episode \== .nil then do
        sequenceWords = translate(episode~sequenceKey, ' ', ',')
        sequenceCount = words(sequenceWords)
        if sequenceCount > 1 then do
          if eventIndex + sequenceCount - 1 <= events~items then do
            memberEvents = .array~new
            validSequence = .true
            do sequenceIndex = 1 to sequenceCount
              memberEvent = events[eventIndex + sequenceIndex - 1]
              if memberEvent~episodeId \= episode~id then validSequence = .false
              if memberEvent~eventType \= word(sequenceWords, sequenceIndex) then validSequence = .false
              if memberEvent~trackAId \= candidateEvent~trackAId then validSequence = .false
              if memberEvent~trackBId \= candidateEvent~trackBId then validSequence = .false
              memberEvents~append(memberEvent)
            end
            if validSequence then do
              self~appendEpisode(episode, memberEvents)
              eventIndex = eventIndex + sequenceCount
              compressed = .true
            end
          end
        end
      end
    end
    if \compressed then do
      self~appendEvent(candidateEvent)
      eventIndex = eventIndex + 1
    end
  end
  return self~bytes~length

::method byteCount
  return self~bytes~length + 1

::method encodedBytes
  return self~bytes || d2c(.CameraConstant~TOKEN_END_STREAM)

::method write
  use arg path
  if path = '' then return 0
  call charout path, self~encodedBytes, 1
  call stream path, 'c', 'close'
  return self~byteCount

::method decode
  use arg bytes
  if arg(1, 'O') then bytes = self~encodedBytes
  decoded = .array~new
  if bytes~length < 5 then return decoded
  magic = bytes~substr(1, 4)
  if magic \= 'CBT1' then do
    if magic \= 'CBT2' then return decoded
  end
  index = 5
  do while index <= bytes~length
    recordType = c2d(bytes~substr(index, 1))
    index = index + 1
    if recordType = .CameraConstant~TOKEN_END_STREAM then leave
    if recordType = .CameraConstant~TOKEN_EPISODE_RECORD then do
      decodedValue = .CameraBinaryCodec~decodeUnsigned(bytes, index)
      episodeToken = decodedValue[1]; index = decodedValue[2]
      decodedValue = .CameraBinaryCodec~decodeUnsigned(bytes, index)
      memberCount = decodedValue[1]; index = decodedValue[2]
      decodedValue = .CameraBinaryCodec~decodeUnsigned(bytes, index)
      tokenA = decodedValue[1]; index = decodedValue[2]
      decodedValue = .CameraBinaryCodec~decodeUnsigned(bytes, index)
      tokenB = decodedValue[1]; index = decodedValue[2]

      episodeText = self~stripPrefix(self~dictionary~textFor(episodeToken), 'EPISODE:')
      if self~episodeModel == .nil then return decoded
      learnedEpisode = self~episodeModel~episodeForId(episodeText)
      if learnedEpisode == .nil then return decoded
      sequenceWords = translate(learnedEpisode~sequenceKey, ' ', ',')
      if words(sequenceWords) \= memberCount then return decoded
      trackA = self~stripPrefix(self~dictionary~textFor(tokenA), 'TRACK:')
      trackB = self~stripPrefix(self~dictionary~textFor(tokenB), 'TRACK:')

      do memberIndex = 1 to memberCount
        decodedValue = .CameraBinaryCodec~decodeUnsigned(bytes, index)
        timestamp = decodedValue[1]; index = decodedValue[2]
        decodedValue = .CameraBinaryCodec~decodeUnsigned(bytes, index)
        routeToken = decodedValue[1]; index = decodedValue[2]
        decodedValue = .CameraBinaryCodec~decodeUnsigned(bytes, index)
        zoneToken = decodedValue[1]; index = decodedValue[2]
        routeId = self~stripPrefix(self~dictionary~textFor(routeToken), 'ROUTE:')
        zoneId = self~stripPrefix(self~dictionary~textFor(zoneToken), 'ZONE:')
        eventType = word(sequenceWords, memberIndex)
        decoded~append(.CameraEventToken~new(eventType, timestamp, trackA, trackB, routeId, zoneId))
      end
      iterate
    end
    if recordType \= .CameraConstant~TOKEN_EVENT_RECORD then leave

    decodedValue = .CameraBinaryCodec~decodeUnsigned(bytes, index)
    eventType = decodedValue[1]; index = decodedValue[2]
    decodedValue = .CameraBinaryCodec~decodeUnsigned(bytes, index)
    timestamp = decodedValue[1]; index = decodedValue[2]
    decodedValue = .CameraBinaryCodec~decodeUnsigned(bytes, index)
    tokenA = decodedValue[1]; index = decodedValue[2]
    decodedValue = .CameraBinaryCodec~decodeUnsigned(bytes, index)
    tokenB = decodedValue[1]; index = decodedValue[2]
    decodedValue = .CameraBinaryCodec~decodeUnsigned(bytes, index)
    routeToken = decodedValue[1]; index = decodedValue[2]
    decodedValue = .CameraBinaryCodec~decodeUnsigned(bytes, index)
    zoneToken = decodedValue[1]; index = decodedValue[2]

    trackA = self~stripPrefix(self~dictionary~textFor(tokenA), 'TRACK:')
    trackB = self~stripPrefix(self~dictionary~textFor(tokenB), 'TRACK:')
    routeId = self~stripPrefix(self~dictionary~textFor(routeToken), 'ROUTE:')
    zoneId = self~stripPrefix(self~dictionary~textFor(zoneToken), 'ZONE:')
    decoded~append(.CameraEventToken~new(eventType, timestamp, trackA, trackB, routeId, zoneId))
  end
  return decoded

::method stripPrefix private
  use arg text, prefix
  if text = '' then return ''
  if text~left(prefix~length) = prefix then return text~substr(prefix~length + 1)
  return text


::class CameraModelPersistence public
::method save class
  use arg camera, path
  if camera == .nil then return 0
  if path = '' then return 0
  call stream path, 'c', 'open write replace'
  root = camera~rootRegion
  call lineout path, 'CAMERA|1|' || camera~id || '|' || root~width || '|' || root~height

  routeSupplier = camera~routeModel~routes~supplier
  do while routeSupplier~available
    route = routeSupplier~item
    routeSupplier~next
    line = 'ROUTE|' || route~id || '|' || route~sampleCount || '|' || route~meanEntryX || '|' || route~meanEntryY || '|' || route~meanMidX || '|' || route~meanMidY || '|' || route~meanExitX || '|' || route~meanExitY || '|' || route~meanDuration || '|' || route~meanLength
    call lineout path, line
  end

  zoneSupplier = camera~spatialModel~zones~zones~supplier
  do while zoneSupplier~available
    zone = zoneSupplier~item
    zoneSupplier~next
    call lineout path, 'ZONE|' || zone~id || '|' || zone~sampleCount || '|' || zone~meanX || '|' || zone~meanY
  end

  do window over camera~behaviour~windows
    call lineout path, 'WINDOW|' || window~centreSecond || '|' || window~halfWidth || '|' || window~observations || '|' || window~weightedObservations
    weightSupplier = window~routeWeights~supplier
    do while weightSupplier~available
      weightValue = weightSupplier~item
      weightKey = weightSupplier~index
      weightSupplier~next
      parse var weightKey 'ROUTE:' routeId
      call lineout path, 'WR|' || window~centreSecond || '|' || routeId || '|' || weightValue
    end
    weightSupplier = window~eventWeights~supplier
    do while weightSupplier~available
      weightValue = weightSupplier~item
      weightKey = weightSupplier~index
      weightSupplier~next
      parse var weightKey 'EVENT:' eventType
      call lineout path, 'WE|' || window~centreSecond || '|' || eventType || '|' || weightValue
    end
    weightSupplier = window~episodeWeights~supplier
    do while weightSupplier~available
      weightValue = weightSupplier~item
      weightKey = weightSupplier~index
      weightSupplier~next
      parse var weightKey 'EPISODE:' episodeId
      call lineout path, 'WEP|' || window~centreSecond || '|' || episodeId || '|' || weightValue
    end
    weightSupplier = window~motifWeights~supplier
    do while weightSupplier~available
      weightValue = weightSupplier~item
      weightKey = weightSupplier~index
      weightSupplier~next
      parse var weightKey 'MOTIF:' motifId
      call lineout path, 'WMOT|' || window~centreSecond || '|' || motifId || '|' || weightValue
    end
    weightSupplier = window~transitionWeights~supplier
    do while weightSupplier~available
      weightValue = weightSupplier~item
      weightKey = weightSupplier~index
      weightSupplier~next
      parse var weightKey 'TRANSITION:' transitionId
      call lineout path, 'WTR|' || window~centreSecond || '|' || transitionId || '|' || weightValue
    end
    weightSupplier = window~zoneEventWeights~supplier
    do while weightSupplier~available
      weightValue = weightSupplier~item
      weightKey = weightSupplier~index
      weightSupplier~next
      parse var weightKey 'ZONEEVENT:' zoneId ':' eventType
      call lineout path, 'WZ|' || window~centreSecond || '|' || zoneId || '|' || eventType || '|' || weightValue
    end
    metricSupplier = window~metrics~supplier
    do while metricSupplier~available
      distribution = metricSupplier~item
      metricName = metricSupplier~index
      metricSupplier~next
      call lineout path, 'WM|' || window~centreSecond || '|' || metricName || '|' || distribution~weightTotal || '|' || distribution~weightedSum || '|' || distribution~weightedSquareSum || '|' || distribution~sampleCount
    end
  end

  dayCountSupplier = camera~calendarBehaviour~sampleCounts~supplier
  do while dayCountSupplier~available
    daySampleCount = dayCountSupplier~item
    dayClass = dayCountSupplier~index
    dayCountSupplier~next
    call lineout path, 'DCOUNT|' || dayClass || '|' || daySampleCount
  end

  dayModelSupplier = camera~calendarBehaviour~models~supplier
  do while dayModelSupplier~available
    dayModel = dayModelSupplier~item
    dayClass = dayModelSupplier~index
    dayModelSupplier~next
    do dayWindow over dayModel~windows
      dayEpisodeSupplier = dayWindow~episodeWeights~supplier
      do while dayEpisodeSupplier~available
        dayEpisodeWeight = dayEpisodeSupplier~item
        dayEpisodeKey = dayEpisodeSupplier~index
        dayEpisodeSupplier~next
        parse var dayEpisodeKey 'EPISODE:' dayEpisodeId
        call lineout path, 'DWEP|' || dayClass || '|' || dayWindow~centreSecond || '|' || dayEpisodeId || '|' || dayEpisodeWeight
      end
      dayMotifSupplier = dayWindow~motifWeights~supplier
      do while dayMotifSupplier~available
        dayMotifWeight = dayMotifSupplier~item
        dayMotifKey = dayMotifSupplier~index
        dayMotifSupplier~next
        parse var dayMotifKey 'MOTIF:' dayMotifId
        call lineout path, 'DWMOT|' || dayClass || '|' || dayWindow~centreSecond || '|' || dayMotifId || '|' || dayMotifWeight
      end
      dayTransitionSupplier = dayWindow~transitionWeights~supplier
      do while dayTransitionSupplier~available
        dayTransitionWeight = dayTransitionSupplier~item
        dayTransitionKey = dayTransitionSupplier~index
        dayTransitionSupplier~next
        parse var dayTransitionKey 'TRANSITION:' dayTransitionId
        call lineout path, 'DWTR|' || dayClass || '|' || dayWindow~centreSecond || '|' || dayTransitionId || '|' || dayTransitionWeight
      end
      dayMetricSupplier = dayWindow~metrics~supplier
      do while dayMetricSupplier~available
        dayDistribution = dayMetricSupplier~item
        dayMetricName = dayMetricSupplier~index
        dayMetricSupplier~next
        call lineout path, 'DWM|' || dayClass || '|' || dayWindow~centreSecond || '|' || dayMetricName || '|' || dayDistribution~weightTotal || '|' || dayDistribution~weightedSum || '|' || dayDistribution~weightedSquareSum || '|' || dayDistribution~sampleCount
      end
    end
  end

  environmentSupplier = camera~environmentModel~profiles~supplier
  do while environmentSupplier~available
    environmentProfile = environmentSupplier~item
    environmentSupplier~next
    lumaDistribution = environmentProfile~backgroundLuma
    structureDistribution = environmentProfile~backgroundStructure
    call lineout path, 'ENVB|' || environmentProfile~code || '|LUMA|' || lumaDistribution~weightTotal || '|' || lumaDistribution~weightedSum || '|' || lumaDistribution~weightedSquareSum || '|' || lumaDistribution~sampleCount
    call lineout path, 'ENVB|' || environmentProfile~code || '|STRUCTURE|' || structureDistribution~weightTotal || '|' || structureDistribution~weightedSum || '|' || structureDistribution~weightedSquareSum || '|' || structureDistribution~sampleCount
    signatureSupplier = environmentProfile~signatureMetrics~supplier
    do while signatureSupplier~available
      signatureDistribution = signatureSupplier~item
      signatureName = signatureSupplier~index
      signatureSupplier~next
      call lineout path, 'ENVS|' || environmentProfile~code || '|' || signatureName || '|' || signatureDistribution~weightTotal || '|' || signatureDistribution~weightedSum || '|' || signatureDistribution~weightedSquareSum || '|' || signatureDistribution~sampleCount
    end
    environmentMetricSupplier = environmentProfile~metrics~supplier
    do while environmentMetricSupplier~available
      environmentDistribution = environmentMetricSupplier~item
      environmentMetricName = environmentMetricSupplier~index
      environmentMetricSupplier~next
      call lineout path, 'ENVM|' || environmentProfile~code || '|' || environmentMetricName || '|' || environmentDistribution~weightTotal || '|' || environmentDistribution~weightedSum || '|' || environmentDistribution~weightedSquareSum || '|' || environmentDistribution~sampleCount
    end
  end

  episodeSupplier = camera~episodeModel~episodes~supplier
  do while episodeSupplier~available
    learnedEpisode = episodeSupplier~item
    episodeSupplier~next
    call lineout path, 'EPISODE|' || learnedEpisode~id || '|' || learnedEpisode~sampleCount || '|' || learnedEpisode~sequenceKey
  end

  motifSupplier = camera~motifModel~motifs~supplier
  do while motifSupplier~available
    learnedMotif = motifSupplier~item
    motifSupplier~next
    call lineout path, 'MOTIF|' || learnedMotif~id || '|' || learnedMotif~sampleCount || '|' || learnedMotif~sequenceKey
  end

  transitionSupplier = camera~transitionModel~transitions~supplier
  do while transitionSupplier~available
    learnedTransition = transitionSupplier~item
    transitionSupplier~next
    call lineout path, 'TRANSITION|' || learnedTransition~id || '|' || learnedTransition~sampleCount || '|' || learnedTransition~fromMotifId || '|' || learnedTransition~toMotifId
  end

  tokenSupplier = camera~tokenDictionary~entries~supplier
  do while tokenSupplier~available
    tokenText = tokenSupplier~item
    tokenNumber = tokenSupplier~index
    tokenSupplier~next
    call lineout path, 'TOKEN|' || tokenNumber || '|' || tokenText
  end
  call stream path, 'c', 'close'
  return 1

::method load class
  use arg path
  if path = '' then return .nil
  if stream(path, 'c', 'query exists') = '' then return .nil

  camera = .nil
  windowsByCentre = .directory~new
  do while lines(path) > 0
    line = linein(path)
    parse var line recordType '|' rest
    select
      when recordType = 'CAMERA' then do
        parse var rest version '|' cameraId '|' width '|' height
        camera = .CameraModel~new(cameraId, width, height)
      end
      when recordType = 'ROUTE' then do
        if camera == .nil then iterate
        parse var rest routeId '|' sampleCount '|' entryX '|' entryY '|' midX '|' midY '|' exitX '|' exitY '|' meanDuration '|' meanLength
        route = .CameraRoute~new(routeId)
        route~sampleCount = sampleCount
        route~meanEntryX = entryX
        route~meanEntryY = entryY
        route~meanMidX = midX
        route~meanMidY = midY
        route~meanExitX = exitX
        route~meanExitY = exitY
        route~meanDuration = meanDuration
        route~meanLength = meanLength
        camera~routeModel~restoreRoute(route)
      end
      when recordType = 'ZONE' then do
        if camera == .nil then iterate
        parse var rest zoneId '|' sampleCount '|' meanX '|' meanY
        zone = .CameraZone~new(zoneId)
        zone~sampleCount = sampleCount
        zone~meanX = meanX
        zone~meanY = meanY
        camera~spatialModel~zones~restoreZone(zone)
      end
      when recordType = 'WINDOW' then do
        if camera == .nil then iterate
        parse var rest centreSecond '|' halfWidth '|' observationCount '|' weightedCount
        window = .CameraBehaviourWindow~new(centreSecond, halfWidth)
        window~observations = observationCount
        window~weightedObservations = weightedCount
        camera~behaviour~addWindow(window)
        windowsByCentre[centreSecond] = window
      end
      when recordType = 'WR' then do
        parse var rest centreSecond '|' routeId '|' weightValue
        if windowsByCentre~hasIndex(centreSecond) then windowsByCentre[centreSecond]~restoreRouteWeight(routeId, weightValue)
      end
      when recordType = 'WE' then do
        parse var rest centreSecond '|' eventType '|' weightValue
        if windowsByCentre~hasIndex(centreSecond) then windowsByCentre[centreSecond]~restoreEventWeight(eventType, weightValue)
      end
      when recordType = 'WEP' then do
        parse var rest centreSecond '|' episodeId '|' weightValue
        if windowsByCentre~hasIndex(centreSecond) then windowsByCentre[centreSecond]~restoreEpisodeWeight(episodeId, weightValue)
      end
      when recordType = 'WMOT' then do
        parse var rest centreSecond '|' motifId '|' weightValue
        if windowsByCentre~hasIndex(centreSecond) then windowsByCentre[centreSecond]~restoreMotifWeight(motifId, weightValue)
      end
      when recordType = 'WTR' then do
        parse var rest centreSecond '|' transitionId '|' weightValue
        if windowsByCentre~hasIndex(centreSecond) then windowsByCentre[centreSecond]~restoreTransitionWeight(transitionId, weightValue)
      end
      when recordType = 'WZ' then do
        parse var rest centreSecond '|' zoneId '|' eventType '|' weightValue
        if windowsByCentre~hasIndex(centreSecond) then windowsByCentre[centreSecond]~restoreZoneEventWeight(zoneId, eventType, weightValue)
      end
      when recordType = 'WM' then do
        parse var rest centreSecond '|' metricName '|' weightTotal '|' weightedSum '|' weightedSquareSum '|' sampleCount
        if windowsByCentre~hasIndex(centreSecond) then windowsByCentre[centreSecond]~restoreMetric(metricName, weightTotal, weightedSum, weightedSquareSum, sampleCount)
      end
      when recordType = 'DCOUNT' then do
        if camera == .nil then iterate
        parse var rest dayClass '|' daySampleCount
        camera~calendarBehaviour~restoreSampleCount(dayClass, daySampleCount)
      end
      when recordType = 'DWM' then do
        if camera == .nil then iterate
        parse var rest dayClass '|' centreSecond '|' metricName '|' weightTotal '|' weightedSum '|' weightedSquareSum '|' sampleCount
        camera~calendarBehaviour~restoreMetric(dayClass, camera~behaviour, centreSecond, metricName, weightTotal, weightedSum, weightedSquareSum, sampleCount)
      end
      when recordType = 'DWEP' then do
        if camera == .nil then iterate
        parse var rest dayClass '|' centreSecond '|' episodeId '|' weightValue
        camera~calendarBehaviour~restoreEpisodeWeight(dayClass, camera~behaviour, centreSecond, episodeId, weightValue)
      end
      when recordType = 'DWMOT' then do
        if camera == .nil then iterate
        parse var rest dayClass '|' centreSecond '|' motifId '|' weightValue
        camera~calendarBehaviour~restoreMotifWeight(dayClass, camera~behaviour, centreSecond, motifId, weightValue)
      end
      when recordType = 'DWTR' then do
        if camera == .nil then iterate
        parse var rest dayClass '|' centreSecond '|' transitionId '|' weightValue
        camera~calendarBehaviour~restoreTransitionWeight(dayClass, camera~behaviour, centreSecond, transitionId, weightValue)
      end
      when recordType = 'ENVB' then do
        if camera == .nil then iterate
        parse var rest environmentCode '|' distributionName '|' weightTotal '|' weightedSum '|' weightedSquareSum '|' sampleCount
        environmentProfile = camera~environmentModel~restoreProfile(environmentCode)
        select
          when distributionName = 'LUMA' then environmentProfile~backgroundLuma~restore(weightTotal, weightedSum, weightedSquareSum, sampleCount)
          when distributionName = 'STRUCTURE' then environmentProfile~backgroundStructure~restore(weightTotal, weightedSum, weightedSquareSum, sampleCount)
          otherwise nop
        end
      end
      when recordType = 'ENVS' then do
        if camera == .nil then iterate
        parse var rest environmentCode '|' metricName '|' weightTotal '|' weightedSum '|' weightedSquareSum '|' sampleCount
        environmentProfile = camera~environmentModel~restoreProfile(environmentCode)
        environmentProfile~restoreSignatureMetric(metricName, weightTotal, weightedSum, weightedSquareSum, sampleCount)
      end
      when recordType = 'ENVM' then do
        if camera == .nil then iterate
        parse var rest environmentCode '|' metricName '|' weightTotal '|' weightedSum '|' weightedSquareSum '|' sampleCount
        environmentProfile = camera~environmentModel~restoreProfile(environmentCode)
        environmentProfile~restoreMetric(metricName, weightTotal, weightedSum, weightedSquareSum, sampleCount)
      end
      when recordType = 'EPISODE' then do
        if camera == .nil then iterate
        parse var rest episodeId '|' episodeSampleCount '|' episodeSequenceKey
        learnedEpisode = .CameraEpisode~new(episodeId, episodeSequenceKey)
        learnedEpisode~sampleCount = episodeSampleCount
        camera~episodeModel~restoreEpisode(learnedEpisode)
      end
      when recordType = 'MOTIF' then do
        if camera == .nil then iterate
        parse var rest motifId '|' motifSampleCount '|' motifSequenceKey
        learnedMotif = .CameraMotif~new(motifId, motifSequenceKey)
        learnedMotif~sampleCount = motifSampleCount
        camera~motifModel~restoreMotif(learnedMotif)
      end
      when recordType = 'TRANSITION' then do
        if camera == .nil then iterate
        parse var rest transitionId '|' transitionSampleCount '|' fromMotifId '|' toMotifId
        learnedTransition = .CameraMotifTransition~new(transitionId, fromMotifId, toMotifId)
        learnedTransition~sampleCount = transitionSampleCount
        camera~transitionModel~restoreTransition(learnedTransition)
      end
      when recordType = 'TOKEN' then do
        if camera == .nil then iterate
        parse var rest tokenNumber '|' tokenText
        camera~tokenDictionary~restoreToken(tokenNumber, tokenText)
      end
      otherwise nop
    end
  end
  call stream path, 'c', 'close'
  return camera



/* ------------------------------------------------------------------------- */
/* Clip/session summaries and external measurement import contract.           */
/* ------------------------------------------------------------------------- */

::class CameraEpisodeOccurrence public
::attribute episodeId
::attribute timestamp

::method init
  use arg episodeId, timestamp
  self~episodeId = episodeId
  self~timestamp = timestamp


::class CameraTrackBehaviourVector public
::attribute subjectId get
::attribute objectType get
::attribute pointCount get

::method init
  expose subjectId objectType pointCount features
  use arg track
  if track == .nil then raise syntax 88.900 array("Track behaviour vector requires a track")
  subjectId = track~id
  objectType = track~objectType
  pointCount = track~pointCount
  features = .directory~new

  first = track~firstPoint
  if first == .nil then return
  scaleX = first~box~width
  scaleY = first~box~height
  scale = .CameraMath~sqrt((scaleX * scaleX) + (scaleY * scaleY))
  if scale < 1 then scale = 1

  dx = track~displacementX / scale
  dy = track~displacementY / scale
  length = track~trajectoryLength / scale
  duration = track~duration
  speed = 0
  if duration > 0 then speed = length / duration
  net = .CameraMath~sqrt((dx * dx) + (dy * dy))
  straightness = 0
  if length > 0 then straightness = net / length

  features["DX"] = dx
  features["DY"] = dy
  features["LENGTH"] = length
  features["SPEED"] = speed
  features["STRAIGHT"] = straightness

::method feature
  expose features
  use arg name
  if features~hasIndex(name) then return features[name]
  return 0

::method featureNames
  expose features
  names = features~allIndexes
  names~sort
  return names

::method compactText
  expose features
  names = self~featureNames
  body = ''
  do name over names
    pair = name || '=' || features[name]
    if body == '' then body = pair
    else body = body || ';' || pair
  end
  return 'CTV1|S=' || self~subjectId || '|O=' || self~objectType || '|N=' || self~pointCount || '|F=' || body


::class CameraPeerOutlierFeature public
::attribute name get
::attribute value get
::attribute peerMedian get
::attribute peerMad get
::attribute residual get
::attribute shifted get

::method init
  expose name value peerMedian peerMad residual shifted
  use arg nameArg, valueArg, medianArg, madArg, scoreThreshold
  name = nameArg
  value = valueArg
  peerMedian = medianArg
  peerMad = madArg
  denominator = peerMad
  if denominator < 0.05 then denominator = 0.05
  residual = abs(value - peerMedian) / denominator
  shifted = residual >= scoreThreshold

::method compactText
  return self~name || ':' || self~value || ':' || self~peerMedian || ':' || self~peerMad || ':' || self~residual || ':' || self~shifted


::class CameraPeerOutlierAssessment public
::attribute subjectId get
::attribute objectType get
::attribute peerCount get
::attribute score get
::attribute maximumResidual get
::attribute strongestFeature get
::attribute shiftedFeatureCount get
::attribute outlier get

::method init
  expose subjectId objectType peerCount score maximumResidual strongestFeature shiftedFeatureCount outlier featureEvidence
  use arg vector, peers, scoreThreshold, minimumShiftedFeatures
  subjectId = vector~subjectId
  objectType = vector~objectType
  peerCount = peers~items
  score = 0
  maximumResidual = 0
  strongestFeature = ''
  shiftedFeatureCount = 0
  outlier = .false
  featureEvidence = .array~new
  if peerCount = 0 then return

  total = 0
  do featureName over vector~featureNames
    values = .array~new
    do peer over peers
      values~append(peer~feature(featureName))
    end
    median = .CameraPeerOutlierModel~median(values)
    deviations = .array~new
    do peerValue over values
      deviations~append(abs(peerValue - median))
    end
    mad = .CameraPeerOutlierModel~median(deviations)
    evidence = .CameraPeerOutlierFeature~new(featureName, vector~feature(featureName), median, mad, scoreThreshold)
    featureEvidence~append(evidence)
    total = total + evidence~residual
    if evidence~shifted then shiftedFeatureCount = shiftedFeatureCount + 1
    if evidence~residual > maximumResidual then do
      maximumResidual = evidence~residual
      strongestFeature = featureName
    end
  end
  if featureEvidence~items > 0 then score = total / featureEvidence~items
  outlier = shiftedFeatureCount >= minimumShiftedFeatures

::method features
  expose featureEvidence
  copy = .array~new
  do item over featureEvidence
    copy~append(item)
  end
  return copy

::method compactText
  return 'CPA1|S=' || self~subjectId || '|P=' || self~peerCount || '|O=' || self~outlier || '|SC=' || self~score || '|MX=' || self~maximumResidual || '|SF=' || self~strongestFeature || '|SH=' || self~shiftedFeatureCount


::class CameraPeerOutlierSet public
::attribute version get
::attribute subjectCount get
::attribute outlierCount get
::attribute strongestSubjectId get
::attribute strongestScore get

::method init
  expose version subjectCount outlierCount strongestSubjectId strongestScore assessments
  use arg assessmentArray
  version = .CameraConstant~PEER_OUTLIER_VERSION
  assessments = .array~new
  subjectCount = 0
  outlierCount = 0
  strongestSubjectId = ''
  strongestScore = 0
  do assessment over assessmentArray
    assessments~append(assessment)
    subjectCount = subjectCount + 1
    if assessment~outlier then outlierCount = outlierCount + 1
    if assessment~score > strongestScore then do
      strongestScore = assessment~score
      strongestSubjectId = assessment~subjectId
    end
  end

::method assessments
  expose assessments
  copy = .array~new
  do item over assessments
    copy~append(item)
  end
  return copy

::method assessment
  expose assessments
  use arg subjectId
  do item over assessments
    if item~subjectId == subjectId then return item
  end
  return .nil

::method compactText
  expose assessments
  values=.array~new
  do item over assessments
    if item~outlier then values~append(item~subjectId || ':' || item~strongestFeature || ':' || item~maximumResidual)
  end
  values~sort
  body=''
  do value over values
    if body=='' then body=value
    else body=body||';'||value
  end
  return 'CPO' || self~version || '|N=' || self~subjectCount || '|O=' || self~outlierCount || '|S=' || self~strongestSubjectId || '|SC=' || self~strongestScore || '|D=' || body


::class CameraPeerOutlierModel public

::method median class
  use arg values
  if values == .nil then return 0
  if values~items = 0 then return 0
  copy=.array~new
  do value over values
    copy~append(value)
  end
  copy~sort
  count=copy~items
  middle=(count + 1) % 2
  if count // 2 = 1 then return copy[middle]
  lower=count % 2
  return (copy[lower] + copy[lower + 1]) / 2

::method assessTracks class
  use arg tracks, minimumPeers, scoreThreshold, minimumShiftedFeatures
  if arg(2,'O') then minimumPeers=.CameraConstant~PEER_OUTLIER_MINIMUM_PEERS
  if arg(3,'O') then scoreThreshold=.CameraConstant~PEER_OUTLIER_SCORE_THRESHOLD
  if arg(4,'O') then minimumShiftedFeatures=.CameraConstant~PEER_OUTLIER_SHIFTED_FEATURES
  vectors=.array~new
  if tracks \== .nil then do track over tracks
    if track == .nil then iterate
    if track~pointCount < 2 then iterate
    vectors~append(.CameraTrackBehaviourVector~new(track))
  end

  results=.array~new
  do vector over vectors
    peers=.array~new
    do candidate over vectors
      if candidate~subjectId == vector~subjectId then iterate
      /* Object type is a coarse geometry class only; UNKNOWN may compare with UNKNOWN. */
      if candidate~objectType \= vector~objectType then iterate
      peers~append(candidate)
    end
    if peers~items < minimumPeers then iterate
    results~append(.CameraPeerOutlierAssessment~new(vector, peers, scoreThreshold, minimumShiftedFeatures))
  end
  return .CameraPeerOutlierSet~new(results)


::class CameraClipSummary public
::attribute clipId
::attribute startSecond
::attribute durationSeconds
::attribute environmentCode
::attribute dayClass
::attribute trackCount
::attribute eventCount
::attribute frameCount
::attribute photometricCount
::attribute ignoredCount
::attribute moverObservationCount
::attribute interactionCount
::attribute deviationCount
::attribute stopCount
::attribute encodedBytes
::attribute bytesPerEvent
::attribute totalEventDescriptionBits
::attribute averageEventDescriptionBits
::attribute totalRouteDescriptionBits
::attribute averageRouteDescriptionBits
::attribute episodeCount
::attribute totalEpisodeDescriptionBits
::attribute averageEpisodeDescriptionBits
::attribute motifCount
::attribute totalMotifDescriptionBits
::attribute averageMotifDescriptionBits
::attribute transitionCount
::attribute totalTransitionDescriptionBits
::attribute averageTransitionDescriptionBits
::attribute currentCondition
::attribute currentAssessment
::attribute peerOutliers

::method init
  expose routeCounts directionCounts eventCounts episodeCounts motifCounts transitionCounts seenTrackIds events episodeOccurrences motifOccurrences transitionOccurrences lastEpisodeKey
  use arg clipId, startSecond, durationSeconds, environmentCode, dayClass
  if arg(1, 'O') then clipId = ''
  if arg(2, 'O') then startSecond = 0
  if arg(3, 'O') then durationSeconds = 0
  if arg(4, 'O') then environmentCode = .CameraConstant~ENV_UNKNOWN
  if arg(5, 'O') then dayClass = .CameraConstant~DAY_UNKNOWN
  self~clipId = clipId
  self~startSecond = startSecond
  self~durationSeconds = durationSeconds
  self~environmentCode = environmentCode
  self~dayClass = dayClass
  self~trackCount = 0
  self~eventCount = 0
  self~frameCount = 0
  self~photometricCount = 0
  self~ignoredCount = 0
  self~moverObservationCount = 0
  self~interactionCount = 0
  self~deviationCount = 0
  self~stopCount = 0
  self~encodedBytes = 0
  self~bytesPerEvent = 0
  self~totalEventDescriptionBits = 0
  self~averageEventDescriptionBits = 0
  self~totalRouteDescriptionBits = 0
  self~averageRouteDescriptionBits = 0
  self~episodeCount = 0
  self~totalEpisodeDescriptionBits = 0
  self~averageEpisodeDescriptionBits = 0
  self~motifCount = 0
  self~totalMotifDescriptionBits = 0
  self~averageMotifDescriptionBits = 0
  self~transitionCount = 0
  self~totalTransitionDescriptionBits = 0
  self~averageTransitionDescriptionBits = 0
  self~currentCondition = .nil
  self~currentAssessment = .nil
  self~peerOutliers = .nil
  routeCounts = .directory~new
  directionCounts = .directory~new
  eventCounts = .directory~new
  episodeCounts = .directory~new
  motifCounts = .directory~new
  transitionCounts = .directory~new
  seenTrackIds = .set~new
  events = .array~new
  episodeOccurrences = .array~new
  motifOccurrences = .array~new
  transitionOccurrences = .array~new
  lastEpisodeKey = ''

::method incrementDirectory private
  use arg directory, key
  if directory == .nil then return 0
  oldCount = 0
  if directory~hasIndex(key) then oldCount = directory[key]
  directory[key] = oldCount + 1
  return directory[key]

::method directionForTrack private
  use arg track
  if track == .nil then return .CameraConstant~DIRECTION_STATIONARY
  dx = track~displacementX
  dy = track~displacementY
  if abs(dx) < 2 & abs(dy) < 2 then return .CameraConstant~DIRECTION_STATIONARY
  if abs(dx) >= abs(dy) then do
    if dx < 0 then return .CameraConstant~DIRECTION_LEFT
    return .CameraConstant~DIRECTION_RIGHT
  end
  if dy < 0 then return .CameraConstant~DIRECTION_UP
  return .CameraConstant~DIRECTION_DOWN

::method addFrameResult
  use arg frameResult
  if frameResult == .nil then return self~frameCount
  self~frameCount = self~frameCount + 1
  self~photometricCount = self~photometricCount + frameResult~photometricCount
  self~ignoredCount = self~ignoredCount + frameResult~ignoredCount
  self~moverObservationCount = self~moverObservationCount + frameResult~moverCount
  return self~frameCount

::method addTrack
  expose routeCounts directionCounts seenTrackIds
  use arg track
  if track == .nil then return self~trackCount
  if seenTrackIds~hasIndex(track~id) then return self~trackCount
  seenTrackIds[track~id] = track~id
  self~trackCount = self~trackCount + 1
  if track~routeId \= '' then self~incrementDirectory(routeCounts, track~routeId)
  self~totalRouteDescriptionBits = self~totalRouteDescriptionBits + track~temporalRouteBits
  if self~trackCount > 0 then self~averageRouteDescriptionBits = self~totalRouteDescriptionBits / self~trackCount
  direction = self~directionForTrack(track)
  self~incrementDirectory(directionCounts, direction)
  return self~trackCount

::method addEvent
  expose eventCounts episodeCounts events episodeOccurrences lastEpisodeKey
  use arg clipEvent
  if clipEvent == .nil then return self~eventCount
  events~append(clipEvent)
  self~eventCount = self~eventCount + 1
  self~totalEventDescriptionBits = self~totalEventDescriptionBits + clipEvent~descriptionBits
  if self~eventCount > 0 then self~averageEventDescriptionBits = self~totalEventDescriptionBits / self~eventCount
  self~incrementDirectory(eventCounts, clipEvent~eventType)
  if clipEvent~episodeId \= '' then do
    episodeKey = clipEvent~episodeInstanceId
    if episodeKey = '' then episodeKey = clipEvent~episodeId || ':' || clipEvent~trackAId || ':' || clipEvent~trackBId
    if episodeKey \= lastEpisodeKey then do
      self~incrementDirectory(episodeCounts, clipEvent~episodeId)
      episodeOccurrences~append(.CameraEpisodeOccurrence~new(clipEvent~episodeId, clipEvent~timestamp))
      self~episodeCount = self~episodeCount + 1
      lastEpisodeKey = episodeKey
    end
  end
  else lastEpisodeKey = ''
  if clipEvent~eventType = .CameraConstant~EVENT_APPROACH then self~interactionCount = self~interactionCount + 1
  if clipEvent~eventType = .CameraConstant~EVENT_CLOSE then self~interactionCount = self~interactionCount + 1
  if clipEvent~eventType = .CameraConstant~EVENT_SEPARATE then self~interactionCount = self~interactionCount + 1
  if clipEvent~eventType = .CameraConstant~EVENT_DEVIATE then self~deviationCount = self~deviationCount + 1
  if clipEvent~eventType = .CameraConstant~EVENT_STOP then self~stopCount = self~stopCount + 1
  return self~eventCount

::method events
  expose events
  return events

::method routeCounts
  expose routeCounts
  return routeCounts

::method directionCounts
  expose directionCounts
  return directionCounts

::method eventCounts
  expose eventCounts
  return eventCounts

::method routeCount
  expose routeCounts
  use arg routeId
  if routeCounts~hasIndex(routeId) then return routeCounts[routeId]
  return 0

::method directionCount
  expose directionCounts
  use arg direction
  if directionCounts~hasIndex(direction) then return directionCounts[direction]
  return 0

::method eventTypeCount
  expose eventCounts
  use arg eventType
  if eventCounts~hasIndex(eventType) then return eventCounts[eventType]
  return 0

::method episodeCounts
  expose episodeCounts
  return episodeCounts

::method episodeOccurrences
  expose episodeOccurrences
  return episodeOccurrences

::method episodeTypeCount
  expose episodeCounts
  use arg episodeId
  if episodeCounts~hasIndex(episodeId) then return episodeCounts[episodeId]
  return 0

::method episodeRatePerMinute
  return self~perMinute(self~episodeCount)


::method addMotifOccurrence
  expose motifCounts motifOccurrences
  use arg motifEncoding
  if motifEncoding == .nil then return self~motifCount
  if motifEncoding~motifId = '' then return self~motifCount
  motifOccurrences~append(motifEncoding)
  self~incrementDirectory(motifCounts, motifEncoding~motifId)
  self~motifCount = self~motifCount + 1
  self~totalMotifDescriptionBits = self~totalMotifDescriptionBits + motifEncoding~encodedBits
  if self~motifCount > 0 then self~averageMotifDescriptionBits = self~totalMotifDescriptionBits / self~motifCount
  return self~motifCount

::method motifCounts
  expose motifCounts
  return motifCounts

::method motifOccurrences
  expose motifOccurrences
  return motifOccurrences

::method motifTypeCount
  expose motifCounts
  use arg motifId
  if motifCounts~hasIndex(motifId) then return motifCounts[motifId]
  return 0

::method motifRatePerMinute
  return self~perMinute(self~motifCount)

::method addTransitionOccurrence
  expose transitionCounts transitionOccurrences
  use arg transitionOccurrence
  if transitionOccurrence == .nil then return self~transitionCount
  if transitionOccurrence~transitionId = '' then return self~transitionCount
  transitionOccurrences~append(transitionOccurrence)
  self~incrementDirectory(transitionCounts, transitionOccurrence~transitionId)
  self~transitionCount = self~transitionCount + 1
  self~totalTransitionDescriptionBits = self~totalTransitionDescriptionBits + transitionOccurrence~descriptionBits
  if self~transitionCount > 0 then self~averageTransitionDescriptionBits = self~totalTransitionDescriptionBits / self~transitionCount
  return self~transitionCount

::method transitionCounts
  expose transitionCounts
  return transitionCounts

::method transitionOccurrences
  expose transitionOccurrences
  return transitionOccurrences

::method transitionRatePerMinute
  return self~perMinute(self~transitionCount)

::method midpointSecond
  midpoint = self~startSecond + (self~durationSeconds / 2)
  do while midpoint >= 86400
    midpoint = midpoint - 86400
  end
  return midpoint

::method perMinute
  use arg count
  if self~durationSeconds <= 0 then return 0
  return count * 60 / self~durationSeconds

::method trackRatePerMinute
  return self~perMinute(self~trackCount)

::method eventRatePerMinute
  return self~perMinute(self~eventCount)

::method interactionRatePerMinute
  return self~perMinute(self~interactionCount)

::method deviationRatePerMinute
  return self~perMinute(self~deviationCount)

::method stopRatePerMinute
  return self~perMinute(self~stopCount)

::method photometricRatePerMinute
  return self~perMinute(self~photometricCount)

::method moverObservationRatePerMinute
  return self~perMinute(self~moverObservationCount)

::method directionShare
  use arg direction
  if self~trackCount <= 0 then return 0
  return self~directionCount(direction) / self~trackCount

::method buildEventStream
  expose events
  use arg camera
  if camera == .nil then return 0
  streamObject = .CameraEventStream~new(camera~tokenDictionary)
  streamObject~appendEvents(events)
  self~encodedBytes = streamObject~byteCount
  if self~eventCount > 0 then self~bytesPerEvent = self~encodedBytes / self~eventCount
  else self~bytesPerEvent = self~encodedBytes
  return streamObject

::method compactText
  return self~clipId || '|start=' || self~startSecond || '|duration=' || self~durationSeconds || '|tracks=' || self~trackCount || '|events=' || self~eventCount || '|interactions=' || self~interactionCount || '|deviations=' || self~deviationCount || '|photometric=' || self~photometricCount || '|bytes=' || self~encodedBytes


::class CameraMetricAssessment public
::attribute name
::attribute value
::attribute expected
::attribute zScore
::attribute support
::attribute state
::attribute baselineContext

::method init
  use arg name, value, expected, zScore, support, state, baselineContext
  self~name = name
  self~value = value
  self~expected = expected
  self~zScore = zScore
  self~support = support
  self~state = state
  if arg(7, 'O') then baselineContext = 'ALL'
  self~baselineContext = baselineContext


::class CameraProductionIdentity public
::attribute version get
::attribute cameraId get
::attribute cameraPackageVersion get
::attribute alchemyBaseVersion get
::attribute methodName get
::attribute contractId get
::attribute contractRevision get
::attribute contractShape get
::attribute constructionEntrypoint get
::attribute constructionCompleted get
::attribute initialIntegrityFingerprint get
::attribute currentIntegrityFingerprint get
::attribute reservedSurfaceDrift get
::attribute digestAlgorithm get
::attribute digestHex get
::attribute compactToken get

::method init
  expose version cameraId cameraPackageVersion alchemyBaseVersion methodName contractId contractRevision contractShape constructionEntrypoint constructionCompleted initialIntegrityFingerprint currentIntegrityFingerprint reservedSurfaceDrift digestAlgorithm digestHex compactToken canonicalSource
  use arg camera
  if camera == .nil then raise syntax 88.900 array("Camera production identity requires a CameraModel")
  version = .CameraConstant~PRODUCTION_IDENTITY_VERSION
  cameraId = camera~id
  cameraPackageVersion = .CameraConstant~CAMERA_PACKAGE_VERSION
  alchemyBaseVersion = camera~alchemyBaseState["base_version"]
  methodName = "ASSESSSUMMARYATGENERATION"
  contractId = .CameraConstant~ASSESSMENT_CONTRACT_ID
  contractRevision = .CameraConstant~ASSESSMENT_CONTRACT_REVISION
  contractShape = .CameraConstant~ASSESSMENT_CONTRACT_SHAPE
  construction = camera~alchemyConstructionProvenance
  integrity = camera~alchemyInheritanceIntegrity
  constructionEntrypoint = construction["entrypoint"]
  constructionCompleted = construction["completed"]
  initialIntegrityFingerprint = construction["initial_integrity_fingerprint"]
  currentIntegrityFingerprint = integrity["fingerprint"]
  reservedSurfaceDrift = construction["reserved_surface_drift"]
  canonicalSource = "CPI" || version || "|CAMERA=" || cameraId || "|PACKAGE=" || cameraPackageVersion || "|ALCHEMY=" || alchemyBaseVersion || "|METHOD=" || methodName || "|CID=" || contractId || "|REV=" || contractRevision || "|SHAPE=" || contractShape || "|ENTRY=" || constructionEntrypoint || "|COMPLETE=" || constructionCompleted || "|INITIAL=" || initialIntegrityFingerprint || "|CURRENT=" || currentIntegrityFingerprint || "|DRIFT=" || reservedSurfaceDrift
  digestAlgorithm = "SHA-512/96"
  digestHex = .SHA512~new(canonicalSource)~digest
  compactToken = digestHex~left(24)

::method canonicalText
  expose canonicalSource
  return canonicalSource || "|DIGEST_ALGORITHM=" || self~digestAlgorithm || "|DIGEST=" || self~digestHex

::method compactText
  return "CPI" || self~version || "|P=" || self~cameraPackageVersion || "|A=" || self~alchemyBaseVersion || "|M=ASG|R=" || self~contractRevision || "|I=" || self~compactToken

::method matchesCurrent
  use arg camera
  if camera == .nil then return .false
  current = .CameraProductionIdentity~new(camera)
  return self~digestHex == current~digestHex


::class CameraClipAssessment public
::attribute clipId
::attribute secondOfDay
::attribute dayClass
::attribute generationId
::attribute evidence
::attribute productionIdentity
::attribute averageEventDescriptionBits
::attribute averageRouteDescriptionBits
::attribute averageEpisodeDescriptionBits
::attribute averageMotifDescriptionBits
::attribute averageTransitionDescriptionBits

::method init
  expose metrics
  use arg clipId, secondOfDay, dayClass, generationId
  if arg(3, 'O') then dayClass = .CameraConstant~DAY_UNKNOWN
  if arg(4, 'O') then generationId = ''
  self~clipId = clipId
  self~secondOfDay = secondOfDay
  self~dayClass = dayClass
  self~generationId = generationId
  self~evidence = .nil
  self~productionIdentity = .nil
  self~averageEventDescriptionBits = 0
  self~averageRouteDescriptionBits = 0
  self~averageEpisodeDescriptionBits = 0
  self~averageMotifDescriptionBits = 0
  self~averageTransitionDescriptionBits = 0
  metrics = .directory~new

::method addMetric
  expose metrics
  use arg metricAssessment
  if metricAssessment == .nil then return 0
  metrics[metricAssessment~name] = metricAssessment
  return metrics~items

::method metric
  expose metrics
  use arg metricName
  if metrics~hasIndex(metricName) then return metrics[metricName]
  return .nil

::method metrics
  expose metrics
  return metrics

::method conditionSignature
  return .CameraAssessmentSignature~new(self)

::method disclosure
  use arg profile
  if arg(1, 'O') then profile = .CameraConstant~DISCLOSURE_PUBLIC
  return .CameraAssessmentDisclosure~new(self, profile)

::method elevatedCount
  expose metrics
  elevated = 0
  metricSupplier = metrics~supplier
  do while metricSupplier~available
    metricAssessment = metricSupplier~item
    metricSupplier~next
    if metricAssessment~state = .CameraConstant~BASELINE_ELEVATED then elevated = elevated + 1
  end
  return elevated


::class CameraAssessmentDisclosure public
::attribute profile get
::attribute clipId get
::attribute generationId get
::attribute payload get
::attribute payloadBytes get

::method init
  expose profile clipId generationId payload payloadBytes
  use arg assessment, profileArg
  if assessment == .nil then raise syntax 88.900 array("Camera assessment disclosure requires an assessment")
  profile = profileArg~string~translate
  if profile \= .CameraConstant~DISCLOSURE_PUBLIC & profile \= .CameraConstant~DISCLOSURE_CUSTOMER & profile \= .CameraConstant~DISCLOSURE_INTERNAL & profile \= .CameraConstant~DISCLOSURE_FULL then raise syntax 88.900 array("Unsupported Camera disclosure profile: " || profile)

  clipId = assessment~clipId
  generationId = assessment~generationId
  signature = assessment~conditionSignature

  select
    when profile == .CameraConstant~DISCLOSURE_PUBLIC then payload = signature~compactText
    when profile == .CameraConstant~DISCLOSURE_CUSTOMER then do
      if assessment~evidence == .nil then payload = signature~compactText
      else payload = assessment~evidence~customerText
    end
    when profile == .CameraConstant~DISCLOSURE_INTERNAL then do
      if assessment~evidence == .nil then payload = signature~compactText
      else payload = assessment~evidence~canonicalText
    end
    when profile == .CameraConstant~DISCLOSURE_FULL then do
      if assessment~evidence == .nil then payload = signature~compactText
      else do
        payload = assessment~evidence~canonicalText
        payload = payload || '0a'x || 'ALCHEMY_OBJECT_ID=' || assessment~evidence~alchemyObjectId
        metrics = assessment~evidence~alchemyMetrics
        payload = payload || '0a'x || 'ALCHEMY_USE_COUNT=' || metrics["use_count"] || '|LIFECYCLE=' || metrics["lifecycle"]
        payload = payload || '0a'x || 'ALCHEMY_INSTRUMENTATION_EVENTS=' || assessment~evidence~instrumentationEvents~items
      end
    end
  end

  payloadBytes = length(payload)

::method canonicalText
  return 'DISCLOSURE=' || self~profile || '|CLIP=' || self~clipId || '|GENERATION=' || self~generationId || '|BYTES=' || self~payloadBytes || '0a'x || self~payload


::class CameraAssessmentSignatureMetric public
::attribute name get
::attribute code get
::attribute quantizedZ get
::attribute state get

::method init
  expose name code quantizedZ state
  use arg metricAssessment
  name = metricAssessment~name
  code = .CameraAssessmentSignature~metricCode(name)
  quantizedZ = .CameraAssessmentSignature~quantizeZ(metricAssessment~zScore)
  state = metricAssessment~state

::method canonicalText
  return self~code || ':' || self~quantizedZ || ':' || self~state


::class CameraAssessmentSignature public
::attribute version get
::attribute generationId get
::attribute clipId get
::attribute secondOfDay get
::attribute dayClass get
::attribute environmentCode get
::attribute productionToken get
::attribute elevatedCount get
::attribute insufficientCount get
::attribute maximumAbsoluteQuantizedZ get

::method init
  expose version generationId clipId secondOfDay dayClass environmentCode productionToken elevatedCount insufficientCount maximumAbsoluteQuantizedZ metricSnapshots
  use arg assessment
  version = .CameraConstant~ASSESSMENT_SIGNATURE_VERSION
  generationId = assessment~generationId
  clipId = assessment~clipId
  secondOfDay = assessment~secondOfDay
  dayClass = assessment~dayClass
  environmentCode = ''
  if assessment~evidence \== .nil then environmentCode = assessment~evidence~environmentCode
  productionToken = ''
  if assessment~productionIdentity \== .nil then productionToken = assessment~productionIdentity~compactToken
  elevatedCount = 0
  insufficientCount = 0
  maximumAbsoluteQuantizedZ = 0
  metricSnapshots = .array~new

  supplier = assessment~metrics~supplier
  do while supplier~available
    metricAssessment = supplier~item
    supplier~next
    metricSnapshot = .CameraAssessmentSignatureMetric~new(metricAssessment)
    metricSnapshots~append(metricSnapshot)
    if metricSnapshot~state == .CameraConstant~BASELINE_ELEVATED then elevatedCount = elevatedCount + 1
    if metricSnapshot~state == .CameraConstant~BASELINE_INSUFFICIENT then insufficientCount = insufficientCount + 1
    absoluteZ = abs(metricSnapshot~quantizedZ)
    if absoluteZ > maximumAbsoluteQuantizedZ then maximumAbsoluteQuantizedZ = absoluteZ
  end

::method metrics
  expose metricSnapshots
  copy = .array~new
  do item over metricSnapshots
    copy~append(item)
  end
  return copy

::method metricCount
  expose metricSnapshots
  return metricSnapshots~items

::method metric
  expose metricSnapshots
  use arg metricName
  do item over metricSnapshots
    if item~name == metricName then return item
  end
  return .nil

::method compactText
  expose metricSnapshots
  metricLines = .array~new
  do item over metricSnapshots
    metricLines~append(item~canonicalText)
  end
  metricLines~sort
  metricsText = ''
  do metricLine over metricLines
    if metricsText == '' then metricsText = metricLine
    else metricsText = metricsText || ';' || metricLine
  end
  return 'CAS' || self~version || '|G=' || self~generationId || '|P=' || self~productionToken || '|T=' || self~secondOfDay || '|D=' || self~dayClass || '|E=' || self~environmentCode || '|M=' || metricsText

::method canonicalText
  return self~compactText

::method compareTo
  use arg other
  if other == .nil then return .nil
  return .CameraAssessmentSignatureDelta~new(self, other)

::method quantizeZ class
  use arg zScore
  if zScore > 15.875 then return 127
  if zScore < -15.875 then return -127
  if zScore >= 0 then return trunc((zScore * 8) + 0.5)
  return trunc((zScore * 8) - 0.5)

::method metricCode class
  use arg metricName
  select
    when metricName == 'TRACK_RATE' then return 'TR'
    when metricName == 'EVENT_RATE' then return 'EV'
    when metricName == 'MOVER_OBS_RATE' then return 'MO'
    when metricName == 'INTERACTION_RATE' then return 'IN'
    when metricName == 'EPISODE_RATE' then return 'EP'
    when metricName == 'MOTIF_RATE' then return 'MF'
    when metricName == 'TRANSITION_RATE' then return 'XT'
    when metricName == 'DEVIATION_RATE' then return 'DV'
    when metricName == 'STOP_RATE' then return 'ST'
    when metricName == 'PHOTOMETRIC_RATE' then return 'PH'
    when metricName == 'DIR_DOWN_SHARE' then return 'DD'
    when metricName == 'DIR_UP_SHARE' then return 'DU'
    when metricName == 'DIR_LEFT_SHARE' then return 'DL'
    when metricName == 'DIR_RIGHT_SHARE' then return 'DR'
    otherwise return metricName
  end


::class CameraSignatureTrendMetric public
::attribute name get
::attribute code get
::attribute sampleCount get
::attribute firstQuantizedZ get
::attribute lastQuantizedZ get
::attribute averageQuantizedZ get
::attribute minimumQuantizedZ get
::attribute maximumQuantizedZ get
::attribute deltaZ get
::attribute elevatedCount get
::attribute elevatedShare get
::attribute trendState get

::method init
  expose name code sampleCount firstQuantizedZ lastQuantizedZ averageQuantizedZ minimumQuantizedZ maximumQuantizedZ deltaZ elevatedCount elevatedShare trendState
  use arg metricName, metricCode, values, states, minimumSamples, deltaThreshold
  name = metricName
  code = metricCode
  sampleCount = values~items
  firstQuantizedZ = 0
  lastQuantizedZ = 0
  averageQuantizedZ = 0
  minimumQuantizedZ = 0
  maximumQuantizedZ = 0
  deltaZ = 0
  elevatedCount = 0
  elevatedShare = 0
  trendState = .CameraConstant~TREND_STABLE
  if sampleCount = 0 then return

  firstQuantizedZ = values[1]
  lastQuantizedZ = values[sampleCount]
  minimumQuantizedZ = values[1]
  maximumQuantizedZ = values[1]
  total = 0
  do value over values
    total = total + value
    if value < minimumQuantizedZ then minimumQuantizedZ = value
    if value > maximumQuantizedZ then maximumQuantizedZ = value
  end
  averageQuantizedZ = total / sampleCount
  deltaZ = lastQuantizedZ - firstQuantizedZ

  do state over states
    if state == .CameraConstant~BASELINE_ELEVATED then elevatedCount = elevatedCount + 1
  end
  elevatedShare = elevatedCount / sampleCount

  if sampleCount >= minimumSamples then do
    if deltaZ >= deltaThreshold then trendState = .CameraConstant~TREND_RISING
    else if deltaZ <= -deltaThreshold then trendState = .CameraConstant~TREND_FALLING
  end

::method canonicalText
  return self~code || '|N=' || self~sampleCount || '|F=' || self~firstQuantizedZ || '|L=' || self~lastQuantizedZ || '|AVG=' || self~averageQuantizedZ || '|MIN=' || self~minimumQuantizedZ || '|MAX=' || self~maximumQuantizedZ || '|D=' || self~deltaZ || '|ES=' || self~elevatedShare || '|T=' || self~trendState


::class CameraSignatureTrendWindowSnapshot public
::attribute spanSeconds get
::attribute sampleCount get
::attribute generationId get
::attribute dayClass get
::attribute environmentCode get
::attribute productionToken get
::attribute strongestMetricName get
::attribute strongestDelta get
::attribute trendingMetricCount get

::method init
  expose spanSeconds sampleCount generationId dayClass environmentCode productionToken strongestMetricName strongestDelta trendingMetricCount metricSnapshots
  use arg spanArg, signatures, minimumSamples, deltaThreshold
  spanSeconds = spanArg
  sampleCount = signatures~items
  generationId = ''
  dayClass = .CameraConstant~DAY_UNKNOWN
  environmentCode = ''
  productionToken = ''
  strongestMetricName = ''
  strongestDelta = 0
  trendingMetricCount = 0
  metricSnapshots = .array~new
  if sampleCount = 0 then return

  latest = signatures[sampleCount]
  generationId = latest~generationId
  dayClass = latest~dayClass
  environmentCode = latest~environmentCode
  productionToken = latest~productionToken

  names = .directory~new
  do signature over signatures
    do metric over signature~metrics
      names[metric~name] = metric~name
    end
  end
  sortedNames = names~allIndexes
  sortedNames~sort

  strongestAbsolute = 0
  do metricName over sortedNames
    values = .array~new
    states = .array~new
    metricCode = .CameraAssessmentSignature~metricCode(metricName)
    do signature over signatures
      metric = signature~metric(metricName)
      if metric == .nil then iterate
      values~append(metric~quantizedZ)
      states~append(metric~state)
    end
    trendMetric = .CameraSignatureTrendMetric~new(metricName, metricCode, values, states, minimumSamples, deltaThreshold)
    metricSnapshots~append(trendMetric)
    if trendMetric~trendState \= .CameraConstant~TREND_STABLE then trendingMetricCount = trendingMetricCount + 1
    absoluteDelta = abs(trendMetric~deltaZ)
    if absoluteDelta > strongestAbsolute then do
      strongestAbsolute = absoluteDelta
      strongestMetricName = metricName
      strongestDelta = trendMetric~deltaZ
    end
  end

::method metrics
  expose metricSnapshots
  copy = .array~new
  do item over metricSnapshots
    copy~append(item)
  end
  return copy

::method metric
  expose metricSnapshots
  use arg metricName
  do item over metricSnapshots
    if item~name == metricName then return item
  end
  return .nil

::method canonicalText
  expose metricSnapshots
  lines = .array~new
  lines~append('WINDOW=' || self~spanSeconds || '|N=' || self~sampleCount || '|G=' || self~generationId || '|P=' || self~productionToken || '|D=' || self~dayClass || '|E=' || self~environmentCode || '|TM=' || self~trendingMetricCount || '|SM=' || self~strongestMetricName || '|SD=' || self~strongestDelta)
  metricLines = .array~new
  do item over metricSnapshots
    metricLines~append(item~canonicalText)
  end
  metricLines~sort
  do metricLine over metricLines
    lines~append('METRIC=' || metricLine)
  end
  return lines~makeString('L')


::class CameraSignatureTrendSnapshot public
::attribute version get
::attribute timestamp get
::attribute generationId get
::attribute dayClass get
::attribute environmentCode get
::attribute productionToken get
::attribute strongestMetricName get
::attribute strongestWindowSeconds get
::attribute strongestDelta get
::attribute trendingWindowCount get

::method init
  expose version timestamp generationId dayClass environmentCode productionToken strongestMetricName strongestWindowSeconds strongestDelta trendingWindowCount windowSnapshots
  use arg latestSignature, windows
  version = .CameraConstant~SIGNATURE_TREND_VERSION
  timestamp = latestSignature~secondOfDay
  generationId = latestSignature~generationId
  dayClass = latestSignature~dayClass
  environmentCode = latestSignature~environmentCode
  productionToken = latestSignature~productionToken
  strongestMetricName = ''
  strongestWindowSeconds = 0
  strongestDelta = 0
  trendingWindowCount = 0
  windowSnapshots = .array~new

  strongestAbsolute = 0
  do window over windows
    windowSnapshots~append(window)
    if window~trendingMetricCount > 0 then trendingWindowCount = trendingWindowCount + 1
    absoluteDelta = abs(window~strongestDelta)
    if absoluteDelta > strongestAbsolute then do
      strongestAbsolute = absoluteDelta
      strongestMetricName = window~strongestMetricName
      strongestWindowSeconds = window~spanSeconds
      strongestDelta = window~strongestDelta
    end
  end

::method windows
  expose windowSnapshots
  copy = .array~new
  do item over windowSnapshots
    copy~append(item)
  end
  return copy

::method window
  expose windowSnapshots
  use arg spanSeconds
  do item over windowSnapshots
    if item~spanSeconds = spanSeconds then return item
  end
  return .nil

::method compactText
  expose windowSnapshots
  values = .array~new
  do item over windowSnapshots
    body = item~spanSeconds || ':' || item~sampleCount || ':' || item~strongestMetricName || ':' || item~strongestDelta || ':' || item~trendingMetricCount
    values~append(body)
  end
  values~sort
  joined = ''
  do value over values
    if joined == '' then joined = value
    else joined = joined || ';' || value
  end
  return 'CST' || self~version || '|T=' || self~timestamp || '|G=' || self~generationId || '|P=' || self~productionToken || '|D=' || self~dayClass || '|E=' || self~environmentCode || '|SM=' || self~strongestMetricName || '|SW=' || self~strongestWindowSeconds || '|SD=' || self~strongestDelta || '|TW=' || self~trendingWindowCount || '|W=' || joined

::method canonicalText
  return self~compactText


::class CameraSignatureTrendModel public
::attribute minimumSamples
::attribute deltaThreshold

::method init
  expose signatures windowSpans
  use arg spans, minimumSamples, deltaThreshold
  if arg(1, 'O') then spans = .array~of(300, 900, 3600)
  if arg(2, 'O') then minimumSamples = .CameraConstant~SIGNATURE_TREND_MINIMUM_SAMPLES
  if arg(3, 'O') then deltaThreshold = .CameraConstant~SIGNATURE_TREND_DELTA_THRESHOLD
  self~minimumSamples = minimumSamples
  self~deltaThreshold = deltaThreshold
  signatures = .array~new
  windowSpans = .array~new
  do span over spans
    if span > 0 then windowSpans~append(span)
  end
  windowSpans~sort

::method clear
  expose signatures
  signatures = .array~new
  return 0

::method signatures
  expose signatures
  copy = .array~new
  do item over signatures
    copy~append(item)
  end
  return copy

::method circularAge private
  use arg nowSecond, thenSecond
  age = nowSecond - thenSecond
  if age < 0 then age = age + 86400
  return age

::method sameContext private
  use arg left, right
  if left~generationId \= right~generationId then return .false
  if left~productionToken \= right~productionToken then return .false
  if left~dayClass \= right~dayClass then return .false
  if left~environmentCode \= right~environmentCode then return .false
  return .true

::method trim private
  expose signatures windowSpans
  use arg latest
  if signatures~items = 0 then return 0
  maximumSpan = windowSpans[windowSpans~items]
  kept = .array~new
  do signature over signatures
    if \self~sameContext(signature, latest) then iterate
    age = self~circularAge(latest~secondOfDay, signature~secondOfDay)
    if age <= maximumSpan then kept~append(signature)
  end
  signatures = kept
  return signatures~items

::method observe
  expose signatures windowSpans
  use arg signature
  if signature == .nil then return .nil
  self~trim(signature)
  signatures~append(signature)

  snapshots = .array~new
  do span over windowSpans
    selected = .array~new
    do item over signatures
      if \self~sameContext(item, signature) then iterate
      age = self~circularAge(signature~secondOfDay, item~secondOfDay)
      if age <= span then selected~append(item)
    end
    snapshots~append(.CameraSignatureTrendWindowSnapshot~new(span, selected, self~minimumSamples, self~deltaThreshold))
  end
  return .CameraSignatureTrendSnapshot~new(signature, snapshots)


::class CameraSignatureTrendRegime public
::attribute id get
::attribute startSecond get
::attribute endSecond get
::attribute state get
::attribute sampleCount get
::attribute strongestMetricName get
::attribute peakAbsoluteDelta get
::attribute lastDelta get
::attribute generationId get
::attribute dayClass get
::attribute environmentCode get
::attribute productionToken get

::method init
  expose id startSecond endSecond state sampleCount strongestMetricName peakAbsoluteDelta lastDelta generationId dayClass environmentCode productionToken
  use arg idArg, trendSnapshot
  id = idArg
  startSecond = trendSnapshot~timestamp
  endSecond = -1
  state = .CameraConstant~SIGNATURE_TREND_REGIME_OPEN
  sampleCount = 0
  strongestMetricName = ''
  peakAbsoluteDelta = 0
  lastDelta = 0
  generationId = trendSnapshot~generationId
  dayClass = trendSnapshot~dayClass
  environmentCode = trendSnapshot~environmentCode
  productionToken = trendSnapshot~productionToken
  ignored = self~observe(trendSnapshot)

::method observe
  expose sampleCount strongestMetricName peakAbsoluteDelta lastDelta
  use arg trendSnapshot
  if trendSnapshot == .nil then return sampleCount
  sampleCount = sampleCount + 1
  lastDelta = trendSnapshot~strongestDelta
  absoluteDelta = abs(lastDelta)
  if absoluteDelta > peakAbsoluteDelta then do
    peakAbsoluteDelta = absoluteDelta
    strongestMetricName = trendSnapshot~strongestMetricName
  end
  return sampleCount

::method close
  expose endSecond state
  use arg timestamp
  endSecond = timestamp
  state = .CameraConstant~SIGNATURE_TREND_REGIME_CLOSED
  return endSecond

::method canonicalText
  return self~id || '|start=' || self~startSecond || '|end=' || self~endSecond || '|state=' || self~state || '|samples=' || self~sampleCount || '|metric=' || self~strongestMetricName || '|peak=' || self~peakAbsoluteDelta || '|last=' || self~lastDelta || '|generation=' || self~generationId || '|day=' || self~dayClass || '|environment=' || self~environmentCode || '|producer=' || self~productionToken


::class CameraSignatureTrendCondition public
::attribute timestamp get
::attribute generationId get
::attribute dayClass get
::attribute environmentCode get
::attribute productionToken get
::attribute phase get
::attribute shifted get
::attribute shiftedStreak get
::attribute expectedStreak get
::attribute regimeId get
::attribute strongestMetricName get
::attribute strongestDelta get
::attribute trendingWindowCount get

::method init
  expose timestamp generationId dayClass environmentCode productionToken phase shifted shiftedStreak expectedStreak regimeId strongestMetricName strongestDelta trendingWindowCount
  use arg trendSnapshot, phaseArg, shiftedArg, shiftedStreakArg, expectedStreakArg, regimeIdArg
  timestamp = trendSnapshot~timestamp
  generationId = trendSnapshot~generationId
  dayClass = trendSnapshot~dayClass
  environmentCode = trendSnapshot~environmentCode
  productionToken = trendSnapshot~productionToken
  phase = phaseArg
  shifted = shiftedArg
  shiftedStreak = shiftedStreakArg
  expectedStreak = expectedStreakArg
  regimeId = regimeIdArg
  strongestMetricName = trendSnapshot~strongestMetricName
  strongestDelta = trendSnapshot~strongestDelta
  trendingWindowCount = trendSnapshot~trendingWindowCount

::method compactText
  return 'CTC1|T=' || self~timestamp || '|G=' || self~generationId || '|I=' || self~productionToken || '|D=' || self~dayClass || '|E=' || self~environmentCode || '|P=' || self~phase || '|S=' || self~shifted || '|SS=' || self~shiftedStreak || '|ES=' || self~expectedStreak || '|R=' || self~regimeId || '|M=' || self~strongestMetricName || '|DZ=' || self~strongestDelta || '|TW=' || self~trendingWindowCount

::method canonicalText
  return self~compactText


::class CameraSignatureTrendPersistenceModel public
::attribute minimumTrendingWindows
::attribute persistenceMinimum
::attribute recoveryMinimum

::method init
  expose phase shiftedStreak expectedStreak nextRegimeNumber activeRegime completedRegimes lastContextKey
  use arg minimumTrendingWindows, persistenceMinimum, recoveryMinimum
  if arg(1, 'O') then minimumTrendingWindows = 2
  if arg(2, 'O') then persistenceMinimum = 2
  if arg(3, 'O') then recoveryMinimum = 2
  self~minimumTrendingWindows = minimumTrendingWindows
  self~persistenceMinimum = persistenceMinimum
  self~recoveryMinimum = recoveryMinimum
  phase = .CameraConstant~SIGNATURE_TREND_PHASE_STABLE
  shiftedStreak = 0
  expectedStreak = 0
  nextRegimeNumber = 1
  activeRegime = .nil
  completedRegimes = .array~new
  lastContextKey = ''

::method activeRegime
  expose activeRegime
  return activeRegime

::method completedRegimes
  expose completedRegimes
  copy = .array~new
  do item over completedRegimes
    copy~append(item)
  end
  return copy

::method contextKey private
  use arg trendSnapshot
  return trendSnapshot~generationId || '|' || trendSnapshot~productionToken || '|' || trendSnapshot~dayClass || '|' || trendSnapshot~environmentCode

::method resetContext private
  expose phase shiftedStreak expectedStreak activeRegime completedRegimes lastContextKey
  use arg trendSnapshot
  if activeRegime \== .nil then do
    closedAt = activeRegime~close(trendSnapshot~timestamp)
    completedRegimes~append(activeRegime)
    activeRegime = .nil
  end
  phase = .CameraConstant~SIGNATURE_TREND_PHASE_STABLE
  shiftedStreak = 0
  expectedStreak = 0
  lastContextKey = self~contextKey(trendSnapshot)
  return lastContextKey

::method observe
  expose phase shiftedStreak expectedStreak nextRegimeNumber activeRegime completedRegimes lastContextKey
  use arg trendSnapshot
  if trendSnapshot == .nil then return .nil
  contextKey = self~contextKey(trendSnapshot)
  if lastContextKey == '' then lastContextKey = contextKey
  else if contextKey \= lastContextKey then ignoredContext = self~resetContext(trendSnapshot)

  shifted = trendSnapshot~trendingWindowCount >= self~minimumTrendingWindows
  if shifted then do
    shiftedStreak = shiftedStreak + 1
    expectedStreak = 0
    if phase == .CameraConstant~SIGNATURE_TREND_PHASE_PERSISTENT then phase = .CameraConstant~SIGNATURE_TREND_PHASE_PERSISTENT
    else if shiftedStreak >= self~persistenceMinimum then phase = .CameraConstant~SIGNATURE_TREND_PHASE_PERSISTENT
    else phase = .CameraConstant~SIGNATURE_TREND_PHASE_EMERGING

    if phase == .CameraConstant~SIGNATURE_TREND_PHASE_PERSISTENT then do
      if activeRegime == .nil then do
        activeRegime = .CameraSignatureTrendRegime~new('CTR' || nextRegimeNumber, trendSnapshot)
        nextRegimeNumber = nextRegimeNumber + 1
      end
      else ignoredSample = activeRegime~observe(trendSnapshot)
    end
  end
  else do
    expectedStreak = expectedStreak + 1
    shiftedStreak = 0
    if phase == .CameraConstant~SIGNATURE_TREND_PHASE_PERSISTENT | phase == .CameraConstant~SIGNATURE_TREND_PHASE_RECOVERING then do
      if expectedStreak >= self~recoveryMinimum then do
        phase = .CameraConstant~SIGNATURE_TREND_PHASE_STABLE
        if activeRegime \== .nil then do
          closedAt = activeRegime~close(trendSnapshot~timestamp)
          completedRegimes~append(activeRegime)
          activeRegime = .nil
        end
      end
      else phase = .CameraConstant~SIGNATURE_TREND_PHASE_RECOVERING
    end
    else phase = .CameraConstant~SIGNATURE_TREND_PHASE_STABLE
  end

  regimeId = ''
  if activeRegime \== .nil then regimeId = activeRegime~id
  return .CameraSignatureTrendCondition~new(trendSnapshot, phase, shifted, shiftedStreak, expectedStreak, regimeId)

::class CameraAssessmentSignatureMetricDelta public
::attribute name get
::attribute code get
::attribute beforeZ get
::attribute afterZ get
::attribute deltaZ get
::attribute beforeState get
::attribute afterState get
::attribute stateChanged get

::method init
  expose name code beforeZ afterZ deltaZ beforeState afterState stateChanged
  use arg beforeMetric, afterMetric
  if beforeMetric == .nil then do
    name = afterMetric~name
    code = afterMetric~code
    beforeZ = 0
    beforeState = .CameraConstant~BASELINE_INSUFFICIENT
  end
  else do
    name = beforeMetric~name
    code = beforeMetric~code
    beforeZ = beforeMetric~quantizedZ
    beforeState = beforeMetric~state
  end
  if afterMetric == .nil then do
    afterZ = 0
    afterState = .CameraConstant~BASELINE_INSUFFICIENT
  end
  else do
    afterZ = afterMetric~quantizedZ
    afterState = afterMetric~state
  end
  deltaZ = afterZ - beforeZ
  stateChanged = beforeState \= afterState

::method canonicalText
  return self~code || ':' || self~beforeZ || '>' || self~afterZ || ':' || self~deltaZ || ':' || self~beforeState || '>' || self~afterState


::class CameraAssessmentSignatureDelta public
::attribute generationChanged get
::attribute producerChanged get
::attribute dayClassChanged get
::attribute environmentChanged get
::attribute metricCount get
::attribute changedStateCount get
::attribute maximumAbsoluteDeltaZ get
::attribute meanAbsoluteDeltaZ get
::attribute elevatedDelta get

::method init
  expose generationChanged producerChanged dayClassChanged environmentChanged metricCount changedStateCount maximumAbsoluteDeltaZ meanAbsoluteDeltaZ elevatedDelta metricDeltas beforeCompact afterCompact
  use arg beforeSignature, afterSignature
  generationChanged = beforeSignature~generationId \= afterSignature~generationId
  producerChanged = beforeSignature~productionToken \= afterSignature~productionToken
  dayClassChanged = beforeSignature~dayClass \= afterSignature~dayClass
  environmentChanged = beforeSignature~environmentCode \= afterSignature~environmentCode
  elevatedDelta = afterSignature~elevatedCount - beforeSignature~elevatedCount
  beforeCompact = beforeSignature~compactText
  afterCompact = afterSignature~compactText
  metricDeltas = .array~new
  changedStateCount = 0
  maximumAbsoluteDeltaZ = 0
  totalAbsoluteDeltaZ = 0

  names = .directory~new
  do item over beforeSignature~metrics
    names[item~name] = item~name
  end
  do item over afterSignature~metrics
    names[item~name] = item~name
  end
  sortedNames = names~allIndexes
  sortedNames~sort
  do metricName over sortedNames
    beforeMetric = beforeSignature~metric(metricName)
    afterMetric = afterSignature~metric(metricName)
    delta = .CameraAssessmentSignatureMetricDelta~new(beforeMetric, afterMetric)
    metricDeltas~append(delta)
    if delta~stateChanged then changedStateCount = changedStateCount + 1
    absoluteDelta = abs(delta~deltaZ)
    totalAbsoluteDeltaZ = totalAbsoluteDeltaZ + absoluteDelta
    if absoluteDelta > maximumAbsoluteDeltaZ then maximumAbsoluteDeltaZ = absoluteDelta
  end
  metricCount = metricDeltas~items
  if metricCount = 0 then meanAbsoluteDeltaZ = 0
  else meanAbsoluteDeltaZ = totalAbsoluteDeltaZ / metricCount

::method metrics
  expose metricDeltas
  copy = .array~new
  do item over metricDeltas
    copy~append(item)
  end
  return copy

::method metric
  expose metricDeltas
  use arg metricName
  do item over metricDeltas
    if item~name == metricName then return item
  end
  return .nil

::method compactText
  expose metricDeltas
  values = .array~new
  do item over metricDeltas
    if item~deltaZ \= 0 | item~stateChanged then values~append(item~canonicalText)
  end
  values~sort
  body = ''
  do value over values
    if body == '' then body = value
    else body = body || ';' || value
  end
  return 'CAD1|G=' || self~generationChanged || '|P=' || self~producerChanged || '|D=' || self~dayClassChanged || '|E=' || self~environmentChanged || '|SC=' || self~changedStateCount || '|MAX=' || self~maximumAbsoluteDeltaZ || '|MEAN=' || self~meanAbsoluteDeltaZ || '|ED=' || self~elevatedDelta || '|M=' || body

::method canonicalText
  return self~compactText


::class CameraAssessmentWindowEvidence public
::attribute centreSecond get
::attribute halfWidth get
::attribute applicabilityWeight get
::attribute metricSampleCount get
::attribute metricMean get
::attribute metricStandardDeviation get

::method init
  expose centreSecond halfWidth applicabilityWeight metricSampleCount metricMean metricStandardDeviation
  use arg window, secondOfDay, metricName
  centreSecond = window~centreSecond
  halfWidth = window~halfWidth
  applicabilityWeight = window~weightFor(secondOfDay)
  distribution = window~metric(metricName)
  if distribution == .nil then do
    metricSampleCount = 0
    metricMean = 0
    metricStandardDeviation = 0
  end
  else do
    metricSampleCount = distribution~sampleCount
    metricMean = distribution~mean
    metricStandardDeviation = distribution~standardDeviation
  end

::method canonicalText
  return 'centre=' || self~centreSecond || '|half=' || self~halfWidth || '|weight=' || self~applicabilityWeight || '|samples=' || self~metricSampleCount || '|mean=' || self~metricMean || '|sd=' || self~metricStandardDeviation


::class CameraAssessmentMetricEvidence public
::attribute name get
::attribute observed get
::attribute expected get
::attribute zScore get
::attribute support get
::attribute state get
::attribute baselineContext get
::attribute baselineFamily get
::attribute environmentCode get

::method init
  expose name observed expected zScore support state baselineContext baselineFamily environmentCode windowEvidence
  use arg metricAssessment, familyArg, environmentCodeArg, sourceBehaviour, secondOfDay
  name = metricAssessment~name
  observed = metricAssessment~value
  expected = metricAssessment~expected
  zScore = metricAssessment~zScore
  support = metricAssessment~support
  state = metricAssessment~state
  baselineContext = metricAssessment~baselineContext
  baselineFamily = familyArg
  if arg(3, 'O') then environmentCodeArg = ''
  environmentCode = environmentCodeArg
  windowEvidence = .array~new

  if sourceBehaviour \== .nil then do window over sourceBehaviour~windows
    weight = window~weightFor(secondOfDay)
    if weight <= 0 then iterate
    distribution = window~metric(name)
    if distribution == .nil then iterate
    if distribution~sampleCount <= 0 then iterate
    windowEvidence~append(.CameraAssessmentWindowEvidence~new(window, secondOfDay, name))
  end

::method windows
  expose windowEvidence
  copy = .array~new
  do item over windowEvidence
    copy~append(item)
  end
  return copy

::method windowCount
  expose windowEvidence
  return windowEvidence~items

::method customerText
  return self~name || '|observed=' || self~observed || '|expected=' || self~expected || '|z=' || self~zScore || '|support=' || self~support || '|state=' || self~state || '|context=' || self~baselineContext || '|family=' || self~baselineFamily || '|environment=' || self~environmentCode

::method canonicalText
  expose windowEvidence
  lines = .array~new
  lines~append('METRIC=' || self~name || '|observed=' || self~observed || '|expected=' || self~expected || '|z=' || self~zScore || '|support=' || self~support || '|state=' || self~state || '|context=' || self~baselineContext || '|family=' || self~baselineFamily || '|environment=' || self~environmentCode)
  windowLines = .array~new
  do item over windowEvidence
    windowLines~append(item~canonicalText)
  end
  windowLines~sort
  do windowLine over windowLines
    lines~append('WINDOW=' || windowLine)
  end
  return lines~makeString('L')


::class CameraAssessmentEvidence subclass AlchemyObject public
::attribute generationId get
::attribute generationVersion get
::attribute generationPublishedAt get
::attribute clipId get
::attribute secondOfDay get
::attribute dayClass get
::attribute environmentCode get
::attribute regionCount get
::attribute zoneCount get
::attribute routeCount get
::attribute primitiveCount get
::attribute episodeCount get
::attribute motifCount get
::attribute transitionCount get
::attribute tokenCount get
::attribute conditionRegimeClassCount get
::attribute eventGrammarText get

::method init
  expose generationId generationVersion generationPublishedAt clipId secondOfDay dayClass environmentCode regionCount zoneCount routeCount primitiveCount episodeCount motifCount transitionCount tokenCount conditionRegimeClassCount eventGrammarText metricEvidence
  use arg generation, summary
  generationId = generation~id
  generationVersion = generation~version
  generationPublishedAt = generation~publishedAt
  clipId = summary~clipId
  secondOfDay = summary~midpointSecond
  dayClass = summary~dayClass
  environmentCode = summary~environmentCode
  regionCount = generation~regionCount
  zoneCount = generation~zoneCount
  routeCount = generation~routeCount
  primitiveCount = generation~primitiveCount
  episodeCount = generation~episodeCount
  motifCount = generation~motifCount
  transitionCount = generation~transitionCount
  tokenCount = generation~tokenCount
  conditionRegimeClassCount = generation~conditionRegimeClassCount
  eventGrammarText = generation~eventGrammar~canonicalText
  metricEvidence = .directory~new

  meta = .directory~new
  meta["PURPOSE"] = "Generation-pinned explanatory evidence for Camera clip assessment"
  meta["PACKAGE"] = "camera_behaviour_oorexx"
  meta["PACKAGE_VERSION"] = .CameraConstant~CAMERA_PACKAGE_VERSION
  meta["AUTHORSHIP"] = "OpenAI / The Architect"
  meta["STANDARDS"] = "ALCHEMY-HOUSE-OBJECT-0.8; deterministic fixed-camera behavioural evidence"
  meta["DESIGN_LIMITATIONS"] = "Camera produces behavioural evidence and learned-world state; it does not grant operational authority or identify people."
  meta["OBJECT_KIND"] = "ASSESSMENT_EVIDENCE"
  self~init:super(meta)
  self~registerExternalRequirement("library", "alchemy_objects", "v0.8", .true)
  self~registerStateVariable("generationId", "CUSTOMER", "learned generation that supplied the assessment baseline")
  self~registerStateVariable("clipId", "CUSTOMER", "source clip identifier")
  self~registerStateVariable("secondOfDay", "CUSTOMER", "clip assessment midpoint seconds")
  self~registerStateVariable("dayClass", "CUSTOMER", "calendar context used for assessment")
  self~registerStateVariable("environmentCode", "CUSTOMER", "environment profile used for assessment")
  self~registerStateVariable("eventGrammarText", "INTERNAL", "frozen event grammar settings contributing to interpretation")
  self~registerMethodContract("CANONICALTEXT", "deterministic explanatory evidence representation", .array~new, "STRING", .false, "TRUE", "CUSTOMER", "NORMAL", "READ", "NONE")
  self~registerMethodContract("CUSTOMERTEXT", "bounded explanatory metric evidence without model-window internals", .array~new, "STRING", .false, "TRUE", "CUSTOMER", "NORMAL", "READ", "NONE")
  self~registerMethodContract("ADDMETRIC", "attach one metric evidence record", .array~of("EVIDENCE"), "NUMERIC", .false, "TRUE", "INTERNAL", "NORMAL", "MUTATE", "NONE")
  self~registerInstrumentationPoint("CAMERA.EVIDENCE.METRIC", "metric evidence attached to generation-pinned assessment evidence", .true, "ALL", "INTERNAL")
  ignoredRelationship = self~recordRelationship("EVIDENCE_FOR_GENERATION", generation, "learned generation whose frozen baselines produced this evidence", "CUSTOMER")

::method addMetric
  expose metricEvidence
  use arg evidence
  if evidence == .nil then return 0
  metricEvidence[evidence~name] = evidence
  eventEvidence = .directory~new
  eventEvidence["metric"] = evidence~name
  eventEvidence["state"] = evidence~state
  eventEvidence["support"] = evidence~support
  ignoredEvent = self~alchemyInstrument("CAMERA.EVIDENCE.METRIC", eventEvidence)
  return metricEvidence~items

::method metric
  expose metricEvidence
  use arg metricName
  if metricEvidence~hasIndex(metricName) then return metricEvidence[metricName]
  return .nil

::method metrics
  expose metricEvidence
  copy = .directory~new
  supplier = metricEvidence~supplier
  do while supplier~available
    item = supplier~item
    key = supplier~index
    supplier~next
    copy[key] = item
  end
  return copy

::method metricCount
  expose metricEvidence
  return metricEvidence~items

::method customerText
  expose metricEvidence
  lines = .array~new
  lines~append('GENERATION=' || self~generationId || '|CLIP=' || self~clipId || '|T=' || self~secondOfDay || '|DAY=' || self~dayClass || '|ENV=' || self~environmentCode)
  metricLines = .array~new
  supplier = metricEvidence~supplier
  do while supplier~available
    item = supplier~item
    supplier~next
    metricLines~append(item~customerText)
  end
  metricLines~sort
  do metricLine over metricLines
    lines~append('METRIC=' || metricLine)
  end
  return lines~makeString('L')

::method canonicalText
  expose metricEvidence
  lines = .array~new
  lines~append('GENERATION=' || self~generationId || '|schema=' || self~generationVersion || '|published=' || self~generationPublishedAt)
  lines~append('CLIP=' || self~clipId || '|second=' || self~secondOfDay || '|day=' || self~dayClass || '|environment=' || self~environmentCode)
  lines~append('WORLD=regions:' || self~regionCount || '|zones:' || self~zoneCount || '|routes:' || self~routeCount || '|primitives:' || self~primitiveCount || '|episodes:' || self~episodeCount || '|motifs:' || self~motifCount || '|transitions:' || self~transitionCount || '|tokens:' || self~tokenCount || '|conditionClasses:' || self~conditionRegimeClassCount)
  lines~append('EVENT_GRAMMAR=' || self~eventGrammarText)

  metricLines = .array~new
  supplier = metricEvidence~supplier
  do while supplier~available
    item = supplier~item
    supplier~next
    metricLines~append(item~canonicalText)
  end
  metricLines~sort
  do metricLine over metricLines
    do line over metricLine~makeArray
      lines~append(line)
    end
  end
  return lines~makeString('L')


::class CameraGenerationClipComparator public
::method assess class
  use arg generation, summary, minimumSupport, elevatedZ
  if generation == .nil then return .nil
  if summary == .nil then return .nil
  if arg(3, 'O') then minimumSupport = 3
  if arg(4, 'O') then elevatedZ = 2.5

  secondOfDay = summary~midpointSecond
  assessment = .CameraClipAssessment~new(summary~clipId, secondOfDay, summary~dayClass, generation~id)
  assessment~evidence = .CameraAssessmentEvidence~new(generation, summary)
  assessment~averageEventDescriptionBits = summary~averageEventDescriptionBits
  assessment~averageRouteDescriptionBits = summary~averageRouteDescriptionBits
  assessment~averageEpisodeDescriptionBits = summary~averageEpisodeDescriptionBits
  assessment~averageMotifDescriptionBits = summary~averageMotifDescriptionBits
  assessment~averageTransitionDescriptionBits = summary~averageTransitionDescriptionBits

  metricAssessment = self~addMetricAssessment(generation, assessment, secondOfDay, summary~dayClass, 'TRACK_RATE', summary~trackRatePerMinute, minimumSupport, elevatedZ)
  metricAssessment = self~addMetricAssessment(generation, assessment, secondOfDay, summary~dayClass, 'EVENT_RATE', summary~eventRatePerMinute, minimumSupport, elevatedZ)
  metricAssessment = self~addMetricAssessment(generation, assessment, secondOfDay, summary~dayClass, 'MOVER_OBS_RATE', summary~moverObservationRatePerMinute, minimumSupport, elevatedZ)
  metricAssessment = self~addMetricAssessment(generation, assessment, secondOfDay, summary~dayClass, 'INTERACTION_RATE', summary~interactionRatePerMinute, minimumSupport, elevatedZ)
  metricAssessment = self~addMetricAssessment(generation, assessment, secondOfDay, summary~dayClass, 'EPISODE_RATE', summary~episodeRatePerMinute, minimumSupport, elevatedZ)
  metricAssessment = self~addMetricAssessment(generation, assessment, secondOfDay, summary~dayClass, 'MOTIF_RATE', summary~motifRatePerMinute, minimumSupport, elevatedZ)
  metricAssessment = self~addMetricAssessment(generation, assessment, secondOfDay, summary~dayClass, 'TRANSITION_RATE', summary~transitionRatePerMinute, minimumSupport, elevatedZ)
  metricAssessment = self~addMetricAssessment(generation, assessment, secondOfDay, summary~dayClass, 'DEVIATION_RATE', summary~deviationRatePerMinute, minimumSupport, elevatedZ)
  metricAssessment = self~addMetricAssessment(generation, assessment, secondOfDay, summary~dayClass, 'STOP_RATE', summary~stopRatePerMinute, minimumSupport, elevatedZ)
  metricAssessment = self~addEnvironmentMetricAssessment(generation, assessment, summary~environmentCode, 'PHOTOMETRIC_RATE', summary~photometricRatePerMinute, minimumSupport, elevatedZ)
  metricAssessment = self~addMetricAssessment(generation, assessment, secondOfDay, summary~dayClass, 'DIR_DOWN_SHARE', summary~directionShare(.CameraConstant~DIRECTION_DOWN), minimumSupport, elevatedZ)
  metricAssessment = self~addMetricAssessment(generation, assessment, secondOfDay, summary~dayClass, 'DIR_UP_SHARE', summary~directionShare(.CameraConstant~DIRECTION_UP), minimumSupport, elevatedZ)
  metricAssessment = self~addMetricAssessment(generation, assessment, secondOfDay, summary~dayClass, 'DIR_LEFT_SHARE', summary~directionShare(.CameraConstant~DIRECTION_LEFT), minimumSupport, elevatedZ)
  metricAssessment = self~addMetricAssessment(generation, assessment, secondOfDay, summary~dayClass, 'DIR_RIGHT_SHARE', summary~directionShare(.CameraConstant~DIRECTION_RIGHT), minimumSupport, elevatedZ)
  return assessment

::method addMetricAssessment class private
  use arg generation, assessment, secondOfDay, dayClass, metricName, value, minimumSupport, elevatedZ
  sourceBehaviour = generation~behaviourModel
  distribution = sourceBehaviour~metricEstimate(secondOfDay, metricName)
  baselineContext = 'ALL'
  baselineFamily = 'ALL'
  support = distribution~sampleCount

  if dayClass \= .CameraConstant~DAY_UNKNOWN then do
    contextualSupport = generation~calendarBehaviour~contextSampleCount(dayClass)
    if contextualSupport >= minimumSupport then do
      contextualDistribution = generation~calendarBehaviour~metricEstimate(dayClass, secondOfDay, metricName)
      if contextualDistribution~sampleCount > 0 then do
        context = generation~calendarBehaviour~context(dayClass)
        distribution = contextualDistribution
        sourceBehaviour = context~behaviourModel
        support = contextualSupport
        baselineContext = 'DAY:' || dayClass
        baselineFamily = 'DAY'
      end
    end
  end

  expected = distribution~mean
  zScore = 0
  state = .CameraConstant~BASELINE_INSUFFICIENT
  if support >= minimumSupport then do
    zScore = distribution~zScore(value)
    state = .CameraConstant~BASELINE_WITHIN
    if abs(zScore) >= elevatedZ then state = .CameraConstant~BASELINE_ELEVATED
  end

  metricAssessment = .CameraMetricAssessment~new(metricName, value, expected, zScore, support, state, baselineContext)
  assessment~addMetric(metricAssessment)
  if assessment~evidence \== .nil then do
    metricEvidence = .CameraAssessmentMetricEvidence~new(metricAssessment, baselineFamily, '', sourceBehaviour, secondOfDay)
    assessment~evidence~addMetric(metricEvidence)
  end
  return metricAssessment

::method addEnvironmentMetricAssessment class private
  use arg generation, assessment, environmentCode, metricName, value, minimumSupport, elevatedZ
  distribution = generation~environmentModel~metricEstimate(environmentCode, metricName)
  support = distribution~sampleCount
  expected = distribution~mean
  zScore = 0
  state = .CameraConstant~BASELINE_INSUFFICIENT
  if support >= minimumSupport then do
    zScore = distribution~zScore(value)
    state = .CameraConstant~BASELINE_WITHIN
    if abs(zScore) >= elevatedZ then state = .CameraConstant~BASELINE_ELEVATED
  end
  metricAssessment = .CameraMetricAssessment~new(metricName, value, expected, zScore, support, state, 'ENV:' || environmentCode)
  assessment~addMetric(metricAssessment)
  if assessment~evidence \== .nil then do
    metricEvidence = .CameraAssessmentMetricEvidence~new(metricAssessment, 'ENV', environmentCode, .nil, assessment~secondOfDay)
    assessment~evidence~addMetric(metricEvidence)
  end
  return metricAssessment


::class CameraClipComparator public
::method assess class
  use arg camera, summary, minimumSupport, elevatedZ
  if camera == .nil then return .nil
  if summary == .nil then return .nil
  if arg(3, 'O') then minimumSupport = 3
  if arg(4, 'O') then elevatedZ = 2.5

  secondOfDay = summary~midpointSecond
  assessment = .CameraClipAssessment~new(summary~clipId, secondOfDay, summary~dayClass)
  assessment~averageEventDescriptionBits = summary~averageEventDescriptionBits
  assessment~averageRouteDescriptionBits = summary~averageRouteDescriptionBits
  motifBitsTotal = 0
  motifOccurrences = summary~motifOccurrences
  motifVocabulary = camera~motifModel~motifCount + 1
  do motifOccurrence over motifOccurrences
    motifBitsTotal = motifBitsTotal + camera~calendarBehaviour~motifDescriptionBits(summary~dayClass, camera~behaviour, motifOccurrence~timestamp, motifOccurrence~motifId, motifVocabulary, minimumSupport)
  end
  if motifOccurrences~items > 0 then assessment~averageMotifDescriptionBits = motifBitsTotal / motifOccurrences~items
  transitionBitsTotal = 0
  transitionOccurrences = summary~transitionOccurrences
  transitionVocabulary = camera~transitionModel~transitionCount + 1
  do transitionOccurrence over transitionOccurrences
    transitionBits = camera~calendarBehaviour~transitionDescriptionBits(summary~dayClass, camera~behaviour, transitionOccurrence~timestamp, transitionOccurrence~transitionId, transitionVocabulary, minimumSupport)
    transitionOccurrence~descriptionBits = transitionBits
    transitionBitsTotal = transitionBitsTotal + transitionBits
  end
  if transitionOccurrences~items > 0 then assessment~averageTransitionDescriptionBits = transitionBitsTotal / transitionOccurrences~items
  episodeBitsTotal = 0
  episodeOccurrences = summary~episodeOccurrences
  episodeVocabulary = camera~episodeModel~episodeCount + 1
  do episodeOccurrence over episodeOccurrences
    episodeBitsTotal = episodeBitsTotal + camera~calendarBehaviour~episodeDescriptionBits(summary~dayClass, camera~behaviour, episodeOccurrence~timestamp, episodeOccurrence~episodeId, episodeVocabulary, minimumSupport)
  end
  if episodeOccurrences~items > 0 then assessment~averageEpisodeDescriptionBits = episodeBitsTotal / episodeOccurrences~items

  metricAssessment = self~addMetricAssessment(camera, assessment, secondOfDay, summary~dayClass, 'TRACK_RATE', summary~trackRatePerMinute, minimumSupport, elevatedZ)
  metricAssessment = self~addMetricAssessment(camera, assessment, secondOfDay, summary~dayClass, 'EVENT_RATE', summary~eventRatePerMinute, minimumSupport, elevatedZ)
  metricAssessment = self~addMetricAssessment(camera, assessment, secondOfDay, summary~dayClass, 'MOVER_OBS_RATE', summary~moverObservationRatePerMinute, minimumSupport, elevatedZ)
  metricAssessment = self~addMetricAssessment(camera, assessment, secondOfDay, summary~dayClass, 'INTERACTION_RATE', summary~interactionRatePerMinute, minimumSupport, elevatedZ)
  metricAssessment = self~addMetricAssessment(camera, assessment, secondOfDay, summary~dayClass, 'EPISODE_RATE', summary~episodeRatePerMinute, minimumSupport, elevatedZ)
  metricAssessment = self~addMetricAssessment(camera, assessment, secondOfDay, summary~dayClass, 'MOTIF_RATE', summary~motifRatePerMinute, minimumSupport, elevatedZ)
  metricAssessment = self~addMetricAssessment(camera, assessment, secondOfDay, summary~dayClass, 'TRANSITION_RATE', summary~transitionRatePerMinute, minimumSupport, elevatedZ)
  metricAssessment = self~addMetricAssessment(camera, assessment, secondOfDay, summary~dayClass, 'DEVIATION_RATE', summary~deviationRatePerMinute, minimumSupport, elevatedZ)
  metricAssessment = self~addMetricAssessment(camera, assessment, secondOfDay, summary~dayClass, 'STOP_RATE', summary~stopRatePerMinute, minimumSupport, elevatedZ)
  metricAssessment = self~addEnvironmentMetricAssessment(camera, assessment, summary~environmentCode, 'PHOTOMETRIC_RATE', summary~photometricRatePerMinute, minimumSupport, elevatedZ)
  metricAssessment = self~addMetricAssessment(camera, assessment, secondOfDay, summary~dayClass, 'DIR_DOWN_SHARE', summary~directionShare(.CameraConstant~DIRECTION_DOWN), minimumSupport, elevatedZ)
  metricAssessment = self~addMetricAssessment(camera, assessment, secondOfDay, summary~dayClass, 'DIR_UP_SHARE', summary~directionShare(.CameraConstant~DIRECTION_UP), minimumSupport, elevatedZ)
  metricAssessment = self~addMetricAssessment(camera, assessment, secondOfDay, summary~dayClass, 'DIR_LEFT_SHARE', summary~directionShare(.CameraConstant~DIRECTION_LEFT), minimumSupport, elevatedZ)
  metricAssessment = self~addMetricAssessment(camera, assessment, secondOfDay, summary~dayClass, 'DIR_RIGHT_SHARE', summary~directionShare(.CameraConstant~DIRECTION_RIGHT), minimumSupport, elevatedZ)
  return assessment

::method addMetricAssessment class private
  use arg camera, assessment, secondOfDay, dayClass, metricName, value, minimumSupport, elevatedZ
  distribution = camera~behaviour~metricEstimate(secondOfDay, metricName)
  baselineContext = 'ALL'
  if dayClass \= .CameraConstant~DAY_UNKNOWN then do
    contextualDistribution = camera~calendarBehaviour~metricEstimate(dayClass, camera~behaviour, secondOfDay, metricName)
    contextualSupport = camera~calendarBehaviour~contextSampleCount(dayClass)
    if contextualSupport >= minimumSupport then do
      distribution = contextualDistribution
      baselineContext = 'DAY:' || dayClass
    end
  end
  support = distribution~sampleCount
  if baselineContext \= 'ALL' then support = camera~calendarBehaviour~contextSampleCount(dayClass)
  expected = distribution~mean
  zScore = 0
  state = .CameraConstant~BASELINE_INSUFFICIENT
  if support >= minimumSupport then do
    zScore = distribution~zScore(value)
    state = .CameraConstant~BASELINE_WITHIN
    if abs(zScore) >= elevatedZ then state = .CameraConstant~BASELINE_ELEVATED
  end
  metricAssessment = .CameraMetricAssessment~new(metricName, value, expected, zScore, support, state, baselineContext)
  assessment~addMetric(metricAssessment)
  return metricAssessment

::method addEnvironmentMetricAssessment class private
  use arg camera, assessment, environmentCode, metricName, value, minimumSupport, elevatedZ
  distribution = camera~environmentModel~metricEstimate(environmentCode, metricName)
  support = distribution~sampleCount
  expected = distribution~mean
  zScore = 0
  state = .CameraConstant~BASELINE_INSUFFICIENT
  if support >= minimumSupport then do
    zScore = distribution~zScore(value)
    state = .CameraConstant~BASELINE_WITHIN
    if abs(zScore) >= elevatedZ then state = .CameraConstant~BASELINE_ELEVATED
  end
  metricAssessment = .CameraMetricAssessment~new(metricName, value, expected, zScore, support, state)
  assessment~addMetric(metricAssessment)
  return metricAssessment

::method learnSummary class
  use arg camera, summary
  if camera == .nil then return 0
  if summary == .nil then return 0
  secondOfDay = summary~midpointSecond
  camera~behaviour~observeMetric(secondOfDay, 'TRACK_RATE', summary~trackRatePerMinute)
  if summary~dayClass \= .CameraConstant~DAY_UNKNOWN then camera~calendarBehaviour~observeMetric(summary~dayClass, camera~behaviour, secondOfDay, 'TRACK_RATE', summary~trackRatePerMinute)
  camera~behaviour~observeMetric(secondOfDay, 'EVENT_RATE', summary~eventRatePerMinute)
  if summary~dayClass \= .CameraConstant~DAY_UNKNOWN then camera~calendarBehaviour~observeMetric(summary~dayClass, camera~behaviour, secondOfDay, 'EVENT_RATE', summary~eventRatePerMinute)
  camera~behaviour~observeMetric(secondOfDay, 'MOVER_OBS_RATE', summary~moverObservationRatePerMinute)
  if summary~dayClass \= .CameraConstant~DAY_UNKNOWN then camera~calendarBehaviour~observeMetric(summary~dayClass, camera~behaviour, secondOfDay, 'MOVER_OBS_RATE', summary~moverObservationRatePerMinute)
  camera~behaviour~observeMetric(secondOfDay, 'INTERACTION_RATE', summary~interactionRatePerMinute)
  if summary~dayClass \= .CameraConstant~DAY_UNKNOWN then camera~calendarBehaviour~observeMetric(summary~dayClass, camera~behaviour, secondOfDay, 'INTERACTION_RATE', summary~interactionRatePerMinute)
  camera~behaviour~observeMetric(secondOfDay, 'EPISODE_RATE', summary~episodeRatePerMinute)
  camera~behaviour~observeMetric(secondOfDay, 'MOTIF_RATE', summary~motifRatePerMinute)
  camera~behaviour~observeMetric(secondOfDay, 'TRANSITION_RATE', summary~transitionRatePerMinute)
  if summary~dayClass \= .CameraConstant~DAY_UNKNOWN then camera~calendarBehaviour~observeMetric(summary~dayClass, camera~behaviour, secondOfDay, 'EPISODE_RATE', summary~episodeRatePerMinute)
  if summary~dayClass \= .CameraConstant~DAY_UNKNOWN then camera~calendarBehaviour~observeMetric(summary~dayClass, camera~behaviour, secondOfDay, 'MOTIF_RATE', summary~motifRatePerMinute)
  if summary~dayClass \= .CameraConstant~DAY_UNKNOWN then camera~calendarBehaviour~observeMetric(summary~dayClass, camera~behaviour, secondOfDay, 'TRANSITION_RATE', summary~transitionRatePerMinute)
  do episodeOccurrence over summary~episodeOccurrences
    /* Global episode timing is already learned by CameraModel for real tracks; the
       calendar context is learned here where the clip day class is known. */
    if summary~dayClass \= .CameraConstant~DAY_UNKNOWN then camera~calendarBehaviour~observeEpisode(summary~dayClass, camera~behaviour, episodeOccurrence~timestamp, episodeOccurrence~episodeId)
  end
  do motifOccurrence over summary~motifOccurrences
    camera~behaviour~observeMotif(motifOccurrence~timestamp, motifOccurrence~motifId)
    if summary~dayClass \= .CameraConstant~DAY_UNKNOWN then camera~calendarBehaviour~observeMotif(summary~dayClass, camera~behaviour, motifOccurrence~timestamp, motifOccurrence~motifId)
  end
  do transitionOccurrence over summary~transitionOccurrences
    camera~behaviour~observeTransition(transitionOccurrence~timestamp, transitionOccurrence~transitionId)
    if summary~dayClass \= .CameraConstant~DAY_UNKNOWN then camera~calendarBehaviour~observeTransition(summary~dayClass, camera~behaviour, transitionOccurrence~timestamp, transitionOccurrence~transitionId)
  end
  camera~behaviour~observeMetric(secondOfDay, 'DEVIATION_RATE', summary~deviationRatePerMinute)
  if summary~dayClass \= .CameraConstant~DAY_UNKNOWN then camera~calendarBehaviour~observeMetric(summary~dayClass, camera~behaviour, secondOfDay, 'DEVIATION_RATE', summary~deviationRatePerMinute)
  camera~behaviour~observeMetric(secondOfDay, 'STOP_RATE', summary~stopRatePerMinute)
  if summary~dayClass \= .CameraConstant~DAY_UNKNOWN then camera~calendarBehaviour~observeMetric(summary~dayClass, camera~behaviour, secondOfDay, 'STOP_RATE', summary~stopRatePerMinute)
  camera~environmentModel~observeMetric(summary~environmentCode, 'PHOTOMETRIC_RATE', summary~photometricRatePerMinute)
  camera~behaviour~observeMetric(secondOfDay, 'DIR_DOWN_SHARE', summary~directionShare(.CameraConstant~DIRECTION_DOWN))
  if summary~dayClass \= .CameraConstant~DAY_UNKNOWN then camera~calendarBehaviour~observeMetric(summary~dayClass, camera~behaviour, secondOfDay, 'DIR_DOWN_SHARE', summary~directionShare(.CameraConstant~DIRECTION_DOWN))
  camera~behaviour~observeMetric(secondOfDay, 'DIR_UP_SHARE', summary~directionShare(.CameraConstant~DIRECTION_UP))
  if summary~dayClass \= .CameraConstant~DAY_UNKNOWN then camera~calendarBehaviour~observeMetric(summary~dayClass, camera~behaviour, secondOfDay, 'DIR_UP_SHARE', summary~directionShare(.CameraConstant~DIRECTION_UP))
  camera~behaviour~observeMetric(secondOfDay, 'DIR_LEFT_SHARE', summary~directionShare(.CameraConstant~DIRECTION_LEFT))
  if summary~dayClass \= .CameraConstant~DAY_UNKNOWN then camera~calendarBehaviour~observeMetric(summary~dayClass, camera~behaviour, secondOfDay, 'DIR_LEFT_SHARE', summary~directionShare(.CameraConstant~DIRECTION_LEFT))
  camera~behaviour~observeMetric(secondOfDay, 'DIR_RIGHT_SHARE', summary~directionShare(.CameraConstant~DIRECTION_RIGHT))
  if summary~dayClass \= .CameraConstant~DAY_UNKNOWN then camera~calendarBehaviour~observeMetric(summary~dayClass, camera~behaviour, secondOfDay, 'DIR_RIGHT_SHARE', summary~directionShare(.CameraConstant~DIRECTION_RIGHT))
  if summary~dayClass \= .CameraConstant~DAY_UNKNOWN then camera~calendarBehaviour~observeSummary(summary~dayClass)
  return 1

::method assessAndLearn class
  use arg camera, summary, minimumSupport, elevatedZ
  if arg(3, 'O') then minimumSupport = 3
  if arg(4, 'O') then elevatedZ = 2.5
  assessment = self~assess(camera, summary, minimumSupport, elevatedZ)
  self~learnSummary(camera, summary)
  return assessment


::class CameraImportedFrame public
::attribute timestamp

::method init
  expose observations
  use arg timestamp
  self~timestamp = timestamp
  observations = .array~new

::method observations
  expose observations
  return observations

::method addObservation
  expose observations
  use arg observation
  if observation == .nil then return observations~items
  observations~append(observation)
  return observations~items


::class CameraImportedClip public
::attribute clipId
::attribute startSecond
::attribute durationSeconds
::attribute environmentCode
::attribute dayClass
::attribute environmentSignature

::method init
  expose frames
  use arg clipId, startSecond, durationSeconds, environmentCode, dayClass
  if arg(1, 'O') then clipId = ''
  if arg(2, 'O') then startSecond = 0
  if arg(3, 'O') then durationSeconds = 0
  if arg(4, 'O') then environmentCode = .CameraConstant~ENV_UNKNOWN
  if arg(5, 'O') then dayClass = .CameraConstant~DAY_UNKNOWN
  self~clipId = clipId
  self~startSecond = startSecond
  self~durationSeconds = durationSeconds
  self~environmentCode = environmentCode
  self~dayClass = dayClass
  self~environmentSignature = .nil
  frames = .array~new

::method frames
  expose frames
  return frames

::method addFrame
  expose frames
  use arg importedFrame
  if importedFrame == .nil then return frames~items
  frames~append(importedFrame)
  return frames~items

::method frameCount
  expose frames
  return frames~items


::class CameraMeasurementImporter public
::method load class
  use arg path
  if path = '' then return .nil
  if stream(path, 'c', 'query exists') = '' then return .nil

  importedClip = .nil
  currentFrame = .nil
  do while lines(path) > 0
    measurementLine = linein(path)
    if measurementLine = '' then iterate
    parse var measurementLine recordType '|' rest
    select
      when recordType = 'CLIP' then do
        parse var rest clipId '|' startSecond '|' durationSeconds '|' environmentCode '|' dayClass
        if dayClass = '' then dayClass = .CameraConstant~DAY_UNKNOWN
        importedClip = .CameraImportedClip~new(clipId, startSecond, durationSeconds, environmentCode, dayClass)
      end
      when recordType = 'ENV' then do
        if importedClip == .nil then iterate
        parse var rest globalLuma '|' localContrast '|' shadowFraction '|' brightFraction '|' structuralNoise
        importedClip~environmentSignature = .CameraEnvironmentSignature~new(globalLuma, localContrast, shadowFraction, brightFraction, structuralNoise)
      end
      when recordType = 'FRAME' then do
        if importedClip == .nil then iterate
        parse var rest frameTimestamp
        currentFrame = .CameraImportedFrame~new(frameTimestamp)
        importedClip~addFrame(currentFrame)
      end
      when recordType = 'OBS' then do
        if importedClip == .nil then iterate
        parse var rest observationTimestamp '|' x '|' y '|' width '|' height '|' luminanceDelta '|' structureDelta
        if currentFrame == .nil then do
          currentFrame = .CameraImportedFrame~new(observationTimestamp)
          importedClip~addFrame(currentFrame)
        end
        if currentFrame~timestamp \= observationTimestamp then do
          currentFrame = .CameraImportedFrame~new(observationTimestamp)
          importedClip~addFrame(currentFrame)
        end
        boxId = 'OBS-' || importedClip~frameCount || '-' || (currentFrame~observations~items + 1)
        observationBox = .CameraBox~new(boxId, x, y, width, height)
        observation = .CameraObservation~new(observationTimestamp, observationBox, luminanceDelta, structureDelta)
        currentFrame~addObservation(observation)
      end
      otherwise nop
    end
  end
  call stream path, 'c', 'close'
  return importedClip


::class CameraClipProcessor public
::method process class
  use arg camera, importedClip
  if camera == .nil then return .nil
  if importedClip == .nil then return .nil

  effectiveEnvironment = importedClip~environmentCode
  if effectiveEnvironment = .CameraConstant~ENV_UNKNOWN then do
    inference = camera~environmentModel~infer(importedClip~environmentSignature, importedClip~startSecond)
    effectiveEnvironment = inference~code
    camera~environment~inferenceConfidence = inference~confidence
    camera~environment~inferenceMethod = inference~method
  end
  else do
    camera~environment~inferenceConfidence = 1
    camera~environment~inferenceMethod = .CameraConstant~ENV_INFERENCE_PROFILE
  end

  summary = .CameraClipSummary~new(importedClip~clipId, importedClip~startSecond, importedClip~durationSeconds, effectiveEnvironment, importedClip~dayClass)
  camera~environment~code = effectiveEnvironment
  camera~environment~timestamp = importedClip~startSecond
  if importedClip~environmentSignature \== .nil then do
    camera~environment~globalLuma = importedClip~environmentSignature~globalLuma
    camera~environment~localContrast = importedClip~environmentSignature~localContrast
    if importedClip~environmentCode \= .CameraConstant~ENV_UNKNOWN then camera~environmentModel~observeSignature(effectiveEnvironment, importedClip~environmentSignature)
  end
  eventStart = camera~eventGrammar~eventCount + 1
  clipTrackIds = .set~new
  clipTracks = .array~new
  lastTimestamp = importedClip~startSecond

  do importedFrame over importedClip~frames
    lastTimestamp = importedFrame~timestamp
    frameResult = camera~observeFrame(importedFrame~timestamp, importedFrame~observations)
    summary~addFrameResult(frameResult)
    do assignedTrack over frameResult~assignments
      clipTrackIds[assignedTrack~id] = assignedTrack~id
    end
  end

  /* Force session-local open tracks through their normal missed-frame lifecycle. */
  flushCount = camera~associator~maxMissedFrames + 1
  do flushIndex = 1 to flushCount
    flushTimestamp = lastTimestamp + flushIndex
    do while flushTimestamp >= 86400
      flushTimestamp = flushTimestamp - 86400
    end
    camera~observeFrame(flushTimestamp, .array~new)
  end

  trackSupplier = camera~tracks~supplier
  do while trackSupplier~available
    clipTrack = trackSupplier~item
    trackSupplier~next
    if clipTrackIds~hasIndex(clipTrack~id) then do
      summary~addTrack(clipTrack)
      clipTracks~append(clipTrack)
    end
  end

  eventFinish = camera~eventGrammar~eventCount
  if eventFinish >= eventStart then do eventIndex = eventStart to eventFinish
    summary~addEvent(camera~eventGrammar~events[eventIndex])
  end
  motifEncodings = camera~motifModel~recogniseAndLearnSummary(summary)
  transitionOccurrences = camera~transitionModel~recogniseAndLearnSummary(summary)
  camera~currentConditionModel~observeSummary(summary)
  summary~peerOutliers = .CameraPeerOutlierModel~assessTracks(clipTracks)
  summary~currentAssessment = .CameraClipComparator~assess(camera, summary, 3, 2.5)
  camera~currentConditionModel~observeAssessment(summary~currentAssessment, summary~midpointSecond)
  summary~currentCondition = camera~currentConditionModel~currentCondition(camera, summary~dayClass, summary~midpointSecond, 3)
  summary~buildEventStream(camera)
  return summary


::requires "AlchemyObject.cls"
