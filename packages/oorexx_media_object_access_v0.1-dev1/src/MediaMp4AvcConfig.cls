/* Strict bounded AVCDecoderConfigurationRecord from a single avc1 sample
 * description. Uses the existing ooRexx MP4 box reader; neither demux nor
 * decoding is delegated to libavformat, subprocesses, or Python.
 *
 * This codec configuration is for one stable sample description only.
 * Switching sample descriptions mid-stream requires explicit new decoder
 * instances and is intentionally rejected by the caller.
 */
::options digits 30

::class MediaMp4AvcConfig public
::attribute annexBPrefix get
::attribute nalLengthBytes get
::attribute sampleDescriptionCount get
::method init
  expose annexBPrefix nalLengthBytes sampleDescriptionCount
  use strict arg stsd
  if stsd==.nil then raise syntax 88.900 array('missing MP4 stsd')
  if stsd~kind<>'stsd' then raise syntax 88.900 array('avc1 sample description must be stsd')
  b=.Mp4BoxReader~new(stsd)
  b~requireBytes(8)
  if b~version<>0 then raise syntax 88.900 array('unsupported stsd version')
  sampleDescriptionCount=b~unsigned(4,4)
  if sampleDescriptionCount<>1 then -
    raise syntax 88.900 array('multiple AVC sample descriptions require explicit decoder switching',sampleDescriptionCount)
  b~requireBytes(94)
  entrySize=b~unsigned(8,4)
  if entrySize<94 | 8+entrySize>b~payloadBytes then -
    raise syntax 88.900 array('avc1 VisualSampleEntry outside stsd',entrySize)
  if b~bytes(12,4)<>'avc1' then -
    raise syntax 88.900 array('unsupported MP4 visual sample entry codec')
  /* VisualSampleEntry fixed portion is 86 bytes, INCLUDING the 8-byte
   * entry header. Child boxes begin at offset 8+86 in stsd payload. */
  at=94
  last=8+entrySize
  configuration=''
  do while at<last
    if last-at<8 then raise syntax 88.900 array('truncated avc1 child atom',at)
    childSize=b~unsigned(at,4)
    childKind=b~bytes(at+4,4)
    if childSize<8 | at+childSize>last then -
      raise syntax 88.900 array('invalid avc1 child bounds',childKind,at,childSize)
    if childKind='avcC' then do
      if configuration<>'' then raise syntax 88.900 array('duplicate AVC codec configuration')
      if childSize-8>8192 then raise syntax 88.900 array('AVC codec metadata exceeds bounded read')
      configuration=b~bytes(at+8,childSize-8)
    end
    at=at+childSize
  end
  if configuration~length<7 then raise syntax 88.900 array('missing/truncated avcC')
  if c2d(substr(configuration,1,1))<>1 then -
    raise syntax 88.900 array('unsupported AVC configuration version')
  nalLengthBytes=(c2d(substr(configuration,5,1))//4)+1
  if nalLengthBytes<>4 then -
    raise syntax 88.900 array('AVC NAL length must be four bytes',nalLengthBytes)
  numSps=c2d(substr(configuration,6,1))//32
  if numSps<1 | numSps>8 then raise syntax 88.900 array('invalid AVC SPS count',numSps)
  at=7
  annexBPrefix=''
  do i=1 to numSps
    size=self~u16(configuration,at)
    at=at+2
    if size<2 | at+size-1>configuration~length then -
      raise syntax 88.900 array('invalid AVC SPS extent',i,size)
    annexBPrefix=annexBPrefix||x2c('00000001')||substr(configuration,at,size)
    at=at+size
  end
  if at>configuration~length then -
    raise syntax 88.900 array('AVC PPS count missing')
  numPps=c2d(substr(configuration,at,1))
  at=at+1
  if numPps<1 | numPps>8 then raise syntax 88.900 array('invalid AVC PPS count',numPps)
  do i=1 to numPps
    size=self~u16(configuration,at)
    at=at+2
    if size<1 | at+size-1>configuration~length then -
      raise syntax 88.900 array('invalid AVC PPS extent',i,size)
    annexBPrefix=annexBPrefix||x2c('00000001')||substr(configuration,at,size)
    at=at+size
  end
  if annexBPrefix~length>8192 then -
    raise syntax 88.900 array('AVC initialization data exceeds byte budget')
::method u16 private
  use strict arg b,at
  if at<1 | at+1>b~length then raise syntax 88.900 array('truncated AVC 16-bit parameter length')
  return x2d(c2x(substr(b,at,2)))
::requires 'Mp4BoxReader.cls'
