/* Canonical Camera temporal motion classes extracted from CameraFFmpegMediaSource.cls
 * (animatedads/alchemy), with only ID-directory lookup optimisation.
 * No altered connected-component or temporal-association policies.
 * v0.18 qualified against first 24 real Manly samples (byte-identical to array-scan).
 */
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
  expose sourcePath comparisonCount regionCount trackCount persistentTrackCount longestTrackObservations tracks trackIndex nextTrackId previousRegions previousTrackIds gridColumns gridRows maximumLinkDistance
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
  trackIndex = .directory~new
  nextTrackId = 1
  previousRegions = .array~new
  previousTrackIds = .array~new

::method trackById private
  expose trackIndex
  use arg id
  return trackIndex[id]

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
  expose comparisonCount regionCount trackCount persistentTrackCount longestTrackObservations tracks trackIndex nextTrackId previousRegions previousTrackIds maximumLinkDistance
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
      trackIndex[trackId] = track
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


