/* Media container selection is based on binary signatures, not suffixes.
 * PNG joins TS and MP4; foreign/unsupported formats fail closed.
 */
::options digits 30
::class MediaFileProbe public
::method detect class
  use strict arg source
  length=source~sizeBytes
  if length>=8 then do
    if source~readAt(0,8)=x2c('89504E470D0A1A0A') then return 'PNG'
  end
  if length>=564 & length // 188=0 then do
    header=source~readAt(0,1)||source~readAt(188,1)||source~readAt(376,1)
    if header=x2c('474747') then return 'MPEG_TS_188'
  end
  if length>=8 then do
    kind=source~readAt(4,4)
    if wordpos(kind,'ftyp styp moov')>0 then return 'ISO_BMFF_MP4'
  end
  if length>=4 then do
    if source~readAt(0,4)=x2c('1A45DFA3') then return 'MATROSKA_UNSUPPORTED'
  end
  return 'UNSUPPORTED'
::method open class
  use strict arg source
  kind=self~detect(source)
  select
    when kind='PNG' then return .MediaPngFile~new(source)
    when kind='MPEG_TS_188' then return .MediaTsFile~new(source)
    when kind='ISO_BMFF_MP4' then return .MediaMp4File~new(source)
    otherwise raise syntax 88.900 array('unsupported media container signature',kind)
  end
::requires 'MediaPngFile.cls'
::requires 'MediaTsFile.cls'