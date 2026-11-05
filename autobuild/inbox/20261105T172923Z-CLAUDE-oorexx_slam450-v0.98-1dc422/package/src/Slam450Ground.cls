/* SLAM450 v0.91 — real ground from Power SLAM v0.40 words.
 * Architecture: Tom Dyer. Implementation: Claude (Opus 5.5), 2026-11-03.
 *
 * Inputs (oorexx_slam_toprope_v0.1/examples/harbour, on main since PR #126):
 *   harbour_heights.words  50 m AHD71 bare-earth grid, GDA94/MGA56, 226 x 204
 *                          (SHA-256 3243f644...a102e)
 *   harbour_water.words    L/W/X classification on the same grid
 *                          (SHA-256 dd6c0bad...436ec7)
 * Authority: the estate's Power SLAM classes, wired exactly as the water
 * README prescribes: HarbourWordsRoleEvidence~setCell for every L/W cell,
 * then HarbourWordsSceneTile~new(heights,0.9,roles). X stays unknown.
 *
 * ONE SURFACE, nearest cell (the adapter's own rule), for every consumer:
 *   L  -> ground at the cell's AHD height       W -> sea surface at 0 m
 *   X, nodata or outside the grid -> NO-FLY (fails closed, as the tracer does)
 * Interpolating a resampled 50 m grid would invent detail, and a second
 * surface would let something be visible but not solid, or the reverse.
 *
 * FAST PATH. HarbourWordsSceneTile projects scene->MGA with a full
 * Transverse Mercator on every call: correct, and far too slow for
 * per-tick collision. Over a few km that map is affine to centimetres, so
 * an affine fit (least squares on a 7 x 7 lattice of the adapter's own
 * sceneMGA) drives the hot loops. At start-up it is VERIFIED against the
 * adapter: max residual on a 25 x 25 lattice must be < 1 m, and 400
 * deterministic sample points must give the same cell, role and height as
 * HarbourWordsSceneTile~sample (points within residual+1 cm of a cell
 * edge are excluded: there the two may legitimately pick neighbours).
 *
 * SEGMENTS are tested exactly: a DDA walks every grid cell the segment's
 * ground track crosses; the segment's lowest point inside each cell is
 * compared with that cell's surface. No sampling gaps.
 */
::class Slam450Ground public
::attribute affine get
::attribute maxResidual get
::attribute checkedPoints get
::attribute excludedPoints get
::attribute heightsFile get
::attribute waterFile get
::attribute columns get
::attribute rows get
::attribute originE get
::attribute originN get
::attribute resolution get
::attribute tile get
::method init
  expose heights roles columns rows originE originN resolution affine maxResidual checkedPoints excludedPoints heightsFile waterFile tile
  use strict arg wordsDir,region
  numeric digits 16
  heightsFile=wordsDir'/harbour_heights.words';waterFile=wordsDir'/harbour_water.words'
  h=self~readGrid(heightsFile,'HEIGHTS')
  w=self~readGrid(waterFile,'WATER')
  if h['HEADER']\==w['HEADER'] then raise syntax 88.900 array('height and water grids differ:' h['HEADER'] '/' w['HEADER'])
  parse value h['HEADER'] with originE originN resolution columns rows
  heights=h['ROWS'];roles=w['ROWS']
  /* Estate authority, wired as the water README prescribes. */
  hw=.HarbourWordsMGA~new(heightsFile)
  evidence=.HarbourWordsRoleEvidence~new('harbour_water.words (oorexx_slam_toprope_v0.1, PR #126)')
  do r=1 to rows
    line=roles[r]
    do c=1 to columns
      ch=substr(line,c,1)
      if ch=='L' | ch=='W' then evidence~setCell(c,r,ch)
    end
  end
  tile=.HarbourWordsSceneTile~new(hw,0.9,evidence)
  self~fitAffine(region)
  self~verify(region)

::method readGrid private
  use strict arg file,kind
  numeric digits 16
  if stream(file,'C','QUERY EXISTS')=='' then raise syntax 88.900 array('missing ground words file:' file)
  out=.array~new;header=''
  do while lines(file)>0
    line=linein(file)~strip
    if line~left(9)=='grid mga ' then do
      parse var line 'grid mga' zone 'top left' e n 'step' s 'across' c 'down' r
      this=(e+0) (n+0) (s+0) (c+0) (r+0)
      if header=='' then header=this
      else if this\==header then raise syntax 88.900 array('inconsistent grid declaration in' file)
      if zone\=56 then raise syntax 88.900 array('not MGA zone 56:' file)
    end
    else if line~left(4)=='row ' then do
      if out~items>=word(header,5) then iterate
      body=line~substr(5)~strip
      if kind=='WATER' then do
        if length(body)\=word(header,4) | verify(body,'LWX')>0 then raise syntax 88.900 array('bad water row' out~items+1)
        out~append(body)
      end
      else do
        if body~words\=word(header,4) then raise syntax 88.900 array('bad height row' out~items+1)
        out~append(body)
      end
    end
  end
  call stream file,'C','CLOSE'
  if header=='' | out~items\=word(header,5) then raise syntax 88.900 array('incomplete grid:' file)
  d=.directory~new;d['HEADER']=header;d['ROWS']=out
  return d

::method fitAffine private
  /* Least squares E = a1 + a2 x + a3 y, N = a4 + a5 x + a6 y on a 7x7
   * lattice of the adapter's own sceneMGA over the region. */
  expose tile affine
  use strict arg region
  numeric digits 20
  s=.array~new;do k=1 to 9;s[k]=0;end;be=.array~of(0,0,0);bn=.array~of(0,0,0)
  do i=0 to 6
    do j=0 to 6
      x=region[1]+(region[2]-region[1])*i/6;y=region[3]+(region[4]-region[3])*j/6
      m=tile~sceneMGA(x,y)
      v=.array~of(1,x,y)
      do a=1 to 3
        do b=1 to 3;s[(a-1)*3+b]+=v[a]*v[b];end
        be[a]+=v[a]*m[1];bn[a]+=v[a]*m[2]
      end
    end
  end
  ce=self~solve3(s,be);cn=self~solve3(s,bn)
  affine=.array~of(ce[1],ce[2],ce[3],cn[1],cn[2],cn[3])

::method solve3 private
  /* Cramer's rule on the 3x3 normal equations. */
  use strict arg m,b
  numeric digits 20
  det=self~det3(m)
  if abs(det)<1e-12 then raise syntax 88.900 array('singular affine fit')
  out=.array~new
  do k=1 to 3
    t=m~copy
    do r=1 to 3;t[(r-1)*3+k]=b[r];end
    out~append(self~det3(t)/det)
  end
  return out
::method det3 private
  use strict arg m
  numeric digits 20
  return m[1]*(m[5]*m[9]-m[6]*m[8])-m[2]*(m[4]*m[9]-m[6]*m[7])+m[3]*(m[4]*m[8]-m[5]*m[7])

::method verify private
  expose tile affine maxResidual checkedPoints excludedPoints originE originN resolution
  use strict arg region
  numeric digits 16
  maxResidual=0
  do i=0 to 24
    do j=0 to 24
      x=region[1]+(region[2]-region[1])*i/24;y=region[3]+(region[4]-region[3])*j/24
      m=tile~sceneMGA(x,y);f=self~mga(x,y)
      maxResidual=max(maxResidual,RxCalcSqrt((m[1]-f[1])**2+(m[2]-f[2])**2,16))
    end
  end
  if maxResidual>=1 then raise syntax 88.900 array('affine scene->MGA residual' maxResidual 'm >= 1 m')
  checkedPoints=0;excludedPoints=0;seed=91045
  do k=1 to 400
    seed=(seed*16807)//2147483647;x=region[1]+(region[2]-region[1])*seed/2147483647
    seed=(seed*16807)//2147483647;y=region[3]+(region[4]-region[3])*seed/2147483647
    f=self~mga(x,y)
    u=(f[1]-originE)/resolution+0.5;v=(originN-f[2])/resolution+0.5
    edge=min(u-trunc(u),1-(u-trunc(u)),v-trunc(v),1-(v-trunc(v)))*resolution
    if edge<=maxResidual+0.01 then do;excludedPoints+=1;iterate;end
    ref=tile~sample(x,y);mine=self~cellAt(x,y)
    refRole=ref['ROLE']
    if refRole\==mine['ROLE'] then raise syntax 88.900 array('ground fast path role mismatch at' x y refRole mine['ROLE'])
    if refRole=='L' then if ref['HEIGHT_M']\=mine['HEIGHT_M'] then ,
      raise syntax 88.900 array('ground fast path height mismatch at' x y ref['HEIGHT_M'] mine['HEIGHT_M'])
    if ref~hasIndex('COLUMN') then if ref['COLUMN']\=mine['COLUMN'] | ref['ROW']\=mine['ROW'] then ,
      raise syntax 88.900 array('ground fast path cell mismatch at' x y)
    checkedPoints+=1
  end

::method mga
  /* Fast scene -> MGA (verified affine). */
  expose affine
  use strict arg x,y
  numeric digits 16
  return .array~of(affine[1]+affine[2]*x+affine[3]*y,affine[4]+affine[5]*x+affine[6]*y)

::method cellAt
  /* Nearest cell, the adapter's rule. Returns ROLE (L/W/X), HEIGHT_M,
   * COLUMN, ROW and TOP_M (surface: L height, W 0, X/outside 1e9). */
  expose heights roles columns rows originE originN resolution
  use strict arg x,y
  numeric digits 16
  f=self~mga(x,y)
  d=.directory~new;d['ROLE']='X';d['HEIGHT_M']='UNKNOWN';d['TOP_M']=1e9
  if f[1]<originE-resolution/2 | f[2]>originN+resolution/2 then return d
  col=trunc((f[1]-originE)/resolution+0.5)+1
  row=trunc((originN-f[2])/resolution+0.5)+1
  if col<1 | col>columns | row<1 | row>rows then return d
  d['COLUMN']=col;d['ROW']=row
  return self~fill(d,col,row)

::method fill private
  expose heights roles
  use strict arg d,col,row
  role=substr(roles[row],col,1);hv=word(heights[row],col)
  if role=='W' then do;d['ROLE']='W';d['TOP_M']=0;return d;end
  if role=='L' & hv\=='-' then do
    d['ROLE']='L';d['HEIGHT_M']=hv+0;d['TOP_M']=hv+0;return d
  end
  d['ROLE']='X';return d

::method topCell
  /* Surface height of a cell by index; 1e9 for X / nodata / outside. */
  expose heights roles columns rows
  use strict arg col,row
  if col<1 | col>columns | row<1 | row>rows then return 1e9
  role=substr(roles[row],col,1)
  if role=='W' then return 0
  hv=word(heights[row],col)
  if role=='L' & hv\=='-' then return hv+0
  return 1e9

::method surface
  use strict arg x,y
  return self~cellAt(x,y)['TOP_M']

::method pointClear
  /* p and its four horizontal neighbours at +/- clearance (the scene's
   * safePoint convention) must all be more than clearance above ground. */
  use strict arg p,clearance=1
  numeric digits 16
  do o over .array~of(.array~of(0,0),.array~of(clearance,0),.array~of(0-clearance,0),.array~of(0,clearance),.array~of(0,0-clearance))
    if p[3]<=self~surface(p[1]+o[1],p[2]+o[2])+clearance then return .false
  end
  return .true

::method segmentClear
  /* Exact: every cell crossed by a->b, lowest segment point in the cell
   * must be above that cell's surface + margin. */
  expose originE originN resolution
  use strict arg a,b,margin=0
  numeric digits 16
  fa=self~mga(a[1],a[2]);fb=self~mga(b[1],b[2])
  u0=(fa[1]-originE)/resolution+0.5;v0=(originN-fa[2])/resolution+0.5
  u1=(fb[1]-originE)/resolution+0.5;v1=(originN-fb[2])/resolution+0.5
  ci=self~floor(u0);cj=self~floor(v0)
  du=u1-u0;dv=v1-v0
  stepI=0;stepJ=0;tMaxI=2;tMaxJ=2;tDeltaI=2;tDeltaJ=2
  if du>0 then do;stepI=1;tMaxI=(ci+1-u0)/du;tDeltaI=1/du;end
  if du<0 then do;stepI=-1;tMaxI=(ci-u0)/du;tDeltaI=-1/du;end
  if dv>0 then do;stepJ=1;tMaxJ=(cj+1-v0)/dv;tDeltaJ=1/dv;end
  if dv<0 then do;stepJ=-1;tMaxJ=(cj-v0)/dv;tDeltaJ=-1/dv;end
  t0=0
  do guard=1 to 100000
    t1=min(1,tMaxI,tMaxJ)
    zLow=min(a[3]+(b[3]-a[3])*t0,a[3]+(b[3]-a[3])*t1)
    if zLow<=self~topCell(ci+1,cj+1)+margin then return .false
    if t1>=1 then return .true
    if tMaxI<tMaxJ then do;ci+=stepI;t0=tMaxI;tMaxI+=tDeltaI;end
    else do;cj+=stepJ;t0=tMaxJ;tMaxJ+=tDeltaJ;end
  end
  return .false

::method firstHit
  /* v0.92 scanner: fraction t in [0,1] where segment a->b first meets the
   * surface (z <= cell top; X / outside counts as a return), or -1. Exact
   * per crossed cell, like segmentClear. */
  expose originE originN resolution
  use strict arg a,b
  numeric digits 16
  fa=self~mga(a[1],a[2]);fb=self~mga(b[1],b[2])
  u0=(fa[1]-originE)/resolution+0.5;v0=(originN-fa[2])/resolution+0.5
  u1=(fb[1]-originE)/resolution+0.5;v1=(originN-fb[2])/resolution+0.5
  ci=self~floor(u0);cj=self~floor(v0)
  du=u1-u0;dv=v1-v0
  stepI=0;stepJ=0;tMaxI=2;tMaxJ=2;tDeltaI=2;tDeltaJ=2
  if du>0 then do;stepI=1;tMaxI=(ci+1-u0)/du;tDeltaI=1/du;end
  if du<0 then do;stepI=-1;tMaxI=(ci-u0)/du;tDeltaI=-1/du;end
  if dv>0 then do;stepJ=1;tMaxJ=(cj+1-v0)/dv;tDeltaJ=1/dv;end
  if dv<0 then do;stepJ=-1;tMaxJ=(cj-v0)/dv;tDeltaJ=-1/dv;end
  t0=0;dz=b[3]-a[3]
  do guard=1 to 100000
    t1=min(1,tMaxI,tMaxJ)
    top=self~topCell(ci+1,cj+1)
    z0=a[3]+dz*t0;z1=a[3]+dz*t1
    if z0<=top then return t0
    if z1<=top then return t0+(top-z0)/dz*(1)
    if t1>=1 then return -1
    if tMaxI<tMaxJ then do;ci+=stepI;t0=tMaxI;tMaxI+=tDeltaI;end
    else do;cj+=stepJ;t0=tMaxJ;tMaxJ+=tDeltaJ;end
  end
  return -1
::method lineClear
  /* The scene's safeLine convention: centre line plus four horizontal
   * offsets of 2 m, each at least `margin` above ground. */
  use strict arg a,b,margin=2
  numeric digits 16
  do o over .array~of(.array~of(0,0),.array~of(2,0),.array~of(-2,0),.array~of(0,2),.array~of(0,-2))
    p=.array~of(a[1]+o[1],a[2]+o[2],a[3]);q=.array~of(b[1]+o[1],b[2]+o[2],b[3])
    if \self~segmentClear(p,q,margin) then return .false
  end
  return .true

::method sightClear
  /* Line of sight: blocked only where the ray passes below the surface. */
  use strict arg a,b
  return self~segmentClear(a,b,0)

::method floor private
  use strict arg v
  t=trunc(v)
  if v<0 & t\=v then t-=1
  return t

::method rasterLocal
  /* For renderers: the grid as heights (land height, else 0) and kinds
   * (1 land, 0 water, -1 X/nodata) plus its local affine frame: origin of cell (1,1)
   * centre in scene coordinates and the scene vectors of one column and
   * one row step. Inverse of the verified affine. */
  expose heights roles columns rows originE originN resolution affine
  numeric digits 16
  det=affine[2]*affine[6]-affine[3]*affine[5]
  /* scene = inv(A) * (mga - t) */
  i11=affine[6]/det;i12=0-affine[3]/det;i21=0-affine[5]/det;i22=affine[2]/det
  ex=originE-affine[1];ny=originN-affine[4]
  ox=i11*ex+i12*ny;oy=i21*ex+i22*ny
  colV=.array~of(i11*resolution,i21*resolution)
  rowV=.array~of(0-i12*resolution,0-i22*resolution)
  flat=.array~new(columns*rows);kinds=.array~new(columns*rows)
  k=0
  do r=1 to rows
    do c=1 to columns
      k+=1;t=self~topCell(c,r)
      if t=1e9 then do;flat[k]=0;kinds[k]=-1;end
      else if substr(roles[r],c,1)=='W' then do;flat[k]=0;kinds[k]=0;end
      else do;flat[k]=t;kinds[k]=1;end
    end
  end
  d=.directory~new
  d['COLUMNS']=columns;d['ROWS']=rows;d['HEIGHTS']=flat;d['KINDS']=kinds
  d['ORIGIN']=.array~of(ox,oy);d['COL_VECTOR']=colV;d['ROW_VECTOR']=rowV
  d['ROLES']=roles
  return d
::requires 'SlamHarbourWordsScene.cls'
