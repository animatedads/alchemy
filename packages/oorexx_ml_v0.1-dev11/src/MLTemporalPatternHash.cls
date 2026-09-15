/* MLTemporalPatternHash.cls - cylindrical temporal pattern hashing.
 *
 * dev9 asked: "where else did something shaped like this happen?"
 * dev10 adds the independent question "did it happen with the same timing?"
 *
 * A temporal series is mapped onto a circular cylinder:
 *   angle  = normalized event progress around one revolution
 *   radius = per-channel value above that channel's minimum, normalized to 0..1
 *   height = elapsed event time above the base plane
 *
 * Each adjacent pair therefore defines a real 3-D direction vector.  The
 * retained signature includes radial shape, elapsed-time gaps, planar bearing,
 * elevation and 3-D turn angle.  Multi-channel series retain each channel
 * independently; they are never collapsed into a magic scalar.
 *
 * Difference is significance ordered: weighted local differences are sorted
 * largest-first and compared lexicographically.  One important structural or
 * temporal disagreement therefore outranks any collection of smaller ones.
 */

::class MLTemporalPatternDescendingComparator private
::method compare
  use strict arg a,b
  if a+0>b+0 then return -1
  if a+0<b+0 then return 1
  return 0

::class MLTemporalPatternPolicy public
::method init
  expose angleCount radialBins timeBins bearingBins elevationBins turnBins radiusWeight timeWeight bearingWeight elevationWeight turnWeight timeShiftInvariant timeScaleInvariant timeQuantum
  use strict arg angleCountValue=36,radialBinsValue=32,timeBinsValue=32,bearingBinsValue=72,elevationBinsValue=36,turnBinsValue=36,radiusWeightValue=1,timeWeightValue=8,bearingWeightValue=4,elevationWeightValue=8,turnWeightValue=10,timeShiftInvariantValue=.true,timeScaleInvariantValue=.true,timeQuantumValue=1
  if angleCountValue<8 | angleCountValue\=trunc(angleCountValue) then raise syntax 88.900 array('temporal pattern angleCount must be an integer >= 8')
  if radialBinsValue<4 | radialBinsValue\=trunc(radialBinsValue) then raise syntax 88.900 array('temporal pattern radialBins must be an integer >= 4')
  if timeBinsValue<4 | timeBinsValue\=trunc(timeBinsValue) then raise syntax 88.900 array('temporal pattern timeBins must be an integer >= 4')
  if bearingBinsValue<8 | bearingBinsValue\=trunc(bearingBinsValue) then raise syntax 88.900 array('temporal pattern bearingBins must be an integer >= 8')
  if elevationBinsValue<8 | elevationBinsValue\=trunc(elevationBinsValue) then raise syntax 88.900 array('temporal pattern elevationBins must be an integer >= 8')
  if turnBinsValue<8 | turnBinsValue\=trunc(turnBinsValue) then raise syntax 88.900 array('temporal pattern turnBins must be an integer >= 8')
  do w over .array~of(radiusWeightValue,timeWeightValue,bearingWeightValue,elevationWeightValue,turnWeightValue)
    if w<1 | w\=trunc(w) then raise syntax 88.900 array('temporal pattern significance weights must be positive integers')
  end
  if timeQuantumValue<=0 then raise syntax 88.900 array('temporal pattern timeQuantum must be positive')
  if timeScaleInvariantValue=.true & timeShiftInvariantValue\=.true then raise syntax 88.900 array('time-scale invariance requires time-shift invariance')
  angleCount=angleCountValue+0; radialBins=radialBinsValue+0; timeBins=timeBinsValue+0; bearingBins=bearingBinsValue+0; elevationBins=elevationBinsValue+0; turnBins=turnBinsValue+0
  radiusWeight=radiusWeightValue+0; timeWeight=timeWeightValue+0; bearingWeight=bearingWeightValue+0; elevationWeight=elevationWeightValue+0; turnWeight=turnWeightValue+0
  timeShiftInvariant=(timeShiftInvariantValue=.true); timeScaleInvariant=(timeScaleInvariantValue=.true); timeQuantum=timeQuantumValue+0
::method angleCount; expose angleCount; return angleCount
::method radialBins; expose radialBins; return radialBins
::method timeBins; expose timeBins; return timeBins
::method bearingBins; expose bearingBins; return bearingBins
::method elevationBins; expose elevationBins; return elevationBins
::method turnBins; expose turnBins; return turnBins
::method radiusWeight; expose radiusWeight; return radiusWeight
::method timeWeight; expose timeWeight; return timeWeight
::method bearingWeight; expose bearingWeight; return bearingWeight
::method elevationWeight; expose elevationWeight; return elevationWeight
::method turnWeight; expose turnWeight; return turnWeight
::method timeShiftInvariant; expose timeShiftInvariant; return timeShiftInvariant
::method timeScaleInvariant; expose timeScaleInvariant; return timeScaleInvariant
::method timeQuantum; expose timeQuantum; return timeQuantum
::method canonicalText
  expose angleCount radialBins timeBins bearingBins elevationBins turnBins radiusWeight timeWeight bearingWeight elevationWeight turnWeight timeShiftInvariant timeScaleInvariant timeQuantum
  return 'TEMPORAL_PATTERN_POLICY=angles='||angleCount||'|bins='||radialBins||','||timeBins||','||bearingBins||','||elevationBins||','||turnBins||'|weights='||radiusWeight||','||timeWeight||','||bearingWeight||','||elevationWeight||','||turnWeight||'|timeShiftInvariant='||timeShiftInvariant||'|timeScaleInvariant='||timeScaleInvariant||'|timeQuantum='||timeQuantum

::class MLTemporalPatternSeries public
::method init
  expose seriesId times channelNames channels channelWeights
  use strict arg timeValues,nameValues,channelValues,weightValues=.nil,seriesIdValue='TEMPORAL-SERIES'
  if \timeValues~isA(.Array) | timeValues~items<3 then raise syntax 88.900 array('temporal pattern series requires at least three event times')
  if \nameValues~isA(.Array) | nameValues~items<1 then raise syntax 88.900 array('temporal pattern series requires channel names')
  if \channelValues~isA(.Array) | channelValues~items<>nameValues~items then raise syntax 88.900 array('temporal pattern channel count mismatch')
  if weightValues==.nil then do; weightValues=.array~new; do i=1 to nameValues~items; weightValues~append(1); end; end
  if \weightValues~isA(.Array) | weightValues~items<>nameValues~items then raise syntax 88.900 array('temporal pattern channel-weight count mismatch')
  times=.array~new; previous=.nil
  do t over timeValues
    x=t+0
    if previous\==.nil then if x<=previous then raise syntax 88.900 array('temporal event times must be strictly increasing')
    times~append(x); previous=x
  end
  channelNames=.array~new; channels=.array~new; channelWeights=.array~new; seen=.directory~new
  do i=1 to nameValues~items
    name=nameValues[i]~string
    if name='' then raise syntax 88.900 array('temporal pattern channel name may not be empty')
    if seen~hasIndex(name) then raise syntax 88.900 array('temporal pattern channel names must be unique',name)
    seen[name]=1
    v=channelValues[i]
    if \v~isA(.Array) | v~items<>times~items then raise syntax 88.900 array('temporal pattern channel length mismatch',name)
    copy=.array~new; do x over v; copy~append(x+0); end
    w=weightValues[i]+0; if w<=0 then raise syntax 88.900 array('temporal pattern channel weight must be positive',name)
    channelNames~append(name); channels~append(.MLFrozenVector~new(copy)); channelWeights~append(w)
  end
  seriesId=seriesIdValue
::method scalar class
  use strict arg times,values,seriesId='TEMPORAL-SCALAR'
  return self~new(times,.array~of('VALUE'),.array~of(values),.array~of(1),seriesId)
::method id; expose seriesId; return seriesId
::method eventCount; expose times; return times~items
::method channelCount; expose channelNames; return channelNames~items
::method times; expose times; out=.array~new; do x over times; out~append(x); end; return out
::method time; expose times; use strict arg i; return times[i]
::method channelNames; expose channelNames; out=.array~new; do x over channelNames; out~append(x); end; return out
::method channelName; expose channelNames; use strict arg i; return channelNames[i]
::method channelWeight; expose channelWeights; use strict arg i; return channelWeights[i]
::method channel
  expose channelNames channels
  use strict arg nameOrIndex
  if datatype(nameOrIndex,'W') then do; i=nameOrIndex+0; if i<1 | i>channels~items then raise syntax 88.900 array('temporal channel index out of range'); return channels[i]~toArray; end
  name=nameOrIndex~string
  do i=1 to channelNames~items; if channelNames[i]==name then return channels[i]~toArray; end
  raise syntax 88.900 array('unknown temporal pattern channel',name)
::method canonicalText
  expose seriesId times channelNames channelWeights
  return 'TEMPORAL_SERIES='||seriesId||'|events='||times~items||'|channels='||channelNames~items||'|firstTime='||times[1]||'|lastTime='||times[times~items]

::class MLCylindricalTemporalPoint public
::method init
  expose channel angleDegrees radius height x y
  use strict arg channelValue,angleValue,radiusValue,heightValue,xValue,yValue
  channel=channelValue; angleDegrees=angleValue+0; radius=radiusValue+0; height=heightValue+0; x=xValue+0; y=yValue+0
::method channel; expose channel; return channel
::method angleDegrees; expose angleDegrees; return angleDegrees
::method radius; expose radius; return radius
::method height; expose height; return height
::method x; expose x; return x
::method y; expose y; return y
::method canonicalText
  expose channel angleDegrees radius height
  return 'CYLINDER_POINT=channel='||channel||'|angle='||angleDegrees||'|radius='||radius||'|height='||height

::class MLTemporalDirectionVector public
::method init
  expose channel segment dx dy dz bearingDegrees elevationDegrees length
  use strict arg channelValue,segmentValue,dxValue,dyValue,dzValue,bearingValue,elevationValue,lengthValue
  channel=channelValue; segment=segmentValue; dx=dxValue+0; dy=dyValue+0; dz=dzValue+0; bearingDegrees=bearingValue+0; elevationDegrees=elevationValue+0; length=lengthValue+0
::method channel; expose channel; return channel
::method segment; expose segment; return segment
::method dx; expose dx; return dx
::method dy; expose dy; return dy
::method dz; expose dz; return dz
::method bearingDegrees; expose bearingDegrees; return bearingDegrees
::method elevationDegrees; expose elevationDegrees; return elevationDegrees
::method length; expose length; return length
::method canonicalText
  expose channel segment bearingDegrees elevationDegrees length
  return 'TEMPORAL_VECTOR=channel='||channel||'|segment='||segment||'|bearing='||bearingDegrees||'|elevation='||elevationDegrees||'|length='||length

::class MLTemporalPatternHash public
::method init
  expose schemaId seriesId channelNames channelWeights radii radialCoordinates heights timeCoordinates timeGaps timeOriginCoordinate bearings elevations turns sourceMinima sourceMaxima sourceStart sourceEnd sourceCount key vectors points
  use strict arg schemaIdValue,seriesIdValue,channelNameValues,channelWeightValues,radiusValues,radialCoordinateValues,heightValues,timeCoordinateValues,timeGapValues,timeOriginCoordinateValue,bearingValues,elevationValues,turnValues,minimumValues,maximumValues,sourceStartValue,sourceEndValue,sourceCountValue,keyValue,vectorValues,pointValues
  schemaId=schemaIdValue; seriesId=seriesIdValue; channelNames=.MLFrozenVector~new(channelNameValues); channelWeights=.MLFrozenVector~new(channelWeightValues)
  radii=.MLFrozenVector~new(radiusValues); radialCoordinates=.MLFrozenVector~new(radialCoordinateValues); heights=.MLFrozenVector~new(heightValues); timeCoordinates=.MLFrozenVector~new(timeCoordinateValues); timeGaps=.MLFrozenVector~new(timeGapValues); timeOriginCoordinate=timeOriginCoordinateValue+0
  bearings=.MLFrozenVector~new(bearingValues); elevations=.MLFrozenVector~new(elevationValues); turns=.MLFrozenVector~new(turnValues); sourceMinima=.MLFrozenVector~new(minimumValues); sourceMaxima=.MLFrozenVector~new(maximumValues)
  sourceStart=sourceStartValue; sourceEnd=sourceEndValue; sourceCount=sourceCountValue; key=keyValue; vectors=.MLFrozenVector~new(vectorValues); points=.MLFrozenVector~new(pointValues)
::method schemaId; expose schemaId; return schemaId
::method seriesId; expose seriesId; return seriesId
::method channelCount; expose channelNames; return channelNames~items
::method channelName; expose channelNames; use strict arg i; return channelNames[i]
::method channelWeight; expose channelWeights; use strict arg i; return channelWeights[i]
::method radii; expose radii; use strict arg channelIndex; return radii[channelIndex]~toArray
::method radialCoordinates; expose radialCoordinates; use strict arg channelIndex; return radialCoordinates[channelIndex]~toArray
::method radialCoordinate; expose radialCoordinates; use strict arg channelIndex,i; return radialCoordinates[channelIndex][i]
::method heights; expose heights; return heights~toArray
::method timeCoordinates; expose timeCoordinates; return timeCoordinates~toArray
::method timeGaps; expose timeGaps; return timeGaps~toArray
::method timeGap; expose timeGaps; use strict arg i; return timeGaps[i]
::method timeOriginCoordinate; expose timeOriginCoordinate; return timeOriginCoordinate
::method bearings; expose bearings; use strict arg channelIndex; return bearings[channelIndex]~toArray
::method bearing; expose bearings; use strict arg channelIndex,i; return bearings[channelIndex][i]
::method elevations; expose elevations; use strict arg channelIndex; return elevations[channelIndex]~toArray
::method elevation; expose elevations; use strict arg channelIndex,i; return elevations[channelIndex][i]
::method turns; expose turns; use strict arg channelIndex; return turns[channelIndex]~toArray
::method turn; expose turns; use strict arg channelIndex,i; return turns[channelIndex][i]
::method sourceMinimum; expose sourceMinima; use strict arg channelIndex; return sourceMinima[channelIndex]
::method sourceMaximum; expose sourceMaxima; use strict arg channelIndex; return sourceMaxima[channelIndex]
::method sourceStart; expose sourceStart; return sourceStart
::method sourceEnd; expose sourceEnd; return sourceEnd
::method sourceDuration; expose sourceStart sourceEnd; return sourceEnd-sourceStart
::method sourceCount; expose sourceCount; return sourceCount
::method key; expose key; return key
::method vectors; expose vectors; return vectors~toArray
::method points; expose points; return points~toArray
::method canonicalText
  expose schemaId seriesId sourceStart sourceEnd sourceCount key
  return 'TEMPORAL_PATTERN_HASH='||schemaId||'|series='||seriesId||'|events='||sourceCount||'|time='||sourceStart||':'||sourceEnd||'|key='||key
::method string; return self~canonicalText

::class MLTemporalPatternDifference public
::method init
  expose orderedDeltas dominantDelta totalDelta radiusMax timeMax bearingMax elevationMax turnMax dominantKind dominantChannel
  use strict arg orderedValues,dominantValue,totalValue,radiusMaxValue,timeMaxValue,bearingMaxValue,elevationMaxValue,turnMaxValue,dominantKindValue,dominantChannelValue
  orderedDeltas=.MLFrozenVector~new(orderedValues); dominantDelta=dominantValue; totalDelta=totalValue; radiusMax=radiusMaxValue; timeMax=timeMaxValue; bearingMax=bearingMaxValue; elevationMax=elevationMaxValue; turnMax=turnMaxValue; dominantKind=dominantKindValue; dominantChannel=dominantChannelValue
::method orderedDeltas; expose orderedDeltas; return orderedDeltas~toArray
::method dominantDelta; expose dominantDelta; return dominantDelta
::method totalDelta; expose totalDelta; return totalDelta
::method radiusMax; expose radiusMax; return radiusMax
::method timeMax; expose timeMax; return timeMax
::method bearingMax; expose bearingMax; return bearingMax
::method elevationMax; expose elevationMax; return elevationMax
::method turnMax; expose turnMax; return turnMax
::method dominantKind; expose dominantKind; return dominantKind
::method dominantChannel; expose dominantChannel; return dominantChannel
::method exact; expose dominantDelta; return dominantDelta=0
::method compare
  expose orderedDeltas totalDelta
  use strict arg other
  a=orderedDeltas; b=other~orderedDeltas; n=a~items; if b~items<n then n=b~items
  do i=1 to n
    if a[i]<b[i] then return -1
    if a[i]>b[i] then return 1
  end
  if a~items<b~items then return -1
  if a~items>b~items then return 1
  if totalDelta<other~totalDelta then return -1
  if totalDelta>other~totalDelta then return 1
  return 0
::method canonicalText
  expose dominantDelta totalDelta radiusMax timeMax bearingMax elevationMax turnMax dominantKind dominantChannel
  return 'TEMPORAL_PATTERN_DIFFERENCE=dominant='||dominantDelta||'|kind='||dominantKind||'|channel='||dominantChannel||'|total='||totalDelta||'|radiusMax='||radiusMax||'|timeMax='||timeMax||'|bearingMax='||bearingMax||'|elevationMax='||elevationMax||'|turnMax='||turnMax

::class MLCylindricalTemporalPatternSchema public
::method init
  expose schemaId policy
  use strict arg policyValue=.nil,schemaIdValue='CYLINDRICAL-TEMPORAL-PATTERN/1'
  if policyValue==.nil then policyValue=.MLTemporalPatternPolicy~new
  if \policyValue~isA(.MLTemporalPatternPolicy) then raise syntax 88.900 array('temporal pattern schema requires MLTemporalPatternPolicy')
  schemaId=schemaIdValue; policy=policyValue
::method id; expose schemaId; return schemaId
::method policy; expose policy; return policy
::method encode
  expose schemaId policy
  use strict arg series
  if \series~isA(.MLTemporalPatternSeries) then raise syntax 88.900 array('temporal pattern encode requires MLTemporalPatternSeries')
  ignored=self~ensureMath
  n=policy~angleCount; rawTimes=series~times; sampledTimes=self~linearResample(rawTimes,n)
  sourceStart=rawTimes[1]; sourceEnd=rawTimes[rawTimes~items]; duration=sourceEnd-sourceStart
  heights=.array~new
  do t over sampledTimes
    elapsed=t
    if policy~timeShiftInvariant then elapsed=t-sourceStart
    if policy~timeScaleInvariant then do; if duration=0 then z=0; else z=(t-sourceStart)/duration; end
    else z=elapsed/policy~timeQuantum
    heights~append(z)
  end
  timeCoords=.array~new
  if policy~timeScaleInvariant then do
    do z over heights; q=trunc(z*(policy~timeBins-1)+.5); if q<0 then q=0; if q>=policy~timeBins then q=policy~timeBins-1; timeCoords~append(q); end
  end
  else do; do z over heights; timeCoords~append(trunc(z+.5)); end; end
  timeGaps=.array~new
  do i=1 to n-1; timeGaps~append(timeCoords[i+1]-timeCoords[i]); end
  originCoord=0; if \policy~timeShiftInvariant then originCoord=trunc(sourceStart/policy~timeQuantum+.5)

  allRadii=.array~new; allCoords=.array~new; allBearings=.array~new; allElevations=.array~new; allTurns=.array~new; minima=.array~new; maxima=.array~new; allVectors=.array~new; allPoints=.array~new
  do c=1 to series~channelCount
    values=series~channel(c); sampled=self~linearResample(values,n); minimum=.nil; maximum=.nil
    do x over values; if minimum==.nil | x<minimum then minimum=x; if maximum==.nil | x>maximum then maximum=x; end
    minima~append(minimum); maxima~append(maximum)
    radii=.array~new; coords=.array~new
    if maximum=minimum then do i=1 to n; radii~append(0); coords~append(0); end
    else do x over sampled
      r=(x-minimum)/(maximum-minimum); radii~append(r); q=trunc(r*(policy~radialBins-1)+.5); if q<0 then q=0; if q>=policy~radialBins then q=policy~radialBins-1; coords~append(q)
    end
    points=.array~new
    do i=1 to n
      angle=360*(i-1)/n; x=radii[i]*RxCalcCos(angle,12,'D'); y=radii[i]*RxCalcSin(angle,12,'D')
      p=.MLCylindricalTemporalPoint~new(series~channelName(c),angle,radii[i],heights[i],x,y); points~append(p); allPoints~append(p)
    end
    bearings=.array~new; elevations=.array~new; vectors=.array~new
    do i=1 to n-1
      p1=points[i]; p2=points[i+1]; dx=p2~x-p1~x; dy=p2~y-p1~y; dz=p2~height-p1~height
      horizontal=RxCalcSqrt(dx*dx+dy*dy); length=RxCalcSqrt(dx*dx+dy*dy+dz*dz)
      bearing=self~bearing(dx,dy); elevation=self~elevation(horizontal,dz)
      bq=trunc(bearing/360*policy~bearingBins+.5); do while bq>=policy~bearingBins; bq=bq-policy~bearingBins; end; if bq<0 then bq=bq+policy~bearingBins
      eq=trunc((elevation+90)/180*(policy~elevationBins-1)+.5); if eq<0 then eq=0; if eq>=policy~elevationBins then eq=policy~elevationBins-1
      bearings~append(bq); elevations~append(eq)
      v=.MLTemporalDirectionVector~new(series~channelName(c),i,dx,dy,dz,bearing,elevation,length); vectors~append(v); allVectors~append(v)
    end
    turns=.array~new
    do i=1 to vectors~items-1
      a=vectors[i]; b=vectors[i+1]
      if a~length=0 | b~length=0 then turn=0
      else do
        cosine=(a~dx*b~dx+a~dy*b~dy+a~dz*b~dz)/(a~length*b~length); if cosine>1 then cosine=1; if cosine< -1 then cosine=-1
        turn=RxCalcArcCos(cosine,12,'D')
      end
      tq=trunc(turn/180*(policy~turnBins-1)+.5); if tq<0 then tq=0; if tq>=policy~turnBins then tq=policy~turnBins-1; turns~append(tq)
    end
    allRadii~append(.MLFrozenVector~new(radii)); allCoords~append(.MLFrozenVector~new(coords)); allBearings~append(.MLFrozenVector~new(bearings)); allElevations~append(.MLFrozenVector~new(elevations)); allTurns~append(.MLFrozenVector~new(turns))
  end
  names=series~channelNames; weights=.array~new; do c=1 to series~channelCount; weights~append(series~channelWeight(c)); end
  key=self~keyFor(names,allCoords,timeGaps,originCoord,allBearings,allElevations,allTurns)
  return .MLTemporalPatternHash~new(schemaId,series~id,names,weights,allRadii,allCoords,heights,timeCoords,timeGaps,originCoord,allBearings,allElevations,allTurns,minima,maxima,sourceStart,sourceEnd,series~eventCount,key,allVectors,allPoints)
::method difference
  expose schemaId policy
  use strict arg left,right
  if left~schemaId\==schemaId | right~schemaId\==schemaId then raise syntax 88.900 array('temporal pattern hash schema mismatch')
  if left~channelCount<>right~channelCount then raise syntax 88.900 array('temporal pattern channel count mismatch')
  weighted=.array~new; radiusMax=0; timeMax=0; bearingMax=0; elevationMax=0; turnMax=0; total=0; dominant=0; dominantKind='NONE'; dominantChannel='NONE'
  lg=left~timeGaps; rg=right~timeGaps
  if lg~items<>rg~items then raise syntax 88.900 array('temporal pattern time width mismatch')
  do i=1 to lg~items
    d=abs(lg[i]-rg[i]); if d>timeMax then timeMax=d; w=d*policy~timeWeight; weighted~append(w); total=total+w; if w>dominant then do; dominant=w; dominantKind='TIME_GAP'; dominantChannel='TIME'; end
  end
  d=abs(left~timeOriginCoordinate-right~timeOriginCoordinate); if d>timeMax then timeMax=d; w=d*policy~timeWeight; weighted~append(w); total=total+w; if w>dominant then do; dominant=w; dominantKind='TIME_ORIGIN'; dominantChannel='TIME'; end
  do c=1 to left~channelCount
    if left~channelName(c)\==right~channelName(c) then raise syntax 88.900 array('temporal pattern channel identity mismatch',left~channelName(c),right~channelName(c))
    channelScale=left~channelWeight(c); if right~channelWeight(c)<>channelScale then raise syntax 88.900 array('temporal pattern channel weight mismatch',left~channelName(c))
    lr=left~radialCoordinates(c); rr=right~radialCoordinates(c)
    do i=1 to lr~items
      d=abs(lr[i]-rr[i]); if d>radiusMax then radiusMax=d; w=d*policy~radiusWeight*channelScale; weighted~append(w); total=total+w; if w>dominant then do; dominant=w; dominantKind='RADIUS'; dominantChannel=left~channelName(c); end
    end
    lb=left~bearings(c); rb=right~bearings(c)
    do i=1 to lb~items
      d=self~circularDistance(lb[i],rb[i],policy~bearingBins); if d>bearingMax then bearingMax=d; w=d*policy~bearingWeight*channelScale; weighted~append(w); total=total+w; if w>dominant then do; dominant=w; dominantKind='BEARING'; dominantChannel=left~channelName(c); end
    end
    le=left~elevations(c); re=right~elevations(c)
    do i=1 to le~items
      d=abs(le[i]-re[i]); if d>elevationMax then elevationMax=d; w=d*policy~elevationWeight*channelScale; weighted~append(w); total=total+w; if w>dominant then do; dominant=w; dominantKind='ELEVATION'; dominantChannel=left~channelName(c); end
    end
    lt=left~turns(c); rt=right~turns(c)
    do i=1 to lt~items
      d=abs(lt[i]-rt[i]); if d>turnMax then turnMax=d; w=d*policy~turnWeight*channelScale; weighted~append(w); total=total+w; if w>dominant then do; dominant=w; dominantKind='TURN'; dominantChannel=left~channelName(c); end
    end
  end
  weighted~sortWith(.MLTemporalPatternDescendingComparator~new)
  return .MLTemporalPatternDifference~new(weighted,dominant,total,radiusMax,timeMax,bearingMax,elevationMax,turnMax,dominantKind,dominantChannel)
::method canonicalText
  expose schemaId policy
  return 'TEMPORAL_PATTERN_SCHEMA='||schemaId||'|'||policy~canonicalText
::method linearResample private
  use strict arg values,targetCount
  out=.array~new; sourceCount=values~items; numeric digits 40
  if targetCount=1 then do; out~append(values[1]); return out; end
  do i=1 to targetCount
    pos=(i-1)*(sourceCount-1)/(targetCount-1); lo=trunc(pos)+1; frac=pos-trunc(pos); hi=lo+1; if hi>sourceCount then hi=sourceCount
    out~append(values[lo]+frac*(values[hi]-values[lo]))
  end
  return out
::method bearing private
  use strict arg dx,dy
  if dx=0 then do; if dy>0 then return 90; if dy<0 then return 270; return 0; end
  a=RxCalcArcTan(abs(dy/dx),12,'D')
  if dx>0 & dy>=0 then return a
  if dx<0 & dy>=0 then return 180-a
  if dx<0 & dy<0 then return 180+a
  return 360-a
::method elevation private
  use strict arg horizontal,dz
  if horizontal=0 then do; if dz>0 then return 90; if dz<0 then return -90; return 0; end
  return RxCalcArcTan(dz/horizontal,12,'D')
::method circularDistance private
  use strict arg a,b,modulus
  d=abs(a-b); x=modulus-d; if x<d then d=x; return d
::method keyFor private
  use strict arg names,coords,timeGaps,originCoord,bearings,elevations,turns
  s='O['||originCoord||']T['; do i=1 to timeGaps~items; if i>1 then s=s||','; s=s||timeGaps[i]; end; s=s||']'
  do c=1 to names~items
    s=s||'|'||names[c]||':R['; a=coords[c]; do i=1 to a~items; if i>1 then s=s||','; s=s||a[i]; end
    s=s||']B['; a=bearings[c]; do i=1 to a~items; if i>1 then s=s||','; s=s||a[i]; end
    s=s||']E['; a=elevations[c]; do i=1 to a~items; if i>1 then s=s||','; s=s||a[i]; end
    s=s||']K['; a=turns[c]; do i=1 to a~items; if i>1 then s=s||','; s=s||a[i]; end; s=s||']'
  end
  return s
::method ensureMath private
  call RxFuncAdd 'RxCalcSin','rxmath','RxCalcSin'; call RxFuncAdd 'RxCalcCos','rxmath','RxCalcCos'; call RxFuncAdd 'RxCalcSqrt','rxmath','RxCalcSqrt'; call RxFuncAdd 'RxCalcArcTan','rxmath','RxCalcArcTan'; call RxFuncAdd 'RxCalcArcCos','rxmath','RxCalcArcCos'; return 1

::class MLTemporalPatternCorpus public
::method init
  expose corpusId series labels sampleIds
  use strict arg seriesValues,labelValues=.nil,sampleIdValues=.nil,corpusIdValue='TEMPORAL-PATTERN-CORPUS'
  if \seriesValues~isA(.Array) | seriesValues~items<1 then raise syntax 88.900 array('temporal pattern corpus requires series')
  n=seriesValues~items
  if labelValues==.nil then do; labelValues=.array~new; do i=1 to n; labelValues~append(.nil); end; end
  if sampleIdValues==.nil then do; sampleIdValues=.array~new; do i=1 to n; sampleIdValues~append('TP'||i); end; end
  if \labelValues~isA(.Array) | labelValues~items<>n then raise syntax 88.900 array('temporal pattern corpus label count mismatch')
  if \sampleIdValues~isA(.Array) | sampleIdValues~items<>n then raise syntax 88.900 array('temporal pattern corpus sample-id count mismatch')
  series=.array~new; labels=.array~new; sampleIds=.array~new; seen=.directory~new
  do i=1 to n
    if \seriesValues[i]~isA(.MLTemporalPatternSeries) then raise syntax 88.900 array('temporal pattern corpus requires MLTemporalPatternSeries',i)
    sid=sampleIdValues[i]~string; if seen~hasIndex(sid) then raise syntax 88.900 array('temporal pattern corpus requires unique sample ids',sid); seen[sid]=1
    series~append(seriesValues[i]); labels~append(labelValues[i]); sampleIds~append(sampleIdValues[i])
  end
  corpusId=corpusIdValue
::method id; expose corpusId; return corpusId
::method sampleCount; expose series; return series~items
::method series; expose series; use strict arg i; return series[i]
::method label; expose labels; use strict arg i; return labels[i]
::method sampleId; expose sampleIds; use strict arg i; return sampleIds[i]

::class MLTemporalPatternEntry public
::method init
  expose sampleId label series hash
  use strict arg sampleIdValue,labelValue,seriesValue,hashValue
  sampleId=sampleIdValue; label=labelValue; series=seriesValue; hash=hashValue
::method sampleId; expose sampleId; return sampleId
::method label; expose label; return label
::method series; expose series; return series
::method hash; expose hash; return hash

::class MLTemporalPatternMatch public
::method init
  expose sampleId label difference hash
  use strict arg sampleIdValue,labelValue,differenceValue,hashValue
  sampleId=sampleIdValue; label=labelValue; difference=differenceValue; hash=hashValue
::method sampleId; expose sampleId; return sampleId
::method label; expose label; return label
::method difference; expose difference; return difference
::method hash; expose hash; return hash
::method canonicalText
  expose sampleId label difference
  return 'TEMPORAL_PATTERN_MATCH='||sampleId||'|label='||label||'|'||difference~canonicalText

::class MLTemporalPatternMatchComparator public
::method compare
  use strict arg a,b
  c=a~difference~compare(b~difference); if c\=0 then return c
  if a~sampleId~string<b~sampleId~string then return -1
  if a~sampleId~string>b~sampleId~string then return 1
  return 0

::class MLTemporalPatternQuery public
::method init
  expose queryHash results candidatesExamined corpusSize
  use strict arg queryHashValue,resultValues,candidatesValue,corpusSizeValue
  queryHash=queryHashValue; results=.MLFrozenVector~new(resultValues); candidatesExamined=candidatesValue; corpusSize=corpusSizeValue
::method queryHash; expose queryHash; return queryHash
::method results; expose results; return results~toArray
::method at; expose results; use strict arg i; return results[i]
::method size; expose results; return results~items
::method candidatesExamined; expose candidatesExamined; return candidatesExamined
::method corpusSize; expose corpusSize; return corpusSize

::class MLTemporalPatternIndex subclass MLDriveableObject public
::method init
  use strict arg stableId='TEMPORAL_PATTERN_INDEX'
  initial=.directory~new; initial['fitted']=.false; self~init:super(stableId,'TEMPORAL_PATTERN_INDEX',initial)
::method fit
  use strict arg corpus,schema
  if \corpus~isA(.MLTemporalPatternCorpus) then raise syntax 88.900 array('temporal pattern index requires MLTemporalPatternCorpus')
  if \schema~isA(.MLCylindricalTemporalPatternSchema) then raise syntax 88.900 array('temporal pattern index requires MLCylindricalTemporalPatternSchema')
  entries=.array~new; buckets=.directory~new
  do i=1 to corpus~sampleCount
    s=corpus~series(i); h=schema~encode(s); e=.MLTemporalPatternEntry~new(corpus~sampleId(i),corpus~label(i),s,h); entries~append(e)
    key=h~key; if \buckets~hasIndex(key) then buckets[key]=.array~new; buckets[key]~append(e)
  end
  frozenBuckets=.directory~new; do key over buckets~allIndexes; frozenBuckets[key]=.MLFrozenVector~new(buckets[key]); end
  c=.directory~new; c['fitted']=.true; c['schema']=schema; c['entries']=.MLFrozenVector~new(entries); c['buckets']=.MLFrozenMap~new(frozenBuckets); c['corpusId']=corpus~id; c['sampleCount']=corpus~sampleCount
  return self~mutate(c,'FIT_TEMPORAL_PATTERN_INDEX')
::method exact
  use strict arg series
  if \self~at('fitted') then raise syntax 88.900 array('temporal pattern index is not fitted')
  h=self~at('schema')~encode(series); buckets=self~at('buckets'); out=.array~new
  if buckets~hasIndex(h~key) then do; b=buckets[h~key]; do i=1 to b~items; out~append(b[i]); end; end
  return out
::method query
  use strict arg series,k=5,excludeSampleId=.nil
  if \self~at('fitted') then raise syntax 88.900 array('temporal pattern index is not fitted')
  if k<1 then raise syntax 88.900 array('temporal pattern query k must be positive')
  schema=self~at('schema'); qh=schema~encode(series); entries=self~at('entries'); matches=.array~new; examined=0
  do i=1 to entries~items
    e=entries[i]; if excludeSampleId\==.nil then if e~sampleId==excludeSampleId then iterate
    examined=examined+1; matches~append(.MLTemporalPatternMatch~new(e~sampleId,e~label,schema~difference(qh,e~hash),e~hash))
  end
  matches~sortWith(.MLTemporalPatternMatchComparator~new); out=.array~new; limit=k; if limit>matches~items then limit=matches~items
  do i=1 to limit; out~append(matches[i]); end
  return .MLTemporalPatternQuery~new(qh,out,examined,self~at('sampleCount'))

::requires "MLCore.cls"
