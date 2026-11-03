/* ooRexx Physics World v0.1-dev17
   Deterministic aerodynamic rigid-body flight experiments.
   The experiment composes Mechanics + RigidBodyAerodynamics; it does not own
   catalogue identity or aerodynamic coefficient truth. */
::class AerodynamicFlightSample public
::method init
 expose _time _position _velocity _orientation _omega _aero
 use strict arg time,position,velocity,orientation,angularVelocity,aerodynamicObservation
 _time=time; _position=position; _velocity=velocity; _orientation=orientation; _omega=angularVelocity; _aero=aerodynamicObservation
::method time; expose _time; return _time
::method position; expose _position; return _position
::method velocity; expose _velocity; return _velocity
::method orientation; expose _orientation; return _orientation
::method angularVelocity; expose _omega; return _omega
::method aerodynamicObservation; expose _aero; return _aero

::class AerodynamicFlightExperiment public
::method init
 expose _body _aero _gravity _time _history
 use strict arg rigidBody,aerodynamicBody,gravity=.nil,startTime=0
 _body=rigidBody; _aero=aerodynamicBody; _time=startTime+0; _history=.array~new
 if gravity==.nil then gravity=.MathVector3~new(0,0,'-9.80665',rigidBody~body~pose~context)
 _gravity=gravity
::method body; expose _body; return _body
::method aerodynamicBody; expose _aero; return _aero
::method time; expose _time; return _time
::method history; expose _history; return _history
::method step
 expose _body _aero _gravity _time _history
 use strict arg dt
 if dt<=0 then raise syntax 88.900 array('positive flight timestep',dt)
 observation=_aero~apply
 _body~integrate(dt,_gravity)
 _time=_time+dt
 sample=.AerodynamicFlightSample~new(_time,_body~position,_body~velocity,_body~orientation,_body~angularVelocity,observation)
 _history~append(sample)
 return sample
::method run
 use strict arg duration,dt
 if duration<0 then raise syntax 88.900 array('non-negative duration',duration)
 steps=trunc(duration/dt)
 do steps; self~step(dt); end
 return self~history
::method runUntilGround
 use strict arg dt,maxDuration,groundZ=0
 if maxDuration<=0 then raise syntax 88.900 array('positive maximum duration',maxDuration)
 do while self~time<maxDuration
   s=self~step(dt)
   if s~position~z<=groundZ then return s
 end
 return .nil

::class RugbyBallFlightFactory public
/* The caller supplies a Parts-style sports-ball projection and explicit
   aerodynamic coefficient model. Local +Y is the ball's long axis. */
::method create class
 use strict arg projection,position,velocity,orientation,angularVelocity,airDensity,coefficientModel,windVelocity=.nil,gravity=.nil
 mass=self~massKg(projection['MASS'])
 length=.SportsBallAerodynamicProjection~lengthMetres(projection['LENGTH'])
 circumference=.SportsBallAerodynamicProjection~lengthMetres(projection['MAX_CIRCUMFERENCE'])
 pi=4*RxCalcArcTan(1,30,'R'); radius=(circumference/pi)/2
 context=position~context
 physical=.PhysicalBody~new(projection['PART_DEFINITION_ID'],.SphereShape~new(radius),.PhysicalPose~new(position,orientation,context))
 /* Prolate-body reference inertia. Local Y is the long axis. */
 transverseRadius=radius; semiLength=length/2
 iy=2*mass*transverseRadius*transverseRadius/5
 ix=mass*(transverseRadius*transverseRadius+semiLength*semiLength)/5
 inertia=.MechanicsMassProperties~new(mass,ix,iy,ix)
 state=.RigidBodyState~new(physical,inertia,velocity,angularVelocity)
 aero=.SportsBallAerodynamicProjection~createRugbyLeague(projection,state,airDensity,coefficientModel,windVelocity)
 return .AerodynamicFlightExperiment~new(state,aero,gravity)
::method massKg class
 use strict arg value
 if value~isA(.UnitQuantity) then return value~canonicalValue
 s=value~string~strip; parse var s number unit
 select
   when unit~upper='G' then return number/1000
   when unit~upper='KG' | unit='' then return number+0
   otherwise raise syntax 93.900 array('unsupported projected mass',value)
 end

::requires 'RigidBodyAerodynamics.cls'
