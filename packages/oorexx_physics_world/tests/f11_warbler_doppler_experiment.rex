/* Continuous F11 deterministic warbler / moving-reflector Doppler trace.
   Five old car positions are reference gates only. The trajectory is sampled continuously. */
numeric digits 20
ctx=.Maths~defaultContext
world=.PhysicalWorld~new(.OpticalMedium~air,.AcousticMedium~air);medium=world~ambientAcoustic
freq=.array~of(500,1000,2000)
materialFreq=.array~of(125,500,1000,2000,4000)
wood=.AcousticBuildingMaterialFactory~solidWoodDoor(materialFreq)
block=.AcousticBuildingMaterialFactory~breezeBlockWall(materialFreq)
base=.AcousticImpulseResponseSolver~new(world)
scale='0.017025100232155435';xOriginPx=75;yOriginPx=145;roadY=(746-yOriginPx)*scale
wallBottom=3.0;wallTop=5.2
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
call panelPx base,'door-A_to_F',383,327,383,366,wood,ctx,scale,xOriginPx,yOriginPx,wallBottom,wallTop
call panelPx base,'door-E_to_F',280,503,294,538,wood,ctx,scale,xOriginPx,yOriginPx,wallBottom,wallTop
call panelPx base,'door-FD_to_stairwell',398,328,461,371,wood,ctx,scale,xOriginPx,yOriginPx,wallBottom,wallTop

fc=.MathVector3~new('14.267033994546255','9.448930628846266','4.8',ctx)
fd=.MathVector3~new('7.014341295648039','3.4220451466632427','4.8',ctx)
receivers=.directory~new;receivers['FC']=fc;receivers['FD']=fd
sx=value('F11_WARBLER_SOURCE_X',,'ENVIRONMENT');if sx='' then sx='5.25'
sy=value('F11_WARBLER_SOURCE_Y',,'ENVIRONMENT');if sy='' then sy='4.5'
source=.MathVector3~new(sx,sy,4.8,ctx)
dt=value('F11_WARBLER_DT',,'ENVIRONMENT');if dt='' then dt='0.020'
duration=value('F11_WARBLER_DURATION',,'ENVIRONMENT');if duration='' then duration='2.4'
signalSpl=value('F11_WARBLER_SPL_DB',,'ENVIRONMENT');if signalSpl='' then signalSpl='80'
pattern=.AcousticWarblerPattern~defaultPipWarbler(duration)
speed='11.111111111111111'

/* Active pips are 80 dB SPL-at-1m reference tones.  A band object is retained
   per tone so Physics supplies spreading, material transmission and phase. */
bands=.directory~new
do f over freq
  bands[f]=.AcousticEmissionBand~new(f,.AcousticLevelMath~acousticPowerForSplAt1m(signalSpl,medium))
end
vehicleSpectrum=.AcousticVehicleNoiseSpectrum~new(78)
vehicleBands=.directory~new
do c over vehicleSpectrum~components
  vehicleBands[c~frequencyHz]=.AcousticEmissionBand~new(c~frequencyHz,.AcousticLevelMath~acousticPowerForSplAt1m(c~sourceSplDb,medium))
end

outDir='.';parse arg outDir;if outDir='' then outDir='.';call SysMkDir outDir
trace=outDir'/f11_warbler_doppler_trace.csv'
call lineout trace,'direction,receive_time_s,car_x_reflection_m,car_x_receive_m,gate,receiver,retarded_emission_s,reflection_time_s,reflection_delay_ms,reference_tone_hz,observed_tone_hz,pitch_ratio,reference_cadence_hz,observed_cadence_hz,speed_ratio,reference_pip_ms,observed_pip_ms,baseline_path_db,reflected_path_db,with_reflection_db,vehicle_reflection_gain_db,vehicle_obs125_hz,vehicle_obs1000_hz,vehicle_obs4000_hz,vehicle_p125_pa,vehicle_p1000_pa,vehicle_p4000_pa'

/* Run until the trajectory has crossed the five reference locations. */
passSeconds='2.16'
do direction over .array~of('RTL','LTR')
  if direction='RTL' then do;vx=-speed;startX=20;end
  else do;vx=speed;startX=-4;end
  car=.AcousticMovingVehicle~new('vehicle',.MathVector3~new(startX,roadY,0,ctx),.MathVector3~new(vx,0,0,ctx),4,1.5,0.5)
  vel=car~velocity
  t=0
  do while t<=passSeconds+'0.0000001'
    do receiverName over .array~of('FC','FD')
      receiver=receivers[receiverName]
      kin=.AcousticMovingReflectionKinematics~solve(car,source,receiver,t,medium~soundSpeed)
      if kin<>.nil then do
        tRef=kin['reflectionTime'];tEmit=kin['emissionTime'];q=kin['reflectionPoint']
        carXRef=car~centerAt(tRef)~x;carXRecv=car~centerAt(t)~x
        ratio=.AcousticDopplerWarp~reflectionRatio(medium~soundSpeed,vel,source,q,receiver)
        refTone=pattern~frequencyAt(tEmit)
        if refTone=0 then obsTone=0;else obsTone=.AcousticDopplerWarp~observedFrequency(refTone,ratio)
        obsCadence=.AcousticDopplerWarp~observedCadenceHz(pattern~cadenceHz,ratio)
        obsPip=.AcousticDopplerWarp~observedDuration('0.080',ratio)*1000

        baseDb='NA';reflectedDb='NA';withDb='NA';gainDb='NA'
        if refTone>0 then do
          band=bands[refTone]
          m1=base~medium(source,q);m2=base~medium(q,receiver)
          if m1~name=m2~name then do
            c1=base~transmission(source,q,refTone);c2=base~transmission(q,receiver,refTone)
            scattered=base~scatterPhasor(band,kin['incidentDistanceM'],kin['receiverDistanceM'],m1,car~length*car~height,c1*c2)
            directDistance=(receiver-source)~norm;directMedium=base~medium(source,receiver);directC=base~transmission(source,receiver,refTone)
            direct=base~pathPhasor(band,directDistance,directMedium,directC)
            combined=direct+scattered
            baseDb=fmt(.AcousticLevelMath~splForPressure(direct~magnitude))
            reflectedDb=fmt(.AcousticLevelMath~splForPressure(scattered~magnitude))
            withDb=fmt(.AcousticLevelMath~splForPressure(combined~magnitude))
            if baseDb<>'NA' & withDb<>'NA' then gainDb=fmt((withDb+0)-(baseDb+0))
          end
        end

        /* Known car noise: retarded moving source position, direct/transmitted path pressure
           and exact source-Doppler frequencies.  These Pa-domain components are the model
           contribution to subtract from a synthetic/observed mixture; dB is not subtracted. */
        sk=.AcousticMovingSourceKinematics~solve(car,receiver,t,medium~soundSpeed);sp=sk['sourcePoint']
        vf=.array~of(125,1000,4000);vp=.array~new;vo=.array~new
        do vi=1 to vf~items
          fveh=vf[vi];vband=vehicleBands[fveh];vd=(receiver-sp)~norm;vm=base~medium(sp,receiver);vc=base~transmission(sp,receiver,fveh)
          vph=base~pathPhasor(vband,vd,vm,vc);vp~append(vph~magnitude)
          vo~append(.AcousticDoppler~movingSourceObserved(fveh,medium~soundSpeed,vel,sp,receiver))
        end
        gate=gateAt(carXRecv)
        call lineout trace,direction','fmt(t)','fmt(carXRef)','fmt(carXRecv)','gate','receiverName','fmt(tEmit)','fmt(tRef)','fmt(kin['delaySeconds']*1000)','fmt(refTone)','fmt(obsTone)','fmt(ratio)','fmt(pattern~cadenceHz)','fmt(obsCadence)','fmt(ratio)','80','fmt(obsPip)','baseDb','reflectedDb','withDb','gainDb','fmt(vo[1])','fmt(vo[2])','fmt(vo[3])','fmt(vp[1])','fmt(vp[2])','fmt(vp[3])
      end
    end
    t=t+dt
  end
end
call lineout trace
say 'PASS F11 warbler Doppler experiment'
say 'trace='trace
exit 0

gateAt: procedure
  use arg x
  gates=.array~of(-4,2,8,14,20)
  do i=1 to gates~items
    if abs(x-gates[i])<='0.12' then return 'P'i
  end
  return ''
fmt: procedure
  use arg n
  if n==.nil then return 'NA'
  return (n+0)~format(,9)
roomRect: procedure
  use arg solver,name,x1,y1,x2,y2,material,ctx,scale,x0,y0,zmin,zmax
  call panelPx solver,name'-top',x1,y1,x2,y1,material,ctx,scale,x0,y0,zmin,zmax
  call panelPx solver,name'-right',x2,y1,x2,y2,material,ctx,scale,x0,y0,zmin,zmax
  call panelPx solver,name'-bottom',x2,y2,x1,y2,material,ctx,scale,x0,y0,zmin,zmax
  call panelPx solver,name'-left',x1,y2,x1,y1,material,ctx,scale,x0,y0,zmin,zmax
return
panelPx: procedure
  use arg solver,name,px1,py1,px2,py2,material,ctx,scale,x0,y0,zmin,zmax
  a=.MathVector3~new((px1-x0)*scale,(py1-y0)*scale,zmin,ctx);b=.MathVector3~new((px2-x0)*scale,(py2-y0)*scale,zmin,ctx)
  solver~addSurface(.AcousticSpectralSurface~new(name,.AcousticVerticalPanel~new(a,b,zmin,zmax),material))
return
::requires 'AcousticCalibrationSignal.cls'
::requires 'rexxutil' LIBRARY

::requires 'F11RearExterior.cls'
