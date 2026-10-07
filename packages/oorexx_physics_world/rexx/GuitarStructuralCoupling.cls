/* Physics World v0.1-dev40
 * Reduced-order string -> bridge -> guitar body energy coupling.
 * Mechanical authority only. Electrical pickup conversion remains Rexx-tronics.
 */
numeric digits 30

::class GuitarBodyMode public
::method init
 expose _name _frequency _mass _damping _area _participation
 use strict arg name,frequencyHz,effectiveMassKg,dampingRatio,radiatingAreaM2,bridgeParticipation=1
 if frequencyHz<=0 | effectiveMassKg<=0 | dampingRatio<0 | dampingRatio>=1 | radiatingAreaM2<=0 then raise syntax 88.900 array('valid guitar body mode parameters')
 _name=name;_frequency=frequencyHz+0;_mass=effectiveMassKg+0;_damping=dampingRatio+0;_area=radiatingAreaM2+0;_participation=bridgeParticipation+0
::method name; expose _name; return _name
::method frequencyHz; expose _frequency; return _frequency
::method effectiveMass; expose _mass; return _mass
::method dampingRatio; expose _damping; return _damping
::method radiatingArea; expose _area; return _area
::method bridgeParticipation; expose _participation; return _participation

::class GuitarBodyModeResponse public
::method init
 expose _mode _start _velocity _source _evidence _omegaNatural _omegaDamped
 use strict arg mode,startTimeSeconds,initialVelocity,sourcePosition,evidence=.nil
 _mode=mode;_start=startTimeSeconds+0;_velocity=initialVelocity+0;_source=sourcePosition;_evidence=evidence
 pi=.Maths~pi(.Maths~defaultContext);_omegaNatural=2*pi*_mode~frequencyHz;_omegaDamped=_omegaNatural*RxCalcSqrt(1-_mode~dampingRatio*_mode~dampingRatio)
::method mode; expose _mode; return _mode
::method startTime; expose _start; return _start
::method sourcePosition; expose _source; return _source
::method evidence; expose _evidence; return _evidence
::method initialVelocity; expose _velocity; return _velocity
::method omegaNatural; expose _omegaNatural; return _omegaNatural
::method omegaDamped; expose _omegaDamped; return _omegaDamped
::method displacementAfter
 use strict arg elapsed
 if elapsed<0 then return 0
 wn=self~omegaNatural;wd=self~omegaDamped;z=self~mode~dampingRatio
 return (self~initialVelocity/wd)*RxCalcExp(-z*wn*elapsed,30)*RxCalcSin(wd*elapsed,30,'R')
::method velocityAfter
 use strict arg elapsed
 if elapsed<0 then return 0
 wn=self~omegaNatural;wd=self~omegaDamped;z=self~mode~dampingRatio
 e=RxCalcExp(-z*wn*elapsed,30)
 return self~initialVelocity*e*(RxCalcCos(wd*elapsed,30,'R')-(z*wn/wd)*RxCalcSin(wd*elapsed,30,'R'))
::method accelerationAfter
 use strict arg elapsed
 if elapsed<0 then return 0
 wn=self~omegaNatural;z=self~mode~dampingRatio
 return -2*z*wn*self~velocityAfter(elapsed)-wn*wn*self~displacementAfter(elapsed)
::method volumeVelocityAfter
 use strict arg elapsed
 return self~mode~radiatingArea*self~velocityAfter(elapsed)
::method volumeAccelerationAfter
 use strict arg elapsed
 return self~mode~radiatingArea*self~accelerationAfter(elapsed)
::method initialMechanicalEnergy
 return self~mode~effectiveMass*self~initialVelocity*self~initialVelocity/2

::class GuitarBridgeCoupling public
::method init
 expose _transfer _bodyModes _sourcePosition _name
 use strict arg name,energyTransferFraction,bodyModes,sourcePosition
 if energyTransferFraction<0 | energyTransferFraction>1 then raise syntax 88.900 array('bridge energy transfer fraction in [0,1]',energyTransferFraction)
 _name=name;_transfer=energyTransferFraction+0;_bodyModes=bodyModes~copy;_sourcePosition=sourcePosition
::method name; expose _name; return _name
::method energyTransferFraction; expose _transfer; return _transfer
::method bodyModes; expose _bodyModes; return _bodyModes~copy
::method sourcePosition; expose _sourcePosition; return _sourcePosition

::method exciteFromString
 expose _transfer _bodyModes _sourcePosition _name
 use strict arg stringModel,fret,pluckDisplacementM=.0008,pluckFraction=.18,articulation='PICK',bendSemitones=0,startTimeSeconds=0
 /* Initial string energy: integrate the modal initial kinetic/potential state
    represented by the same triangular-pluck coefficients used by the string model.
    At t=0 modal velocities are zero, so modal potential energy is sufficient. */
 pi=.Maths~pi(.Maths~defaultContext)
 stringEnergy=0
 do n=1 to stringModel~modeCount
   q=stringModel~modalAmplitude(n,pluckFraction,pluckDisplacementM)
   w=stringModel~modalAngularFrequency(fret,n,bendSemitones)
   m=stringModel~modalEffectiveMass(fret,n)
   stringEnergy += m*w*w*q*q/2
 end
 transferred=stringEnergy*_transfer
 weights=0
 do mode over _bodyModes; weights += abs(mode~bridgeParticipation); end
 if transferred>0 & weights=0 then raise syntax 93.900 array('non-zero bridge transfer requires participating guitar body modes')
 out=.array~new;allocated=0
 do mode over _bodyModes
   if weights=0 then iterate
   e=transferred*abs(mode~bridgeParticipation)/weights
   v=RxCalcSqrt(2*e/mode~effectiveMass)
   /* RxMath is a bounded-precision numerical evaluator; rescale the computed
      velocity once so the modal energy does not numerically exceed its budget. */
   actual=mode~effectiveMass*v*v/2
   if actual>e then v=v*RxCalcSqrt(e/actual)
   ev=.directory~new
   ev['MODEL']='GUITAR_BRIDGE_ENERGY_PARTITION'
   ev['BRIDGE']=_name
   ev['STRING_INITIAL_ENERGY_J']=stringEnergy
   ev['TRANSFERRED_ENERGY_J']=transferred
   ev['MODE_ALLOCATED_ENERGY_J']=e
   ev['ARTICULATION']=articulation
   response=.GuitarBodyModeResponse~new(mode,startTimeSeconds,v,_sourcePosition,ev)
   allocated += response~initialMechanicalEnergy
   out~append(response)
 end
 tolerance=transferred*1E-6+1E-12
 if allocated>transferred+tolerance then raise syntax 93.900 array('guitar body modal allocation exceeds transferred string energy')
 return .GuitarBridgeExcitation~new(stringEnergy,transferred,allocated,out,self)

::class GuitarBridgeExcitation public
::method init
 expose _stringEnergy _transferred _allocated _responses _bridge
 use strict arg stringEnergyJ,transferredEnergyJ,allocatedEnergyJ,responses,bridge
 _stringEnergy=stringEnergyJ;_transferred=transferredEnergyJ;_allocated=allocatedEnergyJ;_responses=responses~copy;_bridge=bridge
::method stringInitialEnergy; expose _stringEnergy; return _stringEnergy
::method transferredEnergy; expose _transferred; return _transferred
::method allocatedBodyEnergy; expose _allocated; return _allocated
::method retainedStringEnergy; expose _stringEnergy _transferred; return _stringEnergy-_transferred
::method responses; expose _responses; return _responses~copy
::method bridge; expose _bridge; return _bridge
::method energyResidual; expose _transferred _allocated; return _transferred-_allocated

::requires 'rxmath' LIBRARY
::requires 'GuitarStringMagnetics.cls'

::requires 'MathsBootstrap.cls'
