/* Physics World dev18: reduced-order propulsion with explicit operating map authority. */
::class PropulsionOperatingPoint public
::method init
 expose _throttle _speed _rho _temp _pressure
 use strict arg throttle,flightSpeed,airDensity,temperature=.nil,pressure=.nil
 if throttle<0 | throttle>1 | flightSpeed<0 | airDensity<=0 then raise syntax 88.900 array('valid throttle, speed and density')
 _throttle=throttle+0; _speed=flightSpeed+0; _rho=airDensity+0; _temp=temperature; _pressure=pressure
::method throttle; expose _throttle; return _throttle
::method flightSpeed; expose _speed; return _speed
::method airDensity; expose _rho; return _rho
::method temperature; expose _temp; return _temp
::method pressure; expose _pressure; return _pressure

::class PropulsionMap public
::method evaluate; use strict arg operatingPoint; raise syntax 93.900 array('PropulsionMap~evaluate must be implemented')

::class LinearStaticThrustMap subclass PropulsionMap public
/* Qualification/reference map, not a real turbofan deck. */
::method init
 expose _staticThrust _fuelAtFull _referenceDensity
 use strict arg staticThrust,fuelMassFlowAtFull,referenceDensity=1.225
 if staticThrust<0 | fuelMassFlowAtFull<0 | referenceDensity<=0 then raise syntax 88.900 array('non-negative thrust/fuel and positive density')
 _staticThrust=staticThrust+0; _fuelAtFull=fuelMassFlowAtFull+0; _referenceDensity=referenceDensity+0
::method evaluate
 expose _staticThrust _fuelAtFull _referenceDensity
 use strict arg op
 densityRatio=op~airDensity/_referenceDensity
 d=.directory~new
 d['THRUST']=_staticThrust*op~throttle*densityRatio
 d['FUEL_MASS_FLOW']=_fuelAtFull*op~throttle
 return d

::class PropulsionUnit public
::method init
 expose _map _fuelUsed _time
 use strict arg propulsionMap,startTime=0
 _map=propulsionMap; _fuelUsed=0; _time=startTime+0
::method step
 expose _map _fuelUsed _time
 use strict arg dt,operatingPoint
 if dt<=0 then raise syntax 88.900 array('positive propulsion timestep')
 r=_map~evaluate(operatingPoint); dm=r['FUEL_MASS_FLOW']*dt
 if dm<0 then raise syntax 93.900 array('propulsion map returned negative fuel flow')
 _fuelUsed=_fuelUsed+dm; _time=_time+dt
 return .PropulsionObservation~new(_time,r['THRUST'],r['FUEL_MASS_FLOW'],dm,_fuelUsed)
::method fuelUsed; expose _fuelUsed; return _fuelUsed
::method time; expose _time; return _time

::class PropulsionObservation public
::method init
 expose _time _thrust _flow _increment _total
 use strict arg time,thrust,fuelMassFlow,fuelIncrement,totalFuel
 _time=time; _thrust=thrust; _flow=fuelMassFlow; _increment=fuelIncrement; _total=totalFuel
::method time; expose _time; return _time
::method thrust; expose _thrust; return _thrust
::method fuelMassFlow; expose _flow; return _flow
::method fuelIncrement; expose _increment; return _increment
::method totalFuel; expose _total; return _total

/* ------------------------------------------------------------------------
   Physics World dev51 (2026-11-03): electric rotorcraft and propeller power.
   Architecture: Tom Dyer. Implementation: Claude (Opus 5.5).
   Both models take EXPLICIT physical data; nothing is inferred from an
   aircraft name. Scalar transcendentals use the Maths v0.20 BINARY64 lane.
   ------------------------------------------------------------------------ */
::class MultirotorMomentumModel public
/* Momentum theory with empirical profile/parasite terms (Leishman form):
     W = m g, D = 0.5 rho f v^2, T = sqrt(W^2 + D^2)       (level trim)
     vh = sqrt(T / (2 rho A)),  A = n pi R^2
     induced: vi^4 + 2 vc vi^3 + (v^2 + vc^2) vi^2 = vh^4  (Newton solve;
              vc>=0 only — descent gets no momentum-theory credit, and the
              vortex-ring state is reported, not modelled)
     P_ind  = kappa T vi,  P_climb = T vc (vc>0)
     P_prof = P0 (1 + 4.65 mu^2), mu = v/(Omega R),
              P0 from hover figure of merit: P0 = P_ideal (1/FM - kappa)
     P_par  = D v
     P_elec = (P_ind + P_climb + P_prof + P_par)/eta_drive + P_avionics  */
::method init
 expose _m _n _r _fm _kappa _tip _f _eta _avionics _g _lane
 numeric digits 16
 use strict arg mass,rotorCount,rotorRadius,figureOfMerit,tipSpeed,parasiteDragArea,driveEfficiency,avionicsPower=0,inducedFactor=1.15,gravity=9.80665
 do v over .array~of(mass,rotorCount,rotorRadius,figureOfMerit,tipSpeed,parasiteDragArea,driveEfficiency,avionicsPower,inducedFactor,gravity)
   if \datatype(v,'N') then raise syntax 88.900 array('numeric multirotor data')
 end
 if mass<=0 | rotorCount<1 | rotorRadius<=0 | tipSpeed<=0 | parasiteDragArea<0 | avionicsPower<0 | gravity<=0 then raise syntax 88.900 array('positive multirotor mass, rotors, radius, tip speed and gravity')
 if figureOfMerit<=0 | figureOfMerit>=1 | driveEfficiency<=0 | driveEfficiency>1 then raise syntax 88.900 array('figure of merit in (0,1), drive efficiency in (0,1]')
 if inducedFactor<1 | 1/figureOfMerit<=inducedFactor then raise syntax 88.900 array('inducedFactor>=1 and below 1/figureOfMerit (non-negative profile power)')
 _m=mass;_n=rotorCount;_r=rotorRadius;_fm=figureOfMerit;_tip=tipSpeed;_f=parasiteDragArea
 _eta=driveEfficiency;_avionics=avionicsPower;_kappa=inducedFactor;_g=gravity
 _lane=.MathBinary64ScalarLane~new
::method lane; expose _lane; return _lane
::method discArea; expose _n _r _lane; numeric digits 16; return _n*_lane~pi*_r*_r
::method weight; expose _m _g; numeric digits 16; return _m*_g
::method power
 expose _m _fm _kappa _tip _f _eta _avionics _g _lane
 numeric digits 16
 use strict arg horizontalAirspeed,climbRate,airDensity
 if \datatype(horizontalAirspeed,'N') | \datatype(climbRate,'N') | \datatype(airDensity,'N') then raise syntax 88.900 array('numeric airspeed, climb rate and density')
 if airDensity<=0 then raise syntax 88.900 array('positive air density')
 v=abs(horizontalAirspeed); vc=max(0,climbRate)
 a=self~discArea; w=self~weight
 drag=airDensity*_f*v*v/2
 thrust=_lane~sqrt(w*w+drag*drag)
 vh=_lane~sqrt(thrust/(2*airDensity*a))
 /* Newton on g(vi)=vi^4+2vc vi^3+(v^2+vc^2)vi^2-vh^4, start at vh. */
 vi=vh
 do 30
   gv=vi**4+2*vc*vi**3+(v*v+vc*vc)*vi*vi-vh**4
   dg=4*vi**3+6*vc*vi*vi+2*(v*v+vc*vc)*vi
   if dg<=0 then leave
   nxt=vi-gv/dg
   if nxt<=0 then nxt=vi/2
   if abs(nxt-vi)<1e-12 then do; vi=nxt; leave; end
   vi=nxt
 end
 wh=self~weight
 pIdealHover=wh*_lane~sqrt(wh/(2*airDensity*a))
 p0=pIdealHover*(1/_fm-_kappa)
 mu=v/_tip
 pInd=_kappa*thrust*vi
 pClimb=thrust*vc
 pProf=p0*(1+4.65*mu*mu)
 pPar=drag*v
 shaft=pInd+pClimb+pProf+pPar
 elec=shaft/_eta+_avionics
 regime='NORMAL'
 if climbRate<0 then regime='DESCENT_NO_MOMENTUM_CREDIT'
 if climbRate<0 & -climbRate<2*vh & v<vh then regime='VORTEX_RING_RISK_NOT_MODELLED'
 d=.directory~new
 d['THRUST']=thrust;d['DRAG']=drag;d['HOVER_INDUCED_VELOCITY']=vh;d['INDUCED_VELOCITY']=vi
 d['INDUCED_POWER']=pInd;d['CLIMB_POWER']=pClimb;d['PROFILE_POWER']=pProf;d['PARASITE_POWER']=pPar
 d['SHAFT_POWER']=shaft;d['ELECTRICAL_POWER']=elec;d['ADVANCE_RATIO']=mu;d['REGIME']=regime
 return d
::method hoverElectricalPower
 numeric digits 16
 use strict arg airDensity
 return self~power(0,0,airDensity)['ELECTRICAL_POWER']

::class ElectricPropellerMap subclass PropulsionMap public
/* Fixed-pitch electric propeller, reduced order and explicit:
     T(thr,v) = Tstatic * thr * max(0, 1 - v/vPitch) * rho/rho_ref
     actuator-disc induced velocity vi = (-v + sqrt(v^2 + 2T/(rho A)))/2
     P_shaft = T (v + vi) / eta_profile,  P_elec = P_shaft/eta_motor
   Returns THRUST, ELECTRICAL_POWER, SHAFT_POWER and FUEL_MASS_FLOW=0 so it
   composes with PropulsionUnit. */
::method init
 expose _ts _vp _rad _etap _etam _rhoref _lane
 numeric digits 16
 use strict arg staticThrust,pitchSpeed,propellerRadius,profileEfficiency,motorEfficiency,referenceDensity=1.225
 do v over .array~of(staticThrust,pitchSpeed,propellerRadius,profileEfficiency,motorEfficiency,referenceDensity)
   if \datatype(v,'N') then raise syntax 88.900 array('numeric propeller data')
 end
 if staticThrust<0 | pitchSpeed<=0 | propellerRadius<=0 | referenceDensity<=0 then raise syntax 88.900 array('valid propeller thrust, pitch speed, radius and density')
 if profileEfficiency<=0 | profileEfficiency>1 | motorEfficiency<=0 | motorEfficiency>1 then raise syntax 88.900 array('efficiencies in (0,1]')
 _ts=staticThrust;_vp=pitchSpeed;_rad=propellerRadius;_etap=profileEfficiency;_etam=motorEfficiency;_rhoref=referenceDensity
 _lane=.MathBinary64ScalarLane~new
::method lane; expose _lane; return _lane
::method availableThrust
 expose _ts _vp _rhoref
 numeric digits 16
 use strict arg flightSpeed,airDensity
 return _ts*max(0,1-flightSpeed/_vp)*airDensity/_rhoref
::method throttleFor
 numeric digits 16
 /* Inverse of the thrust law; fails closed when unattainable. */
 use strict arg thrust,flightSpeed,airDensity
 full=self~availableThrust(flightSpeed,airDensity)
 if thrust<=0 then return 0
 if full<=0 | thrust>full then raise syntax 88.900 array('requested thrust exceeds propeller capability')
 return thrust/full
::method evaluate
 expose _rad _etap _etam _lane
 numeric digits 16
 use strict arg op
 v=op~flightSpeed; rho=op~airDensity
 thrust=op~throttle*self~availableThrust(v,rho)
 area=_lane~pi*_rad*_rad
 vi=0
 if thrust>0 then vi=(-v+_lane~sqrt(v*v+2*thrust/(rho*area)))/2
 shaft=0
 if thrust>0 then shaft=thrust*(v+vi)/_etap
 d=.directory~new
 d['THRUST']=thrust;d['INDUCED_VELOCITY']=vi
 d['SHAFT_POWER']=shaft;d['ELECTRICAL_POWER']=shaft/_etam
 d['FUEL_MASS_FLOW']=0
 return d

::requires 'MathFastLanes.cls'
