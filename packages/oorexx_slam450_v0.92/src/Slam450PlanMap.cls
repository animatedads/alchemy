/* SLAM450 v0.90 — static plan map for LLM pilots and navigators.
 * Architecture: Tom Dyer (map spec, 2026-11-03). Implementation: Claude (Opus 5.5).
 *
 * A top-down scaffold for reasoning, deliberately limited:
 *   - cropped to the course's fixed race region: LEGACY x 100..460 E,
 *     y -880..-340 N (540 x 810 px); QUAYSIDE (v0.91) its field + 60 m,
 *     x -230..270, y -1250..-750 (750 x 750 px). The SAME crop and scale for
 *     every seed, so it carries no information about this race's targets;
 *   - north-up, 1.5 px per metre, unlabelled;
 *   - water, low land/quays/berms (top <= 12 m), taller structures
 *     (buildings, bridge, tower: top > 12 m) as cuboid footprints;
 *   - a 50 m scale bar (bottom-left) and a north arrow (top-right);
 *   - NO start marker, NO "you are here", nothing that moves, no truth.
 * Footprints are the xy convex hull of each PowerSLAM oriented cuboid,
 * scanline-filled (cost proportional to area, not pixels x solids).
 */
::class Slam450PlanMap public
::attribute rows get
::attribute width get
::attribute height get
::method init
  expose rows width height x0 y1 scale
  use strict arg world
  numeric digits 16
  c=self~class~crop(world);x0=c[1];x1=c[2];y0=c[3];y1=c[4];scale=c[5]
  width=trunc((x1-x0)*scale);height=trunc((y1-y0)*scale)
  rows=.array~new(height)
  do r=1 to height;rows[r]='~'~copies(width);end
  /* v0.91: real land from the Power SLAM v0.40 water grid, one 50 m
   * cell at a time (parallelogram in scene coordinates), under the
   * structures. X / nodata cells are left as unmarked background. */
  if world~ground\==.nil then do
    r=world~ground~rasterLocal
    o=r['ORIGIN'];cv=r['COL_VECTOR'];rv=r['ROW_VECTOR'];kinds=r['KINDS'];nc=r['COLUMNS'];hts=r['HEIGHTS']
    do row=1 to r['ROWS']
      do col=1 to nc
        if kinds[(row-1)*nc+col]\=1 then iterate
        cx=o[1]+(col-1)*cv[1]+(row-1)*rv[1];cy=o[2]+(col-1)*cv[2]+(row-1)*rv[2]
        if cx<x0-60 | cx>x1+60 | cy<y0-60 | cy>y1+60 then iterate
        poly=.array~new
        do s over .array~of(.array~of(-0.5,-0.5),.array~of(0.5,-0.5),.array~of(0.5,0.5),.array~of(-0.5,0.5))
          poly~append(.array~of(cx+s[1]*cv[1]+s[2]*rv[1],cy+s[1]*cv[2]+s[2]*rv[2]))
        end
        /* v0.92 relief bands (AHD): G < 15 m, H 15-30 m, K > 30 m. On the
         * HILL course the terrain is the obstacle; land without relief
         * would misrepresent it. Unlabelled, as the rest of the map. */
        hv=hts[(row-1)*nc+col];band='G'
        if hv>=15 then band='H'
        if hv>=30 then band='K'
        self~fill(poly,band)
      end
    end
  end
  low=.array~new;tall=.array~new
  do b over world~scene~boxes
    zTop=-1e9
    do v over b[2];zTop=max(zTop,v[3]);end
    hull=self~hull(b[2]);cls=.Slam450Camera~structureClass(b[1])
    if zTop<=12 then low~append(.array~of(hull,cls))
    else tall~append(.array~of(hull,cls))
  end
  /* v0.92: structures in the same class colours as the pilots' panorama,
   * low ones first so taller ones stay on top. */
  do h over low;self~fill(h[1],h[2]);end
  do h over tall;self~fill(h[1],h[2]);end
  /* 50 m scale bar, bottom-left, 3 px thick with end ticks. */
  bar=50;if scale<1 then bar=100
  len=trunc(bar*scale);bx=20;barY=height-24
  do r=barY to barY+2;self~hline(r,bx,bx+len-1,'C');end
  do r=barY-6 to barY+2;self~hline(r,bx,bx+1,'C');self~hline(r,bx+len-2,bx+len-1,'C');end
  /* North arrow, top-right: a solid up-pointing triangle on a stem. */
  ax=width-30;ay=16
  do k=0 to 13;self~hline(ay+k,ax-trunc(k/2),ax+trunc(k/2),'C');end
  do r=ay+14 to ay+34;self~hline(r,ax-1,ax+1,'C');end
::method crop class
  /* (x0,x1,y0,y1,scale): LEGACY fixed crop; a fixed-field course is its
   * field + 60 m. Shared by the map and the GPS (v0.92). */
  use strict arg world
  x0=100;x1=460;y0=-880;y1=-340
  if world~fieldBox\==.nil then do
    f=world~fieldBox;x0=f[1]-60;x1=f[2]+60;y0=f[3]-60;y1=f[4]+60
  end
  /* v0.92: a field over 700 m on a side (HARBOUR) is drawn at 0.75 px/m so
     the map stays near 800 x 1200 px (the API scales larger images down;
     a smaller exact scale keeps pixel arithmetic honest and costs fewer
     image tokens per call). */
  sc=1.5;if max(x1-x0,y1-y0)>700 then sc=0.75
  return .array~of(x0,x1,y0,y1,sc)
::method palette class
  p=.directory~new
  p['~']='51 126 173';p['L']='150 152 140';p['x']='88 90 98';p['C']='251 249 227';p['G']='169 180 143';p['H']='140 152 110';p['K']='110 120 84'
  sp=.Slam450Camera~palette;do k over sp~allIndexes;p[k]=sp[k];end
  return p
::method hull private
  /* Andrew's monotone chain on the xy projection of the cuboid vertices. */
  use strict arg verts
  numeric digits 16
  pts=.array~new
  do v over verts;pts~append(.array~of(v[1],v[2]));end
  /* insertion sort by x then y (8 points) */
  do i=2 to pts~items
    k=pts[i];j=i-1
    do while j>=1
      if pts[j][1]<k[1] then leave
      if pts[j][1]=k[1] & pts[j][2]<=k[2] then leave
      pts[j+1]=pts[j];j-=1
    end
    pts[j+1]=k
  end
  lower=.array~new;upper=.array~new
  do p over pts
    do while lower~items>=2
      if self~cross(lower[lower~items-1],lower[lower~items],p)>0 then leave
      lower~delete(lower~items)
    end
    lower~append(p)
  end
  do i=pts~items to 1 by -1
    p=pts[i]
    do while upper~items>=2
      if self~cross(upper[upper~items-1],upper[upper~items],p)>0 then leave
      upper~delete(upper~items)
    end
    upper~append(p)
  end
  lower~delete(lower~items);upper~delete(upper~items)
  do p over upper;lower~append(p);end
  return lower
::method cross private
  use strict arg o,a,b
  numeric digits 16
  return (a[1]-o[1])*(b[2]-o[2])-(a[2]-o[2])*(b[1]-o[1])
::method fill private
  /* Scanline fill of a convex polygon given in world metres. */
  expose rows width height x0 y1 scale
  use strict arg poly,ch
  numeric digits 16
  if poly~items<3 then return
  ylo=1e9;yhi=-1e9
  do p over poly;ylo=min(ylo,p[2]);yhi=max(yhi,p[2]);end
  rTop=max(1,trunc((y1-yhi)*scale)+1);rBot=min(height,trunc((y1-ylo)*scale)+1)
  do r=rTop to rBot
    y=y1-(r-0.5)/scale
    xl=1e9;xr=-1e9
    do i=1 to poly~items
      a=poly[i];b=poly[i//poly~items+1]
      if (a[2]<=y & b[2]>y) | (b[2]<=y & a[2]>y) then do
        x=a[1]+(y-a[2])*(b[1]-a[1])/(b[2]-a[2])
        xl=min(xl,x);xr=max(xr,x)
      end
    end
    if xl>xr then iterate
    c1=max(1,trunc((xl-x0)*scale+0.5)+1);c2=min(width,trunc((xr-x0)*scale-0.5)+1)
    if c2>=c1 then self~hline(r,c1,c2,ch)
  end
::method hline private
  expose rows width height
  use strict arg r,c1,c2,ch
  if r<1 | r>height then return
  c1=max(1,c1);c2=min(width,c2)
  if c2<c1 then return
  rows[r]=overlay(ch~copies(c2-c1+1),rows[r],c1)
::method pngBase64
  /* Encoded with the estate's IndexedPngEncoder (oorexx_compress). */
  expose rows
  use strict arg provider=.nil
  return (.IndexedPngEncoder~new(self~class~palette,1,provider))~encodeBase64(rows)
::method landNote class
  if .local['SLAM450.GROUND']\=='GROUND' then return ''
  return ' green-grey = land, three shades by height: lightest under 15 m, middle 15-30 m, darkest over 30 m above sea;'
::method briefingText class
  use strict arg w=540,h=810,sc=1.5
  bar=50;if sc<1 then bar=100
  return 'MAP (first image in every message): a fixed north-up plan of the race area,' w'x'h 'px at' sc 'px per metre'||,
    ' (the whole image is' format(w/sc,,0) 'm wide,' format(h/sc,,0) 'm tall). Blue = water;'||self~landNote||,
    ' structure footprints in the same colours as your panorama: sandstone cream = Opera House, tan = bridge pylons/abutments,'||,
    ' dark slate = bridge deck, teal = Salesforce tower, periwinkle = Blues Point tower, grey-lavender = wharves,'||,
    ' burnt clay = Cahill expressway/station/berm, steel = bridge arch and hangers; white bar bottom-left =' bar 'm; white arrow points north.'||,
    ' Nothing that moves is drawn and you are not marked: work out where you are from what you see.'||'0a'x
::requires 'IndexedPngEncoder.cls'
::requires 'Slam450Flight.cls'
