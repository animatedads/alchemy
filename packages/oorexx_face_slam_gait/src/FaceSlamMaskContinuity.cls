/* Face SLAM mask-continuity audit v0.1-dev3.
 * Alchemy boundary: Motion Control supplies source-bound track and visibility;
 * Perception supplies optional landmark/crop evidence; this class does not
 * detect a face or identify a person. No inference from occluded pixels.
 * An absent mosaic after occlusion is a REVIEW hypothesis, not proof of the
 * blurring engine's failure or an identity claim.
 */
::options digits 30

::class FaceSlamMaskObservation public
::attribute sourceDigest get
::attribute cameraId get
::attribute trackId get
::attribute modelDigest get
::attribute timeUs get
::attribute visibility get
::attribute maskState get
::attribute confidence get
::attribute sampleRef get
::method init
 expose sourceDigest cameraId trackId modelDigest timeUs visibility maskState confidence sampleRef
 use strict arg sourceDigest,cameraId,trackId,modelDigest,timeUs,visibility,maskState,confidence,sampleRef=''
 if sourceDigest='' | cameraId='' | trackId='' | modelDigest='' then -
  raise syntax 88.900 array('Source/camera/track/model required')
 if sourceDigest~length<>64 | verify(sourceDigest,'0123456789abcdefABCDEF')<>0 then -
  raise syntax 88.900 array('sourceDigest must be SHA-256 hex')
 if \datatype(timeUs,'W') | timeUs<0 then -
  raise syntax 88.900 array('Source-global PTS must be an integer >= 0',timeUs)
 visibility=visibility~translate
 maskState=maskState~translate
 if visibility<>'VISIBLE' & visibility<>'OCCLUDED' & visibility<>'PARTIAL' then -
  raise syntax 88.900 array('visibility must be VISIBLE/PARTIAL/OCCLUDED')
 if maskState<>'MOSAIC' & maskState<>'UNMASKED' & maskState<>'UNKNOWN' then -
  raise syntax 88.900 array('mask state must be MOSAIC/UNMASKED/UNKNOWN')
 if \datatype(confidence,'N') | confidence<0 | confidence>1 then -
  raise syntax 88.900 array('confidence must be between 0 and 1')
 if visibility='OCCLUDED' & maskState<>'UNKNOWN' then -
  raise syntax 88.900 array('fully occluded observations cannot claim mask state')
 confidence=confidence+0
 timeUs=timeUs+0

::class FaceSlamMaskAuditEvent public
::attribute kind get
::attribute sourceDigest get
::attribute cameraId get
::attribute trackId get
::attribute maskedUntilUs get
::attribute unmaskedFromUs get
::attribute occludedBetween get
::attribute observedUnmaskedFrames get
::attribute status get
::method init
 expose kind sourceDigest cameraId trackId maskedUntilUs unmaskedFromUs occludedBetween observedUnmaskedFrames status
 use strict arg kind,sourceDigest,cameraId,trackId,maskedUntilUs,unmaskedFromUs,occludedBetween,observedUnmaskedFrames,status

::class FaceSlamMaskContinuity public
::attribute event get
::attribute count get
::method init
 expose sourceDigest cameraId trackId modelDigest lastTime lastMaskUs occluded gapActive -
  firstUnmaskUs observedUnmasked event count confidenceFloor
 use strict arg sourceDigest,cameraId,trackId,modelDigest,confidenceFloor=.8
 if sourceDigest='' | cameraId='' | trackId='' | modelDigest='' then -
  raise syntax 88.900 array('track identity required')
 if sourceDigest~length<>64 | verify(sourceDigest,'0123456789abcdefABCDEF')<>0 then -
  raise syntax 88.900 array('sourceDigest must be SHA-256 hex')
 if \datatype(confidenceFloor,'N') | confidenceFloor<0 | confidenceFloor>1 then -
  raise syntax 88.900 array('invalid confidence floor')
 lastTime=-1; lastMaskUs=.nil; occluded=.false; gapActive=.false
 firstUnmaskUs=.nil; observedUnmasked=0; event=.nil; count=0
::method add
 expose sourceDigest cameraId trackId modelDigest lastTime lastMaskUs occluded gapActive -
  firstUnmaskUs observedUnmasked event count confidenceFloor
 use strict arg obs
 if \obs~isA(.FaceSlamMaskObservation) then raise syntax 88.900 array('expected FaceSlamMaskObservation')
 if obs~sourceDigest<>sourceDigest | obs~cameraId<>cameraId | -
    obs~trackId<>trackId | obs~modelDigest<>modelDigest then -
  raise syntax 88.900 array('cross-source/track/model observation refused')
 if obs~timeUs<=lastTime then raise syntax 88.900 array('non-monotonic PTS refused')
 lastTime=obs~timeUs; count=count+1
 if obs~visibility='OCCLUDED' then do
  if lastMaskUs\==.nil then gapActive=.true
  occluded=.true
  return self
 end
 if obs~visibility='PARTIAL' | obs~confidence<confidenceFloor | obs~maskState='UNKNOWN' then -
  return self
 if obs~maskState='MOSAIC' then do
  lastMaskUs=obs~timeUs
  occluded=.false;gapActive=.false;firstUnmaskUs=.nil;observedUnmasked=0;event=.nil
  return self
 end
 if lastMaskUs==.nil then return self
 if firstUnmaskUs==.nil then do
  firstUnmaskUs=obs~timeUs
  observedUnmasked=0
 end
 observedUnmasked=observedUnmasked+1
 kind='DIRECT_MASK_LOSS_CANDIDATE'
 if gapActive | occluded then kind='POST_OCCLUSION_MASK_LOSS_CANDIDATE'
 status='REVIEW_CANDIDATE'
 if observedUnmasked>=2 then status='REPEATED_OBSERVATION'
 event=.FaceSlamMaskAuditEvent~new(kind,sourceDigest,cameraId,trackId, -
   lastMaskUs,firstUnmaskUs,(gapActive | occluded),observedUnmasked,status)
 return self