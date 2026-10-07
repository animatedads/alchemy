/* Explicit survey constraints for Photo Survey World v0.1-dev6.
   Constraints are evidence supplied to the solver; they are not image guesses. */

::class SurveyConstraint public
::method init
  expose _id _kind _weight _notes
  use strict arg id,kind,weight='1.0',notes=''
  _id=id; _kind=kind~upper; _weight=weight; _notes=notes
::method id; expose _id; return _id
::method kind; expose _kind; return _kind
::method weight; expose _weight; return _weight
::method notes; expose _notes; return _notes
::method residual abstract

::class SurveyPointDistanceConstraint subclass SurveyConstraint public
::method init
  expose _a _b _distance
  use strict arg id,a,b,distance,weight='1.0',notes=''
  self~init:super(id,'POINT_DISTANCE',weight,notes)
  _a=a; _b=b; _distance=distance
::method residual
  expose _a _b _distance
  d=_b~position-_a~position
  actual=.Maths~sqrt(d~x*d~x+d~y*d~y+d~z*d~z,_a~position~context)
  return actual-_distance

::class SurveySameStationConstraint subclass SurveyConstraint public
::method init
  expose _station _firstUnit _secondUnit _expected
  use strict arg id,station,firstUnit,secondUnit,expected,weight='1.0',notes=''
  self~init:super(id,'SAME_STATION_BASELINE',weight,notes)
  _station=station; _firstUnit=firstUnit; _secondUnit=secondUnit; _expected=expected
::method residual
  expose _station _firstUnit _secondUnit _expected
  a=_station~cameraPosition(_firstUnit); b=_station~cameraPosition(_secondUnit)
  d=b-a
  actual=.Maths~sqrt(d~x*d~x+d~y*d~y+d~z*d~z,a~context)
  return actual-_expected

::class SurveyConstraintSet public
::method init
  expose _constraints
  _constraints=.array~new
::method add
  expose _constraints
  use strict arg constraint
  _constraints~append(constraint); return constraint
::method constraints; expose _constraints; return _constraints~copy
::method count; expose _constraints; return _constraints~items
::method weightedRms
  expose _constraints
  if _constraints~items=0 then return 0
  sum=0; weights=0
  do c over _constraints
    r=c~residual; w=c~weight
    sum=sum+w*r*r; weights=weights+w
  end
  if weights=0 then return .nil
  return .Maths~sqrt(sum/weights,.Maths~defaultContext)

::requires 'PhotoObservation.cls'
