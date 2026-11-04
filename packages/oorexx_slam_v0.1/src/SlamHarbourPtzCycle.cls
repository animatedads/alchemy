/* Power SLAM: scheduled PTZ repeat inference from source frame signatures.
 * Architecture Tom Dyer. Implementation ChatGPT GPT-6, 2026-11-02.
 * No OpenCV, external motion classifier, generated scenery or camera-angle claim.
 * Source adapter may use FFmpeg solely to decode images to 96x54 grey.
 * 172s from ONE recurrence is CANDIDATE, not a verified fixed schedule.
 */
::class HarbourPtzCycle public
::method init
  expose signatures
  signatures=.array~new
::method count
  expose signatures
  return signatures~items
::method appendSignature
  expose signatures
  use strict arg feature
  if feature~items<>72 then raise syntax 88.900 array('EXPECTED_72_FEATURES')
  signatures~append(feature)
::method appendFrame
  use strict arg bytes
  if length(bytes)<>5184 then raise syntax 88.900 array('EXPECTED_96x54_BYTES')
  feature=.array~new(72)
  do by=0 to 5
    do bx=0 to 11
      sum=0
      do dy=-1 to 1
        do dx=-1 to 1
          x=bx*8+4+dx
          y=by*9+4+dy
          at=y*96+x+1
          sum=sum+c2d(substr(bytes,at,1))
        end
      end
      feature[by*12+bx+1]=sum/9
    end
  end
  self~appendSignature(feature)
::method readRaw
  use strict arg path
  size=5184
  f=.stream~new(path)
  res=f~open('read binary')
  if left(res,5)<>'READY' then raise syntax 88.900 array('RAW_SOURCE_NOT_OPENED')
  n=0
  do while f~chars>=size
    bytes=f~charin(,size)
    self~appendFrame(bytes)
    n=n+1
  end
  leftover=f~chars
  f~close
  if leftover<>0 then raise syntax 88.900 array('INCOMPLETE_GRAY_FRAME')
  return n
::method estimate
  expose signatures
  use strict arg low, high, window
  count=signatures~items
  if count<16 then return self~rejected('TOO_FEW_FRAMES')
  if low<2 | high<=low | window<12 then return self~rejected('BAD_SEARCH_BOUNDS')
  bestLag=0; bestScore=1e9; second=1e9; bestPairs=0
  do lag=low to high
    usable=count-lag
    if usable>window then usable=window
    if usable<12 then iterate
    total=0
    do n=1 to usable
      a=signatures[n];b=signatures[n+lag]
      subTotal=0
      do k=1 to 72
        subTotal=subTotal+abs(a[k]-b[k])
      end
      total=total+subTotal/72
    end
    score=total/usable
    if score<bestScore then do
      second=bestScore;bestScore=score;bestLag=lag;bestPairs=usable
    end
    else if score<second then second=score
  end
  if bestLag=0 then return self~rejected('NO_OVERLAP')
  d=.directory~new
  d['PERIOD_SECONDS']=bestLag
  d['FRAME_SECONDS']=1
  d['MEAN_ABS_8BIT']=bestScore
  d['RUNNER_UP_MEAN_ABS_8BIT']=second
  d['OVERLAP_PAIRS']=bestPairs
  d['TOTAL_FRAMES']=count
  d['METHOD']='GRID_3X3_MEAN_72_FEATURES'
  d['STATUS']='PTZ_PERIOD_CANDIDATE_UNQUALIFIED'
  return d
::method rejected private
  use strict arg reason
  d=.directory~new
  d['STATUS']=reason
  d['PERIOD_SECONDS']=0
  return d