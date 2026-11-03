/* SLAM450 v0.90 — static plan map for LLM pilots and navigators.
 * Architecture: Tom Dyer (map spec, 2026-11-03). Implementation: Claude (Opus 5.5).
 *
 * A top-down scaffold for reasoning, deliberately limited:
 *   - cropped to the fixed LEGACY race region (x 100..460 E, y -880..-340 N),
 *     the SAME crop and scale for every seed, so it carries no information
 *     about where this race's targets are;
 *   - north-up, 1.5 px per metre (540 x 810 px), unlabelled;
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
  x0=100;x1=460;y0=-880;y1=-340;scale=1.5
  width=trunc((x1-x0)*scale);height=trunc((y1-y0)*scale)
  rows=.array~new(height)
  do r=1 to height;rows[r]='~'~copies(width);end
  low=.array~new;tall=.array~new
  do b over world~scene~boxes
    zTop=-1e9
    do v over b[2];zTop=max(zTop,v[3]);end
    hull=self~hull(b[2])
    if zTop<=12 then low~append(hull)
    else tall~append(hull)
  end
  do h over low;self~fill(h,'L');end
  do h over tall;self~fill(h,'x');end
  /* 50 m scale bar, bottom-left, 3 px thick with end ticks. */
  len=trunc(50*scale);bx=20;barY=height-24
  do r=barY to barY+2;self~hline(r,bx,bx+len-1,'C');end
  do r=barY-6 to barY+2;self~hline(r,bx,bx+1,'C');self~hline(r,bx+len-2,bx+len-1,'C');end
  /* North arrow, top-right: a solid up-pointing triangle on a stem. */
  ax=width-30;ay=16
  do k=0 to 13;self~hline(ay+k,ax-trunc(k/2),ax+trunc(k/2),'C');end
  do r=ay+14 to ay+34;self~hline(r,ax-1,ax+1,'C');end
::method palette class
  p=.directory~new
  p['~']='51 126 173';p['L']='150 152 140';p['x']='88 90 98';p['C']='251 249 227'
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
::method briefingText class
  return 'MAP (first image in every message): a fixed north-up plan of the race area, 540x810 px at 1.5 px per metre'||,
    ' (the whole image is 360 m wide, 540 m tall). Blue = water; light grey = land, quays and low structures;'||,
    ' dark grey = taller structures (buildings, bridge, tower); white bar bottom-left = 50 m; white arrow points north.'||,
    ' Nothing that moves is drawn and you are not marked: work out where you are from what you see.'||'0a'x
::requires 'IndexedPngEncoder.cls'
