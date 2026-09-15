/* MLPatternHash.cls - polar, curve-relative pattern hashing.
 *
 * Pattern hashing answers a different question from ordinary numeric hashing:
 *   "where else did something shaped like this happen?"
 *
 * A source sequence is treated as one revolution around a circular grid.
 * Its minimum becomes the centre radius 0 and its maximum becomes radius 1.
 * The sequence is linearly resampled onto a fixed angular grid, so offset,
 * amplitude and source sample count do not define identity.  The retained
 * signature is the radial curve plus first- and second-difference geometry.
 *
 * Distance is significance ordered rather than a lossy scalar sum.  Weighted
 * per-angle differences are sorted largest-first and compared lexicographically:
 * the largest meaningful disagreement therefore dominates any collection of
 * smaller disagreements.  This mirrors MLCloseNeighbour's dominant-difference
 * doctrine without relying on arithmetic subtraction of opaque hash integers.
 */


::class MLPatternDescendingComparator private
::method compare
  use strict arg a,b
  if a+0>b+0 then return -1
  if a+0<b+0 then return 1
  return 0

::class MLPatternHashPolicy public
::method init
  expose angleCount radialBins radialWeight slopeWeight curvatureWeight rotationInvariant reversalInvariant
  use strict arg angleCountValue=36,radialBinsValue=32,radialWeightValue=1,slopeWeightValue=4,curvatureWeightValue=8,rotationInvariantValue=.true,reversalInvariantValue=.false
  if angleCountValue<8 | angleCountValue\=trunc(angleCountValue) then raise syntax 88.900 array('pattern angleCount must be an integer >= 8')
  if radialBinsValue<4 | radialBinsValue\=trunc(radialBinsValue) then raise syntax 88.900 array('pattern radialBins must be an integer >= 4')
  if radialWeightValue<1 | radialWeightValue\=trunc(radialWeightValue) then raise syntax 88.900 array('pattern radialWeight must be a positive integer')
  if slopeWeightValue<1 | slopeWeightValue\=trunc(slopeWeightValue) then raise syntax 88.900 array('pattern slopeWeight must be a positive integer')
  if curvatureWeightValue<1 | curvatureWeightValue\=trunc(curvatureWeightValue) then raise syntax 88.900 array('pattern curvatureWeight must be a positive integer')
  angleCount=angleCountValue+0; radialBins=radialBinsValue+0; radialWeight=radialWeightValue+0; slopeWeight=slopeWeightValue+0; curvatureWeight=curvatureWeightValue+0
  rotationInvariant=(rotationInvariantValue=.true); reversalInvariant=(reversalInvariantValue=.true)
::method angleCount; expose angleCount; return angleCount
::method radialBins; expose radialBins; return radialBins
::method radialWeight; expose radialWeight; return radialWeight
::method slopeWeight; expose slopeWeight; return slopeWeight
::method curvatureWeight; expose curvatureWeight; return curvatureWeight
::method rotationInvariant; expose rotationInvariant; return rotationInvariant
::method reversalInvariant; expose reversalInvariant; return reversalInvariant
::method canonicalText
  expose angleCount radialBins radialWeight slopeWeight curvatureWeight rotationInvariant reversalInvariant
  return 'PATTERN_POLICY=angles='||angleCount||'|radialBins='||radialBins||'|weights='||radialWeight||','||slopeWeight||','||curvatureWeight||'|rotationInvariant='||rotationInvariant||'|reversalInvariant='||reversalInvariant

::class MLPolarPatternPoint public
::method init
  expose angleDegrees radius radialCoordinate
  use strict arg angleValue,radiusValue,coordinateValue
  angleDegrees=angleValue+0; radius=radiusValue+0; radialCoordinate=coordinateValue+0
::method angleDegrees; expose angleDegrees; return angleDegrees
::method radius; expose radius; return radius
::method radialCoordinate; expose radialCoordinate; return radialCoordinate
::method canonicalText
  expose angleDegrees radius radialCoordinate
  return 'POLAR_POINT=angle='||angleDegrees||'|radius='||radius||'|bin='||radialCoordinate

::class MLPatternHash public
::method init
  expose schemaId radii radialCoordinates slopes curvatures sourceMinimum sourceMaximum sourceCount rotation key
  use strict arg schemaIdValue,radiusValues,coordinateValues,slopeValues,curvatureValues,sourceMinimumValue,sourceMaximumValue,sourceCountValue,rotationValue,keyValue
  schemaId=schemaIdValue; radii=.MLFrozenVector~new(radiusValues); radialCoordinates=.MLFrozenVector~new(coordinateValues); slopes=.MLFrozenVector~new(slopeValues); curvatures=.MLFrozenVector~new(curvatureValues)
  sourceMinimum=sourceMinimumValue; sourceMaximum=sourceMaximumValue; sourceCount=sourceCountValue; rotation=rotationValue; key=keyValue
::method schemaId; expose schemaId; return schemaId
::method radii; expose radii; return radii~toArray
::method radialCoordinates; expose radialCoordinates; return radialCoordinates~toArray
::method radialCoordinate; expose radialCoordinates; use strict arg i; return radialCoordinates[i]
::method slopes; expose slopes; return slopes~toArray
::method slope; expose slopes; use strict arg i; return slopes[i]
::method curvatures; expose curvatures; return curvatures~toArray
::method curvature; expose curvatures; use strict arg i; return curvatures[i]
::method sourceMinimum; expose sourceMinimum; return sourceMinimum
::method sourceMaximum; expose sourceMaximum; return sourceMaximum
::method sourceCount; expose sourceCount; return sourceCount
::method rotation; expose rotation; return rotation
::method key; expose key; return key
::method items; expose radialCoordinates; return radialCoordinates~items
::method flat; expose sourceMinimum sourceMaximum; return sourceMinimum=sourceMaximum
::method polarPoints
  expose radii radialCoordinates
  out=.array~new; n=radii~items
  do i=1 to n
    angle=360*(i-1)/n
    out~append(.MLPolarPatternPoint~new(angle,radii[i],radialCoordinates[i]))
  end
  return out
::method canonicalText
  expose schemaId radialCoordinates slopes curvatures sourceMinimum sourceMaximum sourceCount rotation key
  return 'PATTERN_HASH='||schemaId||'|key='||key||'|sourceRange='||sourceMinimum||':'||sourceMaximum||'|sourceCount='||sourceCount||'|rotation='||rotation||'|r='||radialCoordinates~canonicalText||'|d1='||slopes~canonicalText||'|d2='||curvatures~canonicalText
::method string; return self~canonicalText

::class MLPatternHashDifference public
::method init
  expose orderedDeltas dominantDelta totalDelta rankKey radialMax slopeMax curvatureMax
  use strict arg orderedValues,dominantValue,totalValue,rankKeyValue,radialMaxValue,slopeMaxValue,curvatureMaxValue
  orderedDeltas=.MLFrozenVector~new(orderedValues); dominantDelta=dominantValue; totalDelta=totalValue; rankKey=rankKeyValue; radialMax=radialMaxValue; slopeMax=slopeMaxValue; curvatureMax=curvatureMaxValue
::method orderedDeltas; expose orderedDeltas; return orderedDeltas~toArray
::method dominantDelta; expose dominantDelta; return dominantDelta
::method totalDelta; expose totalDelta; return totalDelta
::method rankKey; expose rankKey; return rankKey
::method radialMax; expose radialMax; return radialMax
::method slopeMax; expose slopeMax; return slopeMax
::method curvatureMax; expose curvatureMax; return curvatureMax
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
  expose dominantDelta totalDelta rankKey radialMax slopeMax curvatureMax orderedDeltas
  return 'PATTERN_DIFFERENCE=dominant='||dominantDelta||'|total='||totalDelta||'|radialMax='||radialMax||'|slopeMax='||slopeMax||'|curvatureMax='||curvatureMax||'|rank='||rankKey||'|ordered='||orderedDeltas~canonicalText

::class MLPatternHashSchema public
::method init
  expose schemaId policy
  use strict arg policyValue=.nil,schemaIdValue='POLAR-PATTERN/1'
  if policyValue==.nil then policyValue=.MLPatternHashPolicy~new
  if \policyValue~isA(.MLPatternHashPolicy) then raise syntax 88.900 array('pattern schema requires MLPatternHashPolicy')
  schemaId=schemaIdValue; policy=policyValue
::method id; expose schemaId; return schemaId
::method policy; expose policy; return policy
::method encode
  expose schemaId policy
  use strict arg sourceValues
  if \sourceValues~isA(.Array) | sourceValues~items<3 then raise syntax 88.900 array('pattern hash requires at least three values')
  values=.array~new; minimum=.nil; maximum=.nil
  do x over sourceValues
    v=x+0; values~append(v)
    if minimum==.nil | v<minimum then minimum=v
    if maximum==.nil | v>maximum then maximum=v
  end
  n=policy~angleCount
  sampled=self~periodicResample(values,n)
  radii=.array~new
  if maximum=minimum then do i=1 to n; radii~append(0); end
  else do x over sampled; radii~append((x-minimum)/(maximum-minimum)); end
  coords=.array~new; bins=policy~radialBins
  do r over radii
    q=trunc(r*(bins-1)+.5); if q<0 then q=0; if q>=bins then q=bins-1; coords~append(q)
  end
  rotation=0
  if policy~rotationInvariant then do
    rotation=self~canonicalRotation(coords)
    coords=self~rotate(coords,rotation); radii=self~rotate(radii,rotation)
  end
  if policy~reversalInvariant then do
    revCoords=self~reverse(coords); revRadii=self~reverse(radii); revRotation=0
    if policy~rotationInvariant then do; revRotation=self~canonicalRotation(revCoords); revCoords=self~rotate(revCoords,revRotation); revRadii=self~rotate(revRadii,revRotation); end
    if self~lexGreater(revCoords,coords) then do; coords=revCoords; radii=revRadii; rotation=-(revRotation+1); end
  end
  slopes=.array~new; curvatures=.array~new
  do i=1 to n
    prev=i-1; if prev<1 then prev=n
    next=i+1; if next>n then next=1
    slopes~append(coords[next]-coords[i])
    curvatures~append(coords[next]-2*coords[i]+coords[prev])
  end
  key=self~keyFor(coords,slopes,curvatures)
  return .MLPatternHash~new(schemaId,radii,coords,slopes,curvatures,minimum,maximum,sourceValues~items,rotation,key)
::method difference
  expose schemaId policy
  use strict arg left,right
  if left~schemaId\==schemaId | right~schemaId\==schemaId then raise syntax 88.900 array('pattern hash schema mismatch')
  if left~items<>right~items then raise syntax 88.900 array('pattern hash width mismatch')
  weighted=.array~new; radialMax=0; slopeMax=0; curvatureMax=0; total=0
  do i=1 to left~items
    rd=abs(left~radialCoordinate(i)-right~radialCoordinate(i)); sd=abs(left~slope(i)-right~slope(i)); cd=abs(left~curvature(i)-right~curvature(i))
    if rd>radialMax then radialMax=rd; if sd>slopeMax then slopeMax=sd; if cd>curvatureMax then curvatureMax=cd
    wr=rd*policy~radialWeight; ws=sd*policy~slopeWeight; wc=cd*policy~curvatureWeight
    weighted~append(wr); weighted~append(ws); weighted~append(wc); total=total+wr+ws+wc
  end
  weighted~sortWith(.MLPatternDescendingComparator~new)
  dominant=0; if weighted~items>0 then dominant=weighted[1]
  maxWeighted=(policy~radialBins-1)*policy~radialWeight; x=(policy~radialBins-1)*policy~slopeWeight; if x>maxWeighted then maxWeighted=x; x=2*(policy~radialBins-1)*policy~curvatureWeight; if x>maxWeighted then maxWeighted=x
  width=length(maxWeighted~string); if width<2 then width=2
  rk=''; do d over weighted; rk=rk||right(d,width,'0'); end
  return .MLPatternHashDifference~new(weighted,dominant,total,rk,radialMax,slopeMax,curvatureMax)
::method polarGrid
  use strict arg hash
  if hash~schemaId\==self~id then raise syntax 88.900 array('pattern hash schema mismatch')
  return hash~polarPoints
::method canonicalText
  expose schemaId policy
  return 'PATTERN_SCHEMA='||schemaId||'|'||policy~canonicalText
::method periodicResample private
  use strict arg values,targetCount
  out=.array~new; sourceCount=values~items
  numeric digits 40
  do i=1 to targetCount
    phase=(i-1)*sourceCount/targetCount
    lo=trunc(phase)+1; frac=phase-trunc(phase); hi=lo+1; if hi>sourceCount then hi=1
    out~append(values[lo]+frac*(values[hi]-values[lo]))
  end
  return out
::method canonicalRotation private
  use strict arg coords
  best=1
  do candidate=2 to coords~items
    if self~rotationGreater(coords,candidate,best) then best=candidate
  end
  return best-1
::method rotationGreater private
  use strict arg coords,a,b
  n=coords~items
  do offset=0 to n-1
    ia=a+offset; do while ia>n; ia=ia-n; end
    ib=b+offset; do while ib>n; ib=ib-n; end
    if coords[ia]>coords[ib] then return .true
    if coords[ia]<coords[ib] then return .false
  end
  return .false
::method rotate private
  use strict arg source,offset
  out=.array~new; n=source~items
  do j=0 to n-1
    i=offset+1+j; do while i>n; i=i-n; end
    out~append(source[i])
  end
  return out
::method reverse private
  use strict arg source
  out=.array~new; do i=source~items to 1 by -1; out~append(source[i]); end; return out
::method lexGreater private
  use strict arg a,b
  do i=1 to a~items
    if a[i]>b[i] then return .true
    if a[i]<b[i] then return .false
  end
  return .false
::method keyFor private
  use strict arg coords,slopes,curvatures
  r=''; s=''; c=''
  do i=1 to coords~items
    if i>1 then do; r=r||','; s=s||','; c=c||','; end
    r=r||coords[i]; s=s||slopes[i]; c=c||curvatures[i]
  end
  return 'R['||r||']D1['||s||']D2['||c||']'

::class MLPatternCorpus public
::method init
  expose corpusId curves labels sampleIds
  use strict arg sourceCurves,sourceLabels=.nil,sourceSampleIds=.nil,corpusIdValue='PATTERN-CORPUS'
  if \sourceCurves~isA(.Array) | sourceCurves~items<1 then raise syntax 88.900 array('pattern corpus requires curves')
  n=sourceCurves~items
  if sourceLabels==.nil then do; sourceLabels=.array~new; do i=1 to n; sourceLabels~append(.nil); end; end
  if sourceSampleIds==.nil then do; sourceSampleIds=.array~new; do i=1 to n; sourceSampleIds~append('P'||i); end; end
  if \sourceLabels~isA(.Array) | sourceLabels~items<>n then raise syntax 88.900 array('pattern corpus label count mismatch')
  if \sourceSampleIds~isA(.Array) | sourceSampleIds~items<>n then raise syntax 88.900 array('pattern corpus sample-id count mismatch')
  curves=.array~new; labels=.array~new; sampleIds=.array~new; seen=.directory~new
  do i=1 to n
    if \sourceCurves[i]~isA(.Array) | sourceCurves[i]~items<3 then raise syntax 88.900 array('pattern corpus curves require at least three values',i)
    sid=sourceSampleIds[i]~string; if seen~hasIndex(sid) then raise syntax 88.900 array('pattern corpus requires unique sample ids',sid); seen[sid]=1
    curves~append(.MLFrozenVector~new(sourceCurves[i])); labels~append(sourceLabels[i]); sampleIds~append(sourceSampleIds[i])
  end
  corpusId=corpusIdValue
::method id; expose corpusId; return corpusId
::method sampleCount; expose curves; return curves~items
::method curve; expose curves; use strict arg i; return curves[i]~toArray
::method label; expose labels; use strict arg i; return labels[i]
::method sampleId; expose sampleIds; use strict arg i; return sampleIds[i]

::class MLPatternEntry public
::method init
  expose sampleId label curve hash
  use strict arg sampleIdValue,labelValue,curveValue,hashValue
  sampleId=sampleIdValue; label=labelValue; curve=.MLFrozenVector~new(curveValue); hash=hashValue
::method sampleId; expose sampleId; return sampleId
::method label; expose label; return label
::method curve; expose curve; return curve~toArray
::method hash; expose hash; return hash

::class MLPatternMatch public
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
  return 'PATTERN_MATCH='||sampleId||'|label='||label||'|'||difference~canonicalText

::class MLPatternMatchComparator public
::method compare
  use strict arg a,b
  c=a~difference~compare(b~difference)
  if c\=0 then return c
  if a~sampleId~string<b~sampleId~string then return -1
  if a~sampleId~string>b~sampleId~string then return 1
  return 0

::class MLPatternQuery public
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
::method canonicalText
  expose queryHash results candidatesExamined corpusSize
  return 'PATTERN_QUERY=results='||results~items||'|candidates='||candidatesExamined||'/'||corpusSize||'|query='||queryHash~key

::class MLPatternIndex subclass MLDriveableObject public
::method init
  use strict arg stableId='PATTERN_INDEX'
  initial=.directory~new; initial['fitted']=.false
  self~init:super(stableId,'PATTERN_INDEX',initial)
::method fit
  use strict arg corpus,schema
  if \corpus~isA(.MLPatternCorpus) then raise syntax 88.900 array('pattern index requires MLPatternCorpus')
  if \schema~isA(.MLPatternHashSchema) then raise syntax 88.900 array('pattern index requires MLPatternHashSchema')
  entries=.array~new; buckets=.directory~new
  do i=1 to corpus~sampleCount
    curve=corpus~curve(i); h=schema~encode(curve); e=.MLPatternEntry~new(corpus~sampleId(i),corpus~label(i),curve,h); entries~append(e)
    key=h~key; if \buckets~hasIndex(key) then buckets[key]=.array~new; buckets[key]~append(e)
  end
  frozenBuckets=.directory~new; do key over buckets~allIndexes; frozenBuckets[key]=.MLFrozenVector~new(buckets[key]); end
  c=.directory~new; c['fitted']=.true; c['schema']=schema; c['entries']=.MLFrozenVector~new(entries); c['buckets']=.MLFrozenMap~new(frozenBuckets); c['corpusId']=corpus~id; c['sampleCount']=corpus~sampleCount
  return self~mutate(c,'FIT_PATTERN_INDEX')
::method schema
  if \self~at('fitted') then raise syntax 88.900 array('pattern index is not fitted')
  return self~at('schema')
::method exact
  use strict arg curve
  if \self~at('fitted') then raise syntax 88.900 array('pattern index is not fitted')
  h=self~at('schema')~encode(curve); buckets=self~at('buckets'); out=.array~new
  if buckets~hasIndex(h~key) then do; b=buckets[h~key]; do i=1 to b~items; out~append(b[i]); end; end
  return out
::method query
  use strict arg curve,k=5,excludeSampleId=.nil
  if \self~at('fitted') then raise syntax 88.900 array('pattern index is not fitted')
  if k<1 then raise syntax 88.900 array('pattern query k must be positive')
  schema=self~at('schema'); qh=schema~encode(curve); entries=self~at('entries'); matches=.array~new; examined=0
  do i=1 to entries~items
    e=entries[i]; if excludeSampleId\==.nil then if e~sampleId==excludeSampleId then iterate
    examined=examined+1; matches~append(.MLPatternMatch~new(e~sampleId,e~label,schema~difference(qh,e~hash),e~hash))
  end
  matches~sortWith(.MLPatternMatchComparator~new); out=.array~new; limit=k; if limit>matches~items then limit=matches~items
  do i=1 to limit; out~append(matches[i]); end
  return .MLPatternQuery~new(qh,out,examined,self~at('sampleCount'))

::requires "MLCore.cls"
