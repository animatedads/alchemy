/* ooRexx-owned JPEG source with native in-process codec provider. JPEG does
 * not carry alpha: RGBA channel A is synthesized to opaque 255, explicitly.
 * Decompression provider performs no file IO, only JPEG-to-RGBA conversion.
 */
::options digits 30
::class MediaJpegFile public
::attribute sourceIdentity get
::attribute format get
::method init
  expose source identity sourceIdentity bytes format
  use strict arg byteSource
  source=byteSource
  sourceIdentity=source~sourceIdentity
  bytes=source~sizeBytes
  if \datatype(bytes,'W') | bytes<4 | bytes>33554432 then -
    raise syntax 88.900 array('JPEG compressed byte size not supported',bytes)
  if source~readAt(0,3)<>x2c('FFD8FF') then -
    raise syntax 88.900 array('not a JPEG SOI marker')
  format='JPEG'
::method decode
  expose source sourceIdentity bytes
  if source~sourceIdentity<>sourceIdentity | source~sizeBytes<>bytes then -
    raise syntax 88.900 array('JPEG source changed before decode')
  compressed='';offset=0
  do while offset<bytes
    n=min(65536,bytes-offset)
    block=source~readAt(offset,n)
    if block~length<>n then raise syntax 88.900 array('JPEG short range read',offset,n)
    compressed=compressed||block
    offset=offset+n
  end
  if source~sourceIdentity<>sourceIdentity | source~sizeBytes<>bytes then -
    raise syntax 88.900 array('JPEG source changed during decode')
  result=MOAJPEGDecode(compressed)
  if result~length<12 | substr(result,1,4)<>'MJG1' then -
    raise syntax 88.900 array('native JPEG decode failure',left(result,180))
  return .MediaJpegFrame~new(result)

::class MediaJpegFrame public
::attribute width get
::attribute height get
::attribute pixels get
::attribute pixelFormat get
::attribute source get
::attribute alphaProvenance get
::method init
  expose width height pixels pixelFormat source alphaProvenance
  use strict arg packet
  if packet~length<12 | substr(packet,1,4)<>'MJG1' then -
    raise syntax 88.900 array('bad JPEG frame signature')
  width=x2d(c2x(substr(packet,5,4)))
  height=x2d(c2x(substr(packet,9,4)))
  if width<1 | height<1 | width>8192 | height>8192 | -
     width*height>12000000 | packet~length<>12+width*height*4 then -
    raise syntax 88.900 array('bad JPEG decoded frame length/dimensions')
  pixels=substr(packet,13)
  pixelFormat='RGBA32';source='NATIVE_JPEG_CODEC'
  alphaProvenance='SYNTHETIC_OPAQUE'
::method pixelAt
  expose pixels width height
  use strict arg x,y
  if \datatype(x,'W') | \datatype(y,'W') | x<0 | y<0 | x>=width | y>=height then -
    raise syntax 88.900 array('JPEG pixel outside image')
  i=(y*width+x)*4+1
  return .array~of(c2d(substr(pixels,i,1)),c2d(substr(pixels,i+1,1)), -
      c2d(substr(pixels,i+2,1)),c2d(substr(pixels,i+3,1)))
::method channelPlane
  expose pixels width height
  use strict arg channel
  return .MediaRasterPlanes~plane(pixels,width,height,4,channel)
::method luma
  expose pixels width height
  return .MediaRasterPlanes~luma(pixels,width,height,4)
::method savePpm
  expose pixels width height
  use strict arg path
  return .MediaRasterPlanes~saveRgbPpm(pixels,width,height,4,path)
::method savePam
  expose pixels width height
  use strict arg path
  return .MediaRasterPlanes~saveRgbaPam(pixels,width,height,4,path)
::method saveChannelPgm
  expose pixels width height
  use strict arg channel,path
  return .MediaRasterPlanes~saveChannelPgm(pixels,width,height,4,channel,path)
::method saveSplit
  expose pixels width height
  use strict arg prefix
  return .MediaRasterPlanes~saveSplit(pixels,width,height,4,prefix)
::method crop
  use strict arg x,y,w,h
  return .MediaRasterOps~crop(self,x,y,w,h)
::method resizeToProcessing
  use strict arg w,h,method='AREA'
  return .MediaRasterOps~resizeToProcessing(self,w,h,method)
::method subtractFrame
  use strict arg other,includeAlpha=.false
  return .MediaRasterOps~subtractFrame(self,other,includeAlpha)
::method subtractLayer
  use strict arg layer,x=0,y=0,channel='X',includeAlpha=.false
  return .MediaRasterOps~subtractLayer(self,layer,x,y,channel,includeAlpha)

::requires 'MediaRasterPlanes.cls'
::requires 'moa_jpeg' LIBRARY

::requires 'MediaRasterOps.cls'