/* Optional bridge from Audio V9 physics-path evidence into Media Methodologies.
 * API: media.methodologies.audio-v9-physics/0.1
 */

::class MediaAudioV9PhysicsBridge public
::method assess
  use strict arg spectralTrackPoint,maxPathRateMPerS=120,sourceEvidenceRef=""
  evidence=.AudioV9PhysicsPathPolicy~new(maxPathRateMPerS)~assess(spectralTrackPoint)
  refs=.Array~new
  if sourceEvidenceRef<>"" then refs~append(sourceEvidenceRef)
  metadata=.Directory~new
  metadata["EVIDENCE_KIND"]=evidence~evidenceKind
  metadata["EXCESS_PATH_M"]=evidence~excessPathM
  metadata["EXCESS_PATH_RATE_M_PER_S"]=evidence~excessPathRateMPerS
  metadata["CAUSALITY_FIT"]=evidence~causalityFit
  metadata["MOTION_FIT"]=evidence~motionFit
  metadata["TRANSFER_FIT"]=evidence~transferFit
  metadata["OVERALL_FIT"]=evidence~overallFit
  metadata["SOURCE_RANGE_PROBABILITY"]="NOT_PRODUCED"
  metadata["REFLECTOR_VELOCITY"]="NOT_PRODUCED"
  return .MediaDerivedEvidence~new("AUDIO.MULTIPATH.PHYSICS_COMPATIBILITY",refs,"audio-v9:physics-path:"||spectralTrackPoint~trajectoryId,spectralTrackPoint~frameTimeMs,spectralTrackPoint~frameTimeMs,"MEASURE",.nil,metadata)

::requires "MediaMethodologies.cls"
::requires "AudioV9Multipath.cls"
::requires "AudioV9PhysicsPathEvidence.cls"
