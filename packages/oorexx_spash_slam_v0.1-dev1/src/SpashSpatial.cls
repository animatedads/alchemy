/* SPASH spatial experiment: predicted microphone arrivals, never new measurements.
 * A virtual position cannot add independent recorded channels to a mono source.
 */
::class SpashPoint public
::method init
  expose _id _x _y _z
  use strict arg id,x,y,z
  if id=='' then raise syntax 88.900 array('point id',id)
  if \datatype(x,'N') | \datatype(y,'N') | \datatype(z,'N') then raise syntax 88.900 array('numeric coordinates',id)
  _id=id; _x=x; _y=y; _z=z
::method id; expose _id; return _id
::method x; expose _x; return _x
::method y; expose _y; return _y
::method z; expose _z; return _z
::method distanceTo
  use strict arg p
  if \p~isA(.SpashPoint) then raise syntax 88.900 array('SpashPoint expected',p)
  dx=self~x-p~x; dy=self~y-p~y; dz=self~z-p~z
  n=dx*dx+dy*dy+dz*dz
  if n=0 then return 0
  g=max(1,n)
  do step=1 to 60
    previous=g
    g=(g+n/g)/2
    if abs(g-previous)<0.0000000001 then leave
  end
  return g
::class SpashSpatialExperiment public
::method init
  expose _speed
  use strict arg soundSpeed=343
  if \datatype(soundSpeed,'N') then raise syntax 88.900 array('numeric sound speed',soundSpeed)
  if soundSpeed<=0 then raise syntax 88.900 array('positive sound speed',soundSpeed)
  _speed=soundSpeed
::method predict
  expose _speed
  use strict arg sourceHypothesis,virtualMicPositions,emissionMs=0
  if \sourceHypothesis~isA(.SpashPoint) then raise syntax 88.900 array('source point hypothesis',sourceHypothesis)
  if \virtualMicPositions~isA(.array) then raise syntax 88.900 array('Array of positions',virtualMicPositions)
  if \datatype(emissionMs,'N') then raise syntax 88.900 array('numeric emission time',emissionMs)
  out=.array~new
  do i=1 to virtualMicPositions~items
    mic=virtualMicPositions[i]
    if \mic~isA(.SpashPoint) then raise syntax 88.900 array('microphone point',mic)
    r=.directory~new
    r~put(mic~id,'MIC_ID'); r~put(emissionMs+1000*sourceHypothesis~distanceTo(mic)/_speed,'PREDICTED_ARRIVAL_MS')
    r~put('MODEL_ONLY','AUTHORITY'); r~put(sourceHypothesis~id,'HYPOTHESIS_ID')
    out~append(r)
  end
  return out
