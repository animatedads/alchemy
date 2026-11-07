/* Persistent flat MP4 sample-map snapshot, source-version bound.
 * Authoritative Storage Fabric MUST publish this text atomically on its MU;
 * a path/inode/size-only identity is insufficient for remote reuse.
 * Restoring this index does not read mdat or rescan stsz/stco/ctts/elst.
 * It reconstructs the same sample / presentation / sync-candidate objects.
 * A container sync flag is not a codec-qualified exact decode point.
 */
::options digits 30

::class MediaMp4IndexSnapshot public
::attribute sourceIdentity get
::attribute sourceSize get
::attribute trackId get
::attribute timeScale get
::attribute sampleCount get
::attribute presentationCount get
::attribute indexStatus get
::method init
  expose source sourceIdentity sourceSize trackId timeScale sampleCount -
         presentationCount indexStatus samples presented syncOrdinals
  use strict arg manifest,byteSource,expectedTrack,expectedScale
  source=byteSource; sourceIdentity=source~sourceIdentity
  sourceSize=source~sizeBytes
  trackId=expectedTrack; timeScale=expectedScale
  samples=.array~new; presented=.array~new; syncOrdinals=.array~new
  rest=manifest
  parse var rest line '0a'x rest
  if line<>'M4SIDX|1' then raise syntax 88.900 array('unsupported MP4 snapshot revision')
  parse var rest line '0a'x rest
  if line<>'IDENTITY|'||c2x(sourceIdentity) then -
    raise syntax 88.900 array('MP4 snapshot source/version mismatch')
  parse var rest line '0a'x rest
  if line<>'SIZE|'||sourceSize then raise syntax 88.900 array('MP4 snapshot size mismatch')
  parse var rest line '0a'x rest
  if line<>'TRACK|'||trackId then raise syntax 88.900 array('MP4 snapshot track mismatch')
  parse var rest line '0a'x rest
  if line<>'TIMESCALE|'||timeScale then raise syntax 88.900 array('MP4 snapshot timescale mismatch')
  parse var rest line '0a'x rest
  parse var line 'SAMPLES|' sampleCount
  if \datatype(sampleCount,'W') | sampleCount<1 | sampleCount>2000000 then -
    raise syntax 88.900 array('MP4 snapshot sample budget exceeded')
  parse var rest line '0a'x rest
  parse var line 'VISIBLE|' presentationCount
  if \datatype(presentationCount,'W') | presentationCount<0 | presentationCount>sampleCount then -
    raise syntax 88.900 array('MP4 snapshot presentation count invalid')
  do i=1 to sampleCount
    parse var rest line '0a'x rest
    parse var line 'S|' ord '|' off '|' nbytes '|' chunk '|' desc '|' dts '|' dur '|' mediaPts '|' moviePts '|' visible '|' sync
    do field over .array~of(ord,off,nbytes,chunk,desc,dts,dur,mediaPts,moviePts,visible,sync)
      if \datatype(field,'W') then raise syntax 88.900 array('MP4 snapshot malformed sample',i)
    end
    if ord<>i | off<0 | nbytes<1 | off+nbytes>sourceSize | -
       chunk<1 | desc<1 | dur<0 | (visible<>0 & visible<>1) | -
       (sync<>0 & sync<>1) then -
      raise syntax 88.900 array('MP4 snapshot sample outside source or invalid',i)
    sample=.MediaMp4Sample~new(i,off,nbytes,chunk,desc)
    sample~assignClock(dts,dur)
    sample~addCompositionOffset(mediaPts-dts)
    if visible=0 then sample~hideFromPresentation
    else sample~setMoviePresentation(moviePts)
    if sync=1 then do
      sample~markSyncCandidate
      syncOrdinals~append(i)
    end
    samples~append(sample)
  end
  previousPts=.nil
  do i=1 to presentationCount
    parse var rest line '0a'x rest
    parse var line 'V|' ord
    if \datatype(ord,'W') | ord<1 | ord>sampleCount then -
      raise syntax 88.900 array('MP4 snapshot presentation ordinal invalid',i)
    sample=samples[ord]
    if \sample~presentationVisible then raise syntax 88.900 array('hidden sample in presentation index',i)
    if previousPts<>.nil & sample~presentationTicks<previousPts then -
      raise syntax 88.900 array('MP4 snapshot presentation not sorted',i)
    presented~append(sample)
    previousPts=sample~presentationTicks
  end
  parse var rest line '0a'x rest
  if line<>'END' | rest<>'' then raise syntax 88.900 array('MP4 snapshot truncated or trailing data')
  indexStatus='CANDIDATE_ONLY'
::method assertSource
  expose source sourceIdentity sourceSize
  if source~sourceIdentity<>sourceIdentity | source~sizeBytes<>sourceSize then -
    raise syntax 88.900 array('MP4 snapshot source changed')
  return self
::method sample
  expose samples sampleCount
  use strict arg ordinal
  self~assertSource
  if \datatype(ordinal,'W') | ordinal<1 | ordinal>sampleCount then -
    raise syntax 88.900 array('MP4 snapshot sample ordinal out of range',ordinal)
  return samples[ordinal]
::method atOrAfter
  expose presented presentationCount
  use strict arg ticks
  self~assertSource
  if \datatype(ticks,'W') then raise syntax 88.900 array('MP4 seek needs integer movie PTS')
  lo=1; hi=presentationCount; found=0
  do while lo<=hi
    middle=(lo+hi)%2
    if presented[middle]~presentationTicks>=ticks then do
      found=middle; hi=middle-1
    end
    else lo=middle+1
  end
  if found=0 then return .nil
  return presented[found]
::method priorSyncCandidate
  expose syncOrdinals samples
  use strict arg ordinal
  lo=1; hi=syncOrdinals~items; found=0
  do while lo<=hi
    middle=(lo+hi)%2
    if syncOrdinals[middle]<=ordinal then do
      found=middle; lo=middle+1
    end
    else hi=middle-1
  end
  if found=0 then return .nil
  return samples[syncOrdinals[found]]
::method planTime
  expose sourceIdentity timeScale
  use strict arg ticks
  self~assertSource
  target=self~atOrAfter(ticks)
  if target==.nil then return .nil
  anchor=self~priorSyncCandidate(target~ordinal)
  return .MediaMp4SeekPlan~new(target,anchor,sourceIdentity,timeScale,ticks)
::method rangesForPlan
  expose samples sampleCount sourceIdentity
  use strict arg plan,budget=4194304,maxSamples=512
  self~assertSource
  if plan==.nil | plan~sourceIdentity<>sourceIdentity then -
    raise syntax 88.900 array('MP4 snapshot plan identity mismatch')
  if \datatype(budget,'W') | \datatype(maxSamples,'W') | -
      budget<1 | maxSamples<1 | budget>16777216 | maxSamples>4096 then -
    raise syntax 88.900 array('MP4 snapshot range budget invalid')
  if plan~anchor==.nil then raise syntax 88.900 array('no MP4 sync candidate for plan')
  first=plan~anchor~ordinal; last=plan~target~ordinal
  if first<1 | last>sampleCount | last<first | last-first+1>maxSamples then -
    raise syntax 88.900 array('MP4 snapshot decoder dependency window unsupported')
  ranges=.array~new; total=0
  do i=first to last
    s=samples[i]
    total=total+s~sizeBytes
    if total>budget then raise syntax 88.900 array('MP4 snapshot seek would exceed byte budget')
    if ranges~items>0 & ranges[ranges~items]~canExtend(s) then -
      ranges[ranges~items]~append(s)
    else ranges~append(.MediaMp4ByteRange~new(s))
  end
  return ranges
::requires 'Mp4SampleTable.cls'