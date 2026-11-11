/* ISO BMFF 'elst' presentation-time translation.
 * Track sample byte offsets and DTS stay in the media timeline. Movie edit
 * timeline is mapped into exact integer track ticks without decoding.
 * Scope: 1x speed, nonrepeating edits, integer-expressible track boundaries.
 * Unsupported rate/repeated edits fail closed rather than introduce drift.
 */
::options digits 30

::class MediaMp4EditTimeline public
::attribute movieTimeScale get
::attribute trackTimeScale get
::attribute entryCount get
::method init
  expose movieTimeScale trackTimeScale entryCount entries
  use strict arg atom,movieScale,trackScale
  if atom==.nil | atom~kind<>'elst' then -
    raise syntax 88.900 array('MP4 track edit list requires elst')
  if datatype(movieScale,'W')=0 | datatype(trackScale,'W')=0 | -
     movieScale<1 | trackScale<1 then -
    raise syntax 88.900 array('invalid MP4 movie/track edit timescales')
  movieTimeScale=movieScale; trackTimeScale=trackScale
  b=.Mp4BoxReader~new(atom)
  b~requireBytes(8)
  version=b~version
  if version<>0 & version<>1 then raise syntax 88.900 array('unsupported MP4 elst version',version)
  entryCount=b~unsigned(4,4)
  if entryCount<1 | entryCount>128 then -
    raise syntax 88.900 array('MP4 edit entry count outside bound',entryCount)
  width=12
  if version=1 then width=20
  b~requireBytes(8+entryCount*width)
  entries=.array~new
  movieStart=0
  do i=1 to entryCount
    offset=8+(i-1)*width
    if version=0 then do
      duration=b~unsigned(offset,4)
      mediaTime=b~signed32(offset+4)
      rateInt=b~signed16(offset+8)
      rateFrac=b~signed16(offset+10)
    end
    else do
      duration=b~unsigned(offset,8)
      mediaTime=b~signed64(offset+8)
      rateInt=b~signed16(offset+16)
      rateFrac=b~signed16(offset+18)
    end
    if duration<1 | mediaTime< -1 then -
      raise syntax 88.900 array('invalid MP4 edit duration/media time',i,duration,mediaTime)
    if rateInt<>1 | rateFrac<>0 then -
      raise syntax 88.900 array('non-unity MP4 edit rate is unqualified',i,rateInt,rateFrac)
    entries~append(.array~of(movieStart,duration,mediaTime))
    movieStart=movieStart+duration
  end

::method applyToSamples
  expose entries movieTimeScale trackTimeScale
  use strict arg samples
  active=0
  do i=1 to samples~items
    sample=samples[i]
    mediaPts=sample~mediaPresentationTicks
    count=0; moviePts=0
    do j=1 to entries~items
      e=entries[j]
      movieStart=e[1]; duration=e[2]; mediaTime=e[3]
      if mediaTime=-1 then iterate  /* empty edit, presentation gap */
      relative=mediaPts-mediaTime
      if relative<0 then iterate
      /* Compare in rational units before dividing: no rounded segment edge. */
      if relative*movieTimeScale>=duration*trackTimeScale then iterate
      count=count+1
      if count>1 then -
        raise syntax 88.900 array('repeated/overlapping MP4 edits require independent presentation instances',i)
      numerator=movieStart*trackTimeScale+relative*movieTimeScale
      if numerator//movieTimeScale<>0 then -
        raise syntax 88.900 array('fractional MP4 edit time cannot be encoded as integer track ticks',i,numerator,movieTimeScale)
      moviePts=numerator%movieTimeScale
    end
    if count=0 then sample~hideFromPresentation
    else do
      sample~setMoviePresentation(moviePts)
      active=active+1
    end
  end
  return active
::requires 'Mp4BoxReader.cls'
