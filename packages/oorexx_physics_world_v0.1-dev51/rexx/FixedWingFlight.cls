/* ooRexx Physics World v0.1-dev51 — fixed-wing point-mass flight.
 * Architecture: Tom Dyer. Implementation: Claude (Opus 5.5), 2026-11-03.
 *
 * Composes existing Physics authorities:
 *   - AerodynamicCoefficientTable1D / LongitudinalAerodynamicTableModel
 *     (dev24) for lift and drag versus angle of attack;
 *   - PropulsionUnit + ElectricPropellerMap (dev51) for thrust and power;
 * and adds 3-DOF point-mass flight with coordinated turns:
 *   L = W cos(gamma) / cos(phi)                      (trim lift)
 *   m dV/dt = T - D - W sin(gamma)                    (along path)
 *   dpsi/dt = g tan(phi) / V                          (coordinated turn)
 *   x' = V cos(gamma) sin(psi) + wE, y' = V cos(gamma) cos(psi) + wN,
 *   z' = V sin(gamma)                                 (air mass drifts)
 * Natural glide is the T=0 case of the same equations; nothing is special-
 * cased. Required CL above the table's monotone maximum fails closed as
 * STALL. This is not CFD, has no pitch dynamics (alpha is trimmed every
 * substep) and no ground effect.
 *
 * Angles in the public API: degrees. Heading psi is a compass bearing.
 */

::class FixedWingParabolicPolar public
/* Explicit wing data -> alpha tables (Physics never invents coefficients):
     CL(alpha) = CLalpha * (alpha - alpha0) up to CLmax at alphaStall,
     CD = CD0 + CL^2 / (pi e AR). Tables span alphaMin..alphaStall in 1 deg. */
::method init
 expose _cd0 _ar _e _clmax _a0 _lane
 numeric digits 16
 use strict arg zeroLiftDrag,aspectRatio,oswaldEfficiency,maximumLiftCoefficient,zeroLiftAngle=(-2)
 do v over .array~of(zeroLiftDrag,aspectRatio,oswaldEfficiency,maximumLiftCoefficient,zeroLiftAngle)
   if \datatype(v,'N') then raise syntax 88.900 array('numeric polar data')
 end
 if zeroLiftDrag<=0 | aspectRatio<=0 | oswaldEfficiency<=0 | oswaldEfficiency>1 | maximumLiftCoefficient<=0 then raise syntax 88.900 array('valid polar data')
 _cd0=zeroLiftDrag;_ar=aspectRatio;_e=oswaldEfficiency;_clmax=maximumLiftCoefficient;_a0=zeroLiftAngle
 _lane=.MathBinary64ScalarLane~new
::method inducedFactor; expose _ar _e _lane; numeric digits 16; return 1/(_lane~pi*_e*_ar)
::method liftSlopePerDegree
 /* Finite-wing lift slope (Helmbold/DATCOM low-sweep form), per degree. */
 expose _ar _lane
 numeric digits 16
 a=2*_lane~pi*_ar/(2+_lane~sqrt(4+_ar*_ar))
 return a*_lane~pi/180
::method maximumLiftToDrag
 expose _cd0
 numeric digits 16
 return 1/(2*self~lane~sqrt(_cd0*self~inducedFactor))
::method lane; expose _lane; return _lane
::method tableModel
 expose _cd0 _clmax _a0
 numeric digits 16
 use strict arg referenceArea,referenceChord,alphaMin=(-6)
 slope=self~liftSlopePerDegree
 stall=_a0+_clmax/slope
 k=self~inducedFactor
 alphas=.array~new;cls=.array~new;cds=.array~new;cms=.array~new
 a=alphaMin
 do while a<stall
   cl=slope*(a-_a0)
   alphas~append(a);cls~append(cl);cds~append(_cd0+k*cl*cl);cms~append(0)
   a=a+1
 end
 alphas~append(stall);cls~append(_clmax);cds~append(_cd0+k*_clmax*_clmax);cms~append(0)
 return .LongitudinalAerodynamicTableModel~new(.AerodynamicCoefficientTable1D~new(alphas,cls), -
   .AerodynamicCoefficientTable1D~new(alphas,cds),.AerodynamicCoefficientTable1D~new(alphas,cms), -
   referenceArea,referenceChord)

::class FixedWingAircraft public
/* Static aircraft definition: mass, wing reference geometry, the alpha
   tables (CL, CD; CM table retained but trimmed to zero), and propulsion. */
::method init
 expose _m _s _chord _model _map _avionics _g _bankLimit _lane _clmax _stallAlpha
 numeric digits 16
 use strict arg mass,wingArea,meanChord,polar,propellerMap,avionicsPower=0,maxBankDegrees=30,gravity=9.80665
 do v over .array~of(mass,wingArea,meanChord,avionicsPower,maxBankDegrees,gravity)
   if \datatype(v,'N') then raise syntax 88.900 array('numeric aircraft data')
 end
 if mass<=0 | wingArea<=0 | meanChord<=0 | avionicsPower<0 | maxBankDegrees<=0 | maxBankDegrees>=80 | gravity<=0 then raise syntax 88.900 array('valid aircraft data')
 _m=mass;_s=wingArea;_chord=meanChord;_map=propellerMap;_avionics=avionicsPower;_g=gravity;_bankLimit=maxBankDegrees
 _model=polar~tableModel(wingArea,meanChord)
 _lane=.MathBinary64ScalarLane~new
 /* The same CL table the model evaluates is inverted for trim. */
 top=self~liftTable~monotoneMaximum
 _stallAlpha=top[1];_clmax=top[2]
::method liftTable
 expose _model
 numeric digits 16
 return _model~liftTable
::method tableModel; expose _model; return _model
::method mass; expose _m; return _m
::method wingArea; expose _s; return _s
::method weight; expose _m _g; numeric digits 16; return _m*_g
::method gravity; expose _g; return _g
::method propellerMap; expose _map; return _map
::method avionicsPower; expose _avionics; return _avionics
::method bankLimit; expose _bankLimit; return _bankLimit
::method maximumLiftCoefficient; expose _clmax; return _clmax
::method lane; expose _lane; return _lane
::method stallSpeed
 numeric digits 16
 use strict arg airDensity,loadFactor=1
 return self~lane~sqrt(2*self~weight*loadFactor/(airDensity*self~wingArea*self~maximumLiftCoefficient))
::method trim
 /* Solve alpha for L = W cos(gamma)/cos(phi) at airspeed V. */
 expose _model _lane _g
 numeric digits 16
 use strict arg airspeed,gammaDeg,bankDeg,airDensity
 if airspeed<=0 then raise syntax 88.900 array('positive airspeed for trim')
 gammaR=_lane~radians(gammaDeg);phiR=_lane~radians(bankDeg)
 n=1/_lane~cos(phiR)
 q=airDensity*airspeed*airspeed/2
 clReq=self~weight*_lane~cos(gammaR)*n/(q*self~wingArea)
 d=.directory~new;d['LOAD_FACTOR']=n;d['CL_REQUIRED']=clReq;d['DYNAMIC_PRESSURE']=q
 if clReq>self~maximumLiftCoefficient then do
   d['STATUS']='STALL';return d
 end
 alpha=self~liftTable~inverseMonotone(clReq)
 obs=_model~evaluate(.AerodynamicOperatingState~new(alpha,0,airspeed/340.3,airspeed,airDensity))
 d['STATUS']='TRIMMED';d['ALPHA']=alpha
 d['CL']=obs~liftCoefficient;d['CD']=obs~dragCoefficient
 d['LIFT']=obs~lift;d['DRAG']=obs~drag
 return d

::class FixedWingFlightState public
/* Mutable point-mass state. step() is pure until commit(): the caller (a
   referee) can reject a proposed step without corrupting the state. */
::attribute x get
::attribute y get
::attribute z get
::attribute heading get
::attribute airspeed get
::attribute time get
::method init
 expose _ac x y z heading airspeed time _unit
 numeric digits 16
 use strict arg aircraft,x0,y0,z0,headingDeg,airspeed0,startTime=0
 do v over .array~of(x0,y0,z0,headingDeg,airspeed0,startTime)
   if \datatype(v,'N') then raise syntax 88.900 array('numeric flight state')
 end
 _ac=aircraft;x=x0;y=y0;z=z0;heading=headingDeg;airspeed=airspeed0;time=startTime
 _unit=.PropulsionUnit~new(aircraft~propellerMap,startTime)
::method aircraft; expose _ac; return _ac
::method propose
 /* Integrate dt with `substeps` explicit sub-steps (default 4).
    throttle in [0,1]; bank and gamma in degrees; wind in m/s. */
 expose _ac x y z heading airspeed time
 numeric digits 16
 use strict arg dt,throttle,bankDeg,gammaDeg,windEast=0,windNorth=0,airDensity=1.225,substeps=4
 if dt<=0 | substeps<1 then raise syntax 88.900 array('positive dt and substeps')
 if throttle<0 | throttle>1 then raise syntax 88.900 array('throttle in [0,1]')
 lane=_ac~lane
 bank=max(-_ac~bankLimit,min(_ac~bankLimit,bankDeg))
 h=dt/substeps
 px=x;py=y;pz=z;psi=heading;v=airspeed
 energy=0;status='OK';minMargin=1e9;lastTrim=.nil;lastThrust=0
 do substeps
   trimmed=_ac~trim(v,gammaDeg,bank,airDensity)
   if trimmed['STATUS']\=='TRIMMED' then do; status='STALL'; leave; end
   lastTrim=trimmed
   op=.PropulsionOperatingPoint~new(throttle,v,airDensity)
   pr=_ac~propellerMap~evaluate(op)
   gammaR=lane~radians(gammaDeg)
   accel=(pr['THRUST']-trimmed['DRAG']-_ac~weight*lane~sin(gammaR))/_ac~mass
   turnRate=lane~degrees(_ac~gravity*lane~tan(lane~radians(bank))/v)
   psiMid=psi+turnRate*h/2
   vMid=v+accel*h/2
   if vMid<=0 then do; status='STALL'; leave; end
   px=px+(vMid*lane~cos(gammaR)*lane~sin(lane~radians(psiMid))+windEast)*h
   py=py+(vMid*lane~cos(gammaR)*lane~cos(lane~radians(psiMid))+windNorth)*h
   pz=pz+vMid*lane~sin(gammaR)*h
   psi=psi+turnRate*h
   v=v+accel*h
   energy=energy+(pr['ELECTRICAL_POWER']+_ac~avionicsPower)*h
   lastThrust=pr['THRUST']
   minMargin=min(minMargin,v-_ac~stallSpeed(airDensity,trimmed['LOAD_FACTOR']))
 end
 do while psi<0;psi=psi+360;end
 do while psi>=360;psi=psi-360;end
 p=.directory~new
 p['STATUS']=status;p['X']=px;p['Y']=py;p['Z']=pz;p['HEADING']=psi;p['AIRSPEED']=v
 p['TIME']=time+dt;p['ELECTRICAL_ENERGY']=energy;p['THRUST']=lastThrust
 p['BANK']=bank;p['GAMMA']=gammaDeg;p['THROTTLE']=throttle;p['STALL_MARGIN']=minMargin
 if lastTrim\==.nil then do
   p['ALPHA']=lastTrim['ALPHA'];p['CL']=lastTrim['CL'];p['DRAG']=lastTrim['DRAG'];p['LOAD_FACTOR']=lastTrim['LOAD_FACTOR']
 end
 if status=='OK' & v<_ac~stallSpeed(airDensity,1) then p['STATUS']='STALL'
 return p
::method commit
 expose x y z heading airspeed time
 numeric digits 16
 use strict arg proposal
 if proposal['STATUS']\=='OK' then raise syntax 88.900 array('cannot commit a stalled proposal')
 x=proposal['X'];y=proposal['Y'];z=proposal['Z'];heading=proposal['HEADING']
 airspeed=proposal['AIRSPEED'];time=proposal['TIME']
 return .true

::requires 'AerodynamicCoefficientTables.cls'
::requires 'Propulsion.cls'
::requires 'MathFastLanes.cls'
