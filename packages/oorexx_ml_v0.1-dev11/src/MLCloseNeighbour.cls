/* MLCloseNeighbour.cls - significance-preserving approximate neighbour search.
 *
 * The central idea is deliberately different from cryptographic hashing and
 * from collision-probability-only LSH.  Values are quantised into ordered
 * coordinates.  Hash distance is dominated by the largest significant
 * coordinate difference, then by the next largest, and so on.  Therefore a
 * large disagreement cannot be hidden by many tiny agreements, while adjacent
 * quantisation cells remain adjacent.
 *
 * Multi-probe lookup searches neighbouring cells and may optionally rerank the
 * bounded candidate set with exact Euclidean distance.  An exact index and
 * recall/efficiency assessor are included so "good enough" is measurable.
 */

::class MLCloseHashDimension public
::method init
  expose name minimum maximum bins importance rangePolicy
  use strict arg nameValue,minimumValue,maximumValue,binsValue=256,importanceValue=1,rangePolicyValue='FAIL'
  if maximumValue<=minimumValue then raise syntax 88.900 array('close-hash dimension maximum must exceed minimum',nameValue)
  if binsValue<2 | binsValue\=trunc(binsValue) then raise syntax 88.900 array('close-hash dimension bins must be an integer >= 2',nameValue)
  if importanceValue<1 | importanceValue\=trunc(importanceValue) then raise syntax 88.900 array('close-hash importance must be a positive integer',nameValue)
  rangePolicyValue=rangePolicyValue~translate
  if rangePolicyValue\='FAIL' & rangePolicyValue\='CLAMP' then raise syntax 88.900 array('close-hash range policy must be FAIL or CLAMP',nameValue)
  name=nameValue; minimum=minimumValue+0; maximum=maximumValue+0; bins=binsValue+0; importance=importanceValue+0; rangePolicy=rangePolicyValue
::method name; expose name; return name
::method minimum; expose minimum; return minimum
::method maximum; expose maximum; return maximum
::method bins; expose bins; return bins
::method importance; expose importance; return importance
::method rangePolicy; expose rangePolicy; return rangePolicy
::method quantize
  expose minimum maximum bins rangePolicy name
  use strict arg value
  x=value+0
  if x<minimum then do
    if rangePolicy='FAIL' then raise syntax 88.900 array('close-hash value below declared range',name,x,minimum)
    return 0
  end
  if x>maximum then do
    if rangePolicy='FAIL' then raise syntax 88.900 array('close-hash value above declared range',name,x,maximum)
    return bins-1
  end
  if x=minimum then return 0
  if x=maximum then return bins-1
  q=trunc(((x-minimum)/(maximum-minimum))*bins)
  if q<0 then q=0
  if q>=bins then q=bins-1
  return q
::method centre
  expose minimum maximum bins
  use strict arg coordinate
  if coordinate<0 | coordinate>=bins then raise syntax 88.900 array('close-hash coordinate out of range',coordinate)
  return minimum+((coordinate+.5)*(maximum-minimum)/bins)
::method maxWeightedDelta
  expose bins importance
  return (bins-1)*importance
::method canonicalText
  expose name minimum maximum bins importance rangePolicy
  return 'DIM='||name||'|min='||minimum||'|max='||maximum||'|bins='||bins||'|importance='||importance||'|rangePolicy='||rangePolicy

::class MLCloseHash public
::method init
  expose schemaId coordinates key
  use strict arg schemaIdValue,sourceCoordinates,keyValue
  if \sourceCoordinates~isA(.Array) then raise syntax 88.900 array('close hash coordinates must be Array')
  coordinates=.MLFrozenVector~new(sourceCoordinates); schemaId=schemaIdValue; key=keyValue
::method schemaId; expose schemaId; return schemaId
::method coordinates; expose coordinates; return coordinates~toArray
::method coordinate; expose coordinates; use strict arg i; return coordinates[i]
::method items; expose coordinates; return coordinates~items
::method key; expose key; return key
::method canonicalText
  expose schemaId coordinates key
  return 'CLOSE_HASH='||schemaId||'|key='||key||'|coords='||coordinates~canonicalText
::method string; return self~canonicalText

::class MLCloseHashDifference public
::method init
  expose score dominantDelta orderedDeltas rawDeltas
  use strict arg scoreValue,dominantDeltaValue,orderedDeltaValues,rawDeltaValues
  score=scoreValue; dominantDelta=dominantDeltaValue; orderedDeltas=.MLFrozenVector~new(orderedDeltaValues); rawDeltas=.MLFrozenVector~new(rawDeltaValues)
::method score; expose score; return score
::method dominantDelta; expose dominantDelta; return dominantDelta
::method orderedDeltas; expose orderedDeltas; return orderedDeltas~toArray
::method rawDeltas; expose rawDeltas; return rawDeltas~toArray
::method exact; expose score; return score=0
::method canonicalText
  expose score dominantDelta orderedDeltas rawDeltas
  return 'HASH_DIFFERENCE=score='||score||'|dominant='||dominantDelta||'|ordered='||orderedDeltas~canonicalText||'|raw='||rawDeltas~canonicalText

::class MLDescendingNumericComparator public
::method compare
  use strict arg a,b
  if a+0>b+0 then return -1
  if a+0<b+0 then return 1
  return 0


::class MLProbeKey public
::method init
  expose key difference
  use strict arg keyValue,differenceValue
  key=keyValue; difference=differenceValue
::method key; expose key; return key
::method difference; expose difference; return difference

::class MLProbeKeyComparator public
::method compare
  use strict arg a,b
  if a~difference~score<b~difference~score then return -1
  if a~difference~score>b~difference~score then return 1
  if a~key<b~key then return -1
  if a~key>b~key then return 1
  return 0

::class MLCloseNeighbourPolicy public
::method init
  expose k probeRadius maxCandidates mode maxProbeBuckets
  use strict arg kValue=5,probeRadiusValue=1,maxCandidatesValue=0,modeValue='HASH',maxProbeBucketsValue=100000
  if kValue<1 then raise syntax 88.900 array('close-neighbour policy k must be positive')
  if probeRadiusValue<0 | probeRadiusValue\=trunc(probeRadiusValue) then raise syntax 88.900 array('close-neighbour policy radius must be non-negative integer')
  if maxCandidatesValue<0 then raise syntax 88.900 array('close-neighbour maxCandidates must be non-negative')
  modeValue=modeValue~translate
  if modeValue\='HASH' & modeValue\='EXACT' then raise syntax 88.900 array('close-neighbour policy mode must be HASH or EXACT')
  if maxProbeBucketsValue<1 then raise syntax 88.900 array('close-neighbour maxProbeBuckets must be positive')
  k=kValue; probeRadius=probeRadiusValue; maxCandidates=maxCandidatesValue; mode=modeValue; maxProbeBuckets=maxProbeBucketsValue
::method k; expose k; return k
::method probeRadius; expose probeRadius; return probeRadius
::method maxCandidates; expose maxCandidates; return maxCandidates
::method mode; expose mode; return mode
::method maxProbeBuckets; expose maxProbeBuckets; return maxProbeBuckets
::method canonicalText
  expose k probeRadius maxCandidates mode maxProbeBuckets
  return 'CLOSE_NEIGHBOUR_POLICY=k='||k||'|radius='||probeRadius||'|maxCandidates='||maxCandidates||'|mode='||mode||'|maxProbeBuckets='||maxProbeBuckets

::class MLCloseHashSchema public
::method init
  expose schemaId dimensions base
  use strict arg sourceDimensions,schemaIdValue='CLOSE-HASH/1'
  if \sourceDimensions~isA(.Array) | sourceDimensions~items<1 then raise syntax 88.900 array('close-hash schema requires dimensions')
  dimensions=.array~new; maxDelta=0
  do d over sourceDimensions
    if \d~isA(.MLCloseHashDimension) then raise syntax 88.900 array('close-hash schema requires MLCloseHashDimension values')
    dimensions~append(d); if d~maxWeightedDelta>maxDelta then maxDelta=d~maxWeightedDelta
  end
  schemaId=schemaIdValue; base=maxDelta+1
::method id; expose schemaId; return schemaId
::method featureCount; expose dimensions; return dimensions~items
::method dimension; expose dimensions; use strict arg i; return dimensions[i]
::method dimensions
  expose dimensions
  out=.array~new; do d over dimensions; out~append(d); end; return out
::method encode
  expose dimensions schemaId
  use strict arg row
  if \row~isA(.Array) | row~items<>dimensions~items then raise syntax 88.900 array('close-hash row width mismatch')
  coords=.array~new
  do i=1 to dimensions~items; coords~append(dimensions[i]~quantize(row[i])); end
  return .MLCloseHash~new(schemaId,coords,self~keyForCoordinates(coords))
::method keyForCoordinates
  expose dimensions
  use strict arg coords
  if \coords~isA(.Array) | coords~items<>dimensions~items then raise syntax 88.900 array('close-hash coordinate width mismatch')
  s=''
  do i=1 to coords~items
    q=coords[i]+0
    if q<0 | q>=dimensions[i]~bins then raise syntax 88.900 array('close-hash coordinate out of range',i,q)
    if i>1 then s=s||':'
    s=s||q
  end
  return s
::method difference
  expose dimensions schemaId base
  use strict arg left,right
  if left~schemaId\==schemaId | right~schemaId\==schemaId then raise syntax 88.900 array('close-hash schema mismatch')
  if left~items<>dimensions~items | right~items<>dimensions~items then raise syntax 88.900 array('close-hash coordinate width mismatch')
  raw=.array~new; weighted=.array~new
  do i=1 to dimensions~items
    d=abs((left~coordinate(i)+0)-(right~coordinate(i)+0)); raw~append(d); weighted~append(d*dimensions[i]~importance)
  end
  ordered=.array~new; do d over weighted; ordered~append(d); end; ordered~sortWith(.MLDescendingNumericComparator~new)
  score=0
  do d over ordered; score=score*base+d; end
  dominant=0; if ordered~items>0 then dominant=ordered[1]
  return .MLCloseHashDifference~new(score,dominant,ordered,raw)
::method estimatedProbeBuckets
  expose dimensions
  use strict arg hash,radius=1
  if radius<0 | radius\=trunc(radius) then raise syntax 88.900 array('close-hash probe radius must be a non-negative integer')
  if hash~items<>dimensions~items then raise syntax 88.900 array('close-hash probe width mismatch')
  count=1
  do i=1 to dimensions~items
    q=hash~coordinate(i); lo=q-radius; hi=q+radius
    if lo<0 then lo=0
    if hi>=dimensions[i]~bins then hi=dimensions[i]~bins-1
    count=count*(hi-lo+1)
  end
  return count
::method neighbourKeys
  expose dimensions schemaId
  use strict arg hash,radius=1,maxKeys=100000
  estimate=self~estimatedProbeBuckets(hash,radius)
  if maxKeys>0 & estimate>maxKeys then raise syntax 88.900 array('close-hash probe bucket budget exceeded','required='||estimate,'maximum='||maxKeys)
  partial=.array~new; partial~append(.array~new)
  do dimIndex=1 to dimensions~items
    next=.array~new; q=hash~coordinate(dimIndex); lo=q-radius; hi=q+radius
    if lo<0 then lo=0
    if hi>=dimensions[dimIndex]~bins then hi=dimensions[dimIndex]~bins-1
    do prefix over partial
      do v=lo to hi
        c=.array~new; do x over prefix; c~append(x); end; c~append(v); next~append(c)
      end
    end
    partial=next
  end
  probes=.array~new
  do c over partial
    key=self~keyForCoordinates(c); candidate=.MLCloseHash~new(schemaId,c,key); probes~append(.MLProbeKey~new(key,self~difference(hash,candidate)))
  end
  probes~sortWith(.MLProbeKeyComparator~new); keys=.array~new; do p over probes; keys~append(p~key); end; return keys
::method partialKey private
  use strict arg coords
  s=''; do i=1 to coords~items; if i>1 then s=s||':'; s=s||coords[i]; end; return s
::method canonicalText
  expose schemaId dimensions base
  lines=.array~new; lines~append('CLOSE_HASH_SCHEMA='||schemaId||'|features='||dimensions~items||'|distanceBase='||base)
  do d over dimensions; lines~append(d~canonicalText); end
  return lines~makeString('L')

::class MLCloseNeighbourEntry public
::method init
  expose sampleId row label hash
  use strict arg sampleIdValue,rowValue,labelValue,hashValue
  sampleId=sampleIdValue; row=.MLFrozenVector~new(rowValue); label=labelValue; hash=hashValue
::method sampleId; expose sampleId; return sampleId
::method row; expose row; return row~toArray
::method label; expose label; return label
::method hash; expose hash; return hash
::method canonicalText
  expose sampleId row label hash
  return 'NEIGHBOUR_ENTRY='||sampleId||'|label='||label||'|hash='||hash~key||'|row='||row~canonicalText

::class MLCloseNeighbourResult public
::method init
  expose sampleId label hashDifference exactDistance hash
  use strict arg sampleIdValue,labelValue,hashDifferenceValue,exactDistanceValue,hashValue
  sampleId=sampleIdValue; label=labelValue; hashDifference=hashDifferenceValue; exactDistance=exactDistanceValue; hash=hashValue
::method sampleId; expose sampleId; return sampleId
::method label; expose label; return label
::method hashDifference; expose hashDifference; return hashDifference
::method hashDistance; expose hashDifference; return hashDifference~score
::method dominantHashDifference; expose hashDifference; return hashDifference~dominantDelta
::method exactDistance; expose exactDistance; return exactDistance
::method hash; expose hash; return hash
::method canonicalText
  expose sampleId label hashDifference exactDistance hash
  return 'NEIGHBOUR_RESULT='||sampleId||'|hashDistance='||hashDifference~score||'|dominant='||hashDifference~dominantDelta||'|exact='||exactDistance||'|hash='||hash~key

::class MLHashResultComparator public
::method compare
  use strict arg a,b
  if a~hashDistance<b~hashDistance then return -1
  if a~hashDistance>b~hashDistance then return 1
  if a~exactDistance<b~exactDistance then return -1
  if a~exactDistance>b~exactDistance then return 1
  if a~sampleId~string<b~sampleId~string then return -1
  if a~sampleId~string>b~sampleId~string then return 1
  return 0

::class MLExactResultComparator public
::method compare
  use strict arg a,b
  if a~exactDistance<b~exactDistance then return -1
  if a~exactDistance>b~exactDistance then return 1
  if a~hashDistance<b~hashDistance then return -1
  if a~hashDistance>b~hashDistance then return 1
  if a~sampleId~string<b~sampleId~string then return -1
  if a~sampleId~string>b~sampleId~string then return 1
  return 0

::class MLCloseNeighbourQuery public
::method init
  expose results candidatesExamined probeBuckets corpusSize queryHash mode
  use strict arg resultValues,candidatesExaminedValue,probeBucketsValue,corpusSizeValue,queryHashValue,modeValue
  results=.MLFrozenVector~new(resultValues); candidatesExamined=candidatesExaminedValue; probeBuckets=probeBucketsValue; corpusSize=corpusSizeValue; queryHash=queryHashValue; mode=modeValue
::method results; expose results; return results~toArray
::method size; expose results; return results~items
::method at; expose results; use strict arg i; return results[i]
::method candidatesExamined; expose candidatesExamined; return candidatesExamined
::method probeBuckets; expose probeBuckets; return probeBuckets
::method corpusSize; expose corpusSize; return corpusSize
::method queryHash; expose queryHash; return queryHash
::method mode; expose mode; return mode
::method candidateFraction
  expose candidatesExamined corpusSize
  if corpusSize=0 then return 0
  return candidatesExamined/corpusSize
::method canonicalText
  expose results candidatesExamined probeBuckets corpusSize queryHash mode
  return 'NEIGHBOUR_QUERY=mode='||mode||'|results='||results~items||'|candidates='||candidatesExamined||'|probeBuckets='||probeBuckets||'|corpus='||corpusSize||'|query='||queryHash~key

::class MLCloseNeighbourIndex subclass MLDriveableObject public
::method init
  use strict arg stableId='CLOSE_NEIGHBOUR_INDEX'
  initial=.directory~new; initial['fitted']=.false
  self~init:super(stableId,'CLOSE_NEIGHBOUR_INDEX',initial)
::method fit
  use strict arg dataset,schema
  if dataset~sampleCount<1 then raise syntax 88.900 array('cannot build close-neighbour index on empty dataset')
  if dataset~featureCount<>schema~featureCount then raise syntax 88.900 array('close-neighbour schema width mismatch')
  entries=.array~new; rawBuckets=.directory~new; sampleSeen=.directory~new
  do i=1 to dataset~sampleCount
    sid=dataset~sampleId(i); sidKey=sid~string; if sampleSeen~hasIndex(sidKey) then raise syntax 88.900 array('close-neighbour index requires unique sample ids',sid); sampleSeen[sidKey]=1
    row=dataset~row(i); h=schema~encode(row); e=.MLCloseNeighbourEntry~new(sid,row,dataset~target(i),h); entries~append(e); key=h~key
    if \rawBuckets~hasIndex(key) then rawBuckets[key]=.array~new
    rawBuckets[key]~append(e)
  end
  frozenBuckets=.directory~new
  do key over rawBuckets~allIndexes; frozenBuckets[key]=.MLFrozenVector~new(rawBuckets[key]); end
  c=.directory~new; c['schema']=schema; c['entries']=.MLFrozenVector~new(entries); c['buckets']=.MLFrozenMap~new(frozenBuckets); c['datasetId']=dataset~id; c['featureCount']=dataset~featureCount; c['sampleCount']=dataset~sampleCount; c['fitted']=.true
  return self~mutate(c,'FIT_CLOSE_NEIGHBOUR_INDEX')
::method schema
  if \self~at('fitted') then raise syntax 88.900 array('close-neighbour index is not fitted')
  return self~at('schema')
::method query
  use strict arg row,k=5,probeRadius=1,maxCandidates=0,mode='HASH',excludeSampleId=.nil,maxProbeBuckets=100000
  if \self~at('fitted') then raise syntax 88.900 array('close-neighbour index is not fitted')
  if k<1 then raise syntax 88.900 array('close-neighbour k must be positive')
  mode=mode~translate
  if mode\='HASH' & mode\='EXACT' then raise syntax 88.900 array('close-neighbour query mode must be HASH or EXACT')
  schema=self~at('schema'); qh=schema~encode(row); keys=schema~neighbourKeys(qh,probeRadius,maxProbeBuckets); buckets=self~at('buckets'); seen=.directory~new; results=.array~new; examined=0
  do key over keys
    if \buckets~hasIndex(key) then iterate
    bucket=buckets[key]
    do i=1 to bucket~items
      e=bucket[i]; sid=e~sampleId
      if excludeSampleId\==.nil then if sid==excludeSampleId then iterate
      sk=sid~string
      if seen~hasIndex(sk) then iterate
      seen[sk]=1; examined=examined+1
      hd=schema~difference(qh,e~hash); ed=self~squaredDistance(row,e~row)
      results~append(.MLCloseNeighbourResult~new(sid,e~label,hd,ed,e~hash))
      if maxCandidates>0 & examined>=maxCandidates then leave
    end
    if maxCandidates>0 & examined>=maxCandidates then leave
  end
  if mode='EXACT' then results~sortWith(.MLExactResultComparator~new); else results~sortWith(.MLHashResultComparator~new)
  out=.array~new; limit=k; if limit>results~items then limit=results~items
  do i=1 to limit; out~append(results[i]); end
  return .MLCloseNeighbourQuery~new(out,examined,keys~items,self~at('sampleCount'),qh,mode)
::method queryPolicy
  use strict arg row,policy,excludeSampleId=.nil
  if \policy~isA(.MLCloseNeighbourPolicy) then raise syntax 88.900 array('queryPolicy requires MLCloseNeighbourPolicy')
  return self~query(row,policy~k,policy~probeRadius,policy~maxCandidates,policy~mode,excludeSampleId,policy~maxProbeBuckets)
::method squaredDistance private
  use strict arg a,b
  if a~items<>b~items then raise syntax 88.900 array('close-neighbour exact distance width mismatch')
  numeric digits 40; d=0; do i=1 to a~items; x=(a[i]+0)-(b[i]+0); d=d+x*x; end; return d

::class MLExactNeighbourIndex public
::method init
  expose dataset
  use strict arg datasetValue
  if datasetValue~sampleCount<1 then raise syntax 88.900 array('cannot build exact-neighbour index on empty dataset')
  dataset=datasetValue
::method query
  expose dataset
  use strict arg row,k=5,excludeSampleId=.nil
  if k<1 then raise syntax 88.900 array('exact-neighbour k must be positive')
  results=.array~new
  dummySchema=.MLCloseHashSchema~new(self~unitDimensions(row~items),'EXACT-ORACLE')
  qh=dummySchema~encode(self~unitRow(row~items))
  do i=1 to dataset~sampleCount
    sid=dataset~sampleId(i); if excludeSampleId\==.nil then if sid==excludeSampleId then iterate
    train=dataset~row(i); d=self~squaredDistance(row,train); zero=.MLCloseHashDifference~new(0,0,.array~of(0),.array~of(0)); results~append(.MLCloseNeighbourResult~new(sid,dataset~target(i),zero,d,qh))
  end
  results~sortWith(.MLExactResultComparator~new); out=.array~new; limit=k; if limit>results~items then limit=results~items
  do i=1 to limit; out~append(results[i]); end
  return out
::method squaredDistance private
  use strict arg a,b
  if a~items<>b~items then raise syntax 88.900 array('exact-neighbour row width mismatch')
  numeric digits 40; d=0; do i=1 to a~items; x=(a[i]+0)-(b[i]+0); d=d+x*x; end; return d
::method unitDimensions private
  use strict arg n
  a=.array~new; do i=1 to n; a~append(.MLCloseHashDimension~new('x'||i,0,1,2,1)); end; return a
::method unitRow private
  use strict arg n
  a=.array~new; do i=1 to n; a~append(0); end; return a

::class MLCloseNeighbourAssessment public
::method init
  expose recallAtK candidateFraction queries exactHits approximateHits k probeRadius
  use strict arg recallAtKValue,candidateFractionValue,queriesValue,exactHitsValue,approximateHitsValue,kValue,probeRadiusValue
  recallAtK=recallAtKValue; candidateFraction=candidateFractionValue; queries=queriesValue; exactHits=exactHitsValue; approximateHits=approximateHitsValue; k=kValue; probeRadius=probeRadiusValue
::method recallAtK; expose recallAtK; return recallAtK
::method candidateFraction; expose candidateFraction; return candidateFraction
::method queries; expose queries; return queries
::method exactHits; expose exactHits; return exactHits
::method approximateHits; expose approximateHits; return approximateHits
::method k; expose k; return k
::method probeRadius; expose probeRadius; return probeRadius
::method canonicalText
  expose recallAtK candidateFraction queries exactHits approximateHits k probeRadius
  return 'CLOSE_NEIGHBOUR_ASSESSMENT=recall@'||k||'='||recallAtK||'|candidateFraction='||candidateFraction||'|queries='||queries||'|hits='||approximateHits||'/'||exactHits||'|radius='||probeRadius
::method evaluate class
  use strict arg index,dataset,k=5,probeRadius=1,maxCandidates=0,mode='EXACT'
  oracle=.MLExactNeighbourIndex~new(dataset); hits=0; total=0; candidates=0; possible=0; queries=0
  do i=1 to dataset~sampleCount
    if dataset~sampleCount<=1 then leave
    row=dataset~row(i); sid=dataset~sampleId(i); exact=oracle~query(row,k,sid); approx=index~query(row,k,probeRadius,maxCandidates,mode,sid)
    exactSet=.directory~new; do r over exact; exactSet[r~sampleId~string]=1; end
    do r over approx~results; if exactSet~hasIndex(r~sampleId~string) then hits=hits+1; end
    total=total+exact~items; candidates=candidates+approx~candidatesExamined; possible=possible+(dataset~sampleCount-1); queries=queries+1
  end
  recall=0; if total>0 then recall=hits/total
  fraction=0; if possible>0 then fraction=candidates/possible
  return self~new(recall,fraction,queries,total,hits,k,probeRadius)

::requires "MLCore.cls"
::requires "MLStandard.cls"
