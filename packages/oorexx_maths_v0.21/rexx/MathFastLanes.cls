/* ooRexx Maths v0.21 — hot-loop lanes (v0.21 adds MathTerrainPanorama).
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

::class MathTerrainPanorama public
/* v0.21 (Claude Opus 5.5, 2026-11-03). Terrain silhouettes for the same
 * equirectangular panorama convention as MathPanoramaProjector.
 *
 * Input: a static height field on an affine grid in the camera's frame —
 * heights (row-major, rows x columns), kinds (1 land, 0 water, -1 unknown),
 * the scene position of cell (1,1)'s CENTRE and the scene vectors of one
 * column step and one row step. Nearest-cell lookup: col = floor(u+0.5)+1.
 *
 * Method: per panorama column, march outward along the column's centre
 * bearing over a fixed distance schedule (d0 = 10 m, d += max(5, 0.02 d),
 * up to maxRange), front to back. Each valid sample has surface height h
 * (land h, water 0) and screen row rr = trunc((90-atan((h-cz)/d))*H/180)+1.
 * A running "lowest painted row so far" (ybuf, starts H+1) occludes what is
 * behind: a LAND sample with rr < ybuf paints rows [rr, ybuf-1]; any valid
 * sample sets ybuf = min(ybuf, rr). Water never paints (the consumer's
 * below-horizon background is already water) but it does occlude. Unknown
 * and off-grid samples are transparent. This is the classic voxel-space
 * column renderer; thin ridges narrower than the far sample spacing
 * (0.02 d, i.e. 60 m at 3 km) can be missed — a rendering limit, not a
 * collision one.
 * Output: array of W entries (one per column), each an array of land runs
 * .array~of(y0,y1), 1-based inclusive, top to bottom order of discovery,
 * adjacent runs merged.
 * Lanes as MathPanoramaProjector: PURE (ooRexx decimal, reference), NUMPY
 * (binary64, field resident; only the pose goes in, one packed string out).
 * The distance schedule is computed once here and shared by both lanes.
 */
::attribute lane get
::attribute columns get
::attribute rows get
::attribute schedule get
::attribute digits get
::method init
  expose lane heights kinds columns rows ox oy i11 i12 i21 i22 schedule digits field
  use strict arg flatHeights,flatKinds,gridColumns,gridRows,origin,colVector,rowVector,maxRange=3000,requestedLane='AUTO',decimalDigits=9
  numeric digits 20
  if \datatype(gridColumns,'W') | \datatype(gridRows,'W') | gridColumns<1 | gridRows<1 then raise syntax 88.900 array('positive grid size',gridColumns gridRows)
  if flatHeights~items<>gridColumns*gridRows | flatKinds~items<>gridColumns*gridRows then raise syntax 88.900 array('heights and kinds of columns*rows items',flatHeights~items flatKinds~items)
  if \datatype(decimalDigits,'W') | decimalDigits<1 then raise syntax 88.900 array('positive digits',decimalDigits)
  heights=flatHeights;kinds=flatKinds;columns=gridColumns;rows=gridRows;digits=decimalDigits
  ox=origin[1];oy=origin[2]
  det=colVector[1]*rowVector[2]-rowVector[1]*colVector[2]
  if abs(det)<1e-12 then raise syntax 88.900 array('non-degenerate grid vectors','singular')
  i11=rowVector[2]/det;i12=0-rowVector[1]/det
  i21=0-colVector[2]/det;i22=colVector[1]/det
  schedule=.array~new;d=10
  do while d<=maxRange
    schedule~append(d)
    d=d+max(5,0.02*d)
  end
  want=requestedLane~upper
  if want<>'AUTO' & want<>'PURE' & want<>'NUMPY' then raise syntax 88.900 array('AUTO, PURE or NUMPY lane',requestedLane)
  if want='AUTO' then do
    if .MathPanoramaProjector~numpyAvailable then want='NUMPY'
    else want='PURE'
  end
  if want='NUMPY' then do
    if \.MathPanoramaProjector~numpyAvailable then raise syntax 88.900 array('importable numpy and oorexx_maths_native for NUMPY lane','not available')
    native=.ForeignPython~import('oorexx_maths_native')
    field=native~terrain_field(heights,kinds,columns,rows,ox,oy,i11,i12,i21,i22,schedule)
  end
  lane=want
::method runs
  expose lane
  use strict arg camera,width,height
  if lane='NUMPY' then return self~runsNumpy(camera,width,height)
  return self~runsPure(camera,width,height)
::method rowRuns
  /* Same picture as runs, transposed for painting: array of H entries
   * (one per row), each an array of .array~of(x0,x1) land column runs,
   * left to right. Land is wide and short, so this is far fewer runs
   * than the column form. */
  expose lane field
  use strict arg camera,width,height
  out=.array~new(height)
  do y=1 to height;out[y]=.array~new;end
  if lane='NUMPY' then do
    packed=field~row_runs(camera[1],camera[2],camera[3],camera[4],width,height)
    do while packed<>''
      parse var packed y n packed
      do j=1 to n
        parse var packed x0 x1 packed
        out[y]~append(.array~of(x0,x1))
      end
    end
    return out
  end
  cols=self~runsPure(camera,width,height)
  mask=.array~new(height)
  do y=1 to height;mask[y]='0'~copies(width);end
  do x=1 to width
    do r over cols[x]
      do y=r[1] to r[2];mask[y]=overlay('1',mask[y],x);end
    end
  end
  do y=1 to height
    m=mask[y];x=1
    do forever
      x0=pos('1',m,x);if x0=0 then leave
      x1=pos('0',m,x0);if x1=0 then x1=width+1
      out[y]~append(.array~of(x0,x1-1));x=x1
      if x>width then leave
    end
  end
  return out
::method runsNumpy private
  expose field
  use strict arg camera,width,height
  packed=field~runs(camera[1],camera[2],camera[3],camera[4],width,height)
  out=.array~new(width)
  do k=1 to width;out[k]=.array~new;end
  do while packed<>''
    parse var packed k n packed
    do j=1 to n
      parse var packed y0 y1 packed
      out[k]~append(.array~of(y0,y1))
    end
  end
  return out
::method runsPure private
  expose heights kinds columns rows ox oy i11 i12 i21 i22 schedule digits
  use strict arg camera,width,height
  numeric digits (digits)
  cx=camera[1];cy=camera[2];cz=camera[3];yaw=camera[4]
  out=.array~new(width)
  do k=1 to width
    list=.array~new
    b=(k-0.5)*360/width+yaw-180
    sb=rxf_sin(b,digits);cb=rxf_cos(b,digits)
    ybuf=height+1
    do d over schedule
      dx=cx+d*sb-ox;dy=cy+d*cb-oy
      u=i11*dx+i12*dy+0.5;v=i21*dx+i22*dy+0.5
      col=trunc(u);if u<0 & col<>u then col-=1
      row=trunc(v);if v<0 & row<>v then row-=1
      col+=1;row+=1
      if col<1 | col>columns | row<1 | row>rows then iterate
      idx=(row-1)*columns+col
      kind=kinds[idx]
      if kind<0 then iterate
      h=0;if kind=1 then h=heights[idx]
      el=rxf_atan((h-cz)/d,digits)
      rr=trunc((90-el)*height/180)+1
      if rr<ybuf then do
        if kind=1 then do
          y0=max(1,rr);y1=min(height,ybuf-1)
          if y0<=y1 then do
            merged=.false
            if list~items>0 then if list[list~items][1]=y1+1 then do
              list[list~items][1]=y0;merged=.true
            end
            if \merged then list~append(.array~of(y0,y1))
          end
        end
        ybuf=rr
      end
    end
    out[k]=list
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
