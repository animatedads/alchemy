/* Power SLAM v0.14: two additional webcam site pose approximations.
   Architecture: Tom Dyer. Implementation: GPT-6. The original user photo
   coordinates are manually measured, not surveyed landmarks. Do not accept
   any camera pose for metric ferry localisation without independent controls.
   The photo canvas has 1536x709 pixels including black sidebands.
   Requires native ooRexx r13196 and rxmath.
 */
::requires 'SlamHarbourPinCorrespondence.cls'
::class HarbourOtherCameraFit public subclass HarbourPerspectiveFit
::method init
  self~init:super
  f=.HarbourBridgeRoofPins~apply(self~model~scene)
  if f['STATUS'] \=='ROOF_PIN_LAYOUT_CONSISTENT_NOT_SURVEYED' then raise syntax 88.900 array('roof pin geometry not qualified')
::method score
  use strict arg cam,obs
  if cam[3]<10 | cam[3]>130 | cam[6]<250 | cam[6]>5000 then return 1e20
  total=0
  do item over obs
    pt=self~world(item[1])
    prediction=self~project(pt,cam,1536,709)
    if prediction==.nil then return 1e20
    dx=(prediction[1]-item[2])/item[4]
    dy=(prediction[2]-item[3])/item[4]
    total+=dx*dx+dy*dy
  end
  return total
::method observations
  use strict arg key,subset='BRIDGE'
  a=.array~new
  select
   when key=='BLUES_TOWER' then do
     a~append(.array~of('NW_ROOF_PIN',183,322,15))
     a~append(.array~of('SW_ROOF_PIN',674,324,15))
     a~append(.array~of('NW_DECK_PROXY',183,354,16))
     a~append(.array~of('SW_DECK_PROXY',674,355,16))
     if subset=='ALL' then do
       a~append(.array~of('ARCH_CROWN',419,273,18))
       a~append(.array~of('O',567,367,60))
       a~append(.array~of('T',1007,255,40))
     end
   end
   when key=='NORTH_SHORE' then do
     a~append(.array~of('NW_ROOF_PIN',1311,337,15))
     a~append(.array~of('NE_ROOF_PIN',1175,350,15))
     a~append(.array~of('NW_DECK_PROXY',1311,472,28))
     a~append(.array~of('NE_DECK_PROXY',1175,478,28))
     if subset=='ALL' then do
       a~append(.array~of('ARCH_CROWN',1005,283,20))
       a~append(.array~of('O',280,416,65))
       a~append(.array~of('T',651,258,40))
     end
   end
   otherwise raise syntax 88.900 array('unknown camera key')
  end
  return a
::method seed
  
  use strict arg key
  scene=self~model~scene
  if key=='BLUES_TOWER' then do
    xy=scene~local(-33.8490006,151.203533)
    return .array~of(xy[1],xy[2],70,150,-2,440)
  end
  if key=='NORTH_SHORE' then do
    xy=scene~local(-33.848849,151.213921)
    return .array~of(xy[1],xy[2],75,207,1,860)
  end
  raise syntax 88.900 array('unknown camera key')
::method limits
  use strict arg key
  p=self~seed(key)
  if key=='BLUES_TOWER' then do
    /* Publicly mapped tower centre, NOT a verified webcam on that building.
       +/-18m is an exploratory test, not a cadastral footprint. */
    lower=.array~of(p[1]-18,p[2]-18,25,100,-20,300)
    upper=.array~of(p[1]+18,p[2]+18,115,175,20,2200)
  end
  else do
    /* USER camera seed -33.848849,151.213921. +/-80m only for
       location exploration: not verified to be on land or within a roof. */
    lower=.array~of(p[1]-80,p[2]-80,20,175,-25,400)
    upper=.array~of(p[1]+80,p[2]+80,120,265,25,2400)
  end
  return .array~of(lower,upper)
::method fitSite
  use strict arg key,subset='BRIDGE',iterations=60
  a=self~observations(key,subset)
  p=self~seed(key)
  limits=self~limits(key); lower=limits[1];upper=limits[2]
  envelope=.HarbourCameraPolygon~new(.array~of(,
      .array~of(lower[1],lower[2]),,
      .array~of(upper[1],lower[2]),,
      .array~of(upper[1],upper[2]),,
      .array~of(lower[1],upper[2])),,
     'UNSURVEYED_CAMERA_SITE_SEARCH_ENVELOPE')
  best=1e20;bestP=.nil;trials=0
  do eastShift over .array~of(-12,0,12)
    do northShift over .array~of(-12,12)
      q=p~copy
      q[1]+=eastShift;q[2]+=northShift
      q[3]=p[3]
      result=self~polish(a,q,lower,upper,envelope,iterations)
      trials+=result[3]
      if result[1]<best then do
        best=result[1]; bestP=result[2]~copy
      end
    end
  end
  r=.directory~new
  r['POSE']=bestP
  r['CHI2']=best
  r['TRIALS']=trials
  r['SAMPLE_COUNT']=a~items
  r['SITE']=key
  r['TRAIN_SET']=subset
  r['STATUS']='PROVISIONAL_IMAGE_FIT_NOT_CAMERA_LOCATION'
  if bestP==.nil then r['STATUS']='BLOCKED_NO_SOLUTION'
  else do
    if bestP[1]-lower[1]<1 | upper[1]-bestP[1]<1 | bestP[2]-lower[2]<1 | upper[2]-bestP[2]<1 then r['STATUS']='BLOCKED_CAMERA_POSITION_BOUNDARY'
  end
  return r
::method holdouts
  use strict arg key,pose
  b=.directory~new
  if key=='BLUES_TOWER' then do
    b['ARCH_CROWN']=.array~of(419,273)
    b['OPERA']=.array~of(567,367)
    b['SALESFORCE']=.array~of(1007,255)
  end
  else do
    b['ARCH_CROWN']=.array~of(1005,283)
    b['OPERA']=.array~of(280,416)
    b['SALESFORCE']=.array~of(651,258)
  end
  arr=.array~new
  do id over .array~of('ARCH_CROWN','OPERA','SALESFORCE')
    landmark=id
    if id=='OPERA' then landmark='O'
    if id=='SALESFORCE' then landmark='T'
    p=self~project(self~world(landmark),pose,1536,709)
    if p==.nil then return .nil
    obs=b[id]
    diff=HSqrt((p[1]-obs[1])**2+(p[2]-obs[2])**2)
    arr~append(.array~of(id,diff,p[1],p[2],obs[1],obs[2]))
  end
  return arr
::method geodetic
  use strict arg pose
  return .array~of(-33.852+pose[2]/111200,151.210+pose[1]/92300)
::method activeWidth
  return 1260
::method activeHorizontalFov
  use strict arg focal
  return self~horizontalFov(focal,1260)
::method qualify
  use strict arg key,fit
  if fit['POSE']==.nil then return 'BLOCKED_NO_SOLUTION'
  p=fit['POSE'];h=self~holdouts(key,p)
  if h==.nil then return 'BLOCKED_HOLDOUT_BEHIND_CAMERA'
  do item over h
    if item[1]=='ARCH_CROWN' & item[2]>25 then return 'BLOCKED_ARCH_HOLDOUT'
  end
  /* Individual pylon roof pins and unknown actual camera building footprint
     mean that zero training error is never proof of real-world calibration. */
  return 'PROVISIONAL_GEOMETRY_NOT_SURVEYED'