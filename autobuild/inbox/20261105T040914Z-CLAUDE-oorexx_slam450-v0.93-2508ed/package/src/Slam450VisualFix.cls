/* SLAM 450 v0.92 - visual position fix against a precomputed 50 m grid.
 *
 * Architecture: Tom Dyer ("grid the area into 50 x 50 metre blocks; one-time
 * precompute of a fixed-point camera against features as a V5V-style image;
 * convert the current image to V5V, look up the closest match point; charge
 * a small visual data charge like a message charge").
 * Written by: Claude (Opus 5.5), 2026-11-04.
 *
 * Feature surface: a SLAM panorama (480 x 121, '.' sky, '~' water, 'G' land,
 * structure class letters), elevation band +45..-45 deg, reduced to 96 x 24
 * points of 3.75 x 3.75 deg (5 x ~2.5 pixels), each
 * point the most common FEATURE class in its block:
 *   0 unknown (targets, aircraft, landmarks: things that move or are tiny)
 *   1 sky  2 water  3 land  4 grey structure  5 Opera  6 pylon/abutment
 *   7 deck  8 Salesforce  9 Blues tower  10 wharves  11 Cahill  12 arch
 * 13 values fit 4 bits per point: 96 x 24 x 4 bits = 1152 bytes per surface,
 * the VisionSurface/V5V packing (oorexx_vision dev14).
 *
 * Lookup: the current surface is rotated by whole columns (3.75 deg) within
 * +-span of the believed heading and compared, point by point, with every
 * grid surface within the search radius of the believed position. The score
 * is the number of points that differ (bitxor + count of zero bytes, done
 * natively on strings). The best block, refined by the inverse-score
 * centroid of its best neighbours, is the fix; the column shift corrects the
 * heading. Accepted only when the best clearly beats the runner-up away
 * from it (distinctiveness), so a featureless view (open sky) is refused.
 */
::class Slam450VisualFix public
::attribute points get
::attribute cols get
::attribute rows get
::attribute cell get
::attribute altitude get

::method classOf class
  use strict arg ch
  select
    when ch=='.' then return 1
    when ch=='~' then return 2
    when ch=='G' | ch=='H' | ch=='K' then return 3
    when ch=='x' then return 4
    when ch=='o' then return 5
    when ch=='p' then return 6
    when ch=='d' then return 7
    when ch=='s' then return 8
    when ch=='b' then return 9
    when ch=='w' then return 10
    when ch=='c' then return 11
    when ch=='a' then return 12
    otherwise return 0
  end

::method surfaceOf class
  /* Frame -> feature string, one byte per point (value 0..12). */
  use strict arg frame,cols=96,rows=24,elTop=45,elBottom=.nil
  if elBottom==.nil then elBottom=-45
  numeric digits 12
  w=frame['WIDTH'];h=frame['HEIGHT'];pix=frame['PIXELS']
  /* v0.92b: only the band +45..-45 deg carries position (the land, the
     structures, the horizon); straight up is sky and straight down is
     whatever is under you. 24 rows over 90 deg = 3.75 deg, square with the
     3.75 deg columns. */
  yTop=(90-elTop)*h/180;yBot=(90-elBottom)*h/180
  bw=w/cols;bh=(yBot-yTop)/rows
  table=.directory~new
  out=''
  do r=0 to rows-1
    y0=trunc(yTop+r*bh)+1;y1=max(y0,trunc(yTop+(r+1)*bh))
    do c=0 to cols-1
      x0=trunc(c*bw)+1;x1=max(x0,trunc((c+1)*bw))
      cnt.=0;best=0;bestN=0
      do y=y0 to y1
        line=pix[y]~substr(x0,x1-x0+1)
        do i=1 to length(line)
          k=table[line~substr(i,1)]
          if k==.nil then do;k=self~classOf(line~substr(i,1));table[line~substr(i,1)]=k;end
          if k=0 then iterate
          cnt.k+=1
          if cnt.k>bestN then do;bestN=cnt.k;best=k;end
        end
      end
      out=out||d2c(best)
    end
  end
  return out

::method rotate class
  /* Shift every row right by k columns (k may be negative): heading change. */
  use strict arg s,k,cols=96,rows=24
  k=k//cols;if k<0 then k+=cols
  if k=0 then return s
  out=''
  do r=0 to rows-1
    row=s~substr(r*cols+1,cols)
    out=out||row~right(k)||row~left(cols-k)
  end
  return out

::method diff class
  /* Points that differ, unknown (0) in the query never counts. */
  use strict arg query,mask,candidate
  x=bitxor(query,candidate)
  x=bitand(x,mask)
  return length(x)-x~countStr('00'x)

::method init
  expose points cols rows cell altitude grid ground x0 y0
  use strict arg file
  letters=.false
  points=.array~new;grid=.directory~new;ground=.directory~new
  parse value linein(file) with magic cols rows cell altitude . cropText .
  parse var cropText x0 ',' . ',' y0 ',' .
  /* VISUALFIX2: one letter a..m per point (value 0..12), half the size of
     VISUALFIX (hex). Both are read. */
  letters=(magic=='VISUALFIX2')
  do while lines(file)>0
    parse value linein(file) with gx gy x y status gm hex
    ground[gx'.'gy]=gm
    if status\=='OK' then iterate
    d=.directory~new;d['GX']=gx;d['GY']=gy;d['X']=x;d['Y']=y;d['GROUND']=gm
    if letters then d['S']=hex~translate(xrange('00'x,'0C'x),'abcdefghijklm')
    else d['S']=x2c(hex)
    points~append(d);grid[gx'.'gy]=d
  end
  call stream file,'C','CLOSE'

::method lookup
  /* Returns a directory: X Y HEADING SCORE SECOND RATIO N ACCEPT. */
  expose points cols rows cell
  use strict arg surface,bx,by,bheading,radius=300,spanDeg=30,minRatio=1.15
  numeric digits 12
  /* mask: 'FF'x where the query knows the feature, '00'x where unknown */
  mask=surface~translate(copies('FF'x,15),xrange('01'x,'0F'x))
  /* grid surfaces face north; the craft's view at heading H matches one
     shifted right by H/3.75 columns, so search around the believed heading */
  span=trunc(spanDeg/(360/cols))
  kc=format(bheading/(360/cols),,0)
  rot.=''
  do k=kc-span to kc+span
    rot.k=self~class~rotate(surface,k,cols,rows)
    msk.k=self~class~rotate(mask,k,cols,rows)
  end
  scored=.array~new
  r2=radius*radius
  do p over points
    if (p['X']-bx)**2+(p['Y']-by)**2>r2 then iterate
    bestK=0;bestS=1e9
    do k=kc-span to kc+span
      sc=self~class~diff(rot.k,msk.k,p['S'])
      if sc<bestS then do;bestS=sc;bestK=k;end
    end
    scored~append(.array~of(bestS,bestK,p))
  end
  r=.directory~new;r['N']=scored~items;r['ACCEPT']=.false
  if scored~items<2 then return r
  /* best and the best that is not a neighbour of it (> 1.5 cells away) */
  best=scored[1];do s over scored;if s[1]<best[1] then best=s;end
  second=.nil
  do s over scored
    if (s[3]['X']-best[3]['X'])**2+(s[3]['Y']-best[3]['Y'])**2<=(1.5*cell)**2 then iterate
    if second==.nil then second=s
    else if s[1]<second[1] then second=s
  end
  /* refine: inverse-score centroid of the best block and its neighbours */
  sw=0;sx=0;sy=0
  do s over scored
    if (s[3]['X']-best[3]['X'])**2+(s[3]['Y']-best[3]['Y'])**2>(1.5*cell)**2 then iterate
    wgt=1/(1+s[1]-best[1])**2
    sw+=wgt;sx+=wgt*s[3]['X'];sy+=wgt*s[3]['Y']
  end
  r['X']=sx/sw;r['Y']=sy/sw;r['BLOCK_X']=best[3]['X'];r['BLOCK_Y']=best[3]['Y']
  hd=(best[2]*(360/cols))//360;if hd<0 then hd+=360
  r['HEADING']=hd
  r['SCORE']=best[1]
  r['SECOND']=-1;r['RATIO']=99
  if second\==.nil then do
    r['SECOND']=second[1]
    r['RATIO']=(second[1]+1)/(best[1]+1)
  end
  r['ACCEPT']=(r['RATIO']>=minRatio)
  return r

::method groundAt
  /* Precomputed ground height (m) of the block holding (x,y); 0 if unknown. */
  expose ground cell x0 y0
  use strict arg x,y
  k=trunc((x-x0)/cell)'.'trunc((y-y0)/cell)
  v=ground[k];if v==.nil then return 0
  return v

::method dataBytes
  /* Bytes held for lookup (raw 4-bit packing) - the precompute's size. */
  expose points cols rows
  return points~items*(cols*rows*4%8)

::class Slam450VisualFixSet public
/* Several height layers of the same grid (15 / 40 / 70 m). With the radio
 * altimeter ON the layer nearest the measured height is searched; with it
 * OFF every layer is searched and the best match wins (3x the comparisons). */
::attribute layers get
::method init
  expose layers
  use strict arg files
  layers=.array~new
  do f over files
    if stream(f,'C','QUERY EXISTS')\=='' then layers~append(.Slam450VisualFix~new(f))
  end
  if layers~items=0 then raise syntax 88.900 array('no visual-fix grid files found')
::method lookup
  expose layers
  use strict arg surface,bx,by,bheading,altAMSL=.nil,radius=300
  numeric digits 12
  best=.nil
  do L over layers
    if datatype(altAMSL,'N') then do
      near=.true
      do M over layers
        if abs(M~altitude-altAMSL)<abs(L~altitude-altAMSL) then near=.false
      end
      if \near then iterate
    end
    r=L~lookup(surface,bx,by,bheading,radius)
    if \r~hasIndex('SCORE') then iterate
    r['LAYER']=L~altitude
    if best==.nil then best=r
    else if r['SCORE']<best['SCORE'] then best=r
  end
  if best==.nil then do;best=.directory~new;best['ACCEPT']=.false;best['N']=0;end
  return best
::method groundAt
  expose layers
  use strict arg x,y
  return layers[1]~groundAt(x,y)
::method dataBytes
  expose layers
  t=0;do L over layers;t+=L~dataBytes;end
  return t
::method points
  expose layers
  t=0;do L over layers;t+=L~points~items;end
  return t

::class Slam450Landmarks public
/* Known tops of tall, distinctive structures, from the scene the grid was
 * built from (map knowledge, not truth about aircraft or targets):
 * Salesforce, Blues Point tower, Opera House, the four pylons, the arch. */
::attribute items get
::method init
  expose items
  use strict arg world
  numeric digits 16
  items=.array~new;archTop=.nil
  do box over world~scene~boxes
    n=box[1]~upper
    kind=''
    select
      when n~left(10)=='SALESFORCE' then kind='SALESFORCE'
      when n~left(5)=='BLUES' then kind='BLUES'
      when n~left(5)=='OPERA' then kind='OPERA'
      when n~left(5)=='PYLON' then kind='PYLON'
      when n~left(4)=='ARCH' then kind='ARCH'
      otherwise nop
    end
    if kind=='' then iterate
    top=-1e9;do v over box[2];top=max(top,v[3]);end
    sx=0;sy=0;k=0
    do v over box[2];if v[3]>=top-0.5 then do;sx+=v[1];sy+=v[2];k+=1;end;end
    d=.directory~new;d['NAME']=box[1];d['KIND']=kind;d['X']=sx/k;d['Y']=sy/k;d['TOP']=top
    d['CLASS']=.Slam450Camera~structureClass(box[1])
    if kind=='ARCH' then do
      if archTop==.nil then archTop=d
      else if top>archTop['TOP'] then archTop=d
      iterate
    end
    items~append(d)
  end
  if archTop\==.nil then items~append(archTop)

::method refine
  /* Altimeter ON: range to the nearest visible landmark top from its
   * elevation angle in a detail frame (960 x 242, 0.744 deg per row) and the
   * aircraft's own height above sea; bearing from the landmark's column.
   * Returns a directory (OK, X, Y, NAME, RANGE, EL) - OK .false if no
   * landmark top could be measured. */
  expose items
  use strict arg detail,estX,estY,heading,ownAMSL
  numeric digits 16
  W=detail['WIDTH'];H=detail['HEIGHT'];pix=detail['PIXELS']
  out=.directory~new;out['OK']=.false
  cand=.array~new
  do L over items
    dx=L['X']-estX;dy=L['Y']-estY;dist=RxCalcSqrt(dx*dx+dy*dy,16)
    if dist<30 | dist>1200 then iterate
    if L['TOP']-ownAMSL<5 then iterate
    cand~append(.array~of(dist,L))
  end
  /* nearest first */
  do i=2 to cand~items
    k=cand[i];j=i-1
    do while j>=1
      if cand[j][1]<=k[1] then leave
      cand[j+1]=cand[j];j=j-1
    end
    cand[j+1]=k
  end
  do c over cand
    L=c[2]
    dx=L['X']-estX;dy=L['Y']-estY
    if abs(dy)<1e-7 then b=90;else if dy>0 then b=RxCalcArcTan(dx/dy);else b=180+RxCalcArcTan(dx/dy)
    rel=b-heading+180;do while rel<0;rel+=360;end;do while rel>=360;rel-=360;end
    col=trunc(rel*W/360)+1
    /* topmost pixel of the landmark's class within +-12 columns */
    topY=0;sumX=0;nX=0
    do y=1 to H
      line=pix[y]
      lo=max(1,col-12);hi=min(W,col+12)
      seg=line~substr(lo,hi-lo+1)
      p=seg~pos(L['CLASS'])
      if p=0 then iterate
      topY=y
      do q=1 to length(seg);if seg~substr(q,1)==L['CLASS'] then do;sumX+=lo+q-1;nX+=1;end;end
      leave
    end
    if topY=0 then iterate
    el=90-(topY-0.5)*180/H
    if el<=0.3 then iterate
    range=(L['TOP']-ownAMSL)/RxCalcTan(el,16)
    mcol=sumX/nX
    brg=heading+(mcol-0.5)*360/W-180
    out['OK']=.true;out['NAME']=L['NAME'];out['RANGE']=range;out['EL']=el
    out['X']=L['X']-range*RxCalcSin(brg,16);out['Y']=L['Y']-range*RxCalcCos(brg,16)
    return out
  end
  return out
::requires 'Slam450Flight.cls'
