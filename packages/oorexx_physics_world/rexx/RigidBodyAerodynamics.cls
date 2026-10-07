/* ooRexx Physics World v0.1-dev16 - orientation-sensitive rigid-body aerodynamics. */
::class AerodynamicCoefficientModel public
::method coefficients; use strict arg state; raise syntax 93.900 array('AerodynamicCoefficientModel~coefficients must be implemented')
::class AxialAerodynamicCoefficientModel subclass AerodynamicCoefficientModel public
::method init
 expose _ca _cb _cl _cm
 use strict arg axialDrag,broadsideDrag,spinLiftCoefficient=0,spinDampingCoefficient=0
 if axialDrag<0 | broadsideDrag<0 | spinLiftCoefficient<0 | spinDampingCoefficient<0 then raise syntax 88.900 array('non-negative aerodynamic coefficients')
 _ca=axialDrag+0; _cb=broadsideDrag+0; _cl=spinLiftCoefficient+0; _cm=spinDampingCoefficient+0
::method coefficients
 expose _ca _cb _cl _cm
 use strict arg state
 d=.directory~new; s=state~broadsideFraction; d['CD']=_ca+(_cb-_ca)*s; d['CL_SPIN']=_cl; d['CM_SPIN']=_cm; return d
::class AerodynamicBodyModel public
::method init
 expose _body _axis _length _diameter _rho _wind _coeff
 use strict arg rigidBody,axisLocal,length,maximumDiameter,airDensity,coefficientModel,windVelocity=.nil
 if length<=0 | maximumDiameter<=0 | airDensity<=0 then raise syntax 88.900 array('positive aerodynamic dimensions and air density')
 _body=rigidBody; _axis=axisLocal~normalized; _length=length+0; _diameter=maximumDiameter+0; _rho=airDensity+0; _coeff=coefficientModel
 if windVelocity==.nil then windVelocity=.MathVector3~new(0,0,0,rigidBody~body~pose~context)
 _wind=windVelocity
::method body; expose _body; return _body
::method axisWorld; expose _axis; return self~body~body~pose~directionToWorld(_axis)
::method relativeAirVelocity; expose _wind; return self~body~velocity-_wind
::method speed; return self~relativeAirVelocity~norm
::method broadsideFraction
 v=self~relativeAirVelocity; n=v~norm
 if n<'0.000000000001' then return 0
 c=abs(self~axisWorld~dot(v*(1/n))); return 1-c*c
::method projectedArea
 expose _length _diameter
 pi=4*RxCalcArcTan(1,30,'R'); ae=pi*_diameter*_diameter/4; as=_length*_diameter; s=self~broadsideFraction
 return ae+(as-ae)*s
::method dynamicPressure; expose _rho; v=self~speed; return _rho*v*v/2
::method force
 expose _coeff
 v=self~relativeAirVelocity; n=v~norm
 if n<'0.000000000001' then return v*0
 c=_coeff~coefficients(self); drag=(v*(-1/n))*(self~dynamicPressure*self~projectedArea*c['CD']); lift=v*0
 omega=self~body~angularVelocity
 if omega~norm>'0.000000000001' & c['CL_SPIN']<>0 then do
  transverse=omega~cross(v)
  if transverse~norm>'0.000000000001' then lift=transverse~normalized*(self~dynamicPressure*self~projectedArea*c['CL_SPIN'])
 end
 return drag+lift
::method torque
 expose _coeff _diameter
 c=_coeff~coefficients(self); omega=self~body~angularVelocity
 if omega~norm<'0.000000000001' | c['CM_SPIN']=0 then return omega*0
 return omega~normalized*(-self~dynamicPressure*self~projectedArea*_diameter*c['CM_SPIN'])
::method apply
 f=self~force; t=self~torque; self~body~applyForce(f); self~body~applyTorque(t)
 return .AerodynamicObservation~new(self~speed,self~broadsideFraction,self~projectedArea,self~dynamicPressure,f,t)
::class AerodynamicObservation public
::method init
 expose _speed _broadside _area _q _force _torque
 use strict arg relativeSpeed,broadsideFraction,projectedArea,dynamicPressure,force,torque
 _speed=relativeSpeed; _broadside=broadsideFraction; _area=projectedArea; _q=dynamicPressure; _force=force; _torque=torque
::method relativeSpeed; expose _speed; return _speed
::method broadsideFraction; expose _broadside; return _broadside
::method projectedArea; expose _area; return _area
::method dynamicPressure; expose _q; return _q
::method force; expose _force; return _force
::method torque; expose _torque; return _torque
::class SportsBallAerodynamicProjection public
::method createRugbyLeague class
 use strict arg projection,rigidBody,airDensity,coefficientModel,windVelocity=.nil
 length=self~lengthMetres(projection['LENGTH']); circumference=self~lengthMetres(projection['MAX_CIRCUMFERENCE']); pi=4*RxCalcArcTan(1,30,'R')
 return .AerodynamicBodyModel~new(rigidBody,.MathVector3~new(0,1,0,rigidBody~body~pose~context),length,circumference/pi,airDensity,coefficientModel,windVelocity)
::method lengthMetres class
 use strict arg value
 if value~isA(.UnitQuantity) then return value~canonicalValue
 s=value~string~strip; parse var s number unit
 select
  when unit~upper='MM' then return number/1000
  when unit~upper='CM' then return number/100
  when unit~upper='M' | unit='' then return number+0
  otherwise raise syntax 93.900 array('unsupported projected length',value)
 end
::requires 'Mechanics.cls'
