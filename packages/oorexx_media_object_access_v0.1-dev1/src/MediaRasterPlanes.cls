/* Shared ooRexx raster channel exports for PNG RGBA and H.264 RGB frames.
 * Format P6/P5/P7; no alpha is silently thrown away by split/PAM exports.
 * The native provider performs bounded byte permutation only, never IO.
 */
::options digits 30
::class MediaRasterPlanes public
::method luma class
  use strict arg pixels,width,height,channels
  raw=MOARasterLuma(pixels,width,height,channels)
  if raw~length<>width*height then -
    raise syntax 88.900 array("raster luma failed",left(raw,120))
  return raw
::method plane class
  use strict arg pixels,width,height,channels,channel
  raw=MOARasterPlane(pixels,width,height,channels,translate(channel))
  if raw~length<>width*height then -
    raise syntax 88.900 array('channel conversion failed',channel,left(raw,120))
  return raw
::method rgb class
  use strict arg pixels,width,height,channels
  raw=MOARasterRGB(pixels,width,height,channels)
  if raw~length<>width*height*3 then -
    raise syntax 88.900 array('RGB conversion failed',left(raw,120))
  return raw
::method rgba class
  use strict arg pixels,width,height,channels
  raw=MOARasterRGBA(pixels,width,height,channels)
  if raw~length<>width*height*4 then -
    raise syntax 88.900 array('RGBA conversion failed',left(raw,120))
  return raw
::method saveRgbPpm class
  use strict arg pixels,width,height,channels,path
  nl='0a'x
  header='P6'||nl||width' 'height||nl||'255'||nl
  self~writeFile(path,header||self~rgb(pixels,width,height,channels))
  return path
::method saveRgbaPam class
  use strict arg pixels,width,height,channels,path
  nl='0a'x
  header='P7'||nl||'WIDTH 'width||nl||'HEIGHT 'height||nl|| -
    'DEPTH 4'||nl||'MAXVAL 255'||nl||'TUPLTYPE RGB_ALPHA'||nl||'ENDHDR'||nl
  self~writeFile(path,header||self~rgba(pixels,width,height,channels))
  return path
::method saveChannelPgm class
  use strict arg pixels,width,height,channels,channel,path
  if wordpos(translate(channel),'R G B A')=0 then -
    raise syntax 88.900 array('unknown raster plane',channel)
  nl='0a'x
  header='P5'||nl||width' 'height||nl||'255'||nl
  self~writeFile(path,header||self~plane(pixels,width,height,channels,channel))
  return path
::method saveSplit class
  use strict arg pixels,width,height,channels,prefix
  paths=.directory~new
  do c over .array~of('R','G','B','A')
    path=prefix||'.'||translate(c,'abcdefghijklmnopqrstuvwxyz','ABCDEFGHIJKLMNOPQRSTUVWXYZ')||'.pgm'
    self~saveChannelPgm(pixels,width,height,channels,c,path)
    paths[c]=path
  end
  return paths
::method writeFile class
  use strict arg path,data
  state=stream(path,'C','OPEN WRITE REPLACE')
  if left(state,5)<>'READY' then raise syntax 88.900 array('cannot open image export',path,state)
  remaining=charout(path,data,1)
  state=stream(path,'C','CLOSE')
  if remaining<>0 then raise syntax 88.900 array('short image export write',path,remaining)
  return path
::requires 'moa_raster' LIBRARY