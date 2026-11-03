/* ooRexx Maths v0.20 — hot-loop lanes.
 * Architecture: Tom Dyer. Implementation: Claude (Opus 5.5), 2026-11-03.
 *
 * Two optimised call families that consumers (Physics World flight solvers,
 * SLAM 450 panorama rendering) need inside per-tick loops:
 *
 * 1. MathBinary64ScalarLane — explicit BINARY64 scalar transcendentals over
 *    the ooRexx RxMath C library. The caller opts in ONCE by opening a lane;
 *    individual calls carry no per-call MathEvidence/MathDerivation objects.
 *    The lane retains one summary MathEvidence (operation counts, provider,
 *    precision) so the domain transition stays explicit (Constitution 2, 6).
 *
 * 2. MathPanoramaProjector — equirectangular (360 x 180 degree) projection
 *    of a STATIC grouped point set from a moving camera, returning each
 *    group's wrap-aware pixel extent. Lanes:
 *      PURE  — ooRexx decimal arithmetic at caller-declared digits (default
 *              9, which reproduces pre-v0.20 consumer renders bit-for-bit);
 *      NUMPY — binary64 kernel over Foreign Runtime. The point set is
 *              uploaded once and stays resident; each call marshals only the
 *              camera pose in and one packed string out.
 *    AUTO selects NUMPY when importable, else PURE. Provider choice is
 *    recorded; binary64 is never a silent substitute for PURE (the caller
 *    sees `lane` and may pin PURE for bit-exact reproduction).
 *
 * Convention (shared by both lanes):
 *   bearing  = compass bearing atan2(dx,dy) in [0,360), +x east, +y north;
 *              |dy| < 1e-7 resolves to 90 (dx>=0) or 270.
 *   relative = (bearing - yaw + 180) mod 360, so straight ahead is centre.
 *   column   = trunc(relative*W/360)+1
 *   el       = atan(dz / max(0.1, horizontal distance)) degrees
 *   row      = trunc((90-el)*H/180)+1
 *   extent   = first vertex column is the wrap base; every other column is
 *              shifted into (-W/2, W/2] of it; x0=max(1,trunc(lo)),
 *              x1=min(W,trunc(hi)), y0=max(1,trunc(top)), y1=min(H,trunc(bottom)).
 */

::class MathBinary64ScalarLane public
::attribute counts get
::method init
  expose counts opened
  counts=.directory~new; opened=date('S') time('L')
::method count private
  expose counts
  use strict arg op
  if counts~hasIndex(op) then counts[op]=counts[op]+1
  else counts[op]=1
::method sqrt
  numeric digits 16
  use strict arg x
  if x<0 then raise syntax 42.3
  self~count('SQRT'); return rxf_sqrt(x,16)
::method sin
  numeric digits 16
  use strict arg x
  self~count('SIN'); return rxf_sin(x,16,'R')
::method cos
  numeric digits 16
  use strict arg x
  self~count('COS'); return rxf_cos(x,16,'R')
::method tan
  numeric digits 16
  use strict arg x
  self~count('TAN'); return rxf_tan(x,16,'R')
::method atan
  numeric digits 16
  use strict arg x
  self~count('ATAN'); return rxf_atan(x,16,'R')
::method asin
  numeric digits 16
  use strict arg x
  if x<-1 | x>1 then raise syntax 88.900 array('asin argument in [-1,1]',x)
  self~count('ASIN'); return rxf_asin(x,16,'R')
::method atan2
  use strict arg y,x
  self~count('ATAN2')
  numeric digits 18
  pi=rxf_pi(16)
  if x>0 then return rxf_atan(y/x,16,'R')
  if x<0 then do
    a=rxf_atan(y/x,16,'R')
    if y>=0 then return a+pi
    return a-pi
  end
  if y>0 then return pi/2
  if y<0 then return -pi/2
  return 0
::method pi
  numeric digits 16
  return rxf_pi(16)
::method degrees
  numeric digits 16
  use strict arg radians
  return radians*180/rxf_pi(16)
::method radians
  numeric digits 16
  use strict arg degrees
  return degrees*rxf_pi(16)/180
::method evidence
  /* One summary record for the whole lane, not one per call. */
  expose counts opened
  context=.MathContext~binary64('RXMATH')
  inputs=.array~new
  do op over counts~allIndexes~sort; inputs~append(op'='counts[op]); end
  ev=.MathEvidence~new('scalar.lane',context,inputs)
  ignored=ev~addStep(.MathPathStep~new('scalar.lane','RXMATH','ooRexx-distribution-RxMath', -
    'native-rxmath-hot-loop-lane','BINARY64',16,'RxMath C double results', -
    'Lane opened 'opened'; per-call evidence deliberately elided; counts summarise every call.', -
    'APPROXIMATE_16_DIGIT_NATIVE','RXMATH,NATIVE,C-DOUBLE,LANE'))
  ev~addWarning('Hot-loop lane: binary64-equivalent 16-digit results without per-call derivations. Use Maths~sqrt etc. with a REFERENCE context where a call must be independently replayable.')
  return ev

::class MathPanoramaProjector public
::attribute lane get
::attribute groupCount get
::attribute digits get
::method numpyAvailable class
  signal on syntax name unavailable
  if .environment~hasEntry('FOREIGNPYTHON') = 0 then do
    .context~package~loadPackage('python_foreign.cls')
  end
  return .ForeignPython~canImport('numpy') & .ForeignPython~canImport('oorexx_maths_native')
unavailable:
  return .false
::method init
  /* groups: array of arrays of [x,y,z] points. Static for the lifetime. */
  expose lane groupCount groups digits native scene
  use strict arg pointGroups,requestedLane='AUTO',decimalDigits=9
  if \pointGroups~isA(.array) then raise syntax 88.900 array('array of point groups',pointGroups)
  if \datatype(decimalDigits,'W') | decimalDigits<1 then raise syntax 88.900 array('positive digits',decimalDigits)
  digits=decimalDigits
  groups=pointGroups
  groupCount=groups~items
  want=requestedLane~upper
  if want<>'AUTO' & want<>'PURE' & want<>'NUMPY' then raise syntax 88.900 array('AUTO, PURE or NUMPY lane',requestedLane)
  if want='AUTO' then do
    if .MathPanoramaProjector~numpyAvailable then want='NUMPY'
    else want='PURE'
  end
  if want='NUMPY' then do
    if \.MathPanoramaProjector~numpyAvailable then raise syntax 88.900 array('importable numpy and oorexx_maths_native for NUMPY lane','not available')
    flat=.array~new; sizes=.array~new
    do g over groups
      sizes~append(g~items)
      do p over g; flat~append(p[1]); flat~append(p[2]); flat~append(p[3]); end
    end
    kw=.ForeignPython~keywords; kw~put('dtype','float64')
    native=.ForeignPython~import('oorexx_maths_native')
    scene=native~panorama_scene(flat,sizes)
  end
  lane=want
::method extents
  /* Returns an array of groupCount entries; each is .nil (not visible in
     frame) or array(x0,x1,y0,y1) of 1-based inclusive pixel bounds. */
  expose lane
  use strict arg camera,width,height
  if lane='NUMPY' then return self~extentsNumpy(camera,width,height)
  return self~extentsPure(camera,width,height)
::method extentsNumpy private
  expose scene groupCount
  use strict arg camera,width,height
  packed=scene~extents(camera[1],camera[2],camera[3],camera[4],width,height)
  out=.array~new(groupCount)
  do i=1 to groupCount
    parse var packed x0 x1 y0 y1 packed
    if x0<=x1 & y0<=y1 then out[i]=.array~of(x0,x1,y0,y1)
    else out[i]=.nil
  end
  return out
::method extentsPure private
  expose groups digits
  use strict arg camera,width,height
  numeric digits (digits)
  out=.array~new(groups~items)
  half=width/2
  i=0
  do g over groups
    i+=1
    lo=1e5;hi=-1e5;top=1e5;bottom=-1e5;base=.nil
    do pt over g
      dx=pt[1]-camera[1];dy=pt[2]-camera[2];dz=pt[3]-camera[3]
      dist=rxf_sqrt(dx*dx+dy*dy,digits)
      if dist<0.1 then dist=0.1
      if abs(dy)<0.0000001 then do
        if dx>=0 then bearing=90
        else bearing=270
      end
      else do
        if dy>0 then bearing=rxf_atan(dx/dy,digits)
        else bearing=180+rxf_atan(dx/dy,digits)
        if bearing<0 then bearing+=360
      end
      a=bearing-camera[4]+180
      do while a<0;a+=360;end
      do while a>=360;a-=360;end
      el=rxf_atan(dz/dist,digits)
      xx=trunc(a*width/360)+1
      yy=trunc((90-el)*height/180)+1
      if base==.nil then base=xx
      delta=xx-base
      if delta>half then delta-=width
      if delta<0-half then delta+=width
      lo=min(lo,base+delta);hi=max(hi,base+delta)
      top=min(top,yy);bottom=max(bottom,yy)
    end
    x0=max(1,trunc(lo));x1=min(width,trunc(hi))
    y0=max(1,trunc(top));y1=min(height,trunc(bottom))
    if x0<=x1 & y0<=y1 then out[i]=.array~of(x0,x1,y0,y1)
    else out[i]=.nil
  end
  return out

::routine rxf_sqrt  external "library rxmath RxCalcSqrt"
::routine rxf_sin   external "library rxmath RxCalcSin"
::routine rxf_cos   external "library rxmath RxCalcCos"
::routine rxf_tan   external "library rxmath RxCalcTan"
::routine rxf_atan  external "library rxmath RxCalcArcTan"
::routine rxf_asin  external "library rxmath RxCalcArcSin"
::routine rxf_pi    external "library rxmath RxCalcPi"

::requires 'MathsBootstrap.cls'
