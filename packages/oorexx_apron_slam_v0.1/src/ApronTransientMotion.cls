/* Apron SLAM — volatile source-bound vehicle-centroid motion, v0.1-dev2.
 * Receives already detected IMAGE-PLANE track observations. No frame, plate,
 * crop, glyph, registration text, disk access, serialization or persistence.
 * Input timestamps are SOURCE PTS in integer microseconds, not frame numbers.
 * All input is transient and can be discarded with ~close.
 * The centre velocity is an approximate IMAGE displacement, NOT a measured
 * number-plate velocity or a physical vehicle speed.
 * Reusable vector/scalar mathematics belongs to ooRexx Maths; ~magnitude
 * delegates sqrt to Maths, and is not used by the isolated core test.
 */
::options digits 30

::class ApronTransientObservation public
::attribute sourceToken get
::attribute trackToken get
::attribute ptsUs get
::attribute x get
::attribute y get
::attribute imageWidth get
::attribute imageHeight get
::attribute quality get
::method init
  expose sourceToken trackToken ptsUs x y imageWidth imageHeight quality
  use strict arg source,track,pts,cx,cy,width,height,score=1
  if source='' | track='' then raise syntax 88.900 array('volatile source and track tokens required')
  if \datatype(pts,'W') | pts<0 then raise syntax 88.900 array('nonnegative integral source PTS required')
  if width<1 | height<1 | \datatype(width,'W') | \datatype(height,'W') then -
    raise syntax 88.900 array('positive integral image dimensions required')
  if \datatype(cx,'N') | \datatype(cy,'N') | cx<0 | cx>=width | cy<0 | cy>=height then -
    raise syntax 88.900 array('centroid outside image')
  if \datatype(score,'N') | score<=0 | score>1 then -
    raise syntax 88.900 array('observation quality must be in (0,1]')
  sourceToken=source; trackToken=track; ptsUs=pts+0
  x=cx+0; y=cy+0; imageWidth=width; imageHeight=height; quality=score+0

::class ApronNumericAscending public
::method compare
  use strict arg a,b
  if a<b then return -1
  if a>b then return 1
  return 0

::class ApronNumericMedian public
::method of class
  use strict arg observations
  if \observations~isA(.Array) | observations~items=0 then -
    raise syntax 88.900 array('nonempty numeric array required')
  v=.array~new
  do item over observations
    if \datatype(item,'N') then raise syntax 88.900 array('numeric median values required')
    v~append(item+0)
  end
  v~sortWith(.ApronNumericAscending~new)
  n=v~items
  if n//2=1 then return v[(n+1)%2]
  return (v[n%2]+v[n%2+1])/2

::class ApronImageMotion public
::attribute velocityX get
::attribute velocityY get
::attribute sampleCount get
::attribute sampleSpanUs get
::method init
  expose velocityX velocityY sampleCount sampleSpanUs
  use strict arg vx,vy,count,span
  velocityX=vx; velocityY=vy; sampleCount=count; sampleSpanUs=span
::method displacement
  expose velocityX velocityY
  use strict arg exposureUs
  if \datatype(exposureUs,'W') | exposureUs<1 | exposureUs>1000000 then -
    raise syntax 88.900 array('positive exposure <=1 second required')
  return .array~of(velocityX*exposureUs/1000000,velocityY*exposureUs/1000000)
::method squaredMagnitude
  expose velocityX velocityY
  return velocityX*velocityX+velocityY*velocityY
::method magnitude
  return .Maths~sqrt(self~squaredMagnitude)

::class ApronTransientTrack public
::attribute count get
::method init
  expose sourceToken trackToken maxGapUs maxSamples observations closed count
  use strict arg source,track,gapMicroseconds=120000,limit=128
  if source='' | track='' | \datatype(gapMicroseconds,'W') | gapMicroseconds<1 | -
     \datatype(limit,'W') | limit<3 | limit>128 then -
    raise syntax 88.900 array('invalid transient track policy')
  sourceToken=source; trackToken=track; maxGapUs=gapMicroseconds
  maxSamples=limit; observations=.array~new; count=0; closed=.false
::method observe
  expose sourceToken trackToken maxGapUs maxSamples observations closed count
  use strict arg item
  if closed then raise syntax 88.900 array('transient track is closed')
  if \item~isA(.ApronTransientObservation) then raise syntax 88.900 array('observation object required')
  if item~sourceToken<>sourceToken | item~trackToken<>trackToken then -
    raise syntax 88.900 array('cross-source or cross-track fusion rejected')
  if count>=maxSamples then raise syntax 88.900 array('transient track capacity exceeded')
  if count>0 then do
    old=observations[count]
    dt=item~ptsUs-old~ptsUs
    if dt<=0 then raise syntax 88.900 array('source PTS not increasing')
    if dt>maxGapUs then raise syntax 88.900 array('track discontinuity; start new segment')
    if item~imageWidth<>old~imageWidth | item~imageHeight<>old~imageHeight then -
      raise syntax 88.900 array('image geometry changed within segment')
  end
  observations~append(item); count=count+1
  return self
::method fit
  expose observations count closed
  if closed then raise syntax 88.900 array('transient track is closed')
  if count<3 then raise syntax 88.900 array('at least three observations required')
  xs=.array~new; ys=.array~new
  do i=1 to count-1
    a=observations[i]
    do j=i+1 to count
      b=observations[j]
      dt=b~ptsUs-a~ptsUs
      xs~append((b~x-a~x)*1000000/dt)
      ys~append((b~y-a~y)*1000000/dt)
    end
  end
  return .ApronImageMotion~new(.ApronNumericMedian~of(xs),.ApronNumericMedian~of(ys), -
    count,observations[count]~ptsUs-observations[1]~ptsUs)
::method close
  expose observations closed count sourceToken trackToken
  observations=.array~new; count=0; sourceToken=''; trackToken=''
  closed=.true
  return self