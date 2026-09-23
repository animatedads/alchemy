/* Wire3D deterministic projector tracking field.
   This is renderer/sensing infrastructure, never application state. */
::class Wire3DTrackingField public
::attribute enabled
::attribute version get
::attribute seed
::attribute starCount
::attribute majorDivisions
::attribute minorDivisions
::attribute intensity
::attribute profile
::method init
  expose enabled version seed starCount majorDivisions minorDivisions intensity profile
  use strict arg seed='4A91C37D', profile='PROJECTOR_TRACKING'
  enabled=.true; version='wire3d-tracking/1'; self~seed=seed
  starCount=384; majorDivisions=8; minorDivisions=32; intensity=.62; self~profile=profile
::method asDirectory
  expose enabled version seed starCount majorDivisions minorDivisions intensity profile
  d=.directory~new
  d['enabled']=enabled; d['version']=version; d['seed']=seed; d['profile']=profile
  d['starCount']=starCount; d['majorDivisions']=majorDivisions; d['minorDivisions']=minorDivisions
  d['intensity']=intensity; d['coordinateSpace']='NORMALIZED_PROJECTOR'; d['spatialIdentity']='SEEDED_UNIQUE'
  d['applicationState']=.false
  return d
