/* SPASH SLAM v0.1: graph of spectral likeness and temporal continuation.
 * All labels are hypotheses; no source/reflector identity is asserted.
 */
::requires 'SpashObservation.cls'
::class SpashGraph public
::method init
  expose _items _byId _edges _families _dirty _likeFloor _linkFloor _maxGap
  use strict arg likenessFloor=.86, linkFloor=.78, maxGapMs=80
  if \datatype(likenessFloor,'N') | \datatype(linkFloor,'N') | \datatype(maxGapMs,'N') then raise syntax 88.900 array('numeric policy',likenessFloor linkFloor maxGapMs)
  if likenessFloor<0 | likenessFloor>1 | linkFloor<0 | linkFloor>1 | maxGapMs<0 then raise syntax 88.900 array('bounded policy',likenessFloor linkFloor maxGapMs)
  _items=.array~new; _byId=.directory~new; _edges=.array~new; _families=.directory~new
  _likeFloor=likenessFloor; _linkFloor=linkFloor; _maxGap=maxGapMs; _dirty=.true
::method add
  expose _items _byId _dirty
  use strict arg observation
  if \observation~isA(.SpashObservation) then raise syntax 88.900 array('SpashObservation expected',observation)
  if _byId~hasIndex(observation~id) then raise syntax 88.900 array('duplicate observation id',observation~id)
  _items~append(observation); _byId~put(observation,observation~id); _dirty=.true
  return observation~id
::method count; expose _items; return _items~items
::method observation
  expose _byId
  use strict arg id
  return _byId~at(id)
::method sorted
  expose _items
  output=.array~new
  do i=1 to _items~items
    output~append(_items[i])
    do j=output~items to 2 by -1
      right=output[j]; left=output[j-1]
      move=.false
      if right~startMs<left~startMs then move=.true
      if right~startMs=left~startMs then do
        if right~id<left~id then move=.true
      end
      if \move then leave
      output[j]=left; output[j-1]=right
    end
  end
  return output
::method root private
  use strict arg parents,id
  key=id
  do while parents~at(key) \== key
    key=parents~at(key)
  end
  return key
::method build
  expose _items _edges _families _dirty _likeFloor _linkFloor _maxGap
  if \_dirty then return
  _edges=.array~new; _families=.directory~new
  ordered=self~sorted
  parents=.directory~new
  do i=1 to ordered~items
    parents~put(ordered[i]~id,ordered[i]~id)
  end
  do i=1 to ordered~items
    a=ordered[i]
    do j=i+1 to ordered~items
      b=ordered[j]
      like=a~likeness(b)
      if like == .nil then iterate
      if like>=_likeFloor then do
        r1=self~root(parents,a~id); r2=self~root(parents,b~id)
        if r1<r2 then parents~put(r1,r2)
        else parents~put(r2,r1)
      end
      /* v0 continuation is restricted to one source timeline, with non-overlap.
       * Cross-feed alignment requires a separately qualified future contract. */
      if a~sourceId \== b~sourceId then iterate
      if a~methodId \== b~methodId then iterate
      gap=b~startMs-a~endMs
      if gap<0 | gap>_maxGap then iterate
      if like<_linkFloor then iterate
      e=.directory~new
      e~put(a~id,'FROM'); e~put(b~id,'TO')
      e~put(like,'LIKENESS'); e~put(gap,'GAP_MS')
      e~put('CONTINUATION_CANDIDATE','RELATION')
      _edges~append(e)
    end
  end
  do i=1 to ordered~items
    id=ordered[i]~id
    _families~put('LIKE:'||self~root(parents,id),id)
  end
  _dirty=.false
::method familyOf
  expose _families
  use strict arg id
  self~build
  return _families~at(id)
::method edges
  expose _edges
  self~build
  out=.array~new
  do i=1 to _edges~items
    out~append(_edges[i])
  end
  return out
::method edgeBetween private
  expose _edges
  use strict arg fromId,toId
  do k=1 to _edges~items
    edge=_edges[k]
    if edge~at('FROM')==fromId & edge~at('TO')==toId then return edge
  end
  return .nil
::method bestPath
  use strict arg excluded=.nil
  self~build
  if excluded==.nil then excluded=.directory~new
  ordered=self~sorted
  dp=.array~new; pred=.array~new
  topIndex=0; topScore=0
  do i=1 to ordered~items
    candidate=ordered[i]
    dp[i]=0; pred[i]=0
    if excluded~hasIndex(candidate~id) then iterate
    dp[i]=1
    do j=1 to i-1
      previous=ordered[j]
      if excluded~hasIndex(previous~id) then iterate
      edge=self~edgeBetween(previous~id,candidate~id)
      if edge==.nil then iterate
      score=dp[j]+1+edge~at('LIKENESS')
      if score>dp[i] then do
        dp[i]=score; pred[i]=j
      end
    end
    if dp[i]>topScore then do
      topScore=dp[i]; topIndex=i
    end
  end
  backward=.array~new
  do while topIndex>0
    backward~append(ordered[topIndex]~id)
    topIndex=pred[topIndex]
  end
  out=.array~new
  do i=backward~items to 1 by -1
    out~append(backward[i])
  end
  return out
::method partition
  use strict arg maxPaths=0
  if \datatype(maxPaths,'N') then raise syntax 88.900 array('numeric maxPaths',maxPaths)
  if maxPaths<0 | maxPaths<>trunc(maxPaths) then raise syntax 88.900 array('nonnegative integer maxPaths',maxPaths)
  used=.directory~new; out=.array~new
  do forever
    if maxPaths>0 then do
      if out~items>=maxPaths then leave
    end
    path=self~bestPath(used)
    if path~items=0 then leave
    out~append(path)
    do i=1 to path~items
      used~put(.true,path[i])
    end
  end
  return out
::method replayPlan
  use strict arg path
  self~build
  if \path~isA(.array) then raise syntax 88.900 array('path must be Array',path)
  out=.array~new; seen=.directory~new
  previousEnd=.nil; previousSource=.nil
  do i=1 to path~items
    o=self~observation(path[i])
    if o==.nil then raise syntax 88.900 array('unknown observation',path[i])
    if seen~hasIndex(o~id) then raise syntax 88.900 array('duplicate path step',o~id)
    seen~put(.true,o~id)
    if previousEnd \== .nil then do
      if o~sourceId \== previousSource then raise syntax 88.900 array('unaligned source switch',o~id)
      if o~startMs<previousEnd then raise syntax 88.900 array('overlapping path order',o~id)
      if self~edgeBetween(path[i-1],o~id)==.nil then raise syntax 88.900 array('no admitted continuation edge',o~id)
    end
    r=.directory~new
    r~put(o~id,'OBSERVATION_ID'); r~put(o~sourceId,'SOURCE_ID')
    r~put(o~methodId,'METHOD_ID'); r~put(o~methodFoundationId,'METHOD_FOUNDATION_ID')
    r~put(o~startSample,'START_SAMPLE'); r~put(o~sampleCount,'SAMPLE_COUNT'); r~put(o~sampleRate,'SAMPLE_RATE')
    r~put(max(0,o~centreHz-o~bandwidthHz/2),'LOW_HZ')
    r~put(o~centreHz+o~bandwidthHz/2,'HIGH_HZ')
    r~put('SOURCE_REFERENCED_PLAN_ONLY','AUTHORITY')
    out~append(r)
    previousEnd=o~endMs; previousSource=o~sourceId
  end
  return out
