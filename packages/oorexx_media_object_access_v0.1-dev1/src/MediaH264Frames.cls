/* ooRexx-owned native H264 pixel frames. Pixel format RGB24, row-major.
 * Only codec operations cross native ABI; no file/container/network access.
 * Backend uses in-process native codec library, never ffmpeg executable.
 */
::options digits 30

::class MediaRgbFrame public
::attribute width get
::attribute height get
::attribute presentationTicks get
::attribute source get
::attribute pixels get
::attribute pixelFormat get
::method init
  expose width height presentationTicks source pixels pixelFormat
  use strict arg packet
  if packet~length<20 | substr(packet,1,4)<>'MHP1' then -
    raise syntax 88.900 array('invalid H264 frame packet signature')
  width=x2d(c2x(substr(packet,5,4)))
  height=x2d(c2x(substr(packet,9,4)))
  if width<16 | height<16 | width>4096 | height>2160 | -
    packet~length<>20+width*height*3 then -
    raise syntax 88.900 array('invalid RGB24 decoded frame dimensions/buffer')
  tick=x2d(c2x(substr(packet,13,8)))
  if tick=18446744073709551615 then tick=-1
  presentationTicks=tick
  source='NATIVE_H264_CODEC'
  pixelFormat='RGB24'
  pixels=substr(packet,21)
::method pixelAt
  expose width height pixels
  use strict arg x,y
  if \datatype(x,'W') | \datatype(y,'W') | x<0 | y<0 | x>=width | y>=height then -
    raise syntax 88.900 array('RGB pixel outside frame',x,y)
  offset=(y*width+x)*3+1
  return .array~of(c2d(substr(pixels,offset,1)), -
                    c2d(substr(pixels,offset+1,1)),c2d(substr(pixels,offset+2,1)))
::method savePpm
  expose width height pixels
  use strict arg path
  opened=stream(path,'C','OPEN WRITE REPLACE')
  if left(opened,5)<>'READY' then raise syntax 88.900 array('cannot write PPM',path,opened)
  header='P6'||'0a'x||width' 'height||'0a'x||'255'||'0a'x
  ignore=charout(path,header||pixels,1)
  ignore=stream(path,'C','CLOSE')
  return self

::class MediaH264Decoder public
::attribute handle get
::attribute backend get
::method init
  expose handle backend
  use strict arg
  backend="moa_h264"
  /* External classic routines provide only bytes-to-pixels codec services. */
  handle=MOAH264Open()
  if left(handle,5)='ERROR' | \datatype(handle,'W') then -
    raise syntax 88.900 array('native H264 codec could not be opened',handle)
::method feed
  expose handle
  use strict arg compressed,pts
  if \datatype(pts,'W') then raise syntax 88.900 array('integer PTS required')
  count=MOAH264Feed(handle,compressed,pts)
  if left(count,5)='ERROR' then raise syntax 88.900 array('native codec feed failed',count)
  if \datatype(count,'W') | count>8 then -
    raise syntax 88.900 array('native codec returned invalid frame count',count)
  return self~take(count)
::method flush
  expose handle
  count=MOAH264Flush(handle)
  if left(count,5)='ERROR' then raise syntax 88.900 array('native codec flush failed',count)
  return self~take(count)
::method take
  expose handle
  use strict arg expected
  frames=.array~new
  do i=1 to expected
    image=MOAH264Take(handle)
    if left(image,5)='ERROR' | image='' then -
      raise syntax 88.900 array('native codec frame extraction error',i)
    frames~append(.MediaRgbFrame~new(image))
  end
  return frames
::method close
  expose handle
  if handle<>'' then do
    ignore=MOAH264Close(handle)
    handle=''
  end
  return self
::requires 'moa_h264' LIBRARY