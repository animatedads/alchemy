/* Shared Alchemy Media Object Access raster operations (ooRexx authority).
 * The native stateless provider performs bounded pixel arithmetic only.
 * Frames retain R/G/B/A provenance; frame/layer subtraction remains signed.
 */
::options digits 30

::class MediaRasterImage public
::attribute width get
::attribute height get
::attribute channels get
::attribute pixels get
::attribute pixelFormat get
::attribute source get
::method init
  expose pixels width height channels pixelFormat source
  use strict arg buffer,w,h,depth,label='DERIVED_RASTER'
  if \datatype(w,'W') | \datatype(h,'W') | \datatype(depth,'W') | -
     w<1 | h<1 | w>8192 | h>8192 | w*h>12000000 | -
     (depth<>3 & depth<>4) | buffer~length<>w*h*depth then -
    raise syntax 88.900 array('invalid bounded raster image',w,h,depth)
  pixels=buffer; width=w; height=h; channels=depth; source=label
  pixelFormat='RGB24'
  if depth=4 then pixelFormat='RGBA32'
::method pixelAt
  expose pixels width height channels
  use strict arg x,y
  if \datatype(x,'W') | \datatype(y,'W') | x<0 | y<0 | x>=width | y>=height then -
    raise syntax 88.900 array('raster pixel outside bounds',x,y)
  off=(y*width+x)*channels+1
  v=.array~new
  do i=0 to channels-1
    v~append(c2d(substr(pixels,off+i,1)))
  end
  return v
::method channelPlane
  expose pixels width height channels
  use strict arg channel
  return .MediaRasterPlanes~plane(pixels,width,height,channels,channel)
::method luma
  expose pixels width height channels
  return .MediaRasterPlanes~luma(pixels,width,height,channels)
::method savePpm
  expose pixels width height channels
  use strict arg path
  return .MediaRasterPlanes~saveRgbPpm(pixels,width,height,channels,path)
::method savePam
  expose pixels width height channels
  use strict arg path
  return .MediaRasterPlanes~saveRgbaPam(pixels,width,height,channels,path)
::method saveSplit
  expose pixels width height channels
  use strict arg prefix
  return .MediaRasterPlanes~saveSplit(pixels,width,height,channels,prefix)
::method crop
  use strict arg x,y,w,h
  return .MediaRasterOps~crop(self,x,y,w,h)
::method resizeToProcessing
  use strict arg w,h,method='AREA'
  return .MediaRasterOps~resizeToProcessing(self,w,h,method)
::method subtractFrame
  use strict arg reference,alpha=.false
  return .MediaRasterOps~subtractFrame(self,reference,alpha)
::method subtractLayer
  use strict arg layer,x=0,y=0,channel='X',alpha=.false
  return .MediaRasterOps~subtractLayer(self,layer,x,y,channel,alpha)

::class MediaRasterLayer public
::attribute width get
::attribute height get
::attribute channels get
::attribute pixels get
::method init
  expose width height channels pixels
  use strict arg raw,w,h,depth=1
  if \datatype(w,'W') | \datatype(h,'W') | \datatype(depth,'W') | -
     w<1 | h<1 | w*h>12000000 | (depth<>1 & depth<>3 & depth<>4) | -
     raw~length<>w*h*depth then -
    raise syntax 88.900 array('invalid raster layer size',w,h,depth)
  pixels=raw;width=w;height=h;channels=depth

::class MediaSignedRasterDifference public
::attribute width get
::attribute height get
::attribute channels get
::attribute signedBytes get
::method init
  expose width height channels signedBytes
  use strict arg bytes,w,h,depth
  if \datatype(w,'W') | \datatype(h,'W') | \datatype(depth,'W') | -
     w<1 | h<1 | w*h>12000000 | depth<1 | depth>4 | -
     bytes~length<>w*h*depth*2 then -
    raise syntax 88.900 array('signed raster buffer invalid')
  signedBytes=bytes;width=w;height=h;channels=depth
::method deltaAt
  expose width height channels signedBytes
  use strict arg x,y,channel=1
  if \datatype(x,'W') | \datatype(y,'W') | \datatype(channel,'W') | -
     x<0 | y<0 | x>=width | y>=height | channel<1 | channel>channels then -
    raise syntax 88.900 array('delta pixel out of bounds')
  at=((y*width+x)*channels+channel-1)*2+1
  n=x2d(c2x(substr(signedBytes,at,2)))
  if n>32767 then n=n-65536
  return n
::method magnitude
  expose width height channels signedBytes
  result=MOARasterOpMagnitude(signedBytes,width,height,channels)
  if result~length<>width*height then -
    raise syntax 88.900 array('invalid signed magnitude output',left(result,64))
  return result
::method saveMagnitudePgm
  expose width height
  use strict arg path
  header='P5'||'0a'x||width' 'height||'0a'x||'255'||'0a'x
  return .MediaRasterPlanes~writeFile(path,header||self~magnitude)

::class MediaRasterOps public
::method asImage class
  use strict arg frame
  if frame~isA(.MediaRasterImage) then return frame
  format=frame~pixelFormat
  select
    when format='RGB24' then channels=3
    when format='RGBA32' then channels=4
    otherwise raise syntax 88.900 array('unknown source pixel format',format)
  end
  return .MediaRasterImage~new(frame~pixels,frame~width,frame~height,channels,'ADAPTED_'format)
::method crop class
  use strict arg frame,x,y,w,h
  image=self~asImage(frame)
  out=MOARasterOpCrop(image~pixels,image~width,image~height,image~channels,x,y,w,h)
  if out~length<>w*h*image~channels then -
    raise syntax 88.900 array('native crop error',left(out,100))
  return .MediaRasterImage~new(out,w,h,image~channels,'CROPPED')
::method resizeToProcessing class
  use strict arg frame,w,h,method='AREA'
  image=self~asImage(frame)
  mode=translate(method)
  out=MOARasterOpResize(image~pixels,image~width,image~height,image~channels,w,h,mode)
  if out~length<>w*h*image~channels then -
    raise syntax 88.900 array('native resize error',left(out,100))
  return .MediaRasterImage~new(out,w,h,image~channels,'RESIZED_'mode)
::method subtractFrame class
  use strict arg frame,reference,includeAlpha=.false
  a=self~asImage(frame); b=self~asImage(reference)
  if a~width<>b~width | a~height<>b~height then -
    raise syntax 88.900 array('frame subtraction requires registered equal geometry')
  n=3;alphaFlag=0
  if includeAlpha then do
    n=4;alphaFlag=1
  end
  raw=MOARasterOpSubtractFrame(a~pixels,a~width,a~height,a~channels, -
      b~pixels,b~width,b~height,b~channels,alphaFlag)
  if raw~length<>a~width*a~height*n*2 then -
    raise syntax 88.900 array('native frame subtraction failed',left(raw,100))
  return .MediaSignedRasterDifference~new(raw,a~width,a~height,n)
::method subtractLayer class
  use strict arg frame,layer,x=0,y=0,channel='X',includeAlpha=.false
  a=self~asImage(frame)
  if layer~isA(.MediaRasterLayer) then do
    b=layer
  end
  else do
    other=self~asImage(layer)
    b=.MediaRasterLayer~new(other~pixels,other~width,other~height,other~channels)
  end
  count=3;flag=0
  if b~channels=1 then count=1
  else if includeAlpha then do
    count=4;flag=1
  end
  raw=MOARasterOpSubtractLayer(a~pixels,a~width,a~height,a~channels, -
     b~pixels,b~width,b~height,b~channels,x,y,translate(channel),flag)
  if raw~length<>a~width*a~height*count*2 then -
    raise syntax 88.900 array('native raster layer subtraction failed',left(raw,100))
  return .MediaSignedRasterDifference~new(raw,a~width,a~height,count)
::method translateBy class
  use strict arg frame,dx,dy
  a=self~asImage(frame)
  raw=MOARasterOpTranslate(a~pixels,a~width,a~height,a~channels,dx,dy)
  if raw~length<>a~pixels~length then -
    raise syntax 88.900 array('native image registration shift failed',left(raw,100))
  return .MediaRasterImage~new(raw,a~width,a~height,a~channels,'TRANSLATED')
/* Landmark-only integer registration. Returns the shift to apply to the
 * second image. Rejects ambiguous/insufficient texture or gross camera move.
 */
::method estimateTranslation class
  use strict arg reference,frame,x,y,w,h,maxShift=8
  a=self~asImage(reference);b=self~asImage(frame)
  if a~width<>b~width | a~height<>b~height then -
    raise syntax 88.900 array('registration sources not same resolution')
  packet=MOARasterOpEstimateTranslation(a~pixels,a~width,a~height,a~channels, -
    b~pixels,b~width,b~height,b~channels,x,y,w,h,maxShift)
  if words(packet)<>4 then raise syntax 88.900 array('registration refused',left(packet,150))
  q=.directory~new
  q['DX']=word(packet,1);q['DY']=word(packet,2)
  q['SCORE_PPM']=word(packet,3);q['LANDMARK_SAMPLES']=word(packet,4)
  return q
::method validityPlane class
  use strict arg w,h,dx=0,dy=0
  raw=MOARasterOpValidity(w,h,dx,dy)
  if raw~length<>w*h then -
    raise syntax 88.900 array('registration validity plane failed',left(raw,100))
  return raw
::method normalizeLuma class
  use strict arg current,reference,width,height
  raw=MOARasterOpNormalizeLuma(current,reference,width,height)
  if raw~length<>8+width*height | substr(raw,1,4)<>'MNL1' then -
    raise syntax 88.900 array('photometric normalization failed',left(raw,100))
  answer=.directory~new
  value=x2d(c2x(substr(raw,5,4)))
  pixels=substr(raw,9)
  answer['GAIN_PPM']=value
  answer['PIXELS']=pixels
  return answer

/* Uniform-scale plus subpixel-translation registration. This is a similarity
 * transform only; not parallax, skew, rotation, rolling shutter or 3-D.
 * Two independent, nonoverlapping stable-landmark ROIs must agree before a
 * fit can be applied to time-series / astronomical evidence. */
::method estimateSimilarity class
  use strict arg reference,frame,x,y,w,h,maxShift=8,maxScalePermille=40,stepPermille=5
  a=self~asImage(reference);b=self~asImage(frame)
  if a~width<>b~width | a~height<>b~height then -
    raise syntax 88.900 array('similarity registration requires equal geometry')
  packet=MOARasterOpEstimateSimilarity(a~pixels,a~width,a~height,a~channels, -
     b~pixels,b~width,b~height,b~channels,x,y,w,h,maxShift,maxScalePermille,stepPermille)
  if words(packet)<>6 then raise syntax 88.900 array('similarity fit failed',left(packet,150))
  fit=.directory~new
  fit['DX_MILLI']=word(packet,1)
  fit['DY_MILLI']=word(packet,2)
  fit['SCALE_PPM']=word(packet,3)
  fit['SCORE_PPM']=word(packet,4)
  fit['LANDMARK_SAMPLES']=word(packet,5)
  fit['NEXT_BEST_PPM']=word(packet,6)
  fit['HELDOUT_PPM']=-1
  fit['HELDOUT_SAMPLES']=0
  fit['QUALIFIED']=0
  return fit
::method scoreSimilarity class
  use strict arg reference,frame,fit,x,y,w,h
  a=self~asImage(reference);b=self~asImage(frame)
  if a~width<>b~width | a~height<>b~height then -
    raise syntax 88.900 array('independent similarity landmark geometry mismatch')
  packet=MOARasterOpScoreSimilarity(a~pixels,a~width,a~height,a~channels, -
    b~pixels,b~width,b~height,b~channels,x,y,w,h, -
    fit['DX_MILLI'],fit['DY_MILLI'],fit['SCALE_PPM'])
  if words(packet)<>2 then raise syntax 88.900 array('independent registration failed',left(packet,140))
  heldout=.directory~new
  heldout['SCORE_PPM']=word(packet,1)
  heldout['LANDMARK_SAMPLES']=word(packet,2)
  return heldout
::method estimateSimilarityValidated class
  use strict arg reference,frame, -
      fitX,fitY,fitW,fitH,checkX,checkY,checkW,checkH, -
      maxShift=8,maxScalePermille=40,stepPermille=5, -
      maxFitPpm=100000,maxCheckPpm=100000,minMarginPpm=2000
  /* Caller chooses mutually disjoint stable city/bridge landmarks.
   * A fit to a single ROI cannot authorize subtraction on its own. */
  if fitX<checkX+checkW & checkX<fitX+fitW & -
     fitY<checkY+checkH & checkY<fitY+fitH then -
    raise syntax 88.900 array('registration fit/check landmark regions overlap')
  fit=self~estimateSimilarity(reference,frame,fitX,fitY,fitW,fitH, -
    maxShift,maxScalePermille,stepPermille)
  held=self~scoreSimilarity(reference,frame,fit,checkX,checkY,checkW,checkH)
  fit['HELDOUT_PPM']=held['SCORE_PPM']
  fit['HELDOUT_SAMPLES']=held['LANDMARK_SAMPLES']
  if fit['SCORE_PPM']<=maxFitPpm & fit['HELDOUT_PPM']<=maxCheckPpm & -
     fit['LANDMARK_SAMPLES']>=36 & fit['HELDOUT_SAMPLES']>=25 & -
     fit['NEXT_BEST_PPM']-fit['SCORE_PPM']>=minMarginPpm then -
    fit['QUALIFIED']=1
  return fit
::method warpSimilarity class
  use strict arg frame,fit,allowUnqualified=.false
  if fit['QUALIFIED']<>1 & \allowUnqualified then -
    raise syntax 88.900 array('similarity warp requires validated disjoint landmark evidence')
  a=self~asImage(frame)
  raw=MOARasterOpWarpSimilarity(a~pixels,a~width,a~height,a~channels, -
      fit['DX_MILLI'],fit['DY_MILLI'],fit['SCALE_PPM'])
  if raw~length<>a~pixels~length then -
    raise syntax 88.900 array('similarity warp native result invalid',left(raw,120))
  return .MediaRasterImage~new(raw,a~width,a~height,a~channels,'SIMILARITY_ALIGNED')
::method similarityValidity class
  use strict arg width,height,fit
  raw=MOARasterOpValiditySimilarity(width,height, -
       fit['DX_MILLI'],fit['DY_MILLI'],fit['SCALE_PPM'])
  if raw~length<>width*height then -
    raise syntax 88.900 array('invalid similarity overlap envelope',left(raw,120))
  return raw

::requires 'MediaRasterPlanes.cls'
::requires 'moa_raster_ops' LIBRARY