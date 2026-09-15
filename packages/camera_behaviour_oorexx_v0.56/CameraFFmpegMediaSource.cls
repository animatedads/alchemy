/* Camera FFmpeg media source through ooRexx Foreign Runtime v0.17.1. */

::class CameraFFmpegMediaInspection public
::attribute sourcePath get
::attribute avformatVersion get
::attribute avformatVersionText get
::attribute streamInfoStatus get
::attribute videoStreamIndex get
::attribute audioStreamIndex get
::attribute hasVideo get
::attribute hasAudio get

::method init
  expose sourcePath avformatVersion avformatVersionText streamInfoStatus videoStreamIndex audioStreamIndex hasVideo hasAudio
  use arg path,version,status,videoIndex,audioIndex
  sourcePath = path
  avformatVersion = version
  major = version % 65536
  minor = (version % 256) // 256
  micro = version // 256
  avformatVersionText = major || '.' || minor || '.' || micro
  streamInfoStatus = status
  videoStreamIndex = videoIndex
  audioStreamIndex = audioIndex
  hasVideo = videoIndex >= 0
  hasAudio = audioIndex >= 0

::method compactText
  return 'CFI1|V=' || self~avformatVersionText || '|SI=' || self~streamInfoStatus || '|VI=' || self~videoStreamIndex || '|AI=' || self~audioStreamIndex

::method canonicalText
  return 'SOURCE=' || self~sourcePath || '|' || self~compactText


::class CameraFFmpegPacketInspection public
::attribute sourcePath get
::attribute packetCount get
::attribute endStatus get
::attribute limited get
::attribute avcodecVersion get
::attribute avcodecVersionText get

::method init
  expose sourcePath packetCount endStatus limited avcodecVersion avcodecVersionText
  use arg path,count,status,wasLimited,codecVersion
  sourcePath = path
  packetCount = count
  endStatus = status
  limited = wasLimited
  avcodecVersion = codecVersion
  major = codecVersion % 65536
  minor = (codecVersion % 256) // 256
  micro = codecVersion // 256
  avcodecVersionText = major || '.' || minor || '.' || micro

::method compactText
  return 'CFP1|V=' || self~avcodecVersionText || '|N=' || self~packetCount || '|END=' || self~endStatus || '|L=' || self~limited

::method canonicalText
  return 'SOURCE=' || self~sourcePath || '|' || self~compactText


::class CameraFFmpegDecodeInspection public
::attribute sourcePath get
::attribute packetCount get
::attribute videoPacketCount get
::attribute frameCount get
::attribute endStatus get
::attribute limited get
::attribute width get
::attribute height get
::attribute pixelFormat get
::attribute lumaLineSize get
::attribute firstLumaPrefixHex get
::attribute avcodecVersion get
::attribute avcodecVersionText get
::attribute avutilVersion get
::attribute avutilVersionText get

::method init
  expose sourcePath packetCount videoPacketCount frameCount endStatus limited width height pixelFormat lumaLineSize firstLumaPrefixHex avcodecVersion avcodecVersionText avutilVersion avutilVersionText
  use arg path,packets,videoPackets,frames,status,wasLimited,w,h,pixelFmt,lineSize,lumaPrefix,codecVersion,utilVersion
  sourcePath = path
  packetCount = packets
  videoPacketCount = videoPackets
  frameCount = frames
  endStatus = status
  limited = wasLimited
  width = w
  height = h
  pixelFormat = pixelFmt
  lumaLineSize = lineSize
  firstLumaPrefixHex = lumaPrefix
  avcodecVersion = codecVersion
  avutilVersion = utilVersion
  major = codecVersion % 65536
  minor = (codecVersion % 256) // 256
  micro = codecVersion // 256
  avcodecVersionText = major || '.' || minor || '.' || micro
  major = utilVersion % 65536
  minor = (utilVersion % 256) // 256
  micro = utilVersion // 256
  avutilVersionText = major || '.' || minor || '.' || micro

::method compactText
  return 'CFD1|CV=' || self~avcodecVersionText || '|UV=' || self~avutilVersionText || '|P=' || self~packetCount || '|VP=' || self~videoPacketCount || '|F=' || self~frameCount || '|W=' || self~width || '|H=' || self~height || '|PF=' || self~pixelFormat || '|LS=' || self~lumaLineSize || '|Y=' || self~firstLumaPrefixHex || '|END=' || self~endStatus || '|L=' || self~limited

::method canonicalText
  return 'SOURCE=' || self~sourcePath || '|' || self~compactText


::class CameraLumaActivityCell public
::attribute column get
::attribute row get
::attribute changeCount get
::attribute maximumDelta get

::method init
  expose column row changeCount maximumDelta
  use arg col,rowIndex
  column = col
  row = rowIndex
  changeCount = 0
  maximumDelta = 0

::method observeDelta
  expose changeCount maximumDelta
  use arg delta,threshold
  if delta >= threshold then changeCount = changeCount + 1
  if delta > maximumDelta then maximumDelta = delta
  return changeCount

::method active
  return self~changeCount > 0

::method compactText
  return self~column || ',' || self~row || ':' || self~changeCount || ':' || self~maximumDelta


::class CameraLumaActivityMap public
::attribute sourcePath get
::attribute gridColumns get
::attribute gridRows get
::attribute sampledFrames get
::attribute comparisonCount get
::attribute activeCellCount get
::attribute invariantCellCount get
::attribute invariantShare get
::attribute changedObservationCount get
::attribute sampleEveryFrames get
::attribute threshold get
::attribute temporalTracks get

::method init
  expose sourcePath gridColumns gridRows sampledFrames comparisonCount activeCellCount invariantCellCount invariantShare changedObservationCount sampleEveryFrames threshold cells temporalTracks comparisonDeltas
  use arg path,columns,rows,sampleEvery,changeThreshold
  sourcePath = path
  gridColumns = columns
  gridRows = rows
  sampleEveryFrames = sampleEvery
  threshold = changeThreshold
  sampledFrames = 0
  comparisonCount = 0
  activeCellCount = 0
  invariantCellCount = columns * rows
  invariantShare = 1
  changedObservationCount = 0
  cells = .array~new
  temporalTracks = .CameraLumaTemporalTrackSet~new(path,columns,rows,2.5)
  comparisonDeltas = .array~new
  do r = 1 to rows
    do c = 1 to columns
      cells~append(.CameraLumaActivityCell~new(c,r))
    end
  end

::method cell
  expose cells gridColumns
  use arg column,row
  index = ((row - 1) * gridColumns) + column
  if index < 1 | index > cells~items then return .nil
  return cells[index]

::method observeFrameSamples
  expose sampledFrames comparisonCount activeCellCount invariantCellCount invariantShare changedObservationCount cells temporalTracks comparisonDeltas
  use arg previousSamples,currentSamples
  sampledFrames = sampledFrames + 1
  if previousSamples == .nil then return 0
  comparisonCount = comparisonCount + 1

  previousMean = 0
  currentMean = 0
  do i = 1 to cells~items
    previousMean = previousMean + previousSamples[i]
    currentMean = currentMean + currentSamples[i]
  end
  if cells~items > 0 then do
    previousMean = previousMean / cells~items
    currentMean = currentMean / cells~items
  end

  deltas = .array~new
  do i = 1 to cells~items
    previousResidual = previousSamples[i] - previousMean
    currentResidual = currentSamples[i] - currentMean
    delta = abs(currentResidual - previousResidual)
    deltas~append(delta)
    before = cells[i]~active
    ignored = cells[i]~observeDelta(delta,self~threshold)
    after = cells[i]~active
    if delta >= self~threshold then changedObservationCount = changedObservationCount + 1
    if \before & after then do
      activeCellCount = activeCellCount + 1
      invariantCellCount = invariantCellCount - 1
    end
  end
  comparisonDeltas~append(deltas)
  ignoredTemporal = temporalTracks~observeComparison(deltas,self~threshold,comparisonCount)
  if cells~items > 0 then invariantShare = invariantCellCount / cells~items
  return changedObservationCount

::method deltasAt
  expose comparisonDeltas
  use arg comparisonIndex
  if comparisonIndex < 1 | comparisonIndex > comparisonDeltas~items then return .nil
  return comparisonDeltas[comparisonIndex]

::method deltaComparisonCount
  expose comparisonDeltas
  return comparisonDeltas~items

::method activeCells
  expose cells
  out = .array~new
  do cell over cells
    if cell~active then out~append(cell)
  end
  return out

::method compactText
  active = self~activeCells
  tokens = .array~new
  do cell over active
    tokens~append(cell~compactText)
  end
  tokens~sort
  body = ''
  do token over tokens
    if body == '' then body = token
    else body = body || ';' || token
  end
  return 'CLA1|G=' || self~gridColumns || 'x' || self~gridRows || '|SF=' || self~sampledFrames || '|CMP=' || self~comparisonCount || '|A=' || self~activeCellCount || '|I=' || self~invariantCellCount || '|IS=' || self~invariantShare || '|CO=' || self~changedObservationCount || '|STEP=' || self~sampleEveryFrames || '|TH=' || self~threshold || '|C=' || body

::method canonicalText
  return 'SOURCE=' || self~sourcePath || '|' || self~compactText

::method scenePriors
  return .CameraLumaScenePriorSet~new(self)

::method directionProfile
  expose temporalTracks
  return .CameraLumaDirectionProfile~new(temporalTracks)

::method hierarchy
  use arg maxDepth
  if arg(1,'O') then maxDepth = 8
  return .CameraLumaActivityHierarchy~new(self,maxDepth)


::class CameraLumaHierarchyNode public
::attribute left get
::attribute top get
::attribute right get
::attribute bottom get
::attribute depth get
::attribute fineCellCount get
::attribute activeFineCellCount get
::attribute state get

::method init
  expose left top right bottom depth fineCellCount activeFineCellCount state children
  use arg activityMap,x1,y1,x2,y2,nodeDepth,maxDepth
  left = x1
  top = y1
  right = x2
  bottom = y2
  depth = nodeDepth
  fineCellCount = (x2 - x1 + 1) * (y2 - y1 + 1)
  activeFineCellCount = 0
  children = .array~new

  do row = y1 to y2
    do column = x1 to x2
      cell = activityMap~cell(column,row)
      if cell \== .nil then if cell~active then activeFineCellCount = activeFineCellCount + 1
    end
  end

  if activeFineCellCount = 0 then do
    state = 'INVARIANT'
    return
  end

  if nodeDepth >= maxDepth | fineCellCount = 1 then do
    state = 'ACTIVE'
    return
  end

  state = 'BRANCH'
  width = x2 - x1 + 1
  height = y2 - y1 + 1
  splitX = x1 + ((width - 1) % 2)
  splitY = y1 + ((height - 1) % 2)

  if width > 1 & height > 1 then do
    children~append(.CameraLumaHierarchyNode~new(activityMap,x1,y1,splitX,splitY,nodeDepth+1,maxDepth))
    children~append(.CameraLumaHierarchyNode~new(activityMap,splitX+1,y1,x2,splitY,nodeDepth+1,maxDepth))
    children~append(.CameraLumaHierarchyNode~new(activityMap,x1,splitY+1,splitX,y2,nodeDepth+1,maxDepth))
    children~append(.CameraLumaHierarchyNode~new(activityMap,splitX+1,splitY+1,x2,y2,nodeDepth+1,maxDepth))
  end
  else if width > 1 then do
    children~append(.CameraLumaHierarchyNode~new(activityMap,x1,y1,splitX,y2,nodeDepth+1,maxDepth))
    children~append(.CameraLumaHierarchyNode~new(activityMap,splitX+1,y1,x2,y2,nodeDepth+1,maxDepth))
  end
  else do
    children~append(.CameraLumaHierarchyNode~new(activityMap,x1,y1,x2,splitY,nodeDepth+1,maxDepth))
    children~append(.CameraLumaHierarchyNode~new(activityMap,x1,splitY+1,x2,y2,nodeDepth+1,maxDepth))
  end

::method isLeaf
  expose children
  return children~items = 0

::method active
  return self~activeFineCellCount > 0

::method children
  expose children
  out = .array~new
  do child over children
    out~append(child)
  end
  return out

::method leafCount
  expose children
  if children~items = 0 then return 1
  total = 0
  do child over children
    total = total + child~leafCount
  end
  return total

::method invariantLeafCount
  expose children
  if children~items = 0 then return self~state = 'INVARIANT'
  total = 0
  do child over children
    total = total + child~invariantLeafCount
  end
  return total

::method activeLeafCount
  expose children
  if children~items = 0 then return self~state = 'ACTIVE'
  total = 0
  do child over children
    total = total + child~activeLeafCount
  end
  return total

::method maximumDepth
  expose children
  if children~items = 0 then return self~depth
  maximum = self~depth
  do child over children
    childDepth = child~maximumDepth
    if childDepth > maximum then maximum = childDepth
  end
  return maximum

::method leafTokens
  expose children
  out = .array~new
  if children~items = 0 then do
    if self~state = 'INVARIANT' then prefix = 'I'
    else prefix = 'A'
    out~append(prefix || ':' || self~left || ',' || self~top || '-' || self~right || ',' || self~bottom)
    return out
  end
  do child over children
    childTokens = child~leafTokens
    do token over childTokens
      out~append(token)
    end
  end
  return out

::method compactText
  tokens = self~leafTokens
  body = ''
  do token over tokens
    if body == '' then body = token
    else body = body || ';' || token
  end
  return body


::class CameraLumaActivityHierarchy public
::attribute sourcePath get
::attribute gridColumns get
::attribute gridRows get
::attribute fineCellCount get
::attribute activeFineCellCount get
::attribute maximumDepth get
::attribute leafCount get
::attribute invariantLeafCount get
::attribute activeLeafCount get
::attribute leafShare get
::attribute savedLeafCount get

::method init
  expose sourcePath gridColumns gridRows fineCellCount activeFineCellCount maximumDepth leafCount invariantLeafCount activeLeafCount leafShare savedLeafCount rootNode
  use arg activityMap,maxDepth
  if arg(2,'O') then maxDepth = 8
  if maxDepth < 0 then maxDepth = 0
  sourcePath = activityMap~sourcePath
  gridColumns = activityMap~gridColumns
  gridRows = activityMap~gridRows
  fineCellCount = gridColumns * gridRows
  activeFineCellCount = activityMap~activeCellCount
  rootNode = .CameraLumaHierarchyNode~new(activityMap,1,1,gridColumns,gridRows,0,maxDepth)
  leafCount = rootNode~leafCount
  invariantLeafCount = rootNode~invariantLeafCount
  activeLeafCount = rootNode~activeLeafCount
  maximumDepth = rootNode~maximumDepth
  if fineCellCount > 0 then leafShare = leafCount / fineCellCount
  else leafShare = 0
  savedLeafCount = fineCellCount - leafCount

::method root
  expose rootNode
  return rootNode

::method compactText
  expose rootNode
  return 'CLH1|G=' || self~gridColumns || 'x' || self~gridRows || '|F=' || self~fineCellCount || '|AF=' || self~activeFineCellCount || '|L=' || self~leafCount || '|IL=' || self~invariantLeafCount || '|AL=' || self~activeLeafCount || '|LS=' || self~leafShare || '|SAVE=' || self~savedLeafCount || '|D=' || self~maximumDepth || '|B=' || rootNode~compactText

::method canonicalText
  return 'SOURCE=' || self~sourcePath || '|' || self~compactText


::class CameraLumaTemporalRegion public
::attribute sampleIndex get
::attribute left get
::attribute top get
::attribute right get
::attribute bottom get
::attribute cellCount get
::attribute maximumDelta get

::method init
  expose sampleIndex left top right bottom cellCount maximumDelta
  use arg sample,x1,y1,x2,y2,count,maxDelta
  sampleIndex = sample
  left = x1
  top = y1
  right = x2
  bottom = y2
  cellCount = count
  maximumDelta = maxDelta

::method centerX
  return (self~left + self~right) / 2

::method centerY
  return (self~top + self~bottom) / 2

::method intersects
  use arg other
  if other == .nil then return .false
  if self~right < other~left then return .false
  if other~right < self~left then return .false
  if self~bottom < other~top then return .false
  if other~bottom < self~top then return .false
  return .true

::method centerDistance
  use arg other
  dx = self~centerX - other~centerX
  dy = self~centerY - other~centerY
  return abs(dx) + abs(dy)

::method compactText
  return self~sampleIndex || ':' || self~left || ',' || self~top || '-' || self~right || ',' || self~bottom || ':' || self~cellCount || ':' || self~maximumDelta


::class CameraLumaTemporalTrack public
::attribute id get
::attribute firstSample get
::attribute lastSample get
::attribute observationCount get
::attribute totalCellCount get
::attribute maximumDelta get

::method init
  expose id firstSample lastSample observationCount totalCellCount maximumDelta regions
  use arg trackId,firstRegion
  id = trackId
  firstSample = firstRegion~sampleIndex
  lastSample = firstRegion~sampleIndex
  observationCount = 0
  totalCellCount = 0
  maximumDelta = 0
  regions = .array~new
  ignored = self~append(firstRegion)

::method append
  expose lastSample observationCount totalCellCount maximumDelta regions
  use arg region
  regions~append(region)
  lastSample = region~sampleIndex
  observationCount = observationCount + 1
  totalCellCount = totalCellCount + region~cellCount
  if region~maximumDelta > maximumDelta then maximumDelta = region~maximumDelta
  return observationCount

::method regions
  expose regions
  out = .array~new
  do region over regions
    out~append(region)
  end
  return out

::method lastRegion
  expose regions
  if regions~items = 0 then return .nil
  return regions[regions~items]

::method displacementX
  expose regions
  if regions~items < 2 then return 0
  return regions[regions~items]~centerX - regions[1]~centerX

::method displacementY
  expose regions
  if regions~items < 2 then return 0
  return regions[regions~items]~centerY - regions[1]~centerY

::method pathLength
  expose regions
  if regions~items < 2 then return 0
  total = 0
  previous = regions[1]
  do i = 2 to regions~items
    current = regions[i]
    total = total + current~centerDistance(previous)
    previous = current
  end
  return total

::method compactText
  return self~id || ':' || self~firstSample || '-' || self~lastSample || ':' || self~observationCount || ':' || self~displacementX || ',' || self~displacementY || ':' || self~pathLength || ':' || self~maximumDelta


::class CameraLumaTemporalTrackSet public
::attribute sourcePath get
::attribute comparisonCount get
::attribute regionCount get
::attribute trackCount get
::attribute persistentTrackCount get
::attribute longestTrackObservations get

::method init
  expose sourcePath comparisonCount regionCount trackCount persistentTrackCount longestTrackObservations tracks nextTrackId previousRegions previousTrackIds gridColumns gridRows maximumLinkDistance
  use arg path,columns,rows,linkDistance
  sourcePath = path
  gridColumns = columns
  gridRows = rows
  maximumLinkDistance = linkDistance
  comparisonCount = 0
  regionCount = 0
  trackCount = 0
  persistentTrackCount = 0
  longestTrackObservations = 0
  tracks = .array~new
  nextTrackId = 1
  previousRegions = .array~new
  previousTrackIds = .array~new

::method trackById private
  expose tracks
  use arg id
  do track over tracks
    if track~id == id then return track
  end
  return .nil

::method regionsFromDeltas private
  expose gridColumns gridRows
  use arg deltas,threshold,sampleIndex
  active = .directory~new
  do row = 1 to gridRows
    do column = 1 to gridColumns
      index = ((row - 1) * gridColumns) + column
      if deltas[index] >= threshold then active[column || ',' || row] = deltas[index]
    end
  end

  regions = .array~new
  visited = .directory~new
  do row = 1 to gridRows
    do column = 1 to gridColumns
      key = column || ',' || row
      if active[key] == .nil then iterate
      if visited[key] \== .nil then iterate

      queueX = .array~new
      queueY = .array~new
      queueX~append(column)
      queueY~append(row)
      visited[key] = .true
      q = 1
      minX = column
      maxX = column
      minY = row
      maxY = row
      count = 0
      maxDelta = 0

      do while q <= queueX~items
        x = queueX[q]
        y = queueY[q]
        q = q + 1
        count = count + 1
        k = x || ',' || y
        if active[k] > maxDelta then maxDelta = active[k]
        if x < minX then minX = x
        if x > maxX then maxX = x
        if y < minY then minY = y
        if y > maxY then maxY = y

        nx = x - 1
        ny = y
        if nx >= 1 then do
          nk = nx || ',' || ny
          if active[nk] \== .nil & visited[nk] == .nil then do
            visited[nk] = .true
            queueX~append(nx)
            queueY~append(ny)
          end
        end
        nx = x + 1
        if nx <= gridColumns then do
          nk = nx || ',' || ny
          if active[nk] \== .nil & visited[nk] == .nil then do
            visited[nk] = .true
            queueX~append(nx)
            queueY~append(ny)
          end
        end
        nx = x
        ny = y - 1
        if ny >= 1 then do
          nk = nx || ',' || ny
          if active[nk] \== .nil & visited[nk] == .nil then do
            visited[nk] = .true
            queueX~append(nx)
            queueY~append(ny)
          end
        end
        ny = y + 1
        if ny <= gridRows then do
          nk = nx || ',' || ny
          if active[nk] \== .nil & visited[nk] == .nil then do
            visited[nk] = .true
            queueX~append(nx)
            queueY~append(ny)
          end
        end
      end

      regions~append(.CameraLumaTemporalRegion~new(sampleIndex,minX,minY,maxX,maxY,count,maxDelta))
    end
  end
  return regions

::method observeComparison
  expose comparisonCount regionCount trackCount persistentTrackCount longestTrackObservations tracks nextTrackId previousRegions previousTrackIds maximumLinkDistance
  use arg deltas,threshold,sampleIndex
  comparisonCount = comparisonCount + 1
  currentRegions = self~regionsFromDeltas(deltas,threshold,sampleIndex)
  regionCount = regionCount + currentRegions~items

  usedPrevious = .directory~new
  currentTrackIds = .array~new

  do region over currentRegions
    bestTrackId = 0
    bestDistance = 999999
    do i = 1 to previousRegions~items
      if usedPrevious[i] \== .nil then iterate
      previous = previousRegions[i]
      distance = region~centerDistance(previous)
      if region~intersects(previous) then distance = 0
      if distance <= maximumLinkDistance & distance < bestDistance then do
        bestDistance = distance
        bestTrackId = previousTrackIds[i]
        bestPreviousIndex = i
      end
    end

    if bestTrackId = 0 then do
      trackId = 'LT' || nextTrackId
      nextTrackId = nextTrackId + 1
      track = .CameraLumaTemporalTrack~new(trackId,region)
      tracks~append(track)
      trackCount = trackCount + 1
    end
    else do
      trackId = bestTrackId
      usedPrevious[bestPreviousIndex] = .true
      track = self~trackById(trackId)
      beforePersistent = track~observationCount >= 2
      ignored = track~append(region)
      if \beforePersistent & track~observationCount >= 2 then persistentTrackCount = persistentTrackCount + 1
    end

    if track~observationCount > longestTrackObservations then longestTrackObservations = track~observationCount
    currentTrackIds~append(trackId)
  end

  previousRegions = currentRegions
  previousTrackIds = currentTrackIds
  return currentRegions~items

::method tracks
  expose tracks
  out = .array~new
  do track over tracks
    out~append(track)
  end
  return out

::method persistentTracks
  expose tracks
  out = .array~new
  do track over tracks
    if track~observationCount >= 2 then out~append(track)
  end
  return out

::method compactText
  persistent = self~persistentTracks
  tokens = .array~new
  do track over persistent
    tokens~append(track~compactText)
  end
  tokens~sort
  body = ''
  do token over tokens
    if body == '' then body = token
    else body = body || ';' || token
  end
  return 'CLT1|CMP=' || self~comparisonCount || '|R=' || self~regionCount || '|T=' || self~trackCount || '|PT=' || self~persistentTrackCount || '|LONG=' || self~longestTrackObservations || '|P=' || body

::method canonicalText
  return 'SOURCE=' || self~sourcePath || '|' || self~compactText


::class CameraSourceBoundaryCandidate public
::attribute sampleIndex get
::attribute pts get
::attribute timeMs get
::attribute changedShare get
::attribute structureDelta get
::attribute preMeanDelta get
::attribute postMeanDelta get
::attribute score get
::attribute boundaryType get

::method init
  expose sampleIndex pts timeMs changedShare structureDelta preMeanDelta postMeanDelta score boundaryType
  use arg sample,framePts,millis,changed,structure,preDelta,postDelta,boundaryScore,kind
  sampleIndex = sample
  pts = framePts
  timeMs = millis
  changedShare = changed
  structureDelta = structure
  preMeanDelta = preDelta
  postMeanDelta = postDelta
  score = boundaryScore
  boundaryType = kind

::method compactText
  return 'CSB1|S=' || self~sampleIndex || '|PTS=' || self~pts || '|MS=' || self~timeMs || '|CH=' || self~changedShare || '|SD=' || self~structureDelta || '|PRE=' || self~preMeanDelta || '|POST=' || self~postMeanDelta || '|SC=' || self~score || '|TYPE=' || self~boundaryType


::class CameraSourceBoundaryAnalysis public
::attribute sourcePath get
::attribute sampledFrames get
::attribute candidateCount get
::attribute dominantBoundary get
::attribute sourceSegmentCount get
::attribute firstTimeMs get
::attribute lastTimeMs get
::attribute gridColumns get
::attribute gridRows get
::attribute sampleEveryFrames get

::method init
  expose sourcePath sampledFrames candidateCount dominantBoundary sourceSegmentCount gridColumns gridRows sampleEveryFrames candidates firstTimeMs lastTimeMs
  use arg path,columns,rows,sampleEvery
  sourcePath = path
  gridColumns = columns
  gridRows = rows
  sampleEveryFrames = sampleEvery
  sampledFrames = 0
  candidateCount = 0
  dominantBoundary = .nil
  sourceSegmentCount = 1
  firstTimeMs = 0
  lastTimeMs = 0
  candidates = .array~new

::method setTimeSpan
  expose firstTimeMs lastTimeMs
  use arg firstMs,lastMs
  firstTimeMs = firstMs
  lastTimeMs = lastMs
  return lastTimeMs

::method setSampledFrames
  expose sampledFrames
  use arg count
  sampledFrames = count
  return sampledFrames

::method addCandidate
  expose candidates candidateCount dominantBoundary sourceSegmentCount
  use arg candidate
  candidates~append(candidate)
  candidateCount = candidateCount + 1
  if dominantBoundary == .nil then dominantBoundary = candidate
  else if candidate~score > dominantBoundary~score then dominantBoundary = candidate
  sourceSegmentCount = candidateCount + 1
  return candidateCount

::method candidates
  expose candidates
  out = .array~new
  do candidate over candidates
    out~append(candidate)
  end
  return out

::method compactText
  if self~dominantBoundary == .nil then boundary = ''
  else boundary = self~dominantBoundary~compactText
  return 'CSBA1|SF=' || self~sampledFrames || '|N=' || self~candidateCount || '|SEG=' || self~sourceSegmentCount || '|B=' || boundary


::class CameraLumaScenePriorSet public
::attribute activeCellCount get
::attribute comparisonCount get

::method init
  expose activeCellCount comparisonCount priors
  use arg activityMap
  activeCellCount = activityMap~activeCellCount
  comparisonCount = activityMap~comparisonCount
  priors = .array~new
  do row = 1 to activityMap~gridRows
    do column = 1 to activityMap~gridColumns
      cell = activityMap~cell(column,row)
      if cell == .nil then iterate
      if \cell~active then iterate
      if comparisonCount > 0 then persistence = cell~changeCount / comparisonCount
      else persistence = 0
      priors~append(column || ',' || row || ':' || cell~maximumDelta || ':' || persistence)
    end
  end

::method compactText
  expose priors
  body = ''
  do prior over priors
    if body == '' then body = prior
    else body = body || ';' || prior
  end
  return 'CLP1|A=' || self~activeCellCount || '|CMP=' || self~comparisonCount || '|P=' || body


::class CameraLumaDirectionProfile public
::attribute upCount get
::attribute downCount get
::attribute leftCount get
::attribute rightCount get
::attribute upLeftCount get
::attribute upRightCount get
::attribute downLeftCount get
::attribute downRightCount get
::attribute stationaryCount get
::attribute stepCount get

::method init
  expose upCount downCount leftCount rightCount upLeftCount upRightCount downLeftCount downRightCount stationaryCount stepCount
  use arg temporalTrackSet
  upCount=0
  downCount=0
  leftCount=0
  rightCount=0
  upLeftCount=0
  upRightCount=0
  downLeftCount=0
  downRightCount=0
  stationaryCount=0
  stepCount=0
  if temporalTrackSet == .nil then return

  do track over temporalTrackSet~tracks
    regions = track~regions
    if regions~items < 2 then iterate
    previous = regions[1]
    do i=2 to regions~items
      current = regions[i]
      dx = current~centerX - previous~centerX
      dy = current~centerY - previous~centerY
      stepCount = stepCount + 1
      if dx=0 & dy=0 then stationaryCount=stationaryCount+1
      else if dx<0 & dy<0 then upLeftCount=upLeftCount+1
      else if dx>0 & dy<0 then upRightCount=upRightCount+1
      else if dx<0 & dy>0 then downLeftCount=downLeftCount+1
      else if dx>0 & dy>0 then downRightCount=downRightCount+1
      else if dx<0 then leftCount=leftCount+1
      else if dx>0 then rightCount=rightCount+1
      else if dy<0 then upCount=upCount+1
      else if dy>0 then downCount=downCount+1
      previous = current
    end
  end

::method compactText
  return 'CLD1|N=' || self~stepCount || '|U=' || self~upCount || '|D=' || self~downCount || '|L=' || self~leftCount || '|R=' || self~rightCount || '|UL=' || self~upLeftCount || '|UR=' || self~upRightCount || '|DL=' || self~downLeftCount || '|DR=' || self~downRightCount || '|S=' || self~stationaryCount


::class CameraLumaSegmentPriorEntry public
::attribute column get
::attribute row get
::attribute maximumDelta get
::attribute persistence get

::method init
  expose column row maximumDelta persistence
  use arg col,rowIndex,maxDelta,persist
  column=col
  row=rowIndex
  maximumDelta=maxDelta
  persistence=persist

::method compactText
  return self~column || ',' || self~row || ':' || self~maximumDelta || ':' || self~persistence


::class CameraLumaSegmentPriorSet public
::attribute segmentId get
::attribute comparisonCount get
::attribute activeCellCount get
::attribute gridColumns get
::attribute gridRows get

::method init
  expose segmentId comparisonCount activeCellCount gridColumns gridRows threshold priors
  use arg activityMap,id,firstComparison,lastComparison
  segmentId = id
  gridColumns = activityMap~gridColumns
  gridRows = activityMap~gridRows
  threshold = activityMap~threshold
  priors = .array~new
  counts = .array~new
  maxima = .array~new
  cellTotal = gridColumns * gridRows
  do i=1 to cellTotal
    counts~append(0)
    maxima~append(0)
  end

  comparisonCount = 0
  if firstComparison < 1 then firstComparison = 1
  if lastComparison > activityMap~deltaComparisonCount then lastComparison = activityMap~deltaComparisonCount
  if lastComparison >= firstComparison then do comparisonIndex=firstComparison to lastComparison
    deltas = activityMap~deltasAt(comparisonIndex)
    if deltas == .nil then iterate
    comparisonCount = comparisonCount + 1
    do i=1 to cellTotal
      delta = deltas[i]
      if delta > maxima[i] then maxima[i] = delta
      if delta >= threshold then counts[i] = counts[i] + 1
    end
  end

  activeCellCount = 0
  do row=1 to gridRows
    do column=1 to gridColumns
      index=((row-1)*gridColumns)+column
      if counts[index] = 0 then iterate
      activeCellCount = activeCellCount + 1
      if comparisonCount > 0 then persistence=counts[index]/comparisonCount
      else persistence=0
      priors~append(.CameraLumaSegmentPriorEntry~new(column,row,maxima[index],persistence))
    end
  end

::method entries
  expose priors
  out=.array~new
  do prior over priors
    out~append(prior)
  end
  return out

::method compactText
  expose priors
  body=''
  do prior over priors
    token=prior~compactText
    if body=='' then body=token
    else body=body || ';' || token
  end
  return 'CLSP1|ID=' || self~segmentId || '|A=' || self~activeCellCount || '|CMP=' || self~comparisonCount || '|P=' || body


::class CameraLumaSegmentTrackSet public
::attribute sourcePath get
::attribute segmentId get
::attribute comparisonCount get
::attribute regionCount get
::attribute trackCount get
::attribute persistentTrackCount get
::attribute longestTrackObservations get

::method init
  expose sourcePath segmentId comparisonCount regionCount trackCount persistentTrackCount longestTrackObservations tracks
  use arg sourceTrackSet,id,firstComparison,lastComparison
  sourcePath = sourceTrackSet~sourcePath
  segmentId = id
  comparisonCount = 0
  if lastComparison >= firstComparison then comparisonCount = lastComparison - firstComparison + 1
  regionCount = 0
  trackCount = 0
  persistentTrackCount = 0
  longestTrackObservations = 0
  tracks = .array~new
  nextId = 1

  do sourceTrack over sourceTrackSet~tracks
    selected = .array~new
    do region over sourceTrack~regions
      if region~sampleIndex >= firstComparison & region~sampleIndex <= lastComparison then selected~append(region)
    end
    if selected~items = 0 then iterate

    localTrack = .CameraLumaTemporalTrack~new('LT' || nextId,selected[1])
    do i=2 to selected~items
      ignored = localTrack~append(selected[i])
    end
    tracks~append(localTrack)
    nextId = nextId + 1
    trackCount = trackCount + 1
    regionCount = regionCount + selected~items
    if localTrack~observationCount >= 2 then persistentTrackCount = persistentTrackCount + 1
    if localTrack~observationCount > longestTrackObservations then longestTrackObservations = localTrack~observationCount
  end

::method tracks
  expose tracks
  out=.array~new
  do track over tracks
    out~append(track)
  end
  return out

::method persistentTracks
  expose tracks
  out=.array~new
  do track over tracks
    if track~observationCount>=2 then out~append(track)
  end
  return out

::method compactText
  return 'CLST1|ID=' || self~segmentId || '|CMP=' || self~comparisonCount || '|R=' || self~regionCount || '|T=' || self~trackCount || '|PT=' || self~persistentTrackCount || '|LONG=' || self~longestTrackObservations


::class CameraSourceSegment public
::attribute id get
::attribute generation get
::attribute startSample get
::attribute endSample get
::attribute firstComparison get
::attribute lastComparison get
::attribute startTimeMs get
::attribute endTimeMs get
::attribute trackSet get
::attribute priors get
::attribute directionProfile get

::method init
  expose id generation startSample endSample firstComparison lastComparison startTimeMs endTimeMs trackSet priors directionProfile
  use arg segmentId,generationId,sampleStart,sampleEnd,comparisonStart,comparisonEnd,timeStart,timeEnd,segmentTracks,segmentPriors
  id = segmentId
  generation = generationId
  startSample = sampleStart
  endSample = sampleEnd
  firstComparison = comparisonStart
  lastComparison = comparisonEnd
  startTimeMs = timeStart
  endTimeMs = timeEnd
  trackSet = segmentTracks
  priors = segmentPriors
  directionProfile = .CameraLumaDirectionProfile~new(segmentTracks)

::method compactText
  return 'CSS1|ID=' || self~id || '|G=' || self~generation || '|S=' || self~startSample || '-' || self~endSample || '|C=' || self~firstComparison || '-' || self~lastComparison || '|MS=' || self~startTimeMs || '-' || self~endTimeMs || '|T=' || self~trackSet~trackCount || '|PT=' || self~trackSet~persistentTrackCount || '|A=' || self~priors~activeCellCount


::class CameraSourceSegmentedAnalysis public
::attribute sourcePath get
::attribute segmentCount get
::attribute boundaryCount get

::method init
  expose sourcePath segmentCount boundaryCount segments boundaries
  use arg path
  sourcePath = path
  segmentCount = 0
  boundaryCount = 0
  segments = .array~new
  boundaries = .array~new

::method addBoundary
  expose boundaries boundaryCount
  use arg boundary
  boundaries~append(boundary)
  boundaryCount = boundaryCount + 1
  return boundaryCount

::method addSegment
  expose segments segmentCount
  use arg segment
  segments~append(segment)
  segmentCount = segmentCount + 1
  return segmentCount

::method segments
  expose segments
  out=.array~new
  do segment over segments
    out~append(segment)
  end
  return out

::method segment
  expose segments
  use arg index
  if index<1 | index>segments~items then return .nil
  return segments[index]

::method compactText
  expose segments boundaries
  segmentBody=''
  do segment over segments
    if segmentBody=='' then segmentBody=segment~compactText
    else segmentBody=segmentBody || ';' || segment~compactText
  end
  boundaryBody=''
  do boundary over boundaries
    if boundaryBody=='' then boundaryBody=boundary~compactText
    else boundaryBody=boundaryBody || ';' || boundary~compactText
  end
  return 'CSSA1|SEG=' || self~segmentCount || '|B=' || self~boundaryCount || '|S=' || segmentBody || '|X=' || boundaryBody


::class CameraFFmpegMediaSource public
::attribute sourcePath get
::attribute bridgePath get
::attribute packetBridgePath get
::attribute frameBridgePath get
::attribute opened get
::attribute streamInfoLoaded get
::attribute lastOpenStatus get
::attribute lastStreamInfoStatus get
::attribute videoStreamIndex get
::attribute audioStreamIndex get
::attribute avformatVersion get

::method init
  expose sourcePath bridgePath packetBridgePath frameBridgePath opened streamInfoLoaded lastOpenStatus lastStreamInfoStatus videoStreamIndex audioStreamIndex avformatVersion library context
  use arg path,bridge,packetBridge,frameBridge
  if arg(1,'O') | path == '' then raise syntax 88.900 array('CameraFFmpegMediaSource requires a media path')
  if arg(2,'O') | bridge == '' then bridge = 'camera_ffmpeg_avformat.bridge.json'
  if arg(3,'O') | packetBridge == '' then packetBridge = 'camera_ffmpeg_avcodec.bridge.json'
  if arg(4,'O') | frameBridge == '' then frameBridge = 'camera_ffmpeg_avutil.bridge.json'
  sourcePath = path
  bridgePath = bridge
  packetBridgePath = packetBridge
  frameBridgePath = frameBridge
  opened = .false
  streamInfoLoaded = .false
  lastOpenStatus = -1
  lastStreamInfoStatus = -1
  videoStreamIndex = -1
  audioStreamIndex = -1
  avformatVersion = 0
  library = .nil
  context = .nil

::method open
  expose bridgePath sourcePath opened streamInfoLoaded lastOpenStatus lastStreamInfoStatus videoStreamIndex audioStreamIndex avformatVersion library context
  if opened then return self~inspection
  library = .foreign~load(bridgePath)
  avformatVersion = library~version
  openResult = library~open_input(.foreign~out,sourcePath,.nil,.nil)
  lastOpenStatus = openResult~returnValue
  if lastOpenStatus <> 0 then do
    library~close
    library = .nil
    return .CameraFFmpegMediaInspection~new(sourcePath,avformatVersion,lastOpenStatus,-1,-1)
  end
  context = openResult~out('context')
  opened = .true
  lastStreamInfoStatus = library~find_stream_info(context,.nil)
  if lastStreamInfoStatus >= 0 then do
    streamInfoLoaded = .true
    videoStreamIndex = library~find_best_stream(context,0,-1,-1,.nil,0)
    audioStreamIndex = library~find_best_stream(context,1,-1,-1,.nil,0)
  end
  return self~inspection

::method inspection
  expose sourcePath avformatVersion lastStreamInfoStatus videoStreamIndex audioStreamIndex
  return .CameraFFmpegMediaInspection~new(sourcePath,avformatVersion,lastStreamInfoStatus,videoStreamIndex,audioStreamIndex)

::method demuxPackets
  expose opened sourcePath packetBridgePath library context
  use arg maximumPackets
  if arg(1,'O') then maximumPackets = 0
  if maximumPackets < 0 then maximumPackets = 0
  if \opened then do
    ignoredInspection = self~open
    if \opened then return .CameraFFmpegPacketInspection~new(sourcePath,0,self~lastOpenStatus,.false,0)
  end

  codecLibrary = .foreign~load(packetBridgePath)
  codecVersion = codecLibrary~version
  packet = codecLibrary~packet_alloc
  if packet == .nil then do
    codecLibrary~close
    return .CameraFFmpegPacketInspection~new(sourcePath,0,-1,.false,codecVersion)
  end

  count = 0
  endStatus = 0
  limited = .false
  do forever
    if maximumPackets > 0 & count >= maximumPackets then do
      limited = .true
      leave
    end
    readStatus = library~read_frame(context,packet)
    if readStatus < 0 then do
      endStatus = readStatus
      leave
    end
    count = count + 1
    ignoredUnref = codecLibrary~packet_unref(packet)
  end

  packet~close
  codecLibrary~close
  return .CameraFFmpegPacketInspection~new(sourcePath,count,endStatus,limited,codecVersion)

::method decodeVideoFrames
  expose opened sourcePath packetBridgePath frameBridgePath library context videoStreamIndex
  use arg maximumFrames
  if arg(1,'O') then maximumFrames = 0
  if maximumFrames < 0 then maximumFrames = 0

  if \opened then do
    ignoredInspection = self~open
    if \opened then return .CameraFFmpegDecodeInspection~new(sourcePath,0,0,0,self~lastOpenStatus,.false,0,0,-1,0,'',0,0)
  end
  if videoStreamIndex < 0 then return .CameraFFmpegDecodeInspection~new(sourcePath,0,0,0,-1,.false,0,0,-1,0,'',0,0)

  codecLibrary = .foreign~load(packetBridgePath)
  utilLibrary = .foreign~load(frameBridgePath)
  codecVersion = codecLibrary~version
  utilVersion = utilLibrary~version

  best = library~find_best_stream_decoder(context,0,-1,-1,.foreign~out,0)
  if \best~isA(.ForeignResult) then do
    utilLibrary~close
    codecLibrary~close
    return .CameraFFmpegDecodeInspection~new(sourcePath,0,0,0,-1,.false,0,0,-1,0,'',codecVersion,utilVersion)
  end
  selectedStream = best~returnValue
  if selectedStream < 0 then do
    utilLibrary~close
    codecLibrary~close
    return .CameraFFmpegDecodeInspection~new(sourcePath,0,0,0,selectedStream,.false,0,0,-1,0,'',codecVersion,utilVersion)
  end
  decoder = best~out('decoder')

  formatView = library~structView('AVFormatContext',context)
  streamsAddress = formatView~get('streams')
  streamAddress = .foreign~pointerAt(streamsAddress,selectedStream)
  streamView = library~structView('AVStream',streamAddress)
  codecParameters = codecLibrary~structView('AVCodecParameters',streamView~get('codecpar'))

  codecContext = codecLibrary~alloc_context(decoder)
  parameterStatus = codecLibrary~parameters_to_context(codecContext,codecParameters)
  if parameterStatus < 0 then do
    codecParameters~close
    streamView~close
    formatView~close
    codecContext~close
    decoder~close
    utilLibrary~close
    codecLibrary~close
    return .CameraFFmpegDecodeInspection~new(sourcePath,0,0,0,parameterStatus,.false,0,0,-1,0,'',codecVersion,utilVersion)
  end

  openStatus = codecLibrary~open_codec(codecContext,decoder,.nil)
  if openStatus < 0 then do
    codecParameters~close
    streamView~close
    formatView~close
    codecContext~close
    decoder~close
    utilLibrary~close
    codecLibrary~close
    return .CameraFFmpegDecodeInspection~new(sourcePath,0,0,0,openStatus,.false,0,0,-1,0,'',codecVersion,utilVersion)
  end

  packet = codecLibrary~packet_alloc
  packetView = codecLibrary~structView('AVPacket',packet)
  frame = utilLibrary~frame_alloc
  frameView = utilLibrary~structView('AVFrame',frame)

  packetCount = 0
  videoPacketCount = 0
  frameCount = 0
  endStatus = 0
  limited = .false
  width = 0
  height = 0
  pixelFormat = -1
  lumaLineSize = 0
  firstLumaPrefixHex = ''
  done = .false

  do while \done
    readStatus = library~read_frame(context,packet)
    if readStatus < 0 then do
      endStatus = readStatus
      leave
    end
    packetCount = packetCount + 1

    if packetView~get('stream_index') = selectedStream then do
      videoPacketCount = videoPacketCount + 1
      sendStatus = codecLibrary~send_packet(codecContext,packet)
      if sendStatus >= 0 then do forever
        receiveStatus = codecLibrary~receive_frame(codecContext,frame)
        if receiveStatus < 0 then leave
        frameCount = frameCount + 1
        if frameCount = 1 then do
          width = frameView~get('width')
          height = frameView~get('height')
          pixelFormat = frameView~get('format')
          lumaLineSize = frameView~get('linesize0')
          lumaAddress = frameView~get('data0')
          if lumaAddress \= 0 & width > 0 then do
            prefixLength = 16
            if width < prefixLength then prefixLength = width
            firstLumaPrefixHex = c2x(.foreign~peekBytes(lumaAddress,prefixLength))
          end
        end
        ignoredFrameUnref = utilLibrary~frame_unref(frame)
        if maximumFrames > 0 & frameCount >= maximumFrames then do
          limited = .true
          done = .true
          leave
        end
      end
    end
    ignoredPacketUnref = codecLibrary~packet_unref(packet)
  end

  if \done then do
    flushStatus = codecLibrary~send_packet(codecContext,.nil)
    if flushStatus >= 0 then do forever
      receiveStatus = codecLibrary~receive_frame(codecContext,frame)
      if receiveStatus < 0 then leave
      frameCount = frameCount + 1
      if frameCount = 1 then do
        width = frameView~get('width')
        height = frameView~get('height')
        pixelFormat = frameView~get('format')
        lumaLineSize = frameView~get('linesize0')
        lumaAddress = frameView~get('data0')
        if lumaAddress \= 0 & width > 0 then do
          prefixLength = 16
          if width < prefixLength then prefixLength = width
          firstLumaPrefixHex = c2x(.foreign~peekBytes(lumaAddress,prefixLength))
        end
      end
      ignoredFrameUnref = utilLibrary~frame_unref(frame)
    end
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
  utilLibrary~close
  codecLibrary~close

  return .CameraFFmpegDecodeInspection~new(sourcePath,packetCount,videoPacketCount,frameCount,endStatus,limited,width,height,pixelFormat,lumaLineSize,firstLumaPrefixHex,codecVersion,utilVersion)

::method analyzeLumaGrid
  expose opened sourcePath packetBridgePath frameBridgePath library context videoStreamIndex
  use arg gridColumns,gridRows,sampleEveryFrames,changeThreshold
  if arg(1,'O') then gridColumns = 16
  if arg(2,'O') then gridRows = 9
  if arg(3,'O') then sampleEveryFrames = 15
  if arg(4,'O') then changeThreshold = 12
  if gridColumns < 1 then gridColumns = 1
  if gridRows < 1 then gridRows = 1
  if sampleEveryFrames < 1 then sampleEveryFrames = 1
  if changeThreshold < 1 then changeThreshold = 1

  activity = .CameraLumaActivityMap~new(sourcePath,gridColumns,gridRows,sampleEveryFrames,changeThreshold)

  if \opened then do
    ignoredInspection = self~open
    if \opened then return activity
  end
  if videoStreamIndex < 0 then return activity

  codecLibrary = .foreign~load(packetBridgePath)
  utilLibrary = .foreign~load(frameBridgePath)

  best = library~find_best_stream_decoder(context,0,-1,-1,.foreign~out,0)
  if \best~isA(.ForeignResult) then do
    utilLibrary~close
    codecLibrary~close
    return activity
  end
  selectedStream = best~returnValue
  if selectedStream < 0 then do
    utilLibrary~close
    codecLibrary~close
    return activity
  end
  decoder = best~out('decoder')

  formatView = library~structView('AVFormatContext',context)
  streamsAddress = formatView~get('streams')
  streamAddress = .foreign~pointerAt(streamsAddress,selectedStream)
  streamView = library~structView('AVStream',streamAddress)
  codecParameters = codecLibrary~structView('AVCodecParameters',streamView~get('codecpar'))

  codecContext = codecLibrary~alloc_context(decoder)
  parameterStatus = codecLibrary~parameters_to_context(codecContext,codecParameters)
  if parameterStatus < 0 then do
    codecParameters~close
    streamView~close
    formatView~close
    codecContext~close
    decoder~close
    utilLibrary~close
    codecLibrary~close
    return activity
  end

  openStatus = codecLibrary~open_codec(codecContext,decoder,.nil)
  if openStatus < 0 then do
    codecParameters~close
    streamView~close
    formatView~close
    codecContext~close
    decoder~close
    utilLibrary~close
    codecLibrary~close
    return activity
  end

  packet = codecLibrary~packet_alloc
  packetView = codecLibrary~structView('AVPacket',packet)
  frame = utilLibrary~frame_alloc
  frameView = utilLibrary~structView('AVFrame',frame)

  frameCount = 0
  previousSamples = .nil
  done = .false

  do while \done
    readStatus = library~read_frame(context,packet)
    if readStatus < 0 then leave
    if packetView~get('stream_index') = selectedStream then do
      sendStatus = codecLibrary~send_packet(codecContext,packet)
      if sendStatus >= 0 then do forever
        receiveStatus = codecLibrary~receive_frame(codecContext,frame)
        if receiveStatus < 0 then leave
        frameCount = frameCount + 1

        if ((frameCount - 1) // sampleEveryFrames) = 0 then do
          width = frameView~get('width')
          height = frameView~get('height')
          lineSize = frameView~get('linesize0')
          lumaAddress = frameView~get('data0')
          samples = .array~new
          if width > 0 & height > 0 & lineSize > 0 & lumaAddress \= 0 then do
            plane = .foreign~peekBytes(lumaAddress,lineSize * height)
            fractions = .array~of(0.25,0.5,0.75)
            do r = 1 to gridRows
              do c = 1 to gridColumns
                total = 0
                pointCount = 0
                do fy over fractions
                  y = trunc((((r - 1) + fy) * height) / gridRows)
                  if y < 0 then y = 0
                  if y >= height then y = height - 1
                  do fx over fractions
                    x = trunc((((c - 1) + fx) * width) / gridColumns)
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
            ignoredActivity = activity~observeFrameSamples(previousSamples,samples)
            previousSamples = samples
          end
        end

        ignoredFrameUnref = utilLibrary~frame_unref(frame)
      end
    end
    ignoredPacketUnref = codecLibrary~packet_unref(packet)
  end

  ignoredFlush = codecLibrary~send_packet(codecContext,.nil)
  do forever
    receiveStatus = codecLibrary~receive_frame(codecContext,frame)
    if receiveStatus < 0 then leave
    frameCount = frameCount + 1
    if ((frameCount - 1) // sampleEveryFrames) = 0 then do
      width = frameView~get('width')
      height = frameView~get('height')
      lineSize = frameView~get('linesize0')
      lumaAddress = frameView~get('data0')
      samples = .array~new
      plane = .foreign~peekBytes(lumaAddress,lineSize * height)
      fractions = .array~of(0.25,0.5,0.75)
      do r = 1 to gridRows
        do c = 1 to gridColumns
          total = 0
          pointCount = 0
          do fy over fractions
            y = trunc((((r - 1) + fy) * height) / gridRows)
            if y < 0 then y = 0
            if y >= height then y = height - 1
            do fx over fractions
              x = trunc((((c - 1) + fx) * width) / gridColumns)
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
      ignoredActivity = activity~observeFrameSamples(previousSamples,samples)
      previousSamples = samples
    end
    ignoredFrameUnref = utilLibrary~frame_unref(frame)
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
  utilLibrary~close
  codecLibrary~close

  return activity

::method analyzeSourceBoundaries
  expose opened sourcePath packetBridgePath frameBridgePath library context videoStreamIndex
  use arg gridColumns,gridRows,sampleEveryFrames,changeThreshold,changedShareThreshold,structureThreshold,stabilityThreshold
  if arg(1,'O') then gridColumns = 16
  if arg(2,'O') then gridRows = 9
  if arg(3,'O') then sampleEveryFrames = 15
  if arg(4,'O') then changeThreshold = 12
  if arg(5,'O') then changedShareThreshold = 0.5
  if arg(6,'O') then structureThreshold = 20
  if arg(7,'O') then stabilityThreshold = 15
  if gridColumns < 1 then gridColumns = 1
  if gridRows < 1 then gridRows = 1
  if sampleEveryFrames < 1 then sampleEveryFrames = 1

  analysis = .CameraSourceBoundaryAnalysis~new(sourcePath,gridColumns,gridRows,sampleEveryFrames)

  if \opened then do
    ignoredInspection = self~open
    if \opened then return analysis
  end
  if videoStreamIndex < 0 then return analysis

  codecLibrary = .foreign~load(packetBridgePath)
  utilLibrary = .foreign~load(frameBridgePath)
  best = library~find_best_stream_decoder(context,0,-1,-1,.foreign~out,0)
  if \best~isA(.ForeignResult) then do
    utilLibrary~close
    codecLibrary~close
    return analysis
  end
  selectedStream = best~returnValue
  if selectedStream < 0 then do
    utilLibrary~close
    codecLibrary~close
    return analysis
  end
  decoder = best~out('decoder')

  formatView = library~structView('AVFormatContext',context)
  streamsAddress = formatView~get('streams')
  streamAddress = .foreign~pointerAt(streamsAddress,selectedStream)
  streamView = library~structView('AVStream',streamAddress)
  timeBaseNum = streamView~get('time_base_num')
  timeBaseDen = streamView~get('time_base_den')
  if timeBaseDen = 0 then timeBaseDen = 1
  codecParameters = codecLibrary~structView('AVCodecParameters',streamView~get('codecpar'))

  codecContext = codecLibrary~alloc_context(decoder)
  parameterStatus = codecLibrary~parameters_to_context(codecContext,codecParameters)
  if parameterStatus < 0 then do
    codecParameters~close
    streamView~close
    formatView~close
    codecContext~close
    decoder~close
    utilLibrary~close
    codecLibrary~close
    return analysis
  end
  openStatus = codecLibrary~open_codec(codecContext,decoder,.nil)
  if openStatus < 0 then do
    codecParameters~close
    streamView~close
    formatView~close
    codecContext~close
    decoder~close
    utilLibrary~close
    codecLibrary~close
    return analysis
  end

  packet = codecLibrary~packet_alloc
  packetView = codecLibrary~structView('AVPacket',packet)
  frame = utilLibrary~frame_alloc
  frameView = utilLibrary~structView('AVFrame',frame)

  sampleVectors = .array~new
  samplePts = .array~new
  sampleMillis = .array~new
  frameCount = 0

  do forever
    readStatus = library~read_frame(context,packet)
    if readStatus < 0 then leave
    if packetView~get('stream_index') = selectedStream then do
      sendStatus = codecLibrary~send_packet(codecContext,packet)
      if sendStatus >= 0 then do forever
        receiveStatus = codecLibrary~receive_frame(codecContext,frame)
        if receiveStatus < 0 then leave
        frameCount = frameCount + 1

        if ((frameCount - 1) // sampleEveryFrames) = 0 then do
          width = frameView~get('width')
          height = frameView~get('height')
          lineSize = frameView~get('linesize0')
          lumaAddress = frameView~get('data0')
          if width > 0 & height > 0 & lineSize > 0 & lumaAddress \= 0 then do
            plane = .foreign~peekBytes(lumaAddress,lineSize * height)
            fractions = .array~of(0.25,0.5,0.75)
            samples = .array~new
            frameMean = 0
            do r = 1 to gridRows
              do c = 1 to gridColumns
                total = 0
                pointCount = 0
                do fy over fractions
                  y = trunc((((r - 1) + fy) * height) / gridRows)
                  if y < 0 then y = 0
                  if y >= height then y = height - 1
                  do fx over fractions
                    x = trunc((((c - 1) + fx) * width) / gridColumns)
                    if x < 0 then x = 0
                    if x >= width then x = width - 1
                    offset = (y * lineSize) + x + 1
                    total = total + c2d(plane~substr(offset,1))
                    pointCount = pointCount + 1
                  end
                end
                value = total / pointCount
                samples~append(value)
                frameMean = frameMean + value
              end
            end
            if samples~items > 0 then frameMean = frameMean / samples~items
            residuals = .array~new
            do value over samples
              residuals~append(value - frameMean)
            end

            framePts = frameView~get('pts')
            frameMs = framePts * timeBaseNum * 1000 / timeBaseDen
            sampleVectors~append(residuals)
            samplePts~append(framePts)
            sampleMillis~append(frameMs)
          end
        end

        ignoredFrameUnref = utilLibrary~frame_unref(frame)
      end
    end
    ignoredPacketUnref = codecLibrary~packet_unref(packet)
  end

  ignoredFlush = codecLibrary~send_packet(codecContext,.nil)
  do forever
    receiveStatus = codecLibrary~receive_frame(codecContext,frame)
    if receiveStatus < 0 then leave
    frameCount = frameCount + 1
    if ((frameCount - 1) // sampleEveryFrames) = 0 then do
      width = frameView~get('width')
      height = frameView~get('height')
      lineSize = frameView~get('linesize0')
      lumaAddress = frameView~get('data0')
      if width > 0 & height > 0 & lineSize > 0 & lumaAddress \= 0 then do
        plane = .foreign~peekBytes(lumaAddress,lineSize * height)
        fractions = .array~of(0.25,0.5,0.75)
        samples = .array~new
        frameMean = 0
        do r = 1 to gridRows
          do c = 1 to gridColumns
            total = 0
            pointCount = 0
            do fy over fractions
              y = trunc((((r - 1) + fy) * height) / gridRows)
              if y < 0 then y = 0
              if y >= height then y = height - 1
              do fx over fractions
                x = trunc((((c - 1) + fx) * width) / gridColumns)
                if x < 0 then x = 0
                if x >= width then x = width - 1
                offset = (y * lineSize) + x + 1
                total = total + c2d(plane~substr(offset,1))
                pointCount = pointCount + 1
              end
            end
            value = total / pointCount
            samples~append(value)
            frameMean = frameMean + value
          end
        end
        if samples~items > 0 then frameMean = frameMean / samples~items
        residuals = .array~new
        do value over samples
          residuals~append(value - frameMean)
        end
        framePts = frameView~get('pts')
        frameMs = framePts * timeBaseNum * 1000 / timeBaseDen
        sampleVectors~append(residuals)
        samplePts~append(framePts)
        sampleMillis~append(frameMs)
      end
    end
    ignoredFrameUnref = utilLibrary~frame_unref(frame)
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
  utilLibrary~close
  codecLibrary~close

  ignoredSampleCount = analysis~setSampledFrames(sampleVectors~items)
  if sampleMillis~items > 0 then ignoredTimeSpan = analysis~setTimeSpan(sampleMillis[1],sampleMillis[sampleMillis~items])

  do i = 2 to sampleVectors~items
    previous = sampleVectors[i-1]
    current = sampleVectors[i]
    if i > 2 then beforePrevious = sampleVectors[i-2]
    else beforePrevious = .nil
    if i < sampleVectors~items then next = sampleVectors[i+1]
    else next = .nil

    changedCount = 0
    meanDelta = 0
    do k = 1 to current~items
      delta = abs(current[k] - previous[k])
      meanDelta = meanDelta + delta
      if delta >= changeThreshold then changedCount = changedCount + 1
    end
    if current~items > 0 then do
      changedShare = changedCount / current~items
      meanDelta = meanDelta / current~items
    end
    else changedShare = 0

    edgeDelta = 0
    edgeCount = 0
    do row = 1 to gridRows
      do column = 1 to gridColumns - 1
        a = ((row - 1) * gridColumns) + column
        b = a + 1
        oldGradient = previous[b] - previous[a]
        newGradient = current[b] - current[a]
        edgeDelta = edgeDelta + abs(newGradient - oldGradient)
        edgeCount = edgeCount + 1
      end
    end
    do row = 1 to gridRows - 1
      do column = 1 to gridColumns
        a = ((row - 1) * gridColumns) + column
        b = a + gridColumns
        oldGradient = previous[b] - previous[a]
        newGradient = current[b] - current[a]
        edgeDelta = edgeDelta + abs(newGradient - oldGradient)
        edgeCount = edgeCount + 1
      end
    end
    if edgeCount > 0 then structureDelta = edgeDelta / edgeCount
    else structureDelta = 0

    preMeanDelta = 0
    if beforePrevious \== .nil then do
      do k = 1 to previous~items
        preMeanDelta = preMeanDelta + abs(previous[k] - beforePrevious[k])
      end
      if previous~items > 0 then preMeanDelta = preMeanDelta / previous~items
    end

    postMeanDelta = 0
    if next \== .nil then do
      do k = 1 to current~items
        postMeanDelta = postMeanDelta + abs(next[k] - current[k])
      end
      if current~items > 0 then postMeanDelta = postMeanDelta / current~items
    end

    if changedShare >= changedShareThreshold & structureDelta >= structureThreshold & preMeanDelta <= stabilityThreshold & postMeanDelta <= stabilityThreshold then do
      score = (changedShare * structureDelta) - preMeanDelta - postMeanDelta
      candidate = .CameraSourceBoundaryCandidate~new(i,samplePts[i],sampleMillis[i],changedShare,structureDelta,preMeanDelta,postMeanDelta,score,'SOURCE_CHANGE')
      ignoredCandidate = analysis~addCandidate(candidate)
    end
  end

  return analysis

::method analyzeSegmentedScene
  expose sourcePath bridgePath packetBridgePath frameBridgePath
  use arg gridColumns,gridRows,sampleEveryFrames,changeThreshold,changedShareThreshold,structureThreshold,stabilityThreshold
  if arg(1,'O') then gridColumns=16
  if arg(2,'O') then gridRows=9
  if arg(3,'O') then sampleEveryFrames=15
  if arg(4,'O') then changeThreshold=12
  if arg(5,'O') then changedShareThreshold=0.5
  if arg(6,'O') then structureThreshold=20
  if arg(7,'O') then stabilityThreshold=15

  boundarySource=.CameraFFmpegMediaSource~new(sourcePath,bridgePath,packetBridgePath,frameBridgePath)
  boundaries=boundarySource~analyzeSourceBoundaries(gridColumns,gridRows,sampleEveryFrames,changeThreshold,changedShareThreshold,structureThreshold,stabilityThreshold)
  ignoredBoundaryClose=boundarySource~close

  activitySource=.CameraFFmpegMediaSource~new(sourcePath,bridgePath,packetBridgePath,frameBridgePath)
  activity=activitySource~analyzeLumaGrid(gridColumns,gridRows,sampleEveryFrames,changeThreshold)
  ignoredActivityClose=activitySource~close

  segmented=.CameraSourceSegmentedAnalysis~new(sourcePath)
  boundaryList=boundaries~candidates
  do boundary over boundaryList
    ignoredBoundary=segmented~addBoundary(boundary)
  end

  sampleStart=1
  comparisonStart=1
  timeStart=boundaries~firstTimeMs
  generation=1

  do boundary over boundaryList
    sampleEnd=boundary~sampleIndex-1
    comparisonEnd=boundary~sampleIndex-2
    if sampleEnd>=sampleStart then do
      segmentId='S' || generation
      generationId='G' || generation
      tracks=.CameraLumaSegmentTrackSet~new(activity~temporalTracks,segmentId,comparisonStart,comparisonEnd)
      priors=.CameraLumaSegmentPriorSet~new(activity,segmentId,comparisonStart,comparisonEnd)
      segment=.CameraSourceSegment~new(segmentId,generationId,sampleStart,sampleEnd,comparisonStart,comparisonEnd,timeStart,boundary~timeMs,tracks,priors)
      ignoredSegment=segmented~addSegment(segment)
    end

    /* The comparison ending at the boundary sample is structural replacement,
       not movement. It is intentionally absent from either generation. */
    sampleStart=boundary~sampleIndex
    comparisonStart=boundary~sampleIndex
    timeStart=boundary~timeMs
    generation=generation+1
  end

  sampleEnd=boundaries~sampledFrames
  comparisonEnd=sampleEnd-1
  if sampleEnd>=sampleStart then do
    segmentId='S' || generation
    generationId='G' || generation
    tracks=.CameraLumaSegmentTrackSet~new(activity~temporalTracks,segmentId,comparisonStart,comparisonEnd)
    priors=.CameraLumaSegmentPriorSet~new(activity,segmentId,comparisonStart,comparisonEnd)
    segment=.CameraSourceSegment~new(segmentId,generationId,sampleStart,sampleEnd,comparisonStart,comparisonEnd,timeStart,boundaries~lastTimeMs,tracks,priors)
    ignoredSegment=segmented~addSegment(segment)
  end

  return segmented

::method close
  expose opened streamInfoLoaded library context
  if context \== .nil then do
    context~close
    context = .nil
  end
  if library \== .nil then do
    library~close
    library = .nil
  end
  opened = .false
  streamInfoLoaded = .false
  return 0

::method uninit
  ignored = self~close

::requires 'foreign.cls'
