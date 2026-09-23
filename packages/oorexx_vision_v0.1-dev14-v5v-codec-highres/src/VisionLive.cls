/*
 * Live Vision vocabulary.
 *
 * IMPORTANT: this package owns frame-local observations only.
 * Track identity, velocity, persistence, stopped/moving state, occlusion and
 * reacquisition belong to oorexx_motion_control.
 */

::class VisionRegionObservation public
::method init
  expose observationId sourceTime region confidence evidenceRef
  use strict arg observationId,sourceTime,region,confidence=1,evidenceRef=.nil
::attribute observationId get
::attribute sourceTime get
::attribute region get
::attribute confidence get
::attribute evidenceRef get

::class VisionFrameObservation public
::method init
  expose sourceTime surface regions continuity evidenceRef
  use strict arg sourceTime,surface,regions=.nil,continuity=.nil,evidenceRef=.nil
  if regions == .nil then regions=.array~new
::attribute sourceTime get
::attribute surface get
::attribute regions get
::attribute continuity get
::attribute evidenceRef get
