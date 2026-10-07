/* Physics World v0.1-dev42
 * Multi-string guitar mechanical instrument.
 * Shared nut/bridge/body boundary; no pickup/circuit/audio inference.
 */
numeric digits 30

::class GuitarStringCourse public
::method init
 expose _name _model _fret _pluck _pickup _oscillators
 use strict arg name,stringModel,fret=0,pluckFraction=.18,pickupPositionFraction=.82
 _name=name;_model=stringModel;_fret=fret+0;_pluck=pluckFraction+0;_pickup=pickupPositionFraction+0
 _oscillators=.array~new
::method name; expose _name; return _name
::method stringModel; expose _model; return _model
::method fret; expose _fret; return _fret
::method pluckFraction; expose _pluck; return _pluck
::method pickupPositionFraction; expose _pickup; return _pickup
::method oscillators; expose _oscillators; return _oscillators~copy
::method addOscillator; expose _oscillators; use strict arg oscillator; _oscillators~append(oscillator); return oscillator
::method displacementAt
 expose _oscillators
 use strict arg positionFraction
 pi=4*RxCalcArcTan(1,30,'R'); y=0;n=0
 do q over _oscillators
   n+=1;y+=q~displacement*RxCalcSin(pi*n*positionFraction,30,'R')
 end
 return y
::method velocityAt
 expose _oscillators
 use strict arg positionFraction
 pi=4*RxCalcArcTan(1,30,'R'); v=0;n=0
 do q over _oscillators
   n+=1;v+=q~velocity*RxCalcSin(pi*n*positionFraction,30,'R')
 end
 return v
::method mechanicalEnergy
 expose _oscillators
 e=0;do q over _oscillators;e+=q~mechanicalEnergy;end;return e

::class GuitarBoundaryImpedance public
::method init
 expose _name _stiffness _damping _participation _evidence
 use strict arg name,stiffnessNPerM,dampingNsPerM=0,participation=1,evidence=.nil
 if stiffnessNPerM<0 | dampingNsPerM<0 then raise syntax 88.900 array('non-negative guitar boundary impedance')
 _name=name;_stiffness=stiffnessNPerM+0;_damping=dampingNsPerM+0;_participation=participation+0;_evidence=evidence
::method name; expose _name; return _name
::method stiffness; expose _stiffness; return _stiffness
::method damping; expose _damping; return _damping
::method participation; expose _participation; return _participation
::method evidence; expose _evidence; return _evidence

::class GuitarInstrumentMechanics public
::method init
 expose _courses _body _bridge _nut _time _ledger _pi
 use strict arg courses,bodyOscillators,bridgeImpedance,nutImpedance=.nil,startTimeSeconds=0
 _courses=courses~copy;_body=bodyOscillators~copy;_bridge=bridgeImpedance;_nut=nutImpedance
 _time=startTimeSeconds+0;_ledger=.array~new;_pi=.Maths~pi(.Maths~defaultContext)
::method courses; expose _courses; return _courses~copy
::method bodyModes; expose _body; return _body~copy
::method time; expose _time; return _time
::method ledger; expose _ledger; return _ledger~copy
::method bridgeImpedance; expose _bridge; return _bridge
::method nutImpedance; expose _nut; return _nut
::method setTime; expose _time; use strict arg value; _time=value+0; return _time
::method recordDynamicsEvidence
 expose _ledger _time
 use strict arg evidence,dt,steps,method
 ev=.directory~new;ev['TIME']=_time;ev['KIND']='MATHS_SECOND_ORDER_DYNAMICS';ev['DT']=dt;ev['STEPS']=steps;ev['METHOD']=method;ev['MATHS_EVIDENCE']=evidence
 _ledger~append(ev);return ev
::method course
 expose _courses
 use strict arg name
 do c over _courses;if c~name=name then return c;end
 return .nil
::method bodyDisplacement
 expose _body
 x=0;do b over _body;x+=b~displacement;end;return x
::method bodyVelocity
 expose _body
 v=0;do b over _body;v+=b~velocity;end;return v
::method totalMechanicalEnergy
 expose _courses _body _bridge
 e=0
 do c over _courses;e+=c~mechanicalEnergy;end
 do b over _body;e+=b~mechanicalEnergy;end
 /* shared bridge spring energy is represented once */
 xs=0;do c over _courses;xs+=c~displacementAt(.999);end
 xb=self~bodyDisplacement
 e+=_bridge~stiffness*(xs-_bridge~participation*xb)**2/2
 return e
::method step
 expose _courses _body _bridge _nut _time _ledger _pi
 use strict arg dt
 if dt<=0 then raise syntax 88.900 array('positive guitar instrument step',dt)
 before=self~totalMechanicalEnergy
 xb=self~bodyDisplacement;vb=self~bodyVelocity
 bridgeNet=0
 /* Each string sees the same body bridge displacement, but its own endpoint
    displacement/velocity. Equal/opposite force is accumulated onto the body. */
 do c over _courses
   xs=c~displacementAt(.999);vs=c~velocityAt(.999)
   relx=xs-_bridge~participation*xb;relv=vs-_bridge~participation*vb
   fb=-_bridge~stiffness*relx-_bridge~damping*relv
   bridgeNet-=fb*_bridge~participation
   n=0
   do q over c~oscillators
     n+=1
     shape=RxCalcSin(_pi*n*.999,30,'R')
     f=-q~stiffness*q~displacement-q~dampingCoefficient*q~velocity+fb*shape
     /* optional nut loss/constraint is local to the opposite endpoint */
     if _nut<>.nil then do
       nutShape=RxCalcSin(_pi*n*.001,30,'R')
       xn=q~displacement*nutShape;vn=q~velocity*nutShape
       f+=(-_nut~stiffness*xn-_nut~damping*vn)*nutShape
     end
     v=q~velocity+dt*f/q~mass;x=q~displacement+dt*v;q~setState(x,v)
   end
 end
 do b over _body
   f=-b~stiffness*b~displacement-b~dampingCoefficient*b~velocity+bridgeNet
   v=b~velocity+dt*f/b~mass;x=b~displacement+dt*v;b~setState(x,v)
 end
 _time+=dt
 after=self~totalMechanicalEnergy
 ev=.directory~new;ev['TIME']=_time;ev['ENERGY_BEFORE_J']=before;ev['ENERGY_AFTER_J']=after;ev['BRIDGE_FORCE_N']=bridgeNet
 _ledger~append(ev);return ev

::class GuitarInstrumentFactory public
::method standardSixString class
 use strict arg stringModels,frets,bodyModes,bridgeImpedance,nutImpedance=.nil,pluckCourse=1,pluckDisplacementM=.0008,pluckFraction=.18
 if stringModels~items<>6 | frets~items<>6 then raise syntax 88.900 array('six string models and fret states required')
 names=.array~of('E2','A2','D3','G3','B3','E4');courses=.array~new;pi=.Maths~pi(.Maths~defaultContext)
 do i=1 to 6
   c=.GuitarStringCourse~new(names[i],stringModels[i],frets[i],pluckFraction,.82)
   do n=1 to stringModels[i]~modeCount
     amp=0;if i=pluckCourse then amp=stringModels[i]~modalAmplitude(n,pluckFraction,pluckDisplacementM)
     w=stringModels[i]~modalAngularFrequency(frets[i],n,0)
     mass=stringModels[i]~modalEffectiveMass(frets[i],n);z=stringModels[i]~modalDamping(n,'PICK')/w
     c~addOscillator(.GuitarCoupledOscillator~new(names[i]'-'n,mass,w/(2*pi),z,amp,0,'STRING_MODE',stringModels[i]))
   end
   courses~append(c)
 end
 bodies=.array~new
 do bm over bodyModes
   bodies~append(.GuitarCoupledOscillator~new(bm~name,bm~effectiveMass,bm~frequencyHz,bm~dampingRatio,0,0,'BODY_MODE',bm))
 end
 return .GuitarInstrumentMechanics~new(courses,bodies,bridgeImpedance,nutImpedance)

::requires 'rxmath' LIBRARY
::requires 'GuitarCoupledBoundary.cls'
::requires 'MathsBootstrap.cls'
