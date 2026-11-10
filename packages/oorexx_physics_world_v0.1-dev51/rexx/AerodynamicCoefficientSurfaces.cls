/* Physics World dev25: bounded bilinear aerodynamic coefficient surfaces.
   Rows are first-coordinate (e.g. alpha), columns second-coordinate (e.g. Mach).
   No extrapolation beyond the supplied qualification rectangle. */
::class AerodynamicCoefficientSurface2D public
::method init
 expose _x _y _v
 use strict arg firstCoordinates,secondCoordinates,valueRows
 if firstCoordinates~items<2 | secondCoordinates~items<2 then raise syntax 88.900 array('at least two coordinates per aerodynamic surface axis required')
 if valueRows~items<>firstCoordinates~items then raise syntax 88.900 array('surface row count must match first axis')
 do i=1 to firstCoordinates~items
   if i>1 then do; p=i-1; if firstCoordinates[i]<=firstCoordinates[p] then raise syntax 88.900 array('first axis must increase strictly'); end
   if valueRows[i]~items<>secondCoordinates~items then raise syntax 88.900 array('surface column count must match second axis')
 end
 do j=2 to secondCoordinates~items
   p=j-1
   if secondCoordinates[j]<=secondCoordinates[p] then raise syntax 88.900 array('second axis must increase strictly')
 end
 _x=firstCoordinates~copy; _y=secondCoordinates~copy; _v=valueRows~copy

::method evaluate
 expose _x _y _v
 use strict arg x,y
 if x<_x[1] | x>_x[_x~items] | y<_y[1] | y>_y[_y~items] then raise syntax 88.900 array('aerodynamic surface lookup outside qualified domain')
 xi=self~lowerIndex(_x,x); yi=self~lowerIndex(_y,y)
 x1=_x[xi]; x2=_x[xi+1]; y1=_y[yi]; y2=_y[yi+1]
 fx=(x-x1)/(x2-x1); fy=(y-y1)/(y2-y1)
 v11=_v[xi][yi]; v12=_v[xi][yi+1]; v21=_v[xi+1][yi]; v22=_v[xi+1][yi+1]
 low=v11+fy*(v12-v11); high=v21+fy*(v22-v21)
 return low+fx*(high-low)

::method lowerIndex private
 use strict arg axis,value
 if value=axis[axis~items] then return axis~items-1
 do i=1 to axis~items-1
   if value>=axis[i] & value<=axis[i+1] then return i
 end
 raise syntax 88.900 array('surface interval lookup failed')

::class LongitudinalAerodynamicSurfaceModel public
::method init
 expose _cl _cd _cm _area _chord
 use strict arg liftSurface,dragSurface,pitchMomentSurface,referenceArea,referenceChord
 if referenceArea<=0 | referenceChord<=0 then raise syntax 88.900 array('positive aerodynamic reference area/chord required')
 _cl=liftSurface; _cd=dragSurface; _cm=pitchMomentSurface; _area=referenceArea+0; _chord=referenceChord+0
::method evaluate
 expose _cl _cd _cm _area _chord
 use strict arg state
 a=state~angleOfAttack; m=state~mach
 cl=_cl~evaluate(a,m); cd=_cd~evaluate(a,m); cm=_cm~evaluate(a,m); q=state~dynamicPressure
 return .LongitudinalAerodynamicSurfaceObservation~new(cl,cd,cm,q,q*_area*cl,q*_area*cd,q*_area*_chord*cm)
::class LongitudinalAerodynamicSurfaceObservation public
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
::requires 'AerodynamicCoefficientTables.cls'
