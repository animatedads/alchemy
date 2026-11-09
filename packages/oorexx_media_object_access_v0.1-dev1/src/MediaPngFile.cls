/* ooRexx PNG image object. Native libpng provider handles only PNG decoding;
 * this class owns source bounds, immutable-version checks, frame and exports.
 * Original RGB/alpha data is preserved as 8-bit straight-alpha RGBA.
 */
::options digits 30
::class MediaPngFile public
::attribute width get
::attribute height get
::attribute sourceIdentity get
::attribute format get
::method init
  expose source sourceIdentity width height format compressedBytes
  use strict arg byteSource
  source=byteSource
  sourceIdentity=source~sourceIdentity
  compressedBytes=source~sizeBytes
  if \datatype(compressedBytes,'W') | compressedBytes<33 | compressedBytes>33554432 then -
    raise syntax 88.900 array('PNG compressed size outside 33..32MiB',compressedBytes)
  h=source~readAt(0,33)
  if h~length<>33 | substr(h,1,8)<>x2c('89504E470D0A1A0A') | -
    substr(h,9,4)<>x2c('0000000D') | substr(h,13,4)<>'IHDR' then -
    raise syntax 88.900 array('invalid PNG signature or first IHDR chunk')
  width=x2d(c2x(substr(h,17,4)))
  height=x2d(c2x(substr(h,21,4)))
  if width<1 | height<1 | width>8192 | height>8192 | width*height>12000000 then -
    raise syntax 88.900 array('PNG image dimensions outside safe budget',width,height)
  format='PNG'
::method decode
  expose source sourceIdentity width height compressedBytes
  if source~sourceIdentity<>sourceIdentity | source~sizeBytes<>compressedBytes then -
    raise syntax 88.900 array('PNG source identity changed before read')
  sourceData=''
  byte=0
  do while byte<compressedBytes
    take=min(65536,compressedBytes-byte)
    part=source~readAt(byte,take)
    if part~length<>take then raise syntax 88.900 array('PNG read truncated',byte,take)
    sourceData=sourceData||part
    byte=byte+take
  end
  if source~sourceIdentity<>sourceIdentity | source~sizeBytes<>compressedBytes then -
    raise syntax 88.900 array('PNG source identity changed during read')
  decoded=MOAPNGDecode(sourceData)
  if decoded~length<12 | substr(decoded,1,4)<>'MPN1' then -
    raise syntax 88.900 array('native PNG decoding failed',left(decoded,150))
  frame=.MediaPngFrame~new(decoded)
  if frame~width<>width | frame~height<>height then -
    raise syntax 88.900 array('decoded PNG dimensions differ from IHDR')
  return frame

::class MediaPngFrame public
::attribute width get
::attribute height get
::attribute pixels get
::attribute pixelFormat get
::attribute source get
::method init
  expose width height pixels pixelFormat source
  use strict arg packet
  if packet~length<12 | substr(packet,1,4)<>'MPN1' then -
    raise syntax 88.900 array('bad PNG frame packet')
  width=x2d(c2x(substr(packet,5,4)))
  height=x2d(c2x(substr(packet,9,4)))
  if width<1 | height<1 | width>8192 | height>8192 | -
     width*height>12000000 | packet~length<>12+width*height*4 then -
    raise syntax 88.900 array('bad RGBA frame dimensions or payload')
  pixels=substr(packet,13)
  pixelFormat='RGBA32'
  source='NATIVE_PNG_CODEC'
::method pixelAt
  expose width height pixels
  use strict arg x,y
  if \datatype(x,'W') | \datatype(y,'W') | x<0 | y<0 | x>=width | y>=height then -
    raise syntax 88.900 array('pixel outside PNG frame',x,y)
  base=(y*width+x)*4+1
  return .array~of(c2d(substr(pixels,base,1)),c2d(substr(pixels,base+1,1)), -
                   c2d(substr(pixels,base+2,1)),c2d(substr(pixels,base+3,1)))
::method channelPlane
  expose pixels width height
  use strict arg channel
  return .MediaRasterPlanes~plane(pixels,width,height,4,channel)
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
::requires 'MediaRasterPlanes.cls'
::requires 'moa_png' LIBRARY