/* Power SLAM harbour 360-degree geometry renderer. Architecture: Tom Dyer.
 * Implemented by ChatGPT GPT-6, 2026-11-01. Rendered graphics are generated
 * by ooRexx, not image-generation models. No inferred landscape features.
 * Longitude/latitude use HarbourScene's existing local tangent approximation.
 */
::requires 'SlamHarbourPose.cls'

::class HarbourPanorama public
::attribute scene
::attribute sites
::attribute renderLines
::method emit
  expose renderLines
  use strict arg text
  renderLines~append(text)
::method init
  expose scene sites
  scene=.HarbourScene~new
  sites=.directory~new
  sites['KIRRIBILLI']=.array~of('Kirribilli House',-33.851286,151.21915)
  sites['CIRCULAR']=.array~of('Circular Quay / Customs House',-33.862128338141,151.21083913743)
  sites['BLUES']=.array~of('Blues Point Reserve',-33.84973,151.20383)
  /* Deliberately coarse cuboid footprint; only lat/lon/height grounded.
     Source-centre: 180 George Street mapped OSM; 263 m from user.
     The footprint width 45 m is an UNSURVEYED renderer parameter. */
  t=scene~local(-33.862337,151.20865)
  scene~boxes~append(scene~cuboid('SALESFORCE',t[1],t[2],0,45,45,263,1,0,0,1))
  scene~features['T']=.array~of(t[1],t[2],263)
  
::method siteCamera
  expose scene sites
  use strict arg key
  if \sites~hasIndex(key~upper) then raise syntax 88.900 array('unknown viewpoint')
  s=sites[key~upper]
  local=scene~local(s[2],s[3])
  return .array~of(local[1],local[2],50)

/* Bearings clockwise from true north; x east, y north, degrees [0,360). */
::method bearing
  use strict arg dx,dy
  if dx=0 & dy=0 then raise syntax 88.900 array('bearing for co-located point')
  if dy>0 then a=RxCalcArcTan(dx/dy)
  else if dy<0 then a=180+RxCalcArcTan(dx/dy)
  else if dx>0 then a=90
  else a=270
  if a<0 then a+=360
  if a>=360 then a-=360
  return a
::method pointAngles
  use strict arg pt,cam
  dx=pt[1]-cam[1];dy=pt[2]-cam[2];dz=pt[3]-cam[3]
  ground=HSqrt(dx*dx+dy*dy)
  if ground<0.001 then raise syntax 88.900 array('singular vertical observation')
  b=self~bearing(dx,dy)
  e=RxCalcArcTan(dz/ground)
  return .array~of(b,e,ground)
::method project
  use strict arg pt,cam,w,h,top=55,bottom=(0-35)
  if top<=bottom then raise syntax 88.900 array('invalid vertical range')
  a=self~pointAngles(pt,cam)
  return .array~of(a[1]*w/360,(top-a[2])*h/(top-bottom),a[3],a[1],a[2])

/* Draw a closed face with wrap at 0/360. Non-topological outside-map geometry
   is not added; only surfaces built from the authoritative simple cuboids. */
::method polygon
  use strict arg file,pts,w,fill,opacity
  lo=1e30;hi=-1e30
  do p over pts
    lo=min(lo,p[1]);hi=max(hi,p[1])
  end
  line=''
  do p over pts
    x=p[1]
    if hi-lo>w/2 & x<w/2 then x+=w
    line=line || ' ' || x || ',' || p[2]
  end
  do shift over .array~of(-w,0,w)
    translated=''
    do j=1 to line~words
      pair=line~word(j)
      parse var pair xx ',' yy
      translated=translated || ' ' || (xx+shift) || ',' || yy
    end
    self~emit('<polygon points="' || translated || '" fill="' || fill || '" fill-opacity="' || opacity || '" stroke="#334155" stroke-width="1.3" stroke-linejoin="round"/>')
  end

::method featureVisible
  use strict arg id,cam
  return .true

::method render
  expose scene sites renderLines
  use strict arg key,file,w=2880,h=720
  key=key~upper
  if \sites~hasIndex(key) then raise syntax 88.900 array('unknown viewpoint')
  cam=self~siteCamera(key)
  site=sites[key]
  renderLines=.array~new
  call SysFileDelete file
  self~emit('<svg xmlns="http://www.w3.org/2000/svg" width="' w '" height="' h '" viewBox="0 0' w h '">')
  self~emit('<rect x="0" y="0" width="' w '" height="' h '" fill="#f7fafc"/>')
  self~emit('<text x="18" y="30" font-size="23" font-family="DejaVu Sans" font-weight="bold" fill="#1e293b">Power SLAM |' site[1] '|' cam[3] 'm ASL | full 360° bearing sweep</text>')
  self~emit('<text x="18" y="56" font-size="16" font-family="DejaVu Sans" fill="#64748b">Projected from model cuboids, not a photograph. Empty sectors have no encoded geometry. Vertical range +55° to -35°.</text>')
  /* Altitude grid, level sight line; no invented shoreline or terrain. */
  do ang=-30 to 50 by 10
    yy=(55-ang)*h/90
    if ang=0 then do
      color='#b35b41';size=2
    end
    else do
      color='#d7dee5';size=1
    end
    self~emit('<line x1="0" y1="' yy '" x2="' w '" y2="' yy '" stroke="' color '" stroke-width="' size '"/>')
    self~emit('<text x="8" y="' yy-5 '" font-size="12" font-family="monospace" fill="#7b8794">' ang '°</text>')
  end
  do az=0 to 330 by 30
    xx=az*w/360
    self~emit('<line x1="' xx '" y1="0" x2="' xx '" y2="' h '" stroke="#b8c4d1" stroke-width="1" stroke-dasharray="4,5"/>')
    self~emit('<text x="' xx+9 '" y="' h-17 '" font-size="16" font-family="monospace" fill="#334155">' az '°</text>')
  end

  /* Sort faces far-to-near. Cuboids belong exclusively to HarbourScene boxes. */
  faces=.array~new
  do box over scene~boxes
    name=box[1]
    vert=box[2]
    color='#9ca3af'
    if name=='DECK' then color='#475569'
    if name=='OPERA' then color='#f6f4dc'
    if name=='SALESFORCE' then color='#3b82ae'
    if name=='BLUES_POINT_TOWER' then color='#7c3aed'
    if name~left(2)=='CQ' then color='#0d9488'
    if name~left(2)=='WB' then color='#bc8c57'
    if name=='CQ_STATION' then color='#8c9aab'
    if name=='CAHILL' then color='#c65e44'
    if name=='CAHILL_BERM' then color='#ad9379'
    if name=='CAHILL_RAMP' then color='#5e666e'
    do ftxt over .array~of('1 2 4 3','5 6 8 7','1 2 6 5','3 4 8 7','1 3 7 5','2 4 8 6')
      vertices=.array~new;projections=.array~new
      sx=0;sy=0
      do i=1 to 4
        ix=ftxt~word(i)
        v=vert[ix]
        vertices~append(v)
        sx+=v[1];sy+=v[2]
        projections~append(self~project(v,cam,w,h))
      end
      dist=(sx/4-cam[1])**2+(sy/4-cam[2])**2
      faces~append(.array~of(dist,projections,color,name))
    end
  end
  /* max 42 faces; insertion sorting is deterministic without OS dependencies. */
  sorted=.array~new
  do f over faces
    inserted=.false
    do i=1 to sorted~items
      if f[1]>sorted[i][1] then do
        if i=1 then sorted~insert(f,.nil)
        else sorted~insert(f,i-1)
        inserted=.true;leave
      end
    end
    if \inserted then sorted~append(f)
  end
  do f over sorted
    self~polygon(file,f[2],w,f[3],0.72)
  end
  /* Landmark annotations are derived by projecting the coordinates, not guesses. */
  do id over .array~of('N','S','O','T','BPT_ROOF')
    if \scene~features~hasIndex(id) then iterate
    if \self~featureVisible(id,cam) then iterate
    p=scene~features[id]
    xyz=.array~of(p[1],p[2],p[3])
    projected=self~project(xyz,cam,w,h)
    name=id
    if id=='N' then name='Bridge N'
    if id=='S' then name='Bridge S'
    if id=='O' then name='Opera box'
    if id=='T' then name='Salesforce 263m'
    if id=='BPT_ROOF' then name='Blues Point Tower'
    x=projected[1];y=projected[2]
    if y<70 then y=70
    if y>h-45 then y=h-45
    if x>w-190 then x=w-190
    self~emit('<circle cx="' projected[1] '" cy="' projected[2] '" r="5" fill="#b45309" stroke="white" stroke-width="1.4"/>')
    self~emit('<text x="' x+10 '" y="' y-10 '" font-size="17" font-family="DejaVu Sans" font-weight="bold" fill="#7c2d12">' name '</text>')
  end
  /* Optional wharf annotations are projected from the same feature vectors.
   * Labels are not estimates of image pixels; they are renderer output. */
  do id over scene~features~allIndexes~sort
    if id~left(2)\=='CQ' & id~left(2)\=='WB' then iterate
    if \self~featureVisible(id,cam) then iterate
    pt=scene~features[id]
    xy=self~project(pt,cam,w,h)
    xx=xy[1]; yy=xy[2]
    if yy<80 then yy=80
    if yy>h-34 then yy=h-34
    self~emit('<circle cx="' xy[1] '" cy="' xy[2] '" r="3" fill="#0f766e"/>')
    self~emit('<text x="' xx+5 '" y="' yy-8 '" font-size="11" font-family="DejaVu Sans" fill="#075985">' id '</text>')
  end
  /* Rail/Cahill endpoints are additional 3D fixed references only if loaded. */
  do id over .array~of('STATION_W','STATION_E','STATION_C','CAHILL_C')
    if \scene~features~hasIndex(id) then iterate
    if \self~featureVisible(id,cam) then iterate
    xyz=scene~features[id]
    xy=self~project(xyz,cam,w,h)
    self~emit('<circle cx="' xy[1] '" cy="' xy[2] '" r="4" fill="#be3f33"/>')
    self~emit('<text x="' xy[1]+7 '" y="' xy[2]-7 '" font-size="13" font-family="monospace" fill="#be3f33">' id '</text>')
  end
  /* Versioned optional registered high-rise reference. No fictional skyline. */
  if scene~features~hasIndex('BPT_ROOF') then do
    xy=self~project(scene~features['BPT_ROOF'],cam,w,h)
    labelX=xy[1]+10; labelY=xy[2]-12
    if labelX>w-240 then labelX=w-240
    if labelY<70 then labelY=70
    self~emit('<circle cx="' xy[1] '" cy="' xy[2] '" r="5" fill="#7c3aed" stroke="white" stroke-width="1.4"/>')
    self~emit('<text x="' labelX '" y="' labelY '" font-size="18" font-family="DejaVu Sans" font-weight="bold" fill="#6d28d9">Blues Point Tower 83m AGL</text>')
  end
  self~emit('<rect x="0" y="' h-11 '" width="' w '" height="11" fill="#cbd5e1"/>')
  self~emit('</svg>')
  do text over renderLines
    call lineout file,text
  end
  call stream file,'C','CLOSE'
  return cam
