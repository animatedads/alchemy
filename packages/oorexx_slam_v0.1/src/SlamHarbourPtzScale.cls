/* Power SLAM v0.17: stationary skyline apparent-scale and translation fit.
 * Architecture: Tom Dyer. Implementation: ChatGPT GPT-6, 2026-11-02.
 * Native ooRexx owns all image matching. FFmpeg is a source decoding adapter only.
 * A fitted 2D image similarity scale is NOT a lens focal-length measurement.
 */
::class HarbourPtzScale public
::method frameW class
  return 640
::method frameH class
  return 360
::method frameBytes class
  return 230400
::method readFrame class
  use strict arg path, frameNumber
  if frameNumber<0 | \datatype(frameNumber,'W') then raise syntax 88.900 array('INVALID_FRAME_INDEX')
  file=.stream~new(path)
  ok=file~open('read binary')
  if left(ok,5)<>'READY' then raise syntax 88.900 array('RAW_FILE_UNREADABLE')
  offset=frameNumber*self~frameBytes+1
  if file~chars < offset-1+self~frameBytes then do
    file~close
    raise syntax 88.900 array('INCOMPLETE_SOURCE_FRAME')
  end
  bytes=file~charin(offset,self~frameBytes)
  file~close
  if length(bytes)<>self~frameBytes then raise syntax 88.900 array('INCOMPLETE_SOURCE_FRAME')
  return bytes
::method profile class
  use strict arg bytes
  if length(bytes)<>self~frameBytes then raise syntax 88.900 array('BAD_RAW_FRAME_LENGTH')
  values=.array~new(638)
  do x=1 to 638
    values[x]=0
  end
  /* Skyline and facades, excluding timestamp and most moving water.
   * Horizontal image gradient integrated vertically; camera pan translates,
   * camera zoom changes spatial frequency of this column profile.
   * Coordinates are half-open x=[0,638), y=[35,255).
   */
  do y=35 to 254
    offset=y*640
    do x=1 to 638
      leftpx=c2d(substr(bytes,offset+x,1))
      rightpx=c2d(substr(bytes,offset+x+2,1))
      values[x]=values[x]+abs(leftpx-rightpx)
    end
  end
  do x=1 to 638
    values[x]=values[x]/220
  end
  smooth5=self~boxSmooth(values,5)
  smooth61=self~boxSmooth(values,61)
  outputProfile=.array~new(638)
  do x=1 to 638
    outputProfile[x]=smooth5[x]-smooth61[x]
  end
  return outputProfile
::method boxSmooth class
  use strict arg a, win
  if win<1 | win//2<>1 then raise syntax 88.900 array('WINDOW_MUST_BE_POSITIVE_ODD')
  n=a~items
  out=.array~new(n)
  half=(win-1)/2
  do i=1 to n
    total=0
    do k=-half to half
      j=i+k
      if j>=1 & j<=n then total=total+a[j]
    end
    out[i]=total/win
  end
  return out
::method fitProfiles class
  /* Fit target coordinate X = scale * source X + shift.
   * All sampled columns must map into target, or the candidate is rejected.
   * A global similarity on a skyline strip is only a coarse zoom/pan model.
   */
  use arg a,b,low,high,sstep,shiftLo,shiftHi,shiftStep
  if \datatype(low,'N') then low=1.55
  if \datatype(high,'N') then high=2.30
  if \datatype(sstep,'N') then sstep=0.025
  if \datatype(shiftLo,'N') then shiftLo=-180
  if \datatype(shiftHi,'N') then shiftHi=0
  if \datatype(shiftStep,'N') then shiftStep=4
  if a~items<>638 | b~items<>638 then raise syntax 88.900 array('PROFILE_WIDTH_MISMATCH')
  if low<=0 | high<low | sstep<=0 | shiftHi<shiftLo | shiftStep<=0 then raise syntax 88.900 array('BAD_SEARCH_BOUNDS')
  n=0;mean=0
  do x=116 to 324 by 2
    mean=mean+a[x]
    n=n+1
  end
  mean=mean/n
  sourceVar=0
  do x=116 to 324 by 2
    d=a[x]-mean
    sourceVar=sourceVar+d*d
  end
  if sourceVar<1.0e-9 then return self~reject('NO_STATIONARY_TEXTURE')
  best=-2; second=-2; bestScale=0; bestShift=0
  do si=0 to trunc((high-low)/sstep+0.00001)
    scale=low+si*sstep
    do shift=shiftLo to shiftHi by shiftStep
      first=trunc(115*scale+shift+0.5)
      last=trunc(323*scale+shift+0.5)
      if first<0 | last>637 then iterate
      sumB=0
      do x=116 to 324 by 2
        dest=trunc((x-1)*scale+shift+0.5)+1
        sumB=sumB+b[dest]
      end
      meanB=sumB/n
      cov=0;varianceB=0
      do x=116 to 324 by 2
        dest=trunc((x-1)*scale+shift+0.5)+1
        da=a[x]-mean
        db=b[dest]-meanB
        cov=cov+da*db
        varianceB=varianceB+db*db
      end
      if varianceB<1.0e-9 then iterate
      corr=cov/PTZsqrt(sourceVar*varianceB)
      if corr>best then do
        second=best
        best=corr;bestScale=scale;bestShift=shift
      end
      else if corr>second then second=corr
    end
  end
  if bestScale=0 then return self~reject('NO_VALID_MATCHING_WINDOW')
  r=.directory~new
  r['STATUS']='APPARENT_SCALE_CANDIDATE_UNQUALIFIED'
  r['SCALE']=bestScale
  r['TRANSLATION_X_PX']=bestShift
  r['CORRELATION']=best
  r['RUNNER_UP_CORRELATION']=second
  r['FEATURE_SAMPLES']=n
  r['METHOD']='NATIVE_OOREXX_HORIZONTAL_GRADIENT_SKYLINE_NCC'
  return r
::method estimatePair class
  use strict arg path,first,second
  frameA=self~readFrame(path,first)
  frameB=self~readFrame(path,second)
  return self~fitProfiles(self~profile(frameA),self~profile(frameB))
::method repeatCheck class
  use strict arg a,b,offset
  r=.directory~new
  r['STATUS']='PTZ_ZOOM_REPEAT_NOT_PROVEN'
  if a['STATUS']<>'APPARENT_SCALE_CANDIDATE_UNQUALIFIED' | b['STATUS']<>'APPARENT_SCALE_CANDIDATE_UNQUALIFIED' then return r
  if offset<>172 then return r
  r['SCALE_DIFFERENCE']=abs(a['SCALE']-b['SCALE'])
  r['TRANSLATION_DIFFERENCE_PX']=abs(a['TRANSLATION_X_PX']-b['TRANSLATION_X_PX'])
  r['CORRELATION_MIN']=min(a['CORRELATION'],b['CORRELATION'])
  if r['SCALE_DIFFERENCE']<=0.075 & r['TRANSLATION_DIFFERENCE_PX']<=16 & r['CORRELATION_MIN']>=0.50 then -
     r['STATUS']='REPEATED_APPARENT_ZOOM_CANDIDATE_NOT_LENS_CALIBRATED'
  return r
::method reject private class
  use strict arg status
  r=.directory~new
  r['STATUS']=status
  r['SCALE']=0
  return r
::routine PTZsqrt public
  use strict arg n
  if n<=0 then return 0
  x=n
  do 28
    x=(x+n/x)/2
  end
  return x