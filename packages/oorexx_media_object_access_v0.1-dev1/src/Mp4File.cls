/* Bounded, media-centric ISO BMFF/MP4 container inspection.
 * No codec decode, no FFmpeg dependency, no sequential traversal of mdat.
 * This initial increment exposes atoms and track metadata, NOT sample seeking.
 */
::options digits 30

::class MediaFileBuild public
::constant VERSION '0.1-dev1'
::constant API 'media.file/0.1'

::class MediaFile public
::method open class
  use strict arg byteSource
  return .MediaFileProbe~open(byteSource)
::method openMp4 class
  use strict arg byteSource
  return .MediaMp4File~new(byteSource)

::class MediaMp4File subclass MediaFile public
::attribute source get
::attribute identity get
::attribute sizeBytes get
::attribute atoms get
::attribute movie get
::attribute tracks get
::attribute layout get
::attribute movieTimeScale get
::method init
  expose source identity sizeBytes atoms movie tracks layout movieTimeScale
  use strict arg byteSource
  source=byteSource
  identity=source~sourceIdentity
  sizeBytes=source~sizeBytes
  if datatype(sizeBytes,'W')=0 | sizeBytes<8 then -
    raise syntax 88.900 array('invalid MP4 size',sizeBytes)
  atoms=.Mp4AtomScanner~scan(source,0,sizeBytes)
  movie=.nil; movieTimeScale=0
  tracks=.array~new
  fragment=.false
  do i=1 to atoms~items
    atom=atoms[i]
    select
      when atom~kind='moov' then do
        if movie<>.nil then raise syntax 88.900 array('multiple moov atoms')
        movie=atom
      end
      when atom~kind='moof' | atom~kind='styp' then fragment=.true
      otherwise nop
    end
  end
  if movie<>.nil then do
    layout='MOVIE'
    if fragment then layout='FRAGMENTED'
    children=movie~children
    /* mvhd supplies the common movie timescale for each track's edit list. */
    do i=1 to children~items
      if children[i]~kind='mvhd' then do
        version=x2d(c2x(children[i]~exactBytes(0,1)))
        select
          when version=0 then movieTimeScale=x2d(c2x(children[i]~exactBytes(12,4)))
          when version=1 then movieTimeScale=x2d(c2x(children[i]~exactBytes(20,4)))
          otherwise raise syntax 88.900 array('unsupported mvhd version',version)
        end
        if movieTimeScale<1 then raise syntax 88.900 array('invalid mvhd movie timescale')
      end
    end
    do i=1 to children~items
      if children[i]~kind='trak' then -
        tracks~append(.MediaMp4Track~new(source,children[i],tracks~items+1,fragment,movieTimeScale))
    end
  end
  else do
    if \fragment then raise syntax 88.900 array('MP4 has no movie or segment metadata')
    layout='SEGMENT_REQUIRES_INIT'
  end
::method track
  expose tracks
  use strict arg ordinal
  if datatype(ordinal,'W')=0 | ordinal<1 | ordinal>tracks~items then -
    raise syntax 88.900 array('track ordinal outside file',ordinal)
  return tracks[ordinal]
::method trackCount
  expose tracks
  return tracks~items

::class Mp4Atom public
::attribute source get
::attribute start get
::attribute length get
::attribute headerBytes get
::attribute kind get
::attribute payloadStart get
::attribute endOffset get
::method init
  expose source start length headerBytes kind payloadStart endOffset
  use strict arg byteSource,offset,size,header,fourcc
  source=byteSource; start=offset; length=size
  headerBytes=header; kind=fourcc
  payloadStart=start+headerBytes
  endOffset=start+length
::method isContainer
  expose kind
  return wordpos(kind,'moov trak mdia minf stbl edts dinf udta mvex moof traf')>0
::method children
  expose source payloadStart endOffset kind
  if \self~isContainer then raise syntax 88.900 array('not a supported MP4 container',kind)
  return .Mp4AtomScanner~scan(source,payloadStart,endOffset)
::method exactBytes
  expose source payloadStart endOffset
  use strict arg relative,count
  if datatype(relative,'W')=0 | datatype(count,'W')=0 then -
    raise syntax 88.900 array('atom reads require whole offsets')
  if relative<0 | count<0 | payloadStart+relative+count>endOffset then -
    raise syntax 88.900 array('atom read out of bounds',relative,count)
  raw=source~readAt(payloadStart+relative,count)
  if raw~length<>count then raise syntax 88.900 array('short atom payload read',relative,count)
  return raw

::class Mp4AtomScanner public
::method scan class
  use strict arg source,startAt,stopAt
  if datatype(startAt,'W')=0 | datatype(stopAt,'W')=0 then -
    raise syntax 88.900 array('MP4 scan offsets must be whole numbers')
  if startAt<0 | stopAt<startAt | stopAt>source~sizeBytes then -
    raise syntax 88.900 array('MP4 atom bounds invalid',startAt,stopAt)
  list=.array~new
  at=startAt
  do while at<stopAt
    if stopAt-at<8 then raise syntax 88.900 array('trailing atom header truncated',at,stopAt)
    raw=source~readAt(at,8)
    if raw~length<>8 then raise syntax 88.900 array('short atom header',at)
    size=x2d(c2x(substr(raw,1,4)))
    kind=substr(raw,5,4)
    header=8
    if size=1 then do
      if stopAt-at<16 then raise syntax 88.900 array('truncated 64-bit atom',at)
      extra=source~readAt(at+8,8)
      if extra~length<>8 then raise syntax 88.900 array('short extended atom header',at)
      size=x2d(c2x(extra)); header=16
    end
    else if size=0 then size=stopAt-at
    if size<header | size>stopAt-at then -
      raise syntax 88.900 array('invalid or overflowing MP4 atom',at,kind,size)
    list~append(.Mp4Atom~new(source,at,size,header,kind))
    at=at+size
  end
  return list

::class MediaMp4Track public
::attribute ordinal get
::attribute trackId get
::attribute kind get
::attribute codecTag get
::attribute timeScale get
::attribute durationTicks get
::attribute sampleTable get
::attribute indexStatus get
::attribute hasEdits get
::attribute fragmented get
::attribute movieTimeScale get
::method init
  expose ordinal trackId kind codecTag timeScale durationTicks sampleTable indexStatus hasEdits fragmented sampleMapCache editAtom movieTimeScale sourceRef
  use strict arg source,atom,position,isFragmented=.false,movieScale=0
  sourceRef=source
  ordinal=position
  trackId=-1; kind='unknown'; codecTag='unknown'; timeScale=0; durationTicks=-1
  sampleTable=.nil; editAtom=.nil
  indexStatus='NOT_INDEXED'; hasEdits=.false
  fragmented=(isFragmented==.true); sampleMapCache=.nil
  movieTimeScale=movieScale
  elements=atom~children
  do i=1 to elements~items
    child=elements[i]
    select
      when child~kind='tkhd' then do
        version=x2d(c2x(child~exactBytes(0,1)))
        if version=0 then trackId=x2d(c2x(child~exactBytes(12,4)))
        else if version=1 then trackId=x2d(c2x(child~exactBytes(20,4)))
        else raise syntax 88.900 array('unsupported tkhd version',version)
      end
      when child~kind='mdia' then self~inspectMedia(child)
      when child~kind='edts' then do
        hasEdits=.true
        editChildren=child~children
        do j=1 to editChildren~items
          if editChildren[j]~kind='elst' then do
            if editAtom<>.nil then raise syntax 88.900 array('multiple elst boxes in track')
            editAtom=editChildren[j]
          end
        end
      end
      otherwise nop
    end
  end
::method inspectMedia private
  expose kind codecTag timeScale durationTicks sampleTable
  use strict arg mdia
  elements=mdia~children
  do i=1 to elements~items
    child=elements[i]
    select
      when child~kind='hdlr' then kind=child~exactBytes(8,4)
      when child~kind='mdhd' then do
        version=x2d(c2x(child~exactBytes(0,1)))
        select
          when version=0 then do
            timeScale=x2d(c2x(child~exactBytes(12,4)))
            durationTicks=x2d(c2x(child~exactBytes(16,4)))
          end
          when version=1 then do
            timeScale=x2d(c2x(child~exactBytes(20,4)))
            durationTicks=x2d(c2x(child~exactBytes(24,8)))
          end
          otherwise raise syntax 88.900 array('unsupported mdhd version',version)
        end
      end
      when child~kind='minf' then do
        minfChildren=child~children
        do j=1 to minfChildren~items
          if minfChildren[j]~kind='stbl' then do
            sampleTable=minfChildren[j]
            tableChildren=sampleTable~children
            do k=1 to tableChildren~items
              if tableChildren[k]~kind='stsd' then do
                entryCount=x2d(c2x(tableChildren[k]~exactBytes(4,4)))
                if entryCount>0 then codecTag=tableChildren[k]~exactBytes(12,4)
              end
            end
          end
        end
      end
      otherwise nop
    end
  end
/* Index sample metadata without invoking a decoder. Requires the separate
 * Mp4SampleTable.cls module in the calling ooRexx package. */
::method mapSamples
  expose sampleTable trackId timeScale hasEdits fragmented sampleMapCache indexStatus editAtom movieTimeScale
  if fragmented then raise syntax 88.900 array('fragmented MP4 sample mapping not implemented')
  if hasEdits & editAtom==.nil then -
    raise syntax 88.900 array('edts track is missing an elst edit list')
  if hasEdits & movieTimeScale<1 then -
    raise syntax 88.900 array('MP4 edit list missing mvhd timescale')
  if sampleTable==.nil then raise syntax 88.900 array('MP4 track has no flat sample table')
  if timeScale<1 then raise syntax 88.900 array('MP4 track timescale is unavailable')
  if sampleMapCache==.nil then do
    sampleMapCache=.MediaMp4SampleTable~new(sampleTable,trackId,timeScale,editAtom,movieTimeScale)
    indexStatus=sampleMapCache~indexStatus
  end
  return sampleMapCache
/* Restore an immutable-version-bound flat sample map without rescanning
 * stsz/stco/stts/ctts/elst; decoder qualification remains separate. */
::method installIndexText
  expose sourceRef trackId timeScale fragmented sampleMapCache indexStatus
  use strict arg manifest
  if fragmented then raise syntax 88.900 array('fragmented MP4 snapshot unsupported')
  if timeScale<1 then raise syntax 88.900 array('missing MP4 media timescale')
  sampleMapCache=.MediaMp4IndexSnapshot~new(manifest,sourceRef,trackId,timeScale)
  indexStatus=sampleMapCache~indexStatus
  return sampleMapCache
::method exportIndexText
  return self~mapSamples~exportIndexText
::method planTime
  use strict arg ticks
  return self~mapSamples~planTime(ticks)
::method seekTime
  use strict arg pts,mode='EXACT'
  raise syntax 88.900 array('MP4 sample-index implementation is not yet qualified',pts,mode)

::requires 'MediaFileProbe.cls'
::requires 'Mp4IndexSnapshot.cls'
