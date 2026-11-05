/* MP4 flat-file sample table, independent of codecs and FFmpeg.
 * Reads only ISO BMFF metadata via bounded absolute MediaByteSource reads.
 * Byte offsets, DTS and PTS remain exact integers (ooRexx digits 30).
 * No compressed payload read, decoder inference or whole-file transfer.
 * Version: 0.1-dev2 source increment (not a qualified decoder seek).
 */
::options digits 30

::class Mp4SampleTableBuild public
::constant VERSION '0.1-dev2'
::constant API 'media.mp4.sample-map/0.1'
::constant MAX_SAMPLES 2000000

/* Metadata-only bounded reader. Reuses a single <=8192 byte block per box.
 * Several small field reads do not cause one remote Storage GET each. */
::class Mp4BoxReader public
::method init
  expose atom cachedStart cached payloadBytes
  use strict arg mp4Atom
  atom=mp4Atom; cachedStart=-1; cached=''
  payloadBytes=atom~length-atom~headerBytes
::method payloadBytes
  expose payloadBytes
  return payloadBytes
::method bytes
  expose atom cachedStart cached payloadBytes
  use strict arg offset,n
  if datatype(offset,'W')=0 | datatype(n,'W')=0 | offset<0 | n<0 | -
     offset+n>payloadBytes | n>8192 then -
    raise syntax 88.900 array('MP4 metadata read out of bounds',offset,n)
  if n=0 then return ''
  if cachedStart>=0 then do
    if offset>=cachedStart & offset+n<=cachedStart+cached~length then -
      return substr(cached,offset-cachedStart+1,n)
  end
  cachedStart=offset
  wanted=payloadBytes-offset
  if wanted>8192 then wanted=8192
  cached=atom~exactBytes(offset,wanted)
  return substr(cached,1,n)
::method unsigned
  use strict arg offset,n
  if n<>1 & n<>2 & n<>4 & n<>8 then -
    raise syntax 88.900 array('unsupported MP4 integer width',n)
  return x2d(c2x(self~bytes(offset,n)))
::method signed32
  use strict arg offset
  n=self~unsigned(offset,4)
  if n>=2147483648 then n=n-4294967296
  return n
::method version
  return self~unsigned(0,1)
::method requireBytes
  expose payloadBytes
  use strict arg n
  if datatype(n,'W')=0 | n>payloadBytes then -
    raise syntax 88.900 array('truncated MP4 sample table',n,payloadBytes)

::class MediaMp4Sample public
::attribute ordinal get
::attribute byteOffset get
::attribute sizeBytes get
::attribute chunkOrdinal get
::attribute descriptionIndex get
::attribute decodeTicks get
::attribute presentationTicks get
::attribute durationTicks get
::attribute syncCandidate get
::method init
  expose ordinal byteOffset sizeBytes chunkOrdinal descriptionIndex decodeTicks presentationTicks durationTicks syncCandidate
  use strict arg ord,offset,bytes,chunk,description
  ordinal=ord; byteOffset=offset; sizeBytes=bytes
  chunkOrdinal=chunk; descriptionIndex=description
  decodeTicks=0; presentationTicks=0; durationTicks=0
  syncCandidate=.false
::method assignClock
  expose decodeTicks presentationTicks durationTicks
  use strict arg dts,duration
  decodeTicks=dts; presentationTicks=dts; durationTicks=duration
  return self
::method addCompositionOffset
  expose presentationTicks
  use strict arg offset
  presentationTicks=presentationTicks+offset
  return self
::method markSyncCandidate
  expose syncCandidate
  syncCandidate=.true
  return self

::class MediaMp4SeekPlan public
::attribute target get
::attribute anchor get
::attribute status get
::attribute sourceIdentity get
::attribute timeScale get
::attribute requestedTicks get
::method init
  expose target anchor status sourceIdentity timeScale requestedTicks
  use strict arg sample,randomAccess,identity,scale,ticks
  target=sample; anchor=randomAccess; sourceIdentity=identity
  timeScale=scale; requestedTicks=ticks
  status='UNVERIFIED_DECODER_PREROLL'
  if anchor==.nil then status='NO_VERIFIED_RANDOM_ACCESS'
/* Never claim an exact decoded frame based only on container flags. */
::method canDecodeExactly
  return .false

::class MediaMp4SampleTable public
::attribute sampleCount get
::attribute timeScale get
::attribute trackId get
::attribute sourceIdentity get
::attribute indexStatus get
::attribute hasCompositionOffsets get
::attribute hasSyncTable get
::method init
  expose source sourceIdentity trackId timeScale samples presented syncOrdinals sampleCount -
         indexStatus hasCompositionOffsets hasSyncTable
  use strict arg stblAtom,id,scale
  if stblAtom~kind<>'stbl' then raise syntax 88.900 array('MP4 sample table expected stbl')
  if datatype(scale,'W')=0 | scale<1 then raise syntax 88.900 array('invalid MP4 media timescale')
  source=stblAtom~source; sourceIdentity=source~sourceIdentity
  trackId=id; timeScale=scale
  samples=.array~new; presented=.array~new; syncOrdinals=.array~new
  sampleCount=0; indexStatus='BUILDING'
  hasCompositionOffsets=.false; hasSyncTable=.false
  boxes=.directory~new
  children=stblAtom~children
  do i=1 to children~items
    atom=children[i]
    key=atom~kind
    if boxes~hasIndex(key) then raise syntax 88.900 array('duplicate MP4 sample-table atom',key)
    boxes[key]=atom
  end
  if \boxes~hasIndex('stts') | \boxes~hasIndex('stsc') | \boxes~hasIndex('stsz') then -
    raise syntax 88.900 array('incomplete flat MP4 sample tables')
  if (boxes~hasIndex('stco') & boxes~hasIndex('co64')) | -
     (\boxes~hasIndex('stco') & \boxes~hasIndex('co64')) then -
    raise syntax 88.900 array('MP4 requires exactly one chunk-offset table')
  if \boxes~hasIndex('stsd') then raise syntax 88.900 array('MP4 missing sample descriptions')
  stsd=.Mp4BoxReader~new(boxes['stsd'])
  stsd~requireBytes(8)
  descriptions=stsd~unsigned(4,4)
  if descriptions<1 then raise syntax 88.900 array('MP4 has no sample descriptions')

  self~readSampleSizes(boxes['stsz'])
  self~mapChunkOffsets(boxes,descriptions)
  self~mapDecodeTime(boxes['stts'])
  if boxes~hasIndex('ctts') then self~mapComposition(boxes['ctts'])
  if boxes~hasIndex('stss') then self~mapSyncCandidates(boxes['stss'])
  self~sortPresentation
  if source~sourceIdentity<>sourceIdentity then -
    raise syntax 88.900 array('MP4 source changed during metadata index construction')
  indexStatus='CANDIDATE_ONLY'
::method readSampleSizes private
  expose samples sampleCount
  use strict arg atom
  b=.Mp4BoxReader~new(atom)
  b~requireBytes(12)
  if b~version<>0 then raise syntax 88.900 array('unsupported stsz version')
  fixed=b~unsigned(4,4)
  sampleCount=b~unsigned(8,4)
  if sampleCount<1 | sampleCount>.Mp4SampleTableBuild~MAX_SAMPLES then -
    raise syntax 88.900 array('MP4 sample count exceeds safe bound',sampleCount)
  if fixed=0 then b~requireBytes(12+sampleCount*4)
  sizes=.array~new
  do i=1 to sampleCount
    sz=fixed
    if fixed=0 then sz=b~unsigned(12+(i-1)*4,4)
    if sz<1 then raise syntax 88.900 array('zero-sized MP4 sample unsupported',i)
    sizes~append(sz)
  end
  self~setSizes(sizes)
::method setSizes private
  expose sampleSizes
  use strict arg sizes
  sampleSizes=sizes

::method mapChunkOffsets private
  expose source sampleSizes samples sampleCount
  use strict arg boxes,descriptions
  stsc=.Mp4BoxReader~new(boxes['stsc'])
  stsc~requireBytes(8)
  if stsc~version<>0 then raise syntax 88.900 array('unsupported stsc version')
  entryCount=stsc~unsigned(4,4)
  if entryCount<1 then raise syntax 88.900 array('MP4 has no sample-to-chunk entries')
  stsc~requireBytes(8+entryCount*12)
  runEntries=.array~new
  prevFirst=0
  do i=1 to entryCount
    off=8+(i-1)*12
    first=stsc~unsigned(off,4)
    per=stsc~unsigned(off+4,4)
    desc=stsc~unsigned(off+8,4)
    if first<=prevFirst | (i=1 & first<>1) | per<1 | desc<1 | desc>descriptions then -
      raise syntax 88.900 array('invalid sample-to-chunk run',i,first,per,desc)
    runEntries~append(.array~of(first,per,desc))
    prevFirst=first
  end
  if boxes~hasIndex('co64') then do
    chunks=.Mp4BoxReader~new(boxes['co64'])
    width=8
  end
  else do
    chunks=.Mp4BoxReader~new(boxes['stco'])
    width=4
  end
  chunks~requireBytes(8)
  if chunks~version<>0 then raise syntax 88.900 array('unsupported chunk-offset version')
  chunkCount=chunks~unsigned(4,4)
  chunks~requireBytes(8+width*chunkCount)
  lastRun=runEntries[entryCount]
  if chunkCount<1 | lastRun[1]>chunkCount then -
    raise syntax 88.900 array('invalid MP4 chunk table count')
  sampleOrdinal=1
  run=1
  do chunk=1 to chunkCount
    do while run<entryCount
      next=runEntries[run+1]
      if next[1]>chunk then leave
      run+=1
    end
    entry=runEntries[run]; per=entry[2]; desc=entry[3]
    byte=chunks~unsigned(8+(chunk-1)*width,width)
    do j=1 to per
      if sampleOrdinal>sampleCount then -
        raise syntax 88.900 array('chunk runs exceed declared sample count',chunk)
      length=sampleSizes[sampleOrdinal]
      if byte+length>source~sizeBytes then -
        raise syntax 88.900 array('sample extends beyond source',sampleOrdinal,byte,length)
      samples~append(.MediaMp4Sample~new(sampleOrdinal,byte,length,chunk,desc))
      byte=byte+length
      sampleOrdinal+=1
    end
  end
  if sampleOrdinal<>sampleCount+1 then -
    raise syntax 88.900 array('chunk runs do not cover sample count',sampleOrdinal,sampleCount)
::method mapDecodeTime private
  expose samples sampleCount
  use strict arg atom
  b=.Mp4BoxReader~new(atom)
  b~requireBytes(8)
  if b~version<>0 then raise syntax 88.900 array('unsupported stts version')
  runs=b~unsigned(4,4)
  b~requireBytes(8+runs*8)
  ordinal=1; dts=0
  do i=1 to runs
    off=8+(i-1)*8
    count=b~unsigned(off,4)
    delta=b~unsigned(off+4,4)
    if count<1 then raise syntax 88.900 array('zero-length stts run',i)
    do j=1 to count
      if ordinal>sampleCount then raise syntax 88.900 array('stts exceeds sample count',ordinal)
      samples[ordinal]~assignClock(dts,delta)
      dts=dts+delta; ordinal+=1
    end
  end
  if ordinal<>sampleCount+1 then raise syntax 88.900 array('stts does not cover sample count')
::method mapComposition private
  expose samples sampleCount hasCompositionOffsets
  use strict arg atom
  b=.Mp4BoxReader~new(atom)
  b~requireBytes(8)
  ver=b~version
  if ver<>0 & ver<>1 then raise syntax 88.900 array('unsupported ctts version',ver)
  runs=b~unsigned(4,4)
  b~requireBytes(8+runs*8)
  ordinal=1
  do i=1 to runs
    off=8+(i-1)*8
    count=b~unsigned(off,4)
    shift=b~unsigned(off+4,4)
    if ver=1 then shift=b~signed32(off+4)
    if count<1 then raise syntax 88.900 array('zero-length ctts run',i)
    do j=1 to count
      if ordinal>sampleCount then raise syntax 88.900 array('ctts exceeds sample count')
      samples[ordinal]~addCompositionOffset(shift)
      ordinal+=1
    end
  end
  if ordinal<>sampleCount+1 then raise syntax 88.900 array('ctts does not cover sample count')
  hasCompositionOffsets=.true
::method mapSyncCandidates private
  expose samples sampleCount syncOrdinals hasSyncTable
  use strict arg atom
  b=.Mp4BoxReader~new(atom)
  b~requireBytes(8)
  if b~version<>0 then raise syntax 88.900 array('unsupported stss version')
  count=b~unsigned(4,4)
  b~requireBytes(8+count*4)
  previous=0
  do i=1 to count
    ordinal=b~unsigned(8+(i-1)*4,4)
    if ordinal<=previous | ordinal>sampleCount then -
      raise syntax 88.900 array('invalid sync sample ordinal',ordinal)
    samples[ordinal]~markSyncCandidate
    syncOrdinals~append(ordinal)
    previous=ordinal
  end
  hasSyncTable=.true
::method sortPresentation private
  expose samples sampleCount presented
  presented=.array~new
  do i=1 to sampleCount
    presented~append(samples[i])
  end
  width=1
  do while width<sampleCount
    merged=.array~new
    start=1
    do while start<=sampleCount
      mid=min(start+width,sampleCount+1)
      stop=min(start+2*width,sampleCount+1)
      a=start; b=mid
      do while a<mid | b<stop
        if b>=stop then do
          merged~append(presented[a]); a+=1
        end
        else if a>=mid then do
          merged~append(presented[b]); b+=1
        end
        else do
          left=presented[a]; right=presented[b]
          if left~presentationTicks<=right~presentationTicks then do
            merged~append(left); a+=1
          end
          else do
            merged~append(right); b+=1
          end
        end
      end
      start=stop
    end
    presented=merged
    width=width*2
  end
::method assertSource
  expose source sourceIdentity
  if source~sourceIdentity<>sourceIdentity then -
    raise syntax 88.900 array('MP4 source identity changed after indexing')
  return self
::method sample
  expose samples sampleCount
  use strict arg ordinal
  self~assertSource
  if datatype(ordinal,'W')=0 | ordinal<1 | ordinal>sampleCount then -
    raise syntax 88.900 array('MP4 sample index outside table',ordinal)
  return samples[ordinal]
::method atOrAfter
  expose presented sampleCount
  use strict arg pts
  self~assertSource
  if datatype(pts,'W')=0 then raise syntax 88.900 array('presentation time must be integer ticks')
  lo=1; hi=sampleCount; found=0
  do while lo<=hi
    mid=(lo+hi)%2
    if presented[mid]~presentationTicks>=pts then do
      found=mid; hi=mid-1
    end
    else lo=mid+1
  end
  if found=0 then return .nil
  return presented[found]
::method priorSyncCandidate
  expose syncOrdinals samples
  use strict arg ordinal
  lo=1; hi=syncOrdinals~items; found=0
  do while lo<=hi
    mid=(lo+hi)%2
    if syncOrdinals[mid]<=ordinal then do
      found=mid; lo=mid+1
    end
    else hi=mid-1
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
