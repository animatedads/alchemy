/* F11 six-state / bidirectional vehicle acoustic experiment.
   Physics calculations are ooRexx.  CSV is deliberately simple for Codex orchestration. */
numeric digits 20
ctx=.Maths~defaultContext
freq=.array~of(125,1000,4000)
wood=.AcousticBuildingMaterialFactory~solidWoodDoor(freq)
block=.AcousticBuildingMaterialFactory~breezeBlockWall(freq)
world=.PhysicalWorld~new(.OpticalMedium~air,.AcousticMedium~air)
medium=world~ambientAcoustic

/* Metric authority: f11_f12_proportion_geometry_v0.1.json, FC-FD = 9.43 m.
   Vertical authority: road 0 m, property floor 3 m, ceiling 5.2 m, microphones/source 4.8 m. */
fc=.MathVector3~new('14.267033994546255','9.448930628846266','4.8',ctx)
fd=.MathVector3~new('7.014341295648039','3.4220451466632427','4.8',ctx)
if abs((fc-fd)~norm-'9.43')>'0.000001' then do;say 'FAIL FC-FD metric authority';exit 2;end

/* Plan conversion authority derived from the geometry JSON calibration. */
scale='0.017025100232155435'; xOriginPx=75; yOriginPx=145
/* The road/frontage track follows the plan front in +X.  y=746 px is the supplied front-E line. */
roadY=(746-yOriginPx)*scale

/* Authoritative internal vertical interval: 2.2 m floor-to-ceiling.
   Floor is z=3.0 m above road, therefore ceiling/wall top is z=5.2 m.
   Ceiling reflection material is intentionally NOT invented; only its geometry is now authoritative. */
wallBottom=3.0; ceilingZ=5.2; wallTop=ceilingZ
if abs((wallTop-wallBottom)-2.2)>0.000001 then do;say 'FAIL F11 floor-to-ceiling authority';exit 2;end
if abs(fc~z-4.8)>0.000001 | abs(fd~z-4.8)>0.000001 then do;say 'FAIL F11 microphone elevation authority';exit 2;end
if fc~z>=ceilingZ | fd~z>=ceilingZ then do;say 'FAIL microphones must be below ceiling';exit 2;end
base=.AcousticImpulseResponseSolver~new(world)

/* Authoritative proportion-coded room boundaries. Duplicate coincident boundaries are harmless
   for reflection topology but are added only once here by named segment. */
call panelPx base,'A-top',142,161,383,161,block,ctx,scale,xOriginPx,yOriginPx,wallBottom,wallTop
call panelPx base,'A-left',142,161,142,370,block,ctx,scale,xOriginPx,yOriginPx,wallBottom,wallTop
call panelPx base,'A-right',383,161,383,370,block,ctx,scale,xOriginPx,yOriginPx,wallBottom,wallTop
call panelPx base,'A-bottom',142,370,383,370,block,ctx,scale,xOriginPx,yOriginPx,wallBottom,wallTop
call roomRect base,'E',76,371,280,699,block,ctx,scale,xOriginPx,yOriginPx,wallBottom,wallTop
call roomRect base,'F',294,371,495,699,block,ctx,scale,xOriginPx,yOriginPx,wallBottom,wallTop
call roomRect base,'B',510,176,725,699,block,ctx,scale,xOriginPx,yOriginPx,wallBottom,wallTop
call roomRect base,'C',744,161,960,371,block,ctx,scale,xOriginPx,yOriginPx,wallBottom,wallTop
call roomRect base,'D',976,161,1230,371,block,ctx,scale,xOriginPx,yOriginPx,wallBottom,wallTop
call roomRect base,'G',744,458,921,699,block,ctx,scale,xOriginPx,yOriginPx,wallBottom,wallTop
call roomRect base,'H',1078,382,1217,517,block,ctx,scale,xOriginPx,yOriginPx,wallBottom,wallTop
call roomRect base,'I',1001,516,1250,766,block,ctx,scale,xOriginPx,yOriginPx,wallBottom,wallTop
call roomRect base,'Stairs',398,145,486,371,block,ctx,scale,xOriginPx,yOriginPx,wallBottom,wallTop
rearSurfaceCount=.F11RearExteriorGeometry~addToSolver(base,block,materialFreq,ctx)

/* Corrected explicit doors. There is intentionally no A_to_stairs door. */
call panelPx base,'door-A_to_F',383,327,383,366,wood,ctx,scale,xOriginPx,yOriginPx,wallBottom,wallTop
call panelPx base,'door-E_to_F',280,503,294,538,wood,ctx,scale,xOriginPx,yOriginPx,wallBottom,wallTop
call panelPx base,'door-FD_to_stairwell',398,328,461,371,wood,ctx,scale,xOriginPx,yOriginPx,wallBottom,wallTop

receivers=.directory~new;receivers['FC']=fc;receivers['FD']=fd
vehicleSpectrum=.AcousticVehicleNoiseSpectrum~new(78)
vehicleEmission=vehicleSpectrum~emissionSpectrum(medium)

/* Continuous 40 km/h road traversal, sampled as the same vehicle centre crosses five fixed points.
   LTR starts at x=-4; RTL starts at x=20.  The car is NOT teleported between states. */
carXs=.array~of(-4,2,8,14,20)
speed='11.111111111111111'
gridMaxX=value('F11_GRID_MAX_X',,'ENVIRONMENT');if gridMaxX='' then gridMaxX=20
gridMaxY=value('F11_GRID_MAX_Y',,'ENVIRONMENT');if gridMaxY='' then gridMaxY=10
stateCount=value('F11_CAR_STATES',,'ENVIRONMENT');if stateCount='' then stateCount=5

outDir='.'
parse arg outDir
if outDir='' then outDir='.'
call SysMkDir outDir
summary=outDir'/f11_vehicle_summary.csv'; paths=outDir'/f11_vehicle_paths.csv'
call lineout summary,'scenario,source_x,source_y,car_state,car_direction,sample_time_s,car_x,car_y,receiver,noise_first_ms,noise_band125_db,noise_band1000_db,noise_band4000_db,noise_total_db,car_first_ms,car_band125_db,car_band1000_db,car_band4000_db,car_total_db,car_obs125_hz,car_obs1000_hz,car_obs4000_hz,noise_fd_minus_fc_ms'
call lineout paths,'scenario,source_x,source_y,car_state,car_direction,sample_time_s,receiver,path_kind,path_evidence,path_distance_m,path_delay_ms,freq_hz,path_spl_db,observed_hz'

/* 1/2: no stationary noise + car right-to-left / left-to-right. */
do direction over .array~of('RTL','LTR')
  do state=1 to stateCount
    if direction='RTL' then targetX=carXs[6-state];else targetX=carXs[state]
    call runCase 'CAR_ONLY_'direction,.nil,.nil,state,direction,targetX,roadY,base,world,receivers,vehicleEmission,vehicleSpectrum,speed,summary,paths,ctx,freq
  end
end

/* 3: stationary noise at every 1 m grid point, no car.
   Grid covers the proportion-coded property bounding box; points are intentionally not pre-labelled by room. */
do y=0 to gridMaxY
  do x=0 to gridMaxX
    source=.MathVector3~new(x,y,4.8,ctx)
    call runCase 'NOISE_NO_CAR',source,.nil,0,'NONE',0,roadY,base,world,receivers,vehicleEmission,vehicleSpectrum,speed,summary,paths,ctx,freq
  end
end

/* 4/5: same stationary source grid + five moving-car snapshots in both directions. */
do direction over .array~of('RTL','LTR')
  do y=0 to gridMaxY
    do x=0 to gridMaxX
      source=.MathVector3~new(x,y,4.8,ctx)
      do state=1 to stateCount
        if direction='RTL' then targetX=carXs[6-state];else targetX=carXs[state]
        call runCase 'NOISE_PLUS_CAR_'direction,source,.true,state,direction,targetX,roadY,base,world,receivers,vehicleEmission,vehicleSpectrum,speed,summary,paths,ctx,freq
      end
    end
  end
end
call lineout summary
call lineout paths
say 'PASS F11 vehicle experiment'
say 'summary='summary
say 'paths='paths
exit 0

runCase: procedure
  use arg scenario,source,includeCarReflection,state,direction,carX,roadY,base,world,receivers,vehicleEmission,vehicleSpectrum,speed,summary,paths,ctx,freq
  medium=world~ambientAcoustic
  if direction='RTL' then do;vx=-speed;startX=20;end
  else if direction='LTR' then do;vx=speed;startX=-4;end
  else do;vx=0;startX=carX;end
  carOrigin=.MathVector3~new(startX,roadY,0,ctx); vel=.MathVector3~new(vx,0,0,ctx)
  car=.AcousticMovingVehicle~new('vehicle',carOrigin,vel,4,1.5,0.5)
  if state>0 then sampleTime=car~timeAtX(carX);else sampleTime=0
  if sampleTime<-'0.000000001' then do;say 'FAIL vehicle sample precedes trajectory start' direction state carX sampleTime;exit 2;end
  carCenter=car~centerAt(sampleTime)
  if abs(carCenter~x-carX)>'0.000001' then do;say 'FAIL continuous vehicle crossing' direction state carX carCenter~x;exit 2;end
  solver=.AcousticImpulseResponseSolver~new(world)
  do s over base~surfaces;solver~addSurface(s);end
  if state>0 & includeCarReflection<>.nil then do
    /* Vehicle material is deliberately explicit test evidence: rigid reflector at test bands.
       No unsupported real-car absorption coefficient is invented. */
    rigid=.AcousticSpectralMaterial~rigid(freq)
    carSurface=.AcousticSpectralSurface~new('MOVING_VEHICLE',car~roadSidePanelAt(sampleTime),rigid)
    solver~addSurface(carSurface)
    /* The 1.5 m-high side cannot create a mirror-specular path between two
       4.8 m points. A real car is finite/curved and scatters sound, so register
       the explicitly requested moving body as a bounded diffuse reflector too.
       Rigid/scatterPressure=1 is an upper-bound test assumption, not a claim
       about production-car absorption. */
    solver~addDiffuseReflector(.AcousticDiffuseReflector~new('MOVING_VEHICLE',carSurface,car~length*car~height,1))
  end

  noiseResult=.nil
  if source<>.nil then do
    /* Stationary calibration noise: 90 dB SPL total, equal acoustic power in three test bands. */
    e=.AcousticEmissionSpectrum~new
    do f over freq
      componentDb=90+10*RxCalcLog10(1/3,30)
      w=.AcousticLevelMath~acousticPowerForSplAt1m(componentDb,medium)
      e~addBand(.AcousticEmissionBand~new(f,w))
    end
    noiseResult=solver~solve(source,e,receivers,0.250)
  end

  carResult=.nil;carSource=.nil
  if state>0 then do
    carSource=car~sourcePositionAt(sampleTime)
    /* Vehicle-own source is propagated through the BUILDING scene, not reflected
       from / blocked by the same idealised vehicle body that carries the source. */
    carSolver=.AcousticImpulseResponseSolver~new(world)
    do bs over base~surfaces;carSolver~addSurface(bs);end
    carResult=carSolver~solve(carSource,vehicleEmission,receivers,0.250)
  end

  noiseDelta='NA'
  if noiseResult<>.nil then do
    a=noiseResult~receiver('FC')~firstArrival;b=noiseResult~receiver('FD')~firstArrival
    if a<>.nil & b<>.nil then noiseDelta=(b~delay-a~delay)*1000
  end

  do receiverName over .array~of('FC','FD')
    rp=receivers[receiverName]
    nFirst='NA';n125='NA';n1000='NA';n4000='NA';nTotal='NA'
    if noiseResult<>.nil then do
      nr=noiseResult~receiver(receiverName);na=nr~firstArrival
      if na<>.nil then nFirst=na~delay*1000
      n125=fmt(.AcousticObservationMath~receiverBandSpl(nr,125));n1000=fmt(.AcousticObservationMath~receiverBandSpl(nr,1000));n4000=fmt(.AcousticObservationMath~receiverBandSpl(nr,4000));nTotal=fmt(.AcousticObservationMath~receiverTotalSpl(nr,freq))
      if state>0 & includeCarReflection<>.nil then call dumpPaths scenario,source,state,direction,sampleTime,receiverName,nr,paths,.nil,medium,.nil,vel,source
      else call dumpPaths scenario,source,state,direction,sampleTime,receiverName,nr,paths,.nil,medium,.nil,.nil,.nil
    end
    cFirst='NA';c125='NA';c1000='NA';c4000='NA';cTotal='NA';o125='NA';o1000='NA';o4000='NA'
    if carResult<>.nil then do
      cr=carResult~receiver(receiverName);ca=cr~firstArrival
      if ca<>.nil then cFirst=ca~delay*1000
      c125=fmt(.AcousticObservationMath~receiverBandSpl(cr,125));c1000=fmt(.AcousticObservationMath~receiverBandSpl(cr,1000));c4000=fmt(.AcousticObservationMath~receiverBandSpl(cr,4000));cTotal=fmt(.AcousticObservationMath~receiverTotalSpl(cr,freq))
      o125=fmt(.AcousticDoppler~movingSourceObserved(125,medium~soundSpeed,vel,carSource,rp));o1000=fmt(.AcousticDoppler~movingSourceObserved(1000,medium~soundSpeed,vel,carSource,rp));o4000=fmt(.AcousticDoppler~movingSourceObserved(4000,medium~soundSpeed,vel,carSource,rp))
      call dumpPaths scenario,carSource,state,direction,sampleTime,receiverName,cr,paths,vel,medium,carSource,.nil,.nil
    end
    if source==.nil then sx='NA';else sx=source~x
    if source==.nil then sy='NA';else sy=source~y
    call lineout summary,scenario','sx','sy','state','direction','sampleTime','carX','roadY','receiverName','nFirst','n125','n1000','n4000','nTotal','cFirst','c125','c1000','c4000','cTotal','o125','o1000','o4000','noiseDelta
  end
  return

/* Every path is retained so pitch/level/reflection structure can be inspected rather than hidden in totals. */
dumpPaths: procedure
  use arg scenario,source,state,direction,sampleTime,receiverName,response,paths,velocity,medium,movingSource,reflectorVelocity,stationarySource
  do a over response~arrivals
    do f over .array~of(125,1000,4000)
      spl=.AcousticObservationMath~arrivalBandSpl(a,f); observed=f
      verts=a~vertices
      if movingSource<>.nil then do
        if a~kind='REFLECTION' & verts~items>=3 then observed=.AcousticDoppler~movingSourceObserved(f,medium~soundSpeed,velocity,movingSource,verts[2]~point)
        else observed=.AcousticDoppler~movingSourceObserved(f,medium~soundSpeed,velocity,movingSource,response~position)
      end
      else if reflectorVelocity<>.nil & stationarySource<>.nil & a~kind='DIFFUSE_REFLECTION' & a~evidence='MOVING_VEHICLE' & verts~items>=3 then observed=.AcousticDoppler~movingReflectionObserved(f,medium~soundSpeed,reflectorVelocity,stationarySource,verts[2]~point,response~position)
      call lineout paths,scenario','source~x','source~y','state','direction','sampleTime','receiverName','a~kind','a~evidence','a~distance','a~delay*1000','f','fmt(spl)','fmt(observed)
    end
  end
  return

fmt: procedure
  use arg n
  if n==.nil then return 'NA'
  return n~format(,6)

roomRect: procedure
  use arg solver,name,x1,y1,x2,y2,material,ctx,scale,x0,y0,zmin,zmax
  call panelPx solver,name'-top',x1,y1,x2,y1,material,ctx,scale,x0,y0,zmin,zmax
  call panelPx solver,name'-right',x2,y1,x2,y2,material,ctx,scale,x0,y0,zmin,zmax
  call panelPx solver,name'-bottom',x2,y2,x1,y2,material,ctx,scale,x0,y0,zmin,zmax
  call panelPx solver,name'-left',x1,y2,x1,y1,material,ctx,scale,x0,y0,zmin,zmax
  return
panelPx: procedure
  use arg solver,name,px1,py1,px2,py2,material,ctx,scale,x0,y0,zmin,zmax
  a=.MathVector3~new((px1-x0)*scale,(py1-y0)*scale,zmin,ctx)
  b=.MathVector3~new((px2-x0)*scale,(py2-y0)*scale,zmin,ctx)
  panel=.AcousticVerticalPanel~new(a,b,zmin,zmax)
  solver~addSurface(.AcousticSpectralSurface~new(name,panel,material))
  return

::requires 'AcousticMovingVehicle.cls'
::requires 'rexxutil' LIBRARY

::requires 'F11RearExterior.cls'
