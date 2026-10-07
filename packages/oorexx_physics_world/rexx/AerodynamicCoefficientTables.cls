/* Physics World dev24: explicit tabulated aerodynamic coefficient authority.
   No aircraft/part identity implies coefficients. Independent variables are
   supplied explicitly by the caller. */
::class AerodynamicCoefficientTable1D public
::method init
 expose _x _y
 use strict arg coordinates,values
 if coordinates~items<2 | coordinates~items<>values~items then raise syntax 88.900 array('matching coefficient table arrays with at least two points required')
 do i=1 to coordinates~items
   if i>1 then do
     previous=i-1
     if coordinates[i]<=coordinates[previous] then raise syntax 88.900 array('coefficient table coordinates must increase strictly')
   end
 end
 _x=coordinates~copy; _y=values~copy
::method evaluate
 expose _x _y
 use strict arg coordinate
 if coordinate<_x[1] | coordinate>_x[_x~items] then raise syntax 88.900 array('coefficient lookup outside qualified table domain')
 if coordinate=_x[_x~items] then return _y[_y~items]
 do i=1 to _x~items-1
   if coordinate>=_x[i] & coordinate<=_x[i+1] then do
     f=(coordinate-_x[i])/(_x[i+1]-_x[i])
     return _y[i]+f*(_y[i+1]-_y[i])
   end
 end
 raise syntax 88.900 array('coefficient lookup failed')

::class AerodynamicOperatingState public
::method init
 expose _alpha _beta _mach _speed _rho
 use strict arg angleOfAttack,sideslipAngle,mach,relativeSpeed,airDensity
 if mach<0 | relativeSpeed<0 | airDensity<=0 then raise syntax 88.900 array('valid aerodynamic operating state required')
 _alpha=angleOfAttack+0; _beta=sideslipAngle+0; _mach=mach+0; _speed=relativeSpeed+0; _rho=airDensity+0
::method angleOfAttack; expose _alpha; return _alpha
::method sideslipAngle; expose _beta; return _beta
::method mach; expose _mach; return _mach
::method relativeSpeed; expose _speed; return _speed
::method airDensity; expose _rho; return _rho
::method dynamicPressure; expose _speed _rho; return _rho*_speed*_speed/2

::class LongitudinalAerodynamicTableModel public
::method init
 expose _cl _cd _cm _area _chord
 use strict arg liftCoefficientTable,dragCoefficientTable,pitchMomentCoefficientTable,referenceArea,referenceChord
 if referenceArea<=0 | referenceChord<=0 then raise syntax 88.900 array('positive aerodynamic reference area/chord required')
 _cl=liftCoefficientTable; _cd=dragCoefficientTable; _cm=pitchMomentCoefficientTable; _area=referenceArea+0; _chord=referenceChord+0
::method evaluate
 expose _cl _cd _cm _area _chord
 use strict arg state
 a=state~angleOfAttack
 cl=_cl~evaluate(a); cd=_cd~evaluate(a); cm=_cm~evaluate(a)
 q=state~dynamicPressure
 return .LongitudinalAerodynamicTableObservation~new(cl,cd,cm,q,q*_area*cl,q*_area*cd,q*_area*_chord*cm)

::class LongitudinalAerodynamicTableObservation public
::method init
 expose _cl _cd _cm _q _lift _drag _moment
 use strict arg cl,cd,cm,dynamicPressure,lift,drag,pitchMoment
 _cl=cl;_cd=cd;_cm=cm;_q=dynamicPressure;_lift=lift;_drag=drag;_moment=pitchMoment
::method liftCoefficient; expose _cl; return _cl
::method dragCoefficient; expose _cd; return _cd
::method pitchMomentCoefficient; expose _cm; return _cm
::method dynamicPressure; expose _q; return _q
::method lift; expose _lift; return _lift
::method drag; expose _drag; return _drag
::method pitchMoment; expose _moment; return _moment
