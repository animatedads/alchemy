/* Power SLAM v0.21: native foreground overdraw and sightline occlusion.
 * Architecture Tom Dyer. Implementation ChatGPT GPT-6, 2026-11-02.
 * Approach polyline endpoints from USER approximate control values.
 * NO SURVEYED DEM: lower masonry is a provisional visual occluder and
 * cannot be admitted as the actual approach retaining-wall profile.
 * Domain tunnel intentionally not modelled as visible elevated roadway.
 */
::requires 'SlamHarbourOperaWestWalk.cls'

/* Segment-plane clipping of 3D line against oriented cuboid.
   This is an actual spatial visibility test, not a screenshot colour test. */
::class HarbourRayOcclusion public
::method firstHit class
  use strict arg scene,cam,target,ignore=''
  best=1.0
  found=''
  do box over scene~boxes
    if ignore<>'' & box[1]==ignore then iterate
    t=self~hitSegment(box,cam,target)
    if t>=0 & t<best then do
      best=t; found=box[1]
    end
  end
  return found
::method hitSegment class
  use strict arg box,cam,target
  v=box[2]
  /* vertices 1=(-u,-v,base), 3=(+u,-v), 2=(-u,+v), 5=base+height */
  ax=v[3][1]-v[1][1];ay=v[3][2]-v[1][2]
  bx=v[2][1]-v[1][1];by=v[2][2]-v[1][2]
  la=HSqrt(ax*ax+ay*ay);lb=HSqrt(bx*bx+by*by)
  if la<0.001 | lb<0.001 then return -1
  ux=ax/la;uy=ay/la;vx=bx/lb;vy=by/lb
  cx=(v[1][1]+v[4][1])/2;cy=(v[1][2]+v[4][2])/2
  x0=cam[1]-cx;y0=cam[2]-cy
  tx=target[1]-cx;ty=target[2]-cy
  origin=.array~of(x0*ux+y0*uy,x0*vx+y0*vy,cam[3])
  finish=.array~of(tx*ux+ty*uy,tx*vx+ty*vy,target[3])
  lows=.array~of(-la/2,-lb/2,v[1][3])
  highs=.array~of(la/2,lb/2,v[5][3])
  enter=0;leave=1
  do j=1 to 3
    d=finish[j]-origin[j]
    if abs(d)<0.00000001 then do
      if origin[j]<lows[j] | origin[j]>highs[j] then return -1
    end
    else do
      t1=(lows[j]-origin[j])/d
      t2=(highs[j]-origin[j])/d
      enter=max(enter,min(t1,t2))
      leave=min(leave,max(t1,t2))
      if enter>leave then return -1
    end
  end
  if leave<=0 | enter>=0.99999 then return -1
  return enter

/* Render foreground in opaque far-to-near order rather than translucent
   overlay. Short segments reduce incorrect painter ordering for long ramps. */
::class HarbourOcclusionPanorama public subclass HarbourOperaWestWalk
::attribute approachSegments
::method init
  self~init:super
  self~sites['NORTH_PTZ']=.array~of('North-shore PTZ same-building hypothesis',-33.8487411,151.214266)
  /* v0.40: authoritative PowerSLAM catalogue, southeast roof corner. */
  blues=.HarbourBluesPointTower~catalogue
  camLat=blues['LAT']-blues['FOOTPRINT_ACROSS_M']/2/111200
  camLon=blues['LON']+blues['FOOTPRINT_ALONG_M']/2/92300
  self~sites['BLUES_PT']=.array~of('Blues Point southeast roof corner +2 m (model hypothesis)',camLat,camLon)
  self~approachSegments=0
::method siteCamera
  use strict arg key
  c=self~siteCamera:super(key)
  if key~upper=='NORTH_PTZ' then c[3]=79
  if key~upper=='BLUES_PT' then do
    scene=self~scene
    if scene~features~hasIndex('BPT_ROOF') then do
      roof=scene~features['BPT_ROOF']
      c[3]=roof[3]+2
    end
    else do
      blues=.HarbourBluesPointTower~catalogue
      c[3]=blues['STRUCTURAL_HEIGHT_M']+2
    end
  end
  return c
::method polygon
  use strict arg file,pts,w,fill,opacity
  self~polygon:super(file,pts,w,fill,1)
::method featureVisible
  use strict arg id,cam
  pt=self~scene~features[id]
  ignore=''
  /* A feature inside its own coarse building must not be called hidden by
     its own geometry, but other structures still have to occlude it. */
  if id=='O' then ignore='OPERA'
  if id=='T' then ignore='SALESFORCE'
  if id=='BPT_ROOF' then ignore='BLUES_POINT_TOWER'
  return .HarbourRayOcclusion~firstHit(self~scene,cam,pt,ignore)==''
::method addApproach
  /* Two user-controlled above-ground sections only: south bridge ->
     Rocks transition -> western Circular Quay station end. The eastern
     station deck already exists. The eastern Domain Tunnel, Woolloomooloo
     and north Milsons ground transition must NOT form a surface berm. */
  s=self~scene
  /* Upstream PowerSLAM v0.39 route: exact model-space segments from the
   * map-snapped expressway_route.words, joined to the relocated station. */
  originalW=s~features['STATION_W']
  path=.array~of(,
     .array~of(-34,-218,49),,
     .array~of(-481,-1022,19.5),,
     .array~of(originalW[1],originalW[2],16.5))
  segments=0
  do k=1 to path~items-1
    a=path[k];b=path[k+1]
    ap=.array~of(a[1],a[2]);bp=.array~of(b[1],b[2])
    dx=bp[1]-ap[1];dy=bp[2]-ap[2]
    dist=HSqrt(dx*dx+dy*dy)
    ux=dx/dist;uy=dy/dist;vx=0-uy;vy=ux
    count=max(2,trunc(dist/30)+1)
    do j=1 to count
      u1=(j-1)/count;u2=j/count
      mid=(u1+u2)/2
      x=ap[1]+mid*dx;y=ap[2]+mid*dy
      t=a[3]+mid*(b[3]-a[3])
      base=5.5
      /* approximate retaining/embankment mass beneath top pavement */
      s~boxes~append(s~cuboid('CAHILL_BERM',x,y,base,dist/count+0.30,20,t-2.5-base,ux,uy,vx,vy))
      s~boxes~append(s~cuboid('CAHILL_RAMP',x,y,t-2.5,dist/count+0.30,20,2.5,ux,uy,vx,vy))
      segments+=1
    end
  end
  self~approachSegments=segments
  m=.directory~new
  m['STATUS']='APPROACH_BERM_MAP_SNAPPED_UNSURVEYED_VISIBLE_OCCLUDER'
  m['ROUTE_SOURCE']='expressway_route.words by Claude Opus 5.5; map-derived'
  m['SEGMENTS']=segments
  m['BOXES_ADDED']=2*segments
  m['EASTERN_TUNNEL']='NOT_MODELLED_AS_SURFACE_BERM'
  m['WEST_RAMP_151205760']='UNLINKED_UNVERIFIED_LOCATION'
  return m
::method configure
  scene=self~scene
  roof=.HarbourBridgeRoofPins~apply(scene)
  bridge=.HarbourBridgeVertical~apply(scene)
  tower=.HarbourBluesPointTower~apply(scene,0)
  opera=self~orientOperaBox
  approach=self~addApproach
  return approach
