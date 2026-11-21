/* Moonsault sky evidence policy: image-space measurements are not star fixes.
 * A small camera can supply clouds/landmarks without supplying usable stellar
 * astrometry. Width is one quality factor, never positive star evidence.
 * Source: ooRexx; no Python/CV orchestration.
 */
::options digits 30

::class MoonsaultSkyEvidence public
::method assessFrame class
  use strict arg frame, cameraId, minimumWidth=960, minimumHeight=540
  w=frame~width; h=frame~height
  if \datatype(w,'W') | \datatype(h,'W') | w<1 | h<1 then -
    raise syntax 88.900 array('invalid camera frame size',w,h)
  out=.directory~new
  out['cameraId']=cameraId
  out['width']=w; out['height']=h
  out['sourcePixels']=w*h
  out['minimumSkyWidth']=minimumWidth; out['minimumSkyHeight']=minimumHeight
  out['observationSource']='CAMERA_FRAME'
  out['predictedStarCount']=0
  out['measuredStarCount']=0
  out['catalogueMatchCount']=0
  out['celestialHeadingAuthorized']=.false
  /* This threshold is the conservative policy for this Sydney fixture,
   * not a claim that 640p can NEVER resolve a bright star elsewhere. */
  if minimumWidth<1 | minimumHeight<1 then -
    raise syntax 88.900 array('invalid camera sky sampling policy')
  if w<minimumWidth | h<minimumHeight then do
    out['role']='SCENE_AND_CLOUDS'
    out['starSearchAllowed']=.false
    out['reason']='This Sydney camera lacks sufficient native sky sampling for a qualified faint-star search'
  end
  else do
    out['role']='STAR_CANDIDATE_AND_CLOUDS'
    out['starSearchAllowed']=.true
    out['reason']='Native sampling permits candidate search, but no stars or camera fix are yet proved'
  end
  return out
::method authorizeFix class
  /* Result of a separate, actually measured camera/astrometry pipeline.
   * NOT a substitute for detection, plate-solve or camera calibration. */
  use strict arg assessment, persistentTracks, catalogueMatches, -
    rmsPixels, cameraCalibrated, timeVerified
  if \assessment['starSearchAllowed'] then return .false
  if \datatype(persistentTracks,'W') | persistentTracks<3 then return .false
  if \datatype(catalogueMatches,'W') | catalogueMatches<3 then return .false
  if \datatype(rmsPixels,'N') | rmsPixels<0 | rmsPixels>1.5 then return .false
  if cameraCalibrated<>.true | timeVerified<>.true then return .false
  return .true