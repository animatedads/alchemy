/* Power SLAM Harbour v0.13. Architecture: Tom Dyer. Implementation: GPT-6.
 * User Google Earth pins are ROOF-INTERIOR, not surveyed corner coordinates.
 * An image pylon-top detection MUST NOT be assigned the midpoint of two
 * independent pylons without an explicit physical correspondence.
 * Four possible south/north observed-tower assignments are evaluated.
 * Real-world camera pose remains BLOCKED until geometric controls qualify.
 */
::requires 'SlamHarbourPerspectiveFit.cls'
::requires 'SlamHarbourRoofPins.cls'
::class HarbourPinCorrespondence public
::attribute fitter
::method init
  expose fitter
  fitter=.HarbourPerspectiveFit~new
  frame=.HarbourBridgeRoofPins~apply(fitter~model~scene)
  if frame['STATUS']\=='ROOF_PIN_LAYOUT_CONSISTENT_NOT_SURVEYED' then raise syntax 88.900 array('invalid pylon pin geometry')
::method alternatives
  answer=.array~new
  do s over .array~of('SW','SE')
    do n over .array~of('NW','NE')
      answer~append(.array~of(s,n))
    end
  end
  return answer
::method world
  expose fitter
  use strict arg id
  /* Forbid the old average-pylon landmark as a photographic target. */
  if id=='S_TOP' | id=='N_TOP' | id=='S_DECK' | id=='N_DECK' then raise syntax 88.900 array('midpoint landmark cannot be a photographed pylon')
  return fitter~world(id)
::method observations
  use strict arg south,north
  if (south\=='SW' & south\=='SE') | (north\=='NW' & north\=='NE') then raise syntax 88.900 array('invalid south/north pylon identities')
  /* Image coordinates are USER-SUPPLIED/ASSISTANT-ANNOTATED PROVISIONAL
     x/y from original 1536x862 frame 1000066577.jpg; pixel uncertainty 14.
     A deck reference is a proxy at SAME pylon XY, not a measured deck corner. */
  a=.array~new
  a~append(.array~of(south||'_ROOF_PIN',122,278,14))
  a~append(.array~of(north||'_ROOF_PIN',770,314,14))
  a~append(.array~of(south||'_DECK_PROXY',122,379,14))
  a~append(.array~of(north||'_DECK_PROXY',770,390,14))
  return a
::method archHoldout
  expose fitter
  use strict arg pose
  a=fitter~project(fitter~world('ARCH_CROWN'),pose)
  if a==.nil then return 1e30
  return HSqrt((a[1]-447)**2+(a[2]-191)**2)
::method nearBoundary
  expose fitter
  use strict arg pose,tolerance=2
  b=fitter~cameraPolygon~bounds
  return pose[1]-b[1]<tolerance | b[2]-pose[1]<tolerance | pose[2]-b[3]<tolerance | b[4]-pose[2]<tolerance
::method qualify
  expose fitter
  use strict arg fit,obs
  d=.directory~new
  d['CHI2']=fit['CHI2']
  d['FOOTPRINT_SOURCE']=fitter~cameraPolygon~provenance
  p=fit['POSE']
  d['POSE']=p
  d['ARCH_HOLDOUT_PX']=1e30
  d['BOUNDARY_REACHED']=.false
  d['STATUS']='BLOCKED_NO_CAMERA_SOLUTION'
  if p==.nil then return d
  d['ARCH_HOLDOUT_PX']=self~archHoldout(p)
  d['BOUNDARY_REACHED']=self~nearBoundary(p)
  d['FOV_DEG']=fitter~horizontalFov(p[6])
  d['STATUS']='BLOCKED_UNSURVEYED_ROOF_AND_IMAGE_CORRESPONDENCE'
  if d['ARCH_HOLDOUT_PX']>30 then d['STATUS']='BLOCKED_ARCH_HOLDOUT_FAILED'
  if d['BOUNDARY_REACHED'] then d['STATUS']='BLOCKED_ROOFTOP_SEARCH_BOUNDARY'
  return d
::method fitOne
  expose fitter
  use strict arg south,north,iterations=20
  obs=self~observations(south,north)
  p=fitter~initialCamera
  r=fitter~fit(obs,p,25,iterations)
  q=self~qualify(r,obs)
  q['SOUTH']=south
  q['NORTH']=north
  q['OBS']=obs
  q['SEEDS']=r['SEEDS']
  return q
::method compare
  use strict arg iterations=20
  ranked=.array~new
  do pair over self~alternatives
    q=self~fitOne(pair[1],pair[2],iterations)
    ranked~append(q)
  end
  /* Best score is only a diagnostic; NEVER an admission. */
  do i=1 to ranked~items
    do j=i+1 to ranked~items
      if ranked[j]['CHI2']<ranked[i]['CHI2'] then do
        temp=ranked[i];ranked[i]=ranked[j];ranked[j]=temp
      end
    end
  end
  return ranked