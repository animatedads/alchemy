/* ooRexx Vision v0.1-dev5
 * Machine-vision knowledge surfaces.  This is deliberately not a viewing codec.
 * API: vision/0.1
 */

::class VisionPackedValues public
::method init
  expose bitsPerValue valueCount values maxValue
  use strict arg bitsPerValue, valueCount
  if \datatype(bitsPerValue, "W") | bitsPerValue < 1 then raise syntax 40.900 array("bitsPerValue must be positive")
  if \datatype(valueCount, "W") | valueCount < 0 then raise syntax 40.900 array("valueCount must be non-negative")
  numeric digits 50
  maxValue = 2 ** bitsPerValue - 1
  values = .array~new(valueCount)
  do i = 1 to valueCount
    values[i] = 0
  end
  return

::attribute bitsPerValue get
::attribute valueCount get

::method at
  expose values valueCount
  use strict arg index
  self~checkIndex(index)
  return values[index + 1]

::method put
  expose values maxValue
  use strict arg index, value
  self~checkIndex(index)
  if \datatype(value, "W") | value < 0 | value > maxValue then raise syntax 40.900 array("packed value out of range:" value)
  values[index + 1] = value
  return value

::method fill
  expose valueCount
  use strict arg value
  do i = 0 to valueCount - 1
    self~put(i, value)
  end
  return self

::method packedByteCount
  expose bitsPerValue valueCount
  return (bitsPerValue * valueCount + 7) % 8

::method packedBytes
  /* MSB-first continuous bit stream.  No ooRexx numeric-width dependency. */
  expose bitsPerValue valueCount values
  out = ""
  byte = 0
  used = 0
  do i = 1 to valueCount
    v = values[i]
    do b = bitsPerValue - 1 to 0 by -1
      divisor = 2 ** b
      bit = (v % divisor) // 2
      byte = byte * 2 + bit
      used = used + 1
      if used = 8 then do
        out = out || d2c(byte)
        byte = 0
        used = 0
      end
    end
  end
  if used > 0 then do
    byte = byte * (2 ** (8 - used))
    out = out || d2c(byte)
  end
  return out

::method fromPackedBytes class
  use strict arg bytes, bitsPerValue, valueCount
  obj = .VisionPackedValues~new(bitsPerValue, valueCount)
  bitAt = 0
  do i = 0 to valueCount - 1
    v = 0
    do b = 1 to bitsPerValue
      byteIndex = bitAt % 8
      within = bitAt // 8
      if byteIndex >= bytes~length then raise syntax 40.900 array("short packed Vision payload")
      byte = c2d(bytes~substr(byteIndex + 1, 1))
      divisor = 2 ** (7 - within)
      bit = (byte % divisor) // 2
      v = v * 2 + bit
      bitAt = bitAt + 1
    end
    obj~put(i, v)
  end
  return obj

::method checkIndex private
  expose valueCount
  use strict arg index
  if \datatype(index, "W") | index < 0 | index >= valueCount then raise syntax 40.900 array("packed index out of range:" index)


::class VisionValueModel public
::method init
  expose valueCount
  use strict arg valueCount
  if \datatype(valueCount, "W") | valueCount < 1 then raise syntax 40.900 array("valueCount must be positive")
  return
::attribute valueCount get

::method value
  use strict arg index
  return index

::method distance
  use strict arg a, b
  return abs(a - b)


::class VisionColourModel subclass VisionValueModel public
::method init
  expose red green blue valueCount
  use strict arg red, green, blue
  if red~items <> green~items | red~items <> blue~items then raise syntax 40.900 array("colour curves must have equal lengths")
  self~init:super(red~items)
  return

::method colour
  expose red green blue valueCount
  use strict arg index
  if index < 0 | index >= valueCount then raise syntax 40.900 array("colour index out of range")
  rgb = .array~new(3)
  rgb[1] = red[index + 1]; rgb[2] = green[index + 1]; rgb[3] = blue[index + 1]
  return rgb

::method distance
  use strict arg a, b
  ca = self~colour(a); cb = self~colour(b)
  dr = ca[1] - cb[1]; dg = ca[2] - cb[2]; db = ca[3] - cb[3]
  /* Squared Euclidean RGB distance: ordering-equivalent and avoids needless sqrt. */
  return dr * dr + dg * dg + db * db


::class VisionRegion public
::method init
  expose x y width height startTime endTime
  use strict arg x, y, width, height, startTime = .nil, endTime = .nil
  if width < 1 | height < 1 then raise syntax 40.900 array("VisionRegion dimensions must be positive")
  return
::attribute x get
::attribute y get
::attribute width get
::attribute height get
::attribute startTime get
::attribute endTime get

::method contains
  expose x y width height
  use strict arg px, py
  return px >= x & px < x + width & py >= y & py < y + height

::method intersects
  expose x y width height
  use strict arg other
  return x < other~x + other~width & x + width > other~x & y < other~y + other~height & y + height > other~y


::class VisionSurface public
::method init
  expose width height bitsPerPoint valueCount packed valueModel sourceRef region timestamp generation
  use strict arg width, height, bitsPerPoint, valueCount, valueModel = .nil
  if width < 1 | height < 1 then raise syntax 40.900 array("VisionSurface dimensions must be positive")
  if valueCount < 1 then raise syntax 40.900 array("VisionSurface valueCount must be positive")
  numeric digits 50
  if valueCount > 2 ** bitsPerPoint then raise syntax 40.900 array("valueCount exceeds bitsPerPoint capacity")
  packed = .VisionPackedValues~new(bitsPerPoint, width * height)
  sourceRef = .nil; region = .nil; timestamp = .nil; generation = 0
  return
::attribute width get
::attribute height get
::attribute bitsPerPoint get
::attribute valueCount get
::attribute valueModel get
::attribute sourceRef
::attribute region
::attribute timestamp
::attribute generation
::attribute packed get

::method at
  expose width height packed
  use strict arg x, y
  self~checkPoint(x, y)
  return packed~at(y * width + x)

::method put
  expose width height packed valueCount
  use strict arg x, y, value
  self~checkPoint(x, y)
  if value >= valueCount then raise syntax 40.900 array("VisionSurface value outside declared V:" value)
  return packed~put(y * width + x, value)

::method packedBytes
  expose packed
  return packed~packedBytes

::method checkPoint private
  expose width height
  use strict arg x, y
  if x < 0 | x >= width | y < 0 | y >= height then raise syntax 40.900 array("VisionSurface point out of range:" x y)


::class VisionFrame subclass VisionSurface public

::class VisionStream public
::method init
  expose frames sourceRef
  use strict arg sourceRef = .nil
  frames = .array~new
  return
::attribute sourceRef
::attribute frames get
::method append
  expose frames
  use strict arg frame
  frames~append(frame)
  return frames~items
::method frame
  expose frames
  use strict arg index
  return frames[index]
::method count
  expose frames
  return frames~items


::class VisionProcessor public
::method process abstract


::class VisionRegionRequest public
::method init
  expose sourceRef region startTime endTime requestedBits requestedValueCount requestedSpatialResolution purpose resultRef
  use strict arg sourceRef, region, startTime, endTime
  requestedBits = .nil; requestedValueCount = .nil; requestedSpatialResolution = "SOURCE"; purpose = .nil; resultRef = .nil
  return
::attribute sourceRef get
::attribute region get
::attribute startTime get
::attribute endTime get
::attribute requestedBits
::attribute requestedValueCount
::attribute requestedSpatialResolution
::attribute purpose
::attribute resultRef


::class VisionRegionMaterial public
::method init
  expose request sourceRef materialRef exactSourceRegion exactTimeRange transform resolution bits valueModel
  use strict arg request, materialRef
  sourceRef = request~sourceRef
  exactSourceRegion = request~region
  exactTimeRange = .array~of(request~startTime, request~endTime)
  transform = .nil; resolution = .nil; bits = .nil; valueModel = .nil
  return
::attribute request get
::attribute sourceRef get
::attribute materialRef get
::attribute exactSourceRegion
::attribute exactTimeRange
::attribute transform
::attribute resolution
::attribute bits
::attribute valueModel


/* Deterministic curve vocabulary.
 * IDs are 0..254.  A curve is reconstructed from its ID; no table is required
 * on the wire.  This dev2 generator deliberately uses integer arithmetic so
 * Rexx and accelerated Foreign Runtime implementations can be bit-identical.
 */
::class VisionCurveLibrary public
::method init
  expose libraryId
  use strict arg libraryId = "GENERAL-A"
  return
::attribute libraryId get

::method curve
  numeric digits 50
  use strict arg curveId
  if \datatype(curveId, "W") | curveId < 0 | curveId > 254 then raise syntax 40.900 array("curveId must be 0..254")
  levels = .array~new(26)
  levels[1] = 0
  if curveId = 0 then do
    do i = 1 to 24
      levels[i + 1] = (i * 255) % 25
    end
  end
  else do
    /* Positive deterministic interval weights.  Curve ID selects a shape. */
    weights = .array~new(25)
    total = 0
    state = curveId * 1103515245 + 12345
    uneven = 1 + (curveId // 9)
    do i = 1 to 25
      state = (state * 1103515245 + 12345) // 2147483647
      w = 1 + ((state // (3 + uneven)) + 1)
      weights[i] = w
      total = total + w
    end
    cumulative = 0
    do i = 1 to 24
      cumulative = cumulative + weights[i]
      levels[i + 1] = (cumulative * 255) % total
    end
  end
  levels[26] = 255
  return .VisionCurve~new(self, curveId, levels)


::class VisionCurve public
::method init
  expose library curveId levels
  use strict arg library, curveId, levels
  return
::attribute library get
::attribute curveId get
::attribute levels get
::method at
  expose levels
  use strict arg index
  if index < 0 | index > 25 then raise syntax 40.900 array("curve index out of range")
  return levels[index + 1]


::class VisionPaletteSelector public
::method init
  expose library redCurveId greenCurveId blueCurveId
  use strict arg library, redCurveId, greenCurveId, blueCurveId
  return
::attribute library get
::attribute redCurveId get
::attribute greenCurveId get
::attribute blueCurveId get

::method colourModel
  expose library redCurveId greenCurveId blueCurveId
  r = library~curve(redCurveId)
  g = library~curve(greenCurveId)
  b = library~curve(blueCurveId)
  return .VisionColourModel~new(r~levels, g~levels, b~levels)


::class VisionPaletteDistanceMatrix public
::method init
  expose model distances
  use strict arg model
  n = model~valueCount
  distances = .array~new(n * n)
  do a = 0 to n - 1
    do b = 0 to n - 1
      distances[a * n + b + 1] = model~distance(a, b)
    end
  end
  return
::attribute model get
::method distance
  expose model distances
  use strict arg a, b
  n = model~valueCount
  if a < 0 | a >= n | b < 0 | b >= n then raise syntax 40.900 array("palette distance index out of range")
  return distances[a * n + b + 1]


/* Lossless temporal evidence between two compatible Vision surfaces.
 * This is intentionally simple: a one-bit changed-cell mask plus N-bit values
 * for changed cells.  Compression/storage policy belongs above this object.
 */
::class VisionSurfaceDelta public
::method init
  expose width height bitsPerPoint valueCount changedMask changedValues changedCount
  use strict arg previous, current
  if previous~width <> current~width | previous~height <> current~height then raise syntax 40.900 array("delta surface dimensions differ")
  if previous~bitsPerPoint <> current~bitsPerPoint | previous~valueCount <> current~valueCount then raise syntax 40.900 array("delta surface value contract differs")
  width = current~width; height = current~height
  bitsPerPoint = current~bitsPerPoint; valueCount = current~valueCount
  count = width * height
  changedMask = .VisionPackedValues~new(1, count)
  changedCount = 0
  do i = 0 to count - 1
    if previous~packed~at(i) <> current~packed~at(i) then changedCount = changedCount + 1
  end
  changedValues = .VisionPackedValues~new(bitsPerPoint, changedCount)
  j = 0
  do i = 0 to count - 1
    pv = previous~packed~at(i); cv = current~packed~at(i)
    if pv <> cv then do
      changedMask~put(i, 1)
      changedValues~put(j, cv)
      j = j + 1
    end
  end
  return
::attribute width get
::attribute height get
::attribute bitsPerPoint get
::attribute valueCount get
::attribute changedMask get
::attribute changedValues get
::attribute changedCount get

::method changedFraction
  expose width height changedCount
  return changedCount / (width * height)

::method applyTo
  expose width height bitsPerPoint valueCount changedMask changedValues changedCount
  use strict arg previous
  if previous~width <> width | previous~height <> height then raise syntax 40.900 array("delta base dimensions differ")
  reconstructed = .VisionSurface~new(width, height, bitsPerPoint, valueCount, previous~valueModel)
  count = width * height
  j = 0
  do i = 0 to count - 1
    v = previous~packed~at(i)
    if changedMask~at(i) = 1 then do
      v = changedValues~at(j)
      j = j + 1
    end
    reconstructed~packed~put(i, v)
  end
  reconstructed~sourceRef = previous~sourceRef
  reconstructed~region = previous~region
  reconstructed~generation = previous~generation + 1
  return reconstructed



/* Connected change components.  These are observations, not classifications. */
::class VisionChangeRegion public
::method init
  expose region cellCount density
  use strict arg region, cellCount, density
::attribute region get
::attribute cellCount get
::attribute density get
::method x
  expose region
  return region~x
::method y
  expose region
  return region~y
::method width
  expose region
  return region~width
::method height
  expose region
  return region~height

::class VisionChangeRegionExtractor public
::method init
  expose connectivity minCells
  use strict arg connectivity = 8, minCells = 1
  if connectivity <> 4 & connectivity <> 8 then raise syntax 40.900 array("connectivity must be 4 or 8")
  if minCells < 1 then raise syntax 40.900 array("minCells must be positive")
::method extract
  expose connectivity minCells
  use strict arg delta
  w=delta~width; h=delta~height; count=w*h
  seen=.VisionPackedValues~new(1,count); regions=.array~new
  do seed=0 to count-1
    if delta~changedMask~at(seed)=1 & seen~at(seed)=0 then do
      q=.array~new; q~append(seed); seen~put(seed,1)
      head=1; cells=0; minX=w; minY=h; maxX=-1; maxY=-1
      do while head<=q~items
        idx=q[head]; head=head+1; x=idx//w; y=idx%w; cells=cells+1
        if x<minX then minX=x
        if y<minY then minY=y
        if x>maxX then maxX=x
        if y>maxY then maxY=y
        do dy=-1 to 1
          do dx=-1 to 1
            if dx=0 & dy=0 then iterate
            if connectivity=4 & abs(dx)+abs(dy)<>1 then iterate
            nx=x+dx; ny=y+dy
            if nx>=0 & nx<w & ny>=0 & ny<h then do
              ni=ny*w+nx
              if delta~changedMask~at(ni)=1 & seen~at(ni)=0 then do
                seen~put(ni,1); q~append(ni)
              end
            end
          end
        end
      end
      if cells>=minCells then do
        rw=maxX-minX+1; rh=maxY-minY+1
        r=.VisionRegion~new(minX,minY,rw,rh)
        regions~append(.VisionChangeRegion~new(r,cells,cells/(rw*rh)))
      end
    end
  end
  return regions


/* Stable Vision/world coordinates are authoritative. A sampling lattice only
 * describes where evidence was measured in that coordinate system.
 */
::class VisionSamplingLattice public
::method init
  expose geometry basisUX basisUY basisVX basisVY originX originY phaseU phaseV sampleDensity revision
  use strict arg geometry, basisUX, basisUY, basisVX, basisVY, originX=0, originY=0, phaseU=0, phaseV=0, sampleDensity=.nil, revision=1
  geometry=geometry~upper
  if geometry <> "HEX" & geometry <> "RECT" then raise syntax 40.900 array("geometry must be HEX or RECT")
  if sampleDensity=.nil then sampleDensity=1
::attribute geometry get
::attribute basisUX get
::attribute basisUY get
::attribute basisVX get
::attribute basisVY get
::attribute originX get
::attribute originY get
::attribute phaseU get
::attribute phaseV get
::attribute sampleDensity get
::attribute revision get

::method point
  expose basisUX basisUY basisVX basisVY originX originY phaseU phaseV
  use strict arg i,j
  u=i+phaseU; v=j+phaseV
  return .array~of(originX+u*basisUX+v*basisVX, originY+u*basisUY+v*basisVY)

::method withPhase
  expose geometry basisUX basisUY basisVX basisVY originX originY sampleDensity revision
  use strict arg u,v
  return .VisionSamplingLattice~new(geometry,basisUX,basisUY,basisVX,basisVY,originX,originY,u,v,sampleDensity,revision)


::class VisionSamplingTransform public
::method init
  expose parentLattice childLattice phaseOffset coveragePolicy
  use strict arg parentLattice, childLattice, phaseOffset, coveragePolicy="MINIMAX-UNCOVERED-RADIUS"
::attribute parentLattice get
::attribute childLattice get
::attribute phaseOffset get
::attribute coveragePolicy get


::class VisionCoveragePhase public
::method init
  expose u v uncoveredRadiusSquared
  use strict arg u,v,uncoveredRadiusSquared
::attribute u get
::attribute v get
::attribute uncoveredRadiusSquared get


/* Reference minimax optimiser:
 * phi* = argmin max distance(p, accumulated U candidate(phi)).
 * Domain probing is deterministic. Foreign Runtime may accelerate this exact
 * contract later; it must not redefine the geometry.
 */
::class VisionCoverageOptimizer public
::method choose
  use strict arg accumulated, childLattice, childWidth, childHeight, domain, phaseDivisions=8, probeDivisions=24
  if phaseDivisions<1 | probeDivisions<1 then raise syntax 40.900 array("coverage divisions must be positive")
  best=.nil
  do pu=0 to phaseDivisions-1
    do pv=0 to phaseDivisions-1
      u=(pu+0.5)/phaseDivisions; v=(pv+0.5)/phaseDivisions
      candidate=childLattice~withPhase(u,v)
      samples=.array~new
      do p over accumulated
        samples~append(p)
      end
      do j=0 to childHeight-1
        do i=0 to childWidth-1
          samples~append(candidate~point(i,j))
        end
      end
      score=self~uncoveredRadiusSquared(samples,domain,probeDivisions)
      if best=.nil then
        best=.VisionCoveragePhase~new(u,v,score)
      else if score<best~uncoveredRadiusSquared then
        best=.VisionCoveragePhase~new(u,v,score)
    end
  end
  return best

::method uncoveredRadiusSquared
  use strict arg samples,domain,probeDivisions
  worst=0
  do py=0 to probeDivisions
    y=domain~y+(py/probeDivisions)*domain~height
    do px=0 to probeDivisions
      x=domain~x+(px/probeDivisions)*domain~width
      nearest=.nil
      do sp over samples
        dx=x-sp[1]; dy=y-sp[2]; d=dx*dx+dy*dy
        if nearest=.nil then
          nearest=d
        else if d<nearest then
          nearest=d
      end
      if nearest>worst then worst=nearest
    end
  end
  return worst


/* Successive keyframes attack holes remaining after all earlier phases. */
::class VisionPhaseSequence public
::method init
  expose optimizer accumulated
  use strict arg optimizer=.nil
  if optimizer=.nil then optimizer=.VisionCoverageOptimizer~new
  accumulated=.array~new

::method seed
  expose accumulated
  use strict arg lattice,width,height
  do j=0 to height-1
    do i=0 to width-1
      accumulated~append(lattice~point(i,j))
    end
  end

::method next
  expose optimizer accumulated
  use strict arg lattice,width,height,domain,phaseDivisions=8,probeDivisions=24
  phase=optimizer~choose(accumulated,lattice,width,height,domain,phaseDivisions,probeDivisions)
  phased=lattice~withPhase(phase~u,phase~v)
  do j=0 to height-1
    do i=0 to width-1
      accumulated~append(phased~point(i,j))
    end
  end
  return phase


::class VisionKeyFrame public
::method init
  expose parent refined parentLattice refinedLattice samplingTransform timestamp
  use strict arg parent, refined, parentLattice, refinedLattice, samplingTransform
  timestamp=parent~timestamp
::attribute parent get
::attribute refined get
::attribute parentLattice get
::attribute refinedLattice get
::attribute samplingTransform get
::attribute timestamp get


/* Stable/world region -> refined samples intersecting that region.
 * No multiplication by a refinement factor occurs.
 */
::class VisionRefinedRegion public
::method init
  expose region lattice samples
  use strict arg region,lattice,sampleWidth,sampleHeight
  samples=.array~new
  do j=0 to sampleHeight-1
    do i=0 to sampleWidth-1
      p=lattice~point(i,j)
      if p[1]>=region~x & p[1]<(region~x+region~width) & p[2]>=region~y & p[2]<(region~y+region~height) then -
        samples~append(.array~of(i,j,p[1],p[2]))
    end
  end
::attribute region get
::attribute lattice get
::attribute samples get


/* Temporally accumulated evidence is never silently declared simultaneous.
 * WORLD is suitable for static scene evidence. Moving evidence is transformed
 * by Movement into TRACK coordinates before combination.
 */
::class VisionAccumulatedSample public
::method init
  expose point timestamp age confidence coordinateSpace trackRef
  use strict arg point,timestamp,age=0,confidence=1,coordinateSpace="WORLD",trackRef=.nil
  coordinateSpace=coordinateSpace~upper
  if coordinateSpace<>"WORLD" & coordinateSpace<>"TRACK" then raise syntax 40.900 array("coordinateSpace must be WORLD or TRACK")
::attribute point get
::attribute timestamp get
::attribute age get
::attribute confidence get
::attribute coordinateSpace get
::attribute trackRef get

/* Policy-free Area of Interest candidate. */
::class VisionAreaOfInterest public
::method init
  expose region reason score evidence
  use strict arg region, reason="change", score=0, evidence=.nil
::attribute region get
::attribute reason get
::attribute score get
::attribute evidence get
::method request
  expose region
  use strict arg sourceRef, bits, valueCount, spatialLevel="SOURCE"
  request=.VisionRegionRequest~new(sourceRef,region,region~startTime,region~endTime)
  request~requestedSpatialResolution=spatialLevel
  request~requestedBits=bits
  request~requestedValueCount=valueCount
  return request

::class VisionAreaOfInterestDetector public
::method init
  expose regionExtractor minimumDensity
  use strict arg regionExtractor=.nil, minimumDensity=0
  if regionExtractor=.nil then regionExtractor=.VisionChangeRegionExtractor~new(8,2)
::method fromDelta
  expose regionExtractor minimumDensity
  use strict arg delta, timeStart=.nil, timeEnd=.nil
  changes=regionExtractor~extract(delta); areas=.array~new
  do c over changes
    if c~density>=minimumDensity then do
      r=.VisionRegion~new(c~x,c~y,c~width,c~height,timeStart,timeEnd)
      areas~append(.VisionAreaOfInterest~new(r,"coherent-change",c~cellCount*c~density,c))
    end
  end
  return areas


::class VisionTrackTransform public
::method init
 expose trackRef worldX worldY trackX trackY revision
 use strict arg trackRef,worldX,worldY,trackX=0,trackY=0,revision=1
::attribute trackRef get
::attribute revision get
::method worldToTrack
 expose worldX worldY trackX trackY
 use strict arg point
 return .array~of(point[1]-worldX+trackX,point[2]-worldY+trackY)

::class VisionTrackObservation public
::method init
 expose trackRef region timestamp confidence transform evidence
 use strict arg trackRef,region,timestamp,confidence,transform,evidence=.nil
::attribute trackRef get
::attribute region get
::attribute timestamp get
::attribute confidence get
::attribute transform get
::attribute evidence get

::class VisionTrackEvidenceAccumulator public
::method init
 expose trackRef samples observations
 use strict arg trackRef
 samples=.array~new; observations=.array~new
::attribute trackRef get
::attribute samples get
::attribute observations get
::method addObservation
 expose trackRef samples observations
 use strict arg observation,lattice,sampleWidth,sampleHeight
 if observation~trackRef<>trackRef then raise syntax 40.900 array("wrong track")
 observations~append(observation)
 covered=.VisionRefinedRegion~new(observation~region,lattice,sampleWidth,sampleHeight)
 do e over covered~samples
  tp=observation~transform~worldToTrack(.array~of(e[3],e[4]))
  samples~append(.VisionAccumulatedSample~new(tp,observation~timestamp,0,observation~confidence,"TRACK",trackRef))
 end
 return covered~samples~items
::method ageAt
 expose samples
 use strict arg now
 aged=.array~new
 do x over samples
  aged~append(.VisionAccumulatedSample~new(x~point,x~timestamp,now-x~timestamp,x~confidence,"TRACK",x~trackRef))
 end
 return aged

::class VisionPersistentRegion public
::method init
 expose trackRef firstTimestamp lastTimestamp observationCount confidence observations
 use strict arg trackRef
 firstTimestamp=.nil; lastTimestamp=.nil; observationCount=0; confidence=0; observations=.array~new
::attribute trackRef get
::attribute firstTimestamp get
::attribute lastTimestamp get
::attribute observationCount get
::attribute confidence get
::attribute observations get
::method observe
 expose firstTimestamp lastTimestamp observationCount confidence observations
 use strict arg observation
 observations~append(observation)
 if firstTimestamp=.nil then
  firstTimestamp=observation~timestamp
 else if observation~timestamp<firstTimestamp then
  firstTimestamp=observation~timestamp
 if lastTimestamp=.nil then
  lastTimestamp=observation~timestamp
 else if observation~timestamp>lastTimestamp then
  lastTimestamp=observation~timestamp
 observationCount=observationCount+1
 confidence=confidence+(observation~confidence-confidence)/observationCount
::method duration
 expose firstTimestamp lastTimestamp
 if firstTimestamp=.nil then return 0
 return lastTimestamp-firstTimestamp

::class VisionRegionAssociation public
::method overlapRatio
 use strict arg a,b
 left=a~x~max(b~x); top=a~y~max(b~y)
 right=(a~x+a~width)~min(b~x+b~width); bottom=(a~y+a~height)~min(b~y+b~height)
 if right<=left | bottom<=top then return 0
 intersection=(right-left)*(bottom-top)
 union=a~width*a~height+b~width*b~height-intersection
 if union=0 then return 0
 return intersection/union
