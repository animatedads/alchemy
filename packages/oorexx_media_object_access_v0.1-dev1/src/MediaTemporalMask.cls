/* Alchemy temporal absolute subtraction mask. ooRexx owns references,
 * alignment/provenance, longitudinal state and retrospective evaluation.
 * Native math consumes only caller-provided, already-aligned byte planes.
 * No frame->time inference: every sample identity is explicit.
 */
::options digits 30
::class MediaTemporalDifferenceMask public
::attribute width get
::attribute height get
::attribute thresholdPercent get
::attribute minimumDifference get
::attribute count get
::attribute generation get
::method init
  expose width height thresholdPercent minimumDifference referenceFloor -
     noiseFactor count samples referenceLuma cachedScores background noise threshold generation dirty
  use strict arg w,h,pct=50,minDiff=12,refFloor=16,noiseMult=3
  if \datatype(w,'W') | \datatype(h,'W') | \datatype(pct,'W') | -
     \datatype(minDiff,'W') | \datatype(refFloor,'W') | -
     \datatype(noiseMult,'W') | w<1 | h<1 | w*h>2000000 | -
     pct<1 | pct>100 | minDiff<1 | minDiff>255 | -
     refFloor<1 | refFloor>255 | noiseMult<0 | noiseMult>12 then -
    raise syntax 88.900 array('invalid temporal mask geometry or policy')
  width=w;height=h;thresholdPercent=pct;minimumDifference=minDiff
  referenceFloor=refFloor;noiseFactor=noiseMult
  count=0;generation=0;samples=.array~new;referenceLuma=''
  cachedScores=.array~new;background='';noise='';threshold='';dirty=.true
::method addFrame
  expose width height count samples referenceLuma dirty
  use strict arg frame,identity,dx=0,dy=0
  if identity='' then raise syntax 88.900 array('temporal sample must have an identity')
  if count>=16 then raise syntax 88.900 array('temporal mask samples exceed 16; checkpoint first')
  image=.MediaRasterOps~asImage(frame)
  if image~width<>width | image~height<>height then -
    raise syntax 88.900 array('register and resize before temporal subtraction')
  if dx<>0 | dy<>0 then image=.MediaRasterOps~translateBy(image,dx,dy)
  luma=image~luma
  gain=1000000
  if count=0 then referenceLuma=luma
  else do
    normalized=.MediaRasterOps~normalizeLuma(luma,referenceLuma,width,height)
    luma=normalized['PIXELS'];gain=normalized['GAIN_PPM']
  end
  s=.directory~new
  s['ID']=identity;s['LUMA']=luma;s['GAIN_PPM']=gain
  s['SHIFT_X']=dx;s['SHIFT_Y']=dy
  s['VALID']=.MediaRasterOps~validityPlane(width,height,dx,dy)
  samples~append(s)
  count=count+1;dirty=.true
  return count
/* Estimate a shift only from an explicitly supplied stable-landmark ROI.
 * The first/reference exposure must already be in this model's geometry.
 * Scale and parallax are not inferred: those require an external warp.
 */
::method addRegisteredFrame
  use strict arg frame,identity,referenceFrame,x,y,w,h,maxShift=8
  fit=.MediaRasterOps~estimateTranslation(referenceFrame,frame,x,y,w,h,maxShift)
  ignored=self~addFrame(frame,identity,fit['DX'],fit['DY'])
  return fit
::method sample
  expose samples count
  use strict arg index
  if \datatype(index,'W') | index<1 | index>count then -
    raise syntax 88.900 array('temporal sample index invalid')
  return samples[index]
::method rebuild
  expose width height count samples background noise threshold dirty -
     generation thresholdPercent minimumDifference referenceFloor noiseFactor cachedScores
  if count<2 then raise syntax 88.900 array('temporal subtraction requires at least two observations')
  if \dirty then return self
  joined='';validity=''
  do i=1 to count
    joined=joined||samples[i]['LUMA']
    validity=validity||samples[i]['VALID']
  end
  packet=MOARasterOpBuildTemporal(joined,validity,width,height,count,thresholdPercent, -
     minimumDifference,referenceFloor,noiseFactor)
  p=width*height
  if packet~length<>4+p*3 | substr(packet,1,4)<>'MTM1' then -
    raise syntax 88.900 array('native temporal model failed',left(packet,100))
  background=substr(packet,5,p)
  noise=substr(packet,5+p,p)
  threshold=substr(packet,5+2*p,p)
  cachedScores=.array~new
  do i=1 to count
    result=MOARasterOpScoreTemporal(samples[i]['LUMA'],samples[i]['VALID'],background,threshold,width,height)
    cachedScores~append(.MediaTemporalFrameScore~new(result,width,height,samples[i]['ID'],generation+1))
  end
  generation=generation+1
  dirty=.false
  return self
::method scoreAll
  expose cachedScores
  self~rebuild
  return cachedScores
::method scoreAt
  expose count cachedScores
  use strict arg index
  if \datatype(index,'W') | index<1 | index>count then -
    raise syntax 88.900 array('temporal index out of range',index)
  self~rebuild
  return cachedScores[index]
::method backgroundPlane
  expose background
  self~rebuild
  return background
::method noisePlane
  expose noise
  self~rebuild
  return noise
::method tolerancePlane
  expose threshold
  self~rebuild
  return threshold
::method saveBackground
  expose width height background
  use strict arg path
  self~rebuild
  return .MediaRasterPlanes~writeFile(path,'P5'||'0a'x||width' 'height||'0a'x||'255'||'0a'x||background)

::class MediaTemporalFrameScore public
::attribute identity get
::attribute modelGeneration get
::attribute width get
::attribute height get
::attribute absoluteDifference get
::attribute changeMask get
::attribute positiveMask get
::attribute negativeMask get
::method init
  expose identity modelGeneration width height absoluteDifference changeMask positiveMask negativeMask
  use strict arg packet,w,h,id,generation
  p=w*h
  if packet~length<>4+4*p | substr(packet,1,4)<>'MTS1' then -
    raise syntax 88.900 array('invalid temporal score packet')
  width=w;height=h;identity=id;modelGeneration=generation
  absoluteDifference=substr(packet,5,p)
  changeMask=substr(packet,5+p,p)
  positiveMask=substr(packet,5+2*p,p)
  negativeMask=substr(packet,5+3*p,p)
::method maskAt
  expose width height changeMask
  use strict arg x,y
  if \datatype(x,'W') | \datatype(y,'W') | x<0 | y<0 | x>=width | y>=height then -
    raise syntax 88.900 array('temporal score pixel outside image')
  return c2d(substr(changeMask,y*width+x+1,1))
::method positiveAt
  expose width height positiveMask
  use strict arg x,y
  if \datatype(x,'W') | \datatype(y,'W') | x<0 | y<0 | x>=width | y>=height then -
    raise syntax 88.900 array('temporal positive pixel outside image')
  return c2d(substr(positiveMask,y*width+x+1,1))
::method absoluteAt
  expose width height absoluteDifference
  use strict arg x,y
  if \datatype(x,'W') | \datatype(y,'W') | x<0 | y<0 | x>=width | y>=height then -
    raise syntax 88.900 array('temporal absolute pixel outside image')
  return c2d(substr(absoluteDifference,y*width+x+1,1))
::method saveMask
  expose width height changeMask
  use strict arg path
  return .MediaRasterPlanes~writeFile(path,'P5'||'0a'x||width' 'height||'0a'x||'255'||'0a'x||changeMask)

::requires 'MediaRasterOps.cls'