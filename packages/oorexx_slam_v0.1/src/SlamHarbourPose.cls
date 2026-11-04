/* Power SLAM harbour geometry experiment. Architecture: Tom Dyer.
 * Isolated ooRexx qualification increment: ChatGPT GPT-6, 2026-11-01.
 * Positive mask = land; everywhere else is NOT ADMITTED.
 * Flat tangent-plane approximation, x east/y north (metres) centred at
 * 33.852 S, 151.210 E. Do not use for geodetic surveying.
 * Shapes deliberately coarse: four solid pylons, one deck, one Opera box.
 */
::class HarbourLandMask public
::attribute regions
::method init
  expose regions maskRows maskBBox maskWidth maskHeight
  regions = .array~new
  maskRows=.nil
  maskBBox=.nil
  maskWidth=0
  maskHeight=0
/* Geo-referenced categorical coastline mask. L=land, B=blue water,
   X=unknown (blocked); north is the first row. Unlike coarse demonstration
   rectangles, when a raster exists it is AUTHORITATIVE and fail-closed.
   File header: HARBOUR_LAND_MASK_V1 WIDTH HEIGHT. No resampling or guessing.
   Geo reference: same local east/north metres as HarbourScene. */
::method loadRasterAscii
  expose maskRows maskBBox maskWidth maskHeight
  use strict arg file,x0,x1,y0,y1
  if x1<=x0 | y1<=y0 then raise syntax 88.900 array('invalid mask extents')
  header=linein(file)
  parse var header signature wide high extra
  if signature \== 'HARBOUR_LAND_MASK_V1' | \datatype(wide,'W') | \datatype(high,'W') then raise syntax 88.900 array('invalid mask header')
  if wide<1 | high<1 | extra\=='' then raise syntax 88.900 array('invalid mask dimensions')
  rows=.array~new
  do i=1 to high
    row=linein(file)~strip
    if row~length<>wide then raise syntax 88.900 array('wrong mask row width')
    do j=1 to wide
      if 'LBX'~pos(row~substr(j,1))=0 then raise syntax 88.900 array('invalid mask symbol')
    end
    rows~append(row)
  end
  call stream file,'C','CLOSE'
  maskRows=rows; maskBBox=.array~of(x0,x1,y0,y1)
  maskWidth=wide;maskHeight=high
::method addRect
  expose regions
  use strict arg x0, x1, y0, y1, name
  if x1 <= x0 | y1 <= y0 then raise syntax 88.900 array('invalid land patch')
  regions~append(.array~of(x0,x1,y0,y1,name))
::method contains
  expose regions maskRows maskBBox maskWidth maskHeight
  use strict arg x,y
  if maskRows\==.nil then do
    if x<maskBBox[1] | x>=maskBBox[2] | y<maskBBox[3] | y>=maskBBox[4] then return .false
    col=trunc((x-maskBBox[1])*maskWidth/(maskBBox[2]-maskBBox[1]))+1
    row=trunc((maskBBox[4]-y)*maskHeight/(maskBBox[4]-maskBBox[3]))+1
    if row<1 | row>maskHeight | col<1 | col>maskWidth then return .false
    return maskRows[row]~substr(col,1)=='L'
  end
  do r over regions
    if x>=r[1] & x<=r[2] & y>=r[3] & y<=r[4] then return .true
  end
  return .false
::method bounds
  expose regions maskRows maskBBox
  if maskRows\==.nil then return maskBBox
  if regions~items=0 then raise syntax 88.900 array('no land evidence')
  x0=1e20; x1=-1e20; y0=1e20; y1=-1e20
  do r over regions
    x0=min(x0,r[1]);x1=max(x1,r[2]);y0=min(y0,r[3]);y1=max(y1,r[4])
  end
  return .array~of(x0,x1,y0,y1)

::class HarbourScene public
::attribute features
::attribute boxes
::method local
  use strict arg lat,lon
  return .array~of((lon-151.210)*92300,(lat+33.852)*111200)
::method init
  expose features boxes
  features=.directory~new; boxes=.array~new
  n=self~local(-33.85003,151.21209)
  s=self~local(-33.85454,151.20926)
  o=self~local(-33.8566674153,151.2152213360)
  features['N']=.array~of(n[1],n[2],81)
  features['S']=.array~of(s[1],s[2],81)
  features['O']=.array~of(o[1],o[2],39)
  features['D']=.array~of((n[1]+s[1])/2,(n[2]+s[2])/2,54)
  dx=n[1]-s[1];dy=n[2]-s[2]
  length=HSqrt(dx*dx+dy*dy)
  ux=dx/length;uy=dy/length
  vx=uy;vy=-ux
  do edge over .array~of(n,s)
    do side over .array~of(-1,1)
      cx=edge[1]+side*20*vx;cy=edge[2]+side*20*vy
      boxes~append(self~cuboid('PYLON',cx,cy,0,14,14,89,ux,uy,vx,vy))
    end
  end
  boxes~append(self~cuboid('DECK',(n[1]+s[1])/2,(n[2]+s[2])/2,52,length,49,5,ux,uy,vx,vy))
  /* Opera House deliberately reduced to one 183 m x 120 m x 65 m white box. */
  boxes~append(self~cuboid('OPERA',o[1],o[2],4,183,120,65,1,0,0,1))
::method cuboid
  use strict arg name,x,y,z,along,across,h,ux,uy,vx,vy
  v=.array~new
  do vertical over .array~of(0,h)
    do a over .array~of(-1,1)
      do b over .array~of(-1,1)
        v~append(.array~of(x+a*along*ux/2+b*across*vx/2,y+a*along*uy/2+b*across*vy/2,z+vertical))
      end
    end
  end
  return .array~of(name,v)
/* direction FROM camera to screen centre; focal length in pixel units.
   Positive shift makes horizon lower in frame. */
::method project
  use strict arg point,cx,cy,cz,fx,fy,focal,w,h,shift=0
  dx=point[1]-cx;dy=point[2]-cy
  front=dx*fx+dy*fy
  if front <= 0.00001 then return .nil
  right=dx*fy-dy*fx
  u=w/2+focal*right/front
  v=h/2+shift-focal*(point[3]-cz)/front
  return .array~of(u,v,front)
/* 2D camera forward direction inferred algebraically from first landmark and image u.
   Avoids trigonometry and avoids guessed compass headings. */
::method aim
  use strict arg point,cx,cy,u,focal,w
  ax=point[1]-cx;ay=point[2]-cy
  r=(u-w/2)/focal
  fx=ax-r*ay;fy=ay+r*ax
  d=HSqrt(fx*fx+fy*fy)
  if d<0.00001 then return .nil
  return .array~of(fx/d,fy/d)
/* Forward model from real camera pose; observations must be supplied separately. */
::method observe
  expose features
  use strict arg camera, forward, focal, w, h, shift=0
  a=.array~new
  do id over .array~of('N','S','O')
    p=self~project(features[id],camera[1],camera[2],camera[3],forward[1],forward[2],focal,w,h,shift)
    if p==.nil then return .nil
    a~append(.array~of(id,p[1],p[2]))
  end
  return a
/* Search every allowed land cell; input observations are [ID, pixelX, pixelY].
   Focal length and camera elevation are EXPLICIT assumptions. Yaw and image vertical
   shift are solved from first observation. Results are ranked, never pronounced unique.
   Every candidate is rejected before scoring if it is outside the land mask. */
::method fit
  expose features
  use strict arg mask, observations, focal,w,h,camHeight,step=25,maxResults=10,maxRms=5
  if observations~items < 3 then raise syntax 88.900 array('at least three distinct landmarks required')
  if focal<=0 | w<=0 | h<=0 | step<=0 | maxResults<1 | maxRms<=0 then raise syntax 88.900 array('invalid camera/search parameters')
  a=observations[1]
  if \features~hasIndex(a[1]) then raise syntax 88.900 array('unknown first feature')
  best=.array~new; candidates=0; rejected=0
  bounds=mask~bounds
  do y=bounds[3] to bounds[4] by step
    do x=bounds[1] to bounds[2] by step
      if \mask~contains(x,y) then do
        rejected+=1
        iterate
      end
      aim=self~aim(features[a[1]],x,y,a[2],focal,w)
      if aim==.nil then iterate
      zero=self~project(features[a[1]],x,y,camHeight,aim[1],aim[2],focal,w,h)
      if zero==.nil then iterate
      shift=a[3]-zero[2]
      score=0;good=.true
      do obs over observations
        if \features~hasIndex(obs[1]) then raise syntax 88.900 array('unknown feature')
        p=self~project(features[obs[1]],x,y,camHeight,aim[1],aim[2],focal,w,h,shift)
        if p==.nil then do;good=.false;leave;end
        /* total squared reprojection residual, px squared */
        score=score+(p[1]-obs[2])**2+(p[2]-obs[3])**2
      end
      if \good then iterate
      candidates+=1
      fit=.array~of(score,x,y,aim[1],aim[2],shift)
      insertAt=best~items+1
      do i=1 to best~items
        if score<best[i][1] then do;insertAt=i;leave;end
      end
      if insertAt<=maxResults then do
        sorted=.array~new
        do j=1 to best~items+1
          if j=insertAt then sorted~append(fit)
          if j<=best~items then sorted~append(best[j])
        end
        best=sorted
        if best~items>maxResults then best~remove(maxResults+1)
      end
    end
  end
  outcome=.directory~new
  outcome['STATUS']='NO_LAND_SOLUTION'
  if best~items>0 then do
    outcome['STATUS']='NO_GEOMETRIC_FIT'
    if best[1][1] <= maxRms*maxRms*2*observations~items then outcome['STATUS']='RANKED_NOT_UNIQUE'
  end
  outcome['BEST']=best
  outcome['LAND_EVALUATED']=candidates
  outcome['WATER_REJECTED']=rejected
  outcome['FOCAL_PX']=focal
  outcome['MAX_RMS_PX']=maxRms
  return outcome
/* Predicted horizontal landmark ordering with no camera yaw or focal length.
   This is a NECESSARY condition for points visible in a common front hemisphere,
   not a sufficient claim of camera location.  A negative cross product means
   the first landmark lies left of the next landmark. */
::method inOrder
  expose features
  use strict arg cx,cy,ids
  if ids~items<2 then return .false
  do i=1 to ids~items-1
    if \features~hasIndex(ids[i]) | \features~hasIndex(ids[i+1]) then return .false
    a=features[ids[i]];b=features[ids[i+1]]
    cross=(a[1]-cx)*(b[2]-cy)-(a[2]-cy)*(b[1]-cx)
    if cross>=0 then return .false
  end
  return .true
::method countLandInOrder
  use strict arg mask,ids,step=25
  bounds=mask~bounds
  count=0
  do y=bounds[3] to bounds[4] by step
    do x=bounds[1] to bounds[2] by step
      if \mask~contains(x,y) then iterate
      if self~inOrder(x,y,ids) then count+=1
    end
  end
  return count
/* Simple box-wireframe SVG; rendered by ooRexx from the SAME 3D geometry used in fit.
   Does not claim photographic realism or permit reverse inference from appearance. */
::method writeSvg
  expose boxes
  use strict arg file,camera,forward,focal,w,h,shift=0
  call SysFileDelete file
  call lineout file,'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0' w h '">'
  call lineout file,'<rect width="100%" height="100%" fill="#dceaf4"/>'
  do box over boxes
    name=box[1];vertices=box[2]
    color='#6d7177'
    if name=='DECK' then color='#43484c'
    if name=='OPERA' then color='#fffdfa'
    p=.array~new
    do v over vertices
      z=self~project(v,camera[1],camera[2],camera[3],forward[1],forward[2],focal,w,h,shift)
      if z==.nil then do
        p=.array~new
        leave
      end
      p~append(z)
    end
    if p~items<>8 then iterate
    /* Draw all twelve edges, not filled overlapping polygons. */
    do pair over .array~of('1 2','1 3','2 4','3 4','5 6','5 7','6 8','7 8','1 5','2 6','3 7','4 8')
      parse var pair i j
      call lineout file,'<line x1="' p[i][1] '" y1="' p[i][2] '" x2="' p[j][1] '" y2="' p[j][2] '" stroke="' color '" stroke-width="2"/>'
    end
  end
  call lineout file,'</svg>'
  call stream file,'C','CLOSE'

/* Decimal Newton square root; does not depend on an external math package. */
::routine HSqrt public
  use strict arg x
  numeric digits 25
  if x < 0 then raise syntax 88.900 array('negative square root')
  if x = 0 then return 0
  g=x
  if g<1 then g=1
  do 300
    n=(g+x/g)/2
    if n>=g then leave
    g=n
  end
  return g
