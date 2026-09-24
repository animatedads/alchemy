/* ooRexx Physics World v0.1-dev12
   Conservative external escaped-fluid parcel mechanics.

   This is intentionally a parcel/ballistic contact model, not CFD.  It gives
   escaped liquid continued physical existence after leaving a breached
   vessel: position, velocity, gravity, plane contact, momentum transfer and
   retained mass/volume provenance.  Parcels do not merge, splash, spread,
   exert pressure fields or re-enter a vessel in this model.
*/

::class ExternalFluidParcelState public
::method init
  expose _parcel _position _velocity _time _active
  use strict arg escapedParcel
  _parcel=escapedParcel
  _position=escapedParcel~positionLocal
  _velocity=escapedParcel~velocityLocal
  _time=escapedParcel~time
  _active=.true
::method parcel; expose _parcel; return _parcel
::method medium; expose _parcel; return _parcel~medium
::method mass; expose _parcel; return _parcel~mass
::method volume; expose _parcel; return _parcel~volume
::method position; expose _position; return _position
::method 'position='; expose _position; use strict arg v; _position=v
::method velocity; expose _velocity; return _velocity
::method 'velocity='; expose _velocity; use strict arg v; _velocity=v
::method time; expose _time; return _time
::method 'time='; expose _time; use strict arg v; _time=v
::method active; expose _active; return _active
::method deactivate; expose _active; _active=.false; return self

::class ExternalFluidPlane public
::method init
  expose _point _normal _restitution _name
  use strict arg point,normal,restitution=0,name='external-fluid-plane'
  _point=point; _normal=normal~normalized; _restitution=restitution+0; _name=name
  if _restitution<0 | _restitution>1 then raise syntax 88.900 array('fluid parcel plane restitution in [0,1]',_restitution)
::method point; expose _point; return _point
::method normal; expose _normal; return _normal
::method restitution; expose _restitution; return _restitution
::method name; expose _name; return _name
::method signedDistance
  use strict arg p
  return (p-self~point)~dot(self~normal)

::class ExternalFluidContactEvent public
::method init
  expose _time _parcelState _plane _point _impulse _preVelocity _postVelocity
  use strict arg timeSeconds,parcelState,plane,point,impulse,preVelocity,postVelocity
  _time=timeSeconds; _parcelState=parcelState; _plane=plane; _point=point
  _impulse=impulse; _preVelocity=preVelocity; _postVelocity=postVelocity
::method time; expose _time; return _time
::method parcelState; expose _parcelState; return _parcelState
::method plane; expose _plane; return _plane
::method point; expose _point; return _point
::method impulse; expose _impulse; return _impulse
::method preVelocity; expose _preVelocity; return _preVelocity
::method postVelocity; expose _postVelocity; return _postVelocity

::class ExternalFluidParcelWorld public
::method init
  expose _states _planes _events _gravity _time
  use strict arg gravity=.nil,startTime=0
  if gravity==.nil then gravity=.MathVector3~new(0,-9.80665,0)
  _gravity=gravity; _time=startTime+0; _states=.array~new; _planes=.array~new; _events=.array~new
::method time; expose _time; return _time
::method states; expose _states; return _states~copy
::method planes; expose _planes; return _planes~copy
::method contactEvents; expose _events; return _events~copy
::method totalMass
  expose _states
  numeric digits 50
  m=0
  do st over _states; m=m+st~mass; end
  return m
::method totalVolume
  expose _states
  numeric digits 50
  v=0
  do st over _states; v=v+st~volume; end
  return v
::method admit
  expose _states
  use strict arg escapedParcel
  st=.ExternalFluidParcelState~new(escapedParcel)
  _states~append(st)
  return st
::method admitAll
  use strict arg parcels
  admitted=.array~new
  do parcel over parcels; admitted~append(self~admit(parcel)); end
  return admitted
::method addPlane
  expose _planes
  use strict arg plane
  _planes~append(plane); return plane
::method step
  expose _states _planes _events _gravity _time
  use strict arg dt
  numeric digits 50
  dt=dt+0
  if dt<=0 then raise syntax 88.900 array('positive external-fluid timestep',dt)
  do st over _states
    if \st~active then iterate
    oldP=st~position; oldV=st~velocity
    newV=oldV+_gravity*dt
    newP=oldP+newV*dt
    do plane over _planes
      d0=plane~signedDistance(oldP); d1=plane~signedDistance(newP)
      if d0>=0 & d1<0 then do
        denom=d0-d1
        if denom<=0 then frac=1
        else frac=d0/denom
        hit=oldP+(newP-oldP)*frac
        vn=newV~dot(plane~normal)
        if vn<0 then do
          postV=newV-plane~normal*((1+plane~restitution)*vn)
          impulse=plane~normal*(-(1+plane~restitution)*st~mass*vn)
          remain=dt*(1-frac)
          newP=hit+postV*remain
          newV=postV
          _events~append(.ExternalFluidContactEvent~new(_time+dt*frac,st,plane,hit,impulse,newV,postV))
        end
      end
    end
    st~position=newP; st~velocity=newV; st~time=_time+dt
  end
  _time=_time+dt
  return self
::method momentum
  expose _states
  v=.MathVector3~new(0,0,0)
  do st over _states
    if st~active then v=v+st~velocity*st~mass
  end
  return v

::class EscapedFluidWorldBinding public
::method init
  expose _breachedVessel _world _admitted
  use strict arg breachedVessel,externalWorld
  _breachedVessel=breachedVessel; _world=externalWorld; _admitted=0
::method synchronize
  expose _breachedVessel _world _admitted
  parcels=_breachedVessel~parcels
  added=.array~new
  do i=_admitted+1 to parcels~items
    added~append(_world~admit(parcels[i]))
  end
  _admitted=parcels~items
  return added
::method accountedMass
  expose _breachedVessel _world
  return _breachedVessel~retainedMass+_world~totalMass
::method massBalanceError
  expose _breachedVessel
  return _breachedVessel~initialMass-self~accountedMass

::requires 'FluidContainment.cls'
