/* ooRexx Physics World v0.1-dev46
 * Acoustic drum-kit mechanics.  Independent peer of the guitar mechanics.
 * Physics owns moving heads/shells/cymbals/snare wires and pressure radiation;
 * no sample-trigger/audio-synthesis authority is hidden here.
 */
numeric digits 30

::class DrumModalMode public
::method init
 expose _name _kind _mass _freq _damping _area _x _v _participation _omega _stiffness _dampingCoeff _lastExternalForce _lastAcceleration _couplingForce
 use strict arg name,kind,massKg,frequencyHz,dampingRatio,radiatingAreaM2,participation=1,initialX=0,initialV=0
 if massKg<=0 | frequencyHz<=0 | dampingRatio<0 | radiatingAreaM2<0 then raise syntax 88.900 array('valid drum modal parameters')
 _name=name; _kind=kind~upper; _mass=massKg+0; _freq=frequencyHz+0; _damping=dampingRatio+0
 _area=radiatingAreaM2+0; _participation=participation+0; _x=initialX+0; _v=initialV+0
 pi=4*RxCalcArcTan(1,30,'R'); _omega=2*pi*_freq; _stiffness=_mass*_omega*_omega; _dampingCoeff=2*_damping*_mass*_omega; _lastExternalForce=0; _couplingForce=0; _lastAcceleration=(-_dampingCoeff*_v-_stiffness*_x)/_mass
::method name; expose _name; return _name
::method kind; expose _kind; return _kind
::method mass; expose _mass; return _mass
::method frequencyHz; expose _freq; return _freq
::method dampingRatio; expose _damping; return _damping
::method 'dampingRatio='; expose _damping _dampingCoeff _mass _omega _lastAcceleration _lastExternalForce _v _stiffness _x; use strict arg z; if z<0 then raise syntax 88.900 array('non-negative modal damping'); _damping=z+0; _dampingCoeff=2*_damping*_mass*_omega; _lastAcceleration=(_lastExternalForce-_dampingCoeff*_v-_stiffness*_x)/_mass
::method radiatingArea; expose _area; return _area
::method participation; expose _participation; return _participation
::method displacement; expose _x; return _x
::method velocity; expose _v; return _v
::method omega; expose _omega; return _omega
::method stiffness; expose _stiffness; return _stiffness
::method dampingCoefficient; expose _dampingCoeff; return _dampingCoeff
::method acceleration
 expose _dampingCoeff _stiffness _v _x _mass _lastExternalForce _lastAcceleration
 use arg externalForceN
 if arg(1,'O') then return _lastAcceleration
 return (externalForceN-_dampingCoeff*_v-_stiffness*_x)/_mass
::method mechanicalEnergy
 expose _mass _v _stiffness _x
 return _mass*_v*_v/2+_stiffness*_x*_x/2
::method applyImpulse
 expose _v _lastAcceleration _lastExternalForce _dampingCoeff _stiffness _x _mass
 use strict arg impulseNs
 _v=_v+(impulseNs*self~participation)/self~mass
 _lastAcceleration=(_lastExternalForce-_dampingCoeff*_v-_stiffness*_x)/_mass
 return _v
::method applyPressureImpulse
 use strict arg pressurePa,dtSeconds
 return self~applyImpulse(pressurePa*self~radiatingArea*dtSeconds)
::method clearCouplingForce
 expose _couplingForce
 _couplingForce=0; return 0
::method addCouplingForce
 expose _couplingForce
 use strict arg f
 _couplingForce+=f; return _couplingForce
::method couplingForce; expose _couplingForce; return _couplingForce
::method step
 expose _x _v _lastExternalForce _lastAcceleration _dampingCoeff _stiffness _mass
 use strict arg dt,externalForceN=0
 if dt<=0 then raise syntax 88.900 array('positive drum modal step',dt)
 _lastExternalForce=externalForceN+0
 a=self~acceleration(_lastExternalForce)
 _v=_v+dt*a; _x=_x+dt*_v
 _lastAcceleration=(_lastExternalForce-_dampingCoeff*_v-_stiffness*_x)/_mass
 return self
::method setState
 expose _x _v _lastAcceleration _lastExternalForce _dampingCoeff _stiffness _mass
 use strict arg x,v
 _x=x+0;_v=v+0;_lastAcceleration=(_lastExternalForce-_dampingCoeff*_v-_stiffness*_x)/_mass;return self
::method volumeAcceleration
 return self~radiatingArea*self~acceleration

::class DrumStructuralLink public
::method init
 expose _name _a _b _k _c
 use strict arg name,modeA,modeB,stiffnessNPerM,dampingNsPerM=0
 if stiffnessNPerM<0 | dampingNsPerM<0 then raise syntax 88.900 array('non-negative drum structural coupling')
 _name=name;_a=modeA;_b=modeB;_k=stiffnessNPerM+0;_c=dampingNsPerM+0
::method name; expose _name; return _name
::method modeA; expose _a; return _a
::method modeB; expose _b; return _b
::method forceOnA
 expose _a _b _k _c
 return -_k*(_a~displacement-_b~displacement)-_c*(_a~velocity-_b~velocity)
::method mechanicalEnergy
 expose _a _b _k
 dx=_a~displacement-_b~displacement
 return _k*dx*dx/2

::class DrumVoice public
::method init
 expose _name _kind _position _modes _ledger _open _lastVolumeAcceleration
 use strict arg name,kind,position,modes
 _name=name;_kind=kind~upper;_position=position;_modes=modes~copy;_ledger=.array~new;_open=1;_lastVolumeAcceleration=0
 do m over _modes; _lastVolumeAcceleration+=m~volumeAcceleration; end
::method name; expose _name; return _name
::method kind; expose _kind; return _kind
::method position; expose _position; return _position
::method 'position='; expose _position; use strict arg p; _position=p; return p
::method modes; expose _modes; return _modes~copy
::method ledger; expose _ledger; return _ledger~copy
::method openness; expose _open; return _open
::method mechanicalEnergy
 expose _modes
 e=0; do m over _modes; e+=m~mechanicalEnergy; end; return e
::method volumeAcceleration
 expose _lastVolumeAcceleration
 return _lastVolumeAcceleration
::method strike
 expose _modes _ledger _name
 use strict arg impulseNs,radialFraction=.35,rimFraction=0
 if impulseNs<0 then raise syntax 88.900 array('non-negative drum strike impulse',impulseNs)
 if radialFraction<0 | radialFraction>1 | rimFraction<0 | rimFraction>1 then raise syntax 88.900 array('strike fractions in range 0..1')
 weights=.array~new; total=0; i=0
 do m over _modes
   i+=1
   if m~kind='SHELL' then w=(.15+.85*rimFraction)/i
   else if m~kind='SNARE_WIRE' then w=(.12+.38*(1-radialFraction))/i
   else if m~kind='CYMBAL' then w=(.35+.65*radialFraction)/RxCalcSqrt(i)
   else w=(1-.65*radialFraction)/i+.10
   if w<0 then w=0
   weights~append(w); total+=w
 end
 if total=0 then return 0
 i=0
 do m over _modes
   i+=1; m~applyImpulse(impulseNs*weights[i]/total)
 end
 ev=.directory~new; ev['VOICE']=_name;ev['IMPULSE_NS']=impulseNs;ev['RADIAL_FRACTION']=radialFraction;ev['RIM_FRACTION']=rimFraction
 _ledger~append(ev)
 return impulseNs
::method applyAcousticPressure
 expose _modes
 use strict arg pressurePa,dtSeconds
 do m over _modes; m~applyPressureImpulse(pressurePa,dtSeconds); end
 return pressurePa
::method step
 expose _modes _lastVolumeAcceleration
 use strict arg dt,forceDirectory=.nil
 _lastVolumeAcceleration=0
 do m over _modes
   f=0
   if forceDirectory<>.nil then if forceDirectory~hasIndex(m~name) then f=forceDirectory[m~name]
   m~step(dt,f)
   _lastVolumeAcceleration+=m~volumeAcceleration
 end
 return self
::method stepCoupled
 expose _modes _lastVolumeAcceleration
 use strict arg dt
 _lastVolumeAcceleration=0
 do m over _modes
   m~step(dt,m~couplingForce)
   _lastVolumeAcceleration+=m~volumeAcceleration
 end
 return self
::method choke
 expose _modes
 do m over _modes
   if m~kind='CYMBAL' then if m~dampingRatio<.85 then m~dampingRatio=.85
 end
 return self
::method setHiHatOpen
 expose _modes _kind _open
 use strict arg fraction
 if _kind<>'HIHAT' then raise syntax 93.900 array('HIHAT voice',self~name)
 if fraction<0 | fraction>1 then raise syntax 88.900 array('hi-hat openness in range 0..1')
 _open=fraction+0
 do m over _modes
   /* Closed hats dissipate rapidly at the plate/contact boundary. */
   m~dampingRatio=.035+(.012-.035)*_open
 end
 return _open

::class DrumAcousticHistorySample public
::method init
 expose _time _voiceAccelerations
 use strict arg timeSeconds,voiceAccelerations
 _time=timeSeconds+0;_voiceAccelerations=voiceAccelerations~copy
::method time; expose _time; return _time
::method voiceAccelerations; expose _voiceAccelerations; return _voiceAccelerations~copy
::method accelerationFor
 expose _voiceAccelerations
 use strict arg voiceName
 if _voiceAccelerations~hasIndex(voiceName) then return _voiceAccelerations[voiceName]
 return 0

::class DrumPressureObservation public
::method init
 expose _time _pressure _contributions _evidence
 use strict arg timeSeconds,pressurePa,contributions,evidence=.nil
 _time=timeSeconds+0;_pressure=pressurePa+0;_contributions=contributions~copy;_evidence=evidence
::method time; expose _time; return _time
::method pressurePa; expose _pressure; return _pressure
::method contributions; expose _contributions; return _contributions~copy
::method evidence; expose _evidence; return _evidence

::class DrumPressurePath public
::method init
 expose _voice _delay _gain
 use strict arg voiceName,delaySeconds,gain
 _voice=voiceName;_delay=delaySeconds+0;_gain=gain+0
::method voiceName; expose _voice; return _voice
::method delaySeconds; expose _delay; return _delay
::method gain; expose _gain; return _gain

::class DrumPressurePlan public
::method init
 expose _listener _paths _evidence _cursors
 use strict arg listenerPosition,paths,evidence=.nil
 _listener=listenerPosition;_paths=paths~copy;_cursors=.directory~new
 if evidence==.nil then _evidence=.directory~new; else _evidence=evidence~copy
 do p over _paths; _cursors[p~voiceName]=1; end
::method listenerPosition; expose _listener; return _listener
::method paths; expose _paths; return _paths~copy
::method pathCount; expose _paths; return _paths~items
::method pathAt
 expose _paths
 use strict arg index
 return _paths[index]
::method evidence; expose _evidence; return _evidence~copy
::method cursor
 expose _cursors
 use strict arg voiceName
 if _cursors~hasIndex(voiceName) then return _cursors[voiceName]
 return 1
::method setCursor
 expose _cursors
 use strict arg voiceName,index
 _cursors[voiceName]=index+0
 return index+0

::class DrumKitContinuationState public
::method init
 expose _time _modeStates _history _hihat
 use strict arg timeSeconds,modeStates,history,hihatStates
 _time=timeSeconds+0;_modeStates=modeStates~copy;_history=history~copy;_hihat=hihatStates~copy
::method time; expose _time; return _time
::method modeStates; expose _modeStates; return _modeStates~copy
::method history; expose _history; return _history~copy
::method hihatStates; expose _hihat; return _hihat~copy

::class DrumKitFreezeParticipant public
::method init
 expose _id _kit
 use strict arg identity,kit
 _id=identity;_kit=kit
::method checkpointIdentity; expose _id; return 'instrument.drum-kit:'_id
::method checkpointSchema; return 'physics.drum-kit-state/0.1'
::method exportContinuationState; expose _kit; return _kit~exportContinuationState
::method restoreContinuationState; expose _kit; use strict arg state; return _kit~restoreContinuationState(state)

::class DrumKitPhysics public
::method init
 expose _voices _time _history _historySeconds _participant _links _pi _allModes
 use strict arg voices,startTimeSeconds=0,historySeconds=10,structuralLinks=.nil
 _voices=voices~copy;_time=startTimeSeconds+0;_history=.queue~new;_historySeconds=historySeconds+0;_participant=.nil;_pi=4*RxCalcArcTan(1,30,'R')
 if structuralLinks==.nil then _links=.array~new; else _links=structuralLinks~copy
 _allModes=.array~new
 do vv over _voices
   do mm over vv~modes; _allModes~append(mm); end
 end
 if _historySeconds<=0 then raise syntax 88.900 array('positive drum acoustic history duration')
 self~recordHistory
::method voices; expose _voices; return _voices~copy
::method time; expose _time; return _time
::method voice
 expose _voices
 use strict arg name
 do v over _voices; if v~name=name then return v; end
 return .nil
::method structuralLinks; expose _links; return _links~copy
::method totalMechanicalEnergy
 expose _voices _links
 e=0; do v over _voices; e+=v~mechanicalEnergy; end
 do link over _links; e+=link~mechanicalEnergy; end
 return e
::method strike
 use strict arg voiceName,impulseNs,radialFraction=.35,rimFraction=0
 v=self~voice(voiceName); if v==.nil then raise syntax 93.900 array('known drum voice',voiceName)
 return v~strike(impulseNs,radialFraction,rimFraction)
::method kick
 use strict arg impulseNs=.65
 return self~strike('kick',impulseNs,.20,0)
::method snare
 use strict arg impulseNs=.22,radialFraction=.30,rimFraction=0
 return self~strike('snare',impulseNs,radialFraction,rimFraction)
::method hiHat
 use strict arg impulseNs=.10,radialFraction=.55
 return self~strike('hihat',impulseNs,radialFraction,0)
::method setHiHatOpen
 use strict arg fraction
 return self~voice('hihat')~setHiHatOpen(fraction)
::method applyUniformAcousticPressure
 expose _voices
 use strict arg pressurePa,dtSeconds
 do v over _voices; v~applyAcousticPressure(pressurePa,dtSeconds); end
 return pressurePa
::method step
 use strict arg dt
 t=self~stepWithoutHistory(dt)
 self~recordHistory
 return t
::method stepWithoutHistory
 expose _voices _time _links _allModes
 use strict arg dt
 if dt<=0 then raise syntax 88.900 array('positive drum kit step',dt)
 do m over _allModes; m~clearCouplingForce; end
 do link over _links
   fa=link~forceOnA
   link~modeA~addCouplingForce(fa)
   link~modeB~addCouplingForce(-fa)
 end
 do v over _voices; v~stepCoupled(dt); end
 _time+=dt
 return _time
::method recordHistory
 expose _voices _time _history _historySeconds
 d=.directory~new
 do v over _voices; d[v~name]=v~volumeAcceleration; end
 _history~queue(.DrumAcousticHistorySample~new(_time,d))
 cutoff=_time-_historySeconds
 do while _history~items>1 & _history[1]~time<cutoff; discard=_history~pull; end
 return _history[_history~items]
::method history; expose _history; return _history~copy
::method sampleVoiceAccelerationAt
 expose _history
 use strict arg voiceName,timeSeconds
 n=_history~items
 if n=0 then return 0
 if timeSeconds<_history[1]~time | timeSeconds>_history[n]~time then return 0
 /* Retarded observations normally query close to the newest sample. Search
  * backward so fixed-distance microphone rendering stays O(delay), not O(history).
  */
 if n=1 then return _history[1]~voiceAccelerations[voiceName]
 nxt=_history[n]
 do i=n-1 to 1 by -1
   prev=_history[i]
   if prev~time<=timeSeconds then do
     a0=prev~voiceAccelerations[voiceName]; a1=nxt~voiceAccelerations[voiceName]
     if nxt~time=prev~time then return a1
     f=(timeSeconds-prev~time)/(nxt~time-prev~time)
     return a0+(a1-a0)*f
   end
   nxt=prev
 end
 return _history[1]~voiceAccelerations[voiceName]
::method pressureAt
 expose _voices _pi
 use strict arg listenerPosition,observationTimeSeconds,acousticSolver
 pressure=0; contributions=.directory~new
 do v over _voices
   delta=listenerPosition-v~position; distance=delta~norm
   if distance<'0.000000001' then iterate
   medium=acousticSolver~mediumForPath(v~position,listenerPosition)
   transmission=acousticSolver~pathSurfaceTransmission(v~position,listenerPosition)
   if transmission=0 then do; contributions[v~name]=0; iterate; end
   emissionTime=observationTimeSeconds-distance/medium~soundSpeed
   qa=self~sampleVoiceAccelerationAt(v~name,emissionTime)
   /* qa is volume acceleration (m^3/s^2), hence p=rho*qa/(4*pi*r). */
   p=medium~density*qa/(4*_pi*distance)*transmission
   contributions[v~name]=p; pressure+=p
 end
 ev=.directory~new;ev['MODEL']='retarded compact radiators';ev['OBSERVATION_TIME']=observationTimeSeconds
 return .DrumPressureObservation~new(observationTimeSeconds,pressure,contributions,ev)
::method preparePressurePlan
 expose _voices _pi
 use strict arg listenerPosition,acousticSolver
 paths=.array~new
 do v over _voices
   delta=listenerPosition-v~position; distance=delta~norm
   if distance<'0.000000001' then iterate
   medium=acousticSolver~mediumForPath(v~position,listenerPosition)
   transmission=acousticSolver~pathSurfaceTransmission(v~position,listenerPosition)
   delay=distance/medium~soundSpeed
   gain=medium~density/(4*_pi*distance)*transmission
   paths~append(.DrumPressurePath~new(v~name,delay,gain))
 end
 ev=.directory~new;ev['MODEL']='fixed-geometry retarded compact-radiator plan';ev['PATH_COUNT']=paths~items
 return .DrumPressurePlan~new(listenerPosition,paths,ev)
::method pressureScalarAtPlan
 expose _history
 use strict arg plan,observationTimeSeconds
 pressure=0;n=_history~items
 do j=1 to plan~pathCount
   path=plan~pathAt(j);emissionTime=observationTimeSeconds-path~delaySeconds;qa=0
   if n>0 & emissionTime>=_history[1]~time & emissionTime<=_history[n]~time then do
     if n=1 then qa=_history[1]~accelerationFor(path~voiceName)
     else do
       ci=plan~cursor(path~voiceName)
       if ci<1 then ci=1
       if ci>=n then ci=n-1
       do while ci>1 & _history[ci]~time>emissionTime;ci-=1;end
       do while ci<n-1 & _history[ci+1]~time<emissionTime;ci+=1;end
       prev=_history[ci];nxt=_history[ci+1]
       a0=prev~accelerationFor(path~voiceName);a1=nxt~accelerationFor(path~voiceName)
       if nxt~time=prev~time then qa=a1
       else qa=a0+(a1-a0)*((emissionTime-prev~time)/(nxt~time-prev~time))
       plan~setCursor(path~voiceName,ci)
     end
   end
   pressure+=qa*path~gain
 end
 return pressure

::method pressureAtPlan
 expose _history
 use strict arg plan,observationTimeSeconds
 pressure=0;contributions=.directory~new;n=_history~items
 do path over plan~paths
   emissionTime=observationTimeSeconds-path~delaySeconds
   qa=0
   if n>0 & emissionTime>=_history[1]~time & emissionTime<=_history[n]~time then do
     if n=1 then qa=_history[1]~accelerationFor(path~voiceName)
     else do
       idx=plan~cursor(path~voiceName)
       if idx<1 then idx=1
       if idx>=n then idx=n-1
       /* A pruned queue or non-monotonic observation can put the cached cursor
          ahead of the requested time. Back up only as far as needed. */
       do while idx>1 & _history[idx]~time>emissionTime; idx-=1; end
       do while idx<n-1 & _history[idx+1]~time<emissionTime; idx+=1; end
       prev=_history[idx];nxt=_history[idx+1]
       a0=prev~accelerationFor(path~voiceName);a1=nxt~accelerationFor(path~voiceName)
       if nxt~time=prev~time then qa=a1
       else do
         f=(emissionTime-prev~time)/(nxt~time-prev~time)
         qa=a0+(a1-a0)*f
       end
       plan~setCursor(path~voiceName,idx)
     end
   end
   p=qa*path~gain
   contributions[path~voiceName]=p;pressure+=p
 end
 ev=plan~evidence;ev['OBSERVATION_TIME']=observationTimeSeconds
 return .DrumPressureObservation~new(observationTimeSeconds,pressure,contributions,ev)

::method attachToWorld
 expose _participant
 use strict arg world,identity='band-kit'
 if _participant<>.nil then return _participant
 _participant=.DrumKitFreezeParticipant~new(identity,self);world~registerFreezeParticipant(_participant);return _participant
::method exportContinuationState
 expose _voices _time _history
 states=.directory~new; hats=.directory~new
 do v over _voices
   a=.array~new
   do m over v~modes
     d=.directory~new;d['X']=m~displacement;d['V']=m~velocity;d['DAMPING']=m~dampingRatio;a~append(d)
   end
   states[v~name]=a
   if v~kind='HIHAT' then hats[v~name]=v~openness
 end
 return .DrumKitContinuationState~new(_time,states,_history,hats)
::method restoreContinuationState
 expose _voices _time _history
 use strict arg state
 states=state~modeStates
 do v over _voices
   if \states~hasIndex(v~name) then raise syntax 93.900 array('drum voice present in checkpoint',v~name)
   a=states[v~name]; modes=v~modes
   if a~items<>modes~items then raise syntax 93.900 array('matching drum mode inventory',v~name)
   do i=1 to modes~items
     modes[i]~setState(a[i]['X'],a[i]['V']); modes[i]~dampingRatio=a[i]['DAMPING']
   end
 end
 _time=state~time;_history=.queue~new; do h over state~history; _history~queue(h); end
 hats=state~hihatStates
 do name over hats; self~voice(name)~setHiHatOpen(hats[name]); end
 return self

::class DrumKitFactory public
::method mode class
 use strict arg name,kind,mass,freq,damping,area,participation=1
 return .DrumModalMode~new(name,kind,mass,freq,damping,area,participation)
::method drumVoice class
 use strict arg name,kind,position,diameterM,depthM,fundamentalHz,withSnares=.false
 pi=4*RxCalcArcTan(1,30,'R'); area=pi*(diameterM/2)**2;m=.array~new
 /* Reduced-order head + shell family.  Effective masses/areas are modal, not gross shell mass. */
 m~append(self~mode(name'.head1','HEAD',.055,fundamentalHz,.018,area*.62,1))
 m~append(self~mode(name'.head2','HEAD',.042,fundamentalHz*1.59,.025,area*.36,.72))
 m~append(self~mode(name'.head3','HEAD',.032,fundamentalHz*2.14,.032,area*.24,.51))
 m~append(self~mode(name'.shell1','SHELL',.35,fundamentalHz*2.75,.045,diameterM*depthM*.16,.22))
 if withSnares then do
   m~append(self~mode(name'.snare1','SNARE_WIRE',.008,185,.070,area*.12,.32))
   m~append(self~mode(name'.snare2','SNARE_WIRE',.006,330,.085,area*.09,.24))
   m~append(self~mode(name'.snare3','SNARE_WIRE',.0045,620,.11,area*.06,.18))
 end
 return .DrumVoice~new(name,kind,position,m)
::method cymbalVoice class
 use strict arg name,kind,position,diameterM,fundamentalHz
 pi=4*RxCalcArcTan(1,30,'R');area=pi*(diameterM/2)**2;m=.array~new
 m~append(self~mode(name'.plate1','CYMBAL',.18,fundamentalHz,.012,area*.45,1))
 m~append(self~mode(name'.plate2','CYMBAL',.12,fundamentalHz*1.73,.010,area*.30,.75))
 m~append(self~mode(name'.plate3','CYMBAL',.085,fundamentalHz*2.61,.009,area*.20,.56))
 m~append(self~mode(name'.plate4','CYMBAL',.060,fundamentalHz*4.18,.008,area*.12,.40))
 return .DrumVoice~new(name,kind,position,m)
::method standardRockKit class
 use strict arg origin=.nil
 if origin==.nil then origin=.MathVector3~new(0,0,0,.Maths~defaultContext)
 c=origin~context; voices=.array~new
 /* x=left/right, y=front/back, z=height relative to floor. */
 voices~append(self~drumVoice('kick','KICK',origin+.MathVector3~new(0,.18,.34,c),.559,.457,58))
 voices~append(self~drumVoice('snare','SNARE',origin+.MathVector3~new(-.38,0,.72,c),.356,.140,185,.true))
 voices~append(self~drumVoice('rackTom10','TOM',origin+.MathVector3~new(-.18,.18,.86,c),.254,.203,145))
 voices~append(self~drumVoice('rackTom12','TOM',origin+.MathVector3~new(.16,.20,.84,c),.305,.229,118))
 voices~append(self~drumVoice('floorTom16','TOM',origin+.MathVector3~new(.48,.02,.66,c),.406,.406,82))
 hh=self~cymbalVoice('hihat','HIHAT',origin+.MathVector3~new(-.55,.05,.92,c),.356,410);hh~setHiHatOpen(.25);voices~append(hh)
 voices~append(self~cymbalVoice('crash16','CYMBAL',origin+.MathVector3~new(-.55,.30,1.18,c),.406,315))
 voices~append(self~cymbalVoice('crash18','CYMBAL',origin+.MathVector3~new(.55,.32,1.20,c),.457,270))
 voices~append(self~cymbalVoice('ride20','CYMBAL',origin+.MathVector3~new(.68,.08,1.02,c),.508,235))
 /* Reduced-order structural graph: rack/floor/stand connections.
  * Links are intentionally weak relative to local modal stiffness and reciprocal.
  */
 byName=.directory~new; do v over voices; byName[v~name]=v; end
 links=.array~new
 links~append(.DrumStructuralLink~new('rack10-kick',byName['rackTom10']~modes[4],byName['kick']~modes[4],18,.055))
 links~append(.DrumStructuralLink~new('rack12-kick',byName['rackTom12']~modes[4],byName['kick']~modes[4],18,.055))
 links~append(.DrumStructuralLink~new('snare-floor',byName['snare']~modes[4],byName['floorTom16']~modes[4],7,.030))
 links~append(.DrumStructuralLink~new('floor-kick',byName['floorTom16']~modes[4],byName['kick']~modes[4],9,.035))
 links~append(.DrumStructuralLink~new('hihat-snare',byName['hihat']~modes[1],byName['snare']~modes[4],2.2,.012))
 links~append(.DrumStructuralLink~new('crash16-rack10',byName['crash16']~modes[1],byName['rackTom10']~modes[4],1.6,.010))
 links~append(.DrumStructuralLink~new('crash18-floor',byName['crash18']~modes[1],byName['floorTom16']~modes[4],1.6,.010))
 links~append(.DrumStructuralLink~new('ride-floor',byName['ride20']~modes[1],byName['floorTom16']~modes[4],1.3,.009))
 return .DrumKitPhysics~new(voices,0,10,links)

::requires 'PhysicsWorld.cls'
::requires 'Acoustics.cls'


/* Fixed-listener real-time pressure observer.  This is the same compact-
 * radiator pressure model as pressureAt/preparePressurePlan, but it keeps
 * only the short causal delay state required by a fixed microphone instead
 * of allocating general acoustic-history samples at audio rate. */
::class DrumFixedMicPathState public
::method init
 expose _voice _gain _delayFloor _frac _buffer _cursor _filled
 use strict arg voice,gain,delaySamples
 _voice=voice; _gain=gain+0
 _delayFloor=delaySamples~floor; _frac=delaySamples-_delayFloor
 n=_delayFloor+3; if n<4 then n=4
 _buffer=.array~new(n); do i=1 to n; _buffer[i]=0; end
 _cursor=0; _filled=0
::method nextPressure
 expose _voice _gain _delayFloor _frac _buffer _cursor _filled
 _cursor+=1; if _cursor>_buffer~items then _cursor=1
 _buffer[_cursor]=_voice~volumeAcceleration
 if _filled<_buffer~items then _filled+=1
 idx0=_cursor-_delayFloor
 do while idx0<1; idx0+=_buffer~items; end
 idx1=idx0-1; if idx1<1 then idx1=_buffer~items
 /* Before enough source samples exist, causal history is zero. */
 if _filled<=_delayFloor then return 0
 q0=_buffer[idx0]; q1=_buffer[idx1]
 return _gain*(q0*(1-_frac)+q1*_frac)

::class DrumFixedMicStream public
::method init
 expose _paths
 use strict arg kit,pressurePlan,sampleRate
 _paths=.array~new
 do i=1 to pressurePlan~pathCount
   p=pressurePlan~pathAt(i); v=kit~voice(p~voiceName)
   _paths~append(.DrumFixedMicPathState~new(v,p~gain,p~delaySeconds*sampleRate))
 end
::method nextPressure
 expose _paths
 p=0; do path over _paths; p+=path~nextPressure; end
 return p

::requires 'rxmath' LIBRARY
