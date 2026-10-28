/* Default workload shapes for built-in media methodologies.
 *
 * These are semantic work-shape hints, not hardware requirements.  Provider
 * implementation profiles remain separate and may override them.
 */
::class MediaWorkShapeBuiltins public
::method populate class
  use strict arg shapeCatalogue, methodologyCatalogue
  do spec over methodologyCatalogue~all
    shapeCatalogue~register(self~shapeFor(spec))
  end
  return shapeCatalogue

::method shapeFor class
  use strict arg spec
  domain=spec~domain
  family=spec~family
  shard="NONE"
  state="STATELESS"
  access="WINDOWED"
  before=0
  after=0
  merge="COLLECT"
  continuity="NONE"
  materialization="REFERENCE_FIRST"

  select
    when domain="VIDEO" then do
      shard="FRAME_RANGE"; access="SEQUENTIAL_WINDOW"; before=2; after=2
      if family="ACQUISITION" then do; before=0; after=0; merge="TIMELINE_CONCAT"; end
      if family="CAMERA_STATE" then do; state="TRACK_STATE"; before=8; after=8; merge="STATE_SEQUENCE"; continuity="STATE_HANDOFF_REQUIRED"; end
      if family="CAMERA_MODEL" then do; state="GLOBAL"; shard="SOURCE_SET"; before=0; after=0; merge="MODEL_SET"; end
      if family="MOTION_MEASUREMENT" then do; state="WINDOW_STATE"; before=4; after=4; merge="FLOW_FIELD_MOSAIC"; end
      if family="TRACKING" then do; state="TRACK_STATE"; before=12; after=12; merge="TRACK_STITCH"; continuity="STATE_HANDOFF_REQUIRED"; end
      if family="STRUCTURE_MEASUREMENT" then do; state="WINDOW_STATE"; before=2; after=2; merge="STRUCTURE_SET"; end
      if family="GEOMETRY" then do; state="GLOBAL"; shard="SOURCE_SET"; before=0; after=0; merge="GEOMETRY_CONSTRAINT_SET"; end
      if family="RECONSTRUCTION" then do; state="WINDOW_STATE"; before=8; after=8; merge="RECONSTRUCTION_SUPPORT_MERGE"; continuity="OVERLAP_REQUIRED"; end
      if family="RESTORATION" then do; state="WINDOW_STATE"; before=4; after=4; merge="MEDIA_WINDOW_BLEND"; end
      if family="FORENSIC" then do; state="WINDOW_STATE"; before=4; after=4; merge="MEASUREMENT_SET"; end
      if family="ENHANCEMENT" then do; state="WINDOW_STATE"; before=4; after=4; merge="MEDIA_WINDOW_BLEND"; end
    end
    when domain="AUDIO" then do
      shard="SAMPLE_RANGE"; access="SEQUENTIAL_WINDOW"; before=2048; after=2048; merge="AUDIO_WINDOW_BLEND"
      if family="ACQUISITION" then do; before=0; after=0; merge="TIMELINE_CONCAT"; end
      if family="CALIBRATION" | family="SYSTEM_IDENTIFICATION" then do; state="GLOBAL"; shard="SOURCE_SET"; before=0; after=0; merge="MODEL_SET"; end
      if family="ANALYSIS" | family="MEASUREMENT" | family="FORENSIC" then do; state="WINDOW_STATE"; before=4096; after=4096; merge="MEASUREMENT_SET"; end
      if family="SEPARATION" | family="SPATIAL" then do; state="WINDOW_STATE"; before=8192; after=8192; merge="AUDIO_WINDOW_BLEND"; end
      if family="RECONSTRUCTION" | family="RESTORATION" then do; state="WINDOW_STATE"; before=8192; after=8192; merge="RECONSTRUCTION_SUPPORT_MERGE"; continuity="OVERLAP_REQUIRED"; end
      if family="SEMANTIC_ANALYSIS" then do; state="WINDOW_STATE"; before=16000; after=16000; merge="SEMANTIC_SEGMENT_SET"; end
    end
    when domain="CROSS_MODAL" then do
      shard="TIME_RANGE"; state="WINDOW_STATE"; access="SYNCHRONIZED_WINDOW"; before=2; after=2; merge="CROSS_MODAL_EVIDENCE_SET"; continuity="CLOCK_ALIGNMENT_REQUIRED"
      if family="SYNC" then do; state="GLOBAL"; shard="SOURCE_SET"; before=0; after=0; merge="CLOCK_MODEL_SET"; end
      if family="RECONSTRUCTION" then merge="RECONSTRUCTION_SUPPORT_MERGE"
    end
    otherwise do
      shard="SOURCE_SET"; state="GLOBAL"; access="REFERENCE_ONLY"; before=0; after=0; merge="QUALIFICATION_REPORT_SET"
    end
  end

  /* The Architect's leading-edge method is deliberately explicit: trajectory
   * state crosses shard boundaries, so overlap and state handoff are required. */
  if spec~id="VIDEO.RECON.LEADING_EDGE_BACKPROJECTION" then do
    shard="FRAME_RANGE"; state="TRACK_STATE"; access="SEQUENTIAL_WINDOW"
    before=8; after=8; merge="TRACK_COORDINATE_SUPPORT_MERGE"
    continuity="STATE_HANDOFF_REQUIRED"; materialization="REFERENCE_FIRST"
  end

  /* Audio V9 multipath methods expose stronger continuation boundaries than
   * the generic AUDIO defaults.  Values are sample/observation halos, not a
   * claim about source geometry. */
  select
    when spec~id="AUDIO.MULTIPATH.PATH_ESTIMATE" then do
      shard="EVENT_SET"; state="STATELESS"; access="LOCAL_EVENT_WINDOW"
      before=7600; after=960; merge="MEASUREMENT_SET"; continuity="NONE"
    end
    when spec~id="AUDIO.MULTIPATH.SPECTRAL_TRACK" then do
      shard="SAMPLE_RANGE"; state="TRACK_STATE"; access="SEQUENTIAL_WINDOW"
      before=8192; after=8192; merge="TRACK_STITCH"; continuity="STATE_HANDOFF_REQUIRED"
    end
    when spec~id="AUDIO.MULTIPATH.MOTION_COHERENCE" then do
      shard="OBSERVATION_RANGE"; state="ACCUMULATOR_STATE"; access="SEQUENTIAL_OBSERVATIONS"
      before=1; after=0; merge="STATE_SEQUENCE"; continuity="STATE_HANDOFF_REQUIRED"
    end
    when spec~id="AUDIO.MULTIPATH.PHYSICS_COMPATIBILITY" then do
      shard="TRAJECTORY_SET"; state="STATELESS"; access="REFERENCE_ONLY"
      before=0; after=0; merge="MEASUREMENT_SET"; continuity="NONE"
    end
    when spec~id="AUDIO.RECON.MULTIPATH_VIRTUAL_MIC" then do
      shard="SAMPLE_RANGE"; state="TRACK_STATE"; access="SEQUENTIAL_WINDOW"
      before=8192; after=8192; merge="RECONSTRUCTION_SUPPORT_MERGE"; continuity="STATE_HANDOFF_REQUIRED"
    end
    otherwise nop
  end

  /* Spectral-integrity methods are deliberately local derived views or
   * measurements.  The positive control is a source-set qualification and
   * never shards unknown field evidence into synthetic truth. */
  select
    when spec~id="AUDIO.SPECTRAL_INTEGRITY.COMPLEMENTARY_BUCKET_VIEWS" then do
      shard="SAMPLE_RANGE"; state="WINDOW_STATE"; access="SEQUENTIAL_WINDOW"
      before=4096; after=4096; merge="DERIVED_VIEW_SET"; continuity="OVERLAP_REQUIRED"
    end
    when spec~id="AUDIO.SPECTRAL_INTEGRITY.PHASE_SWEEP" then do
      shard="SAMPLE_RANGE"; state="WINDOW_STATE"; access="SEQUENTIAL_WINDOW"
      before=4096; after=4096; merge="MEASUREMENT_SET"; continuity="OVERLAP_REQUIRED"
    end
    when spec~id="AUDIO.SPECTRAL_INTEGRITY.BOUNDED_PREFERENCE_VIEW" then do
      shard="SAMPLE_RANGE"; state="WINDOW_STATE"; access="SEQUENTIAL_WINDOW"
      before=4096; after=4096; merge="DERIVED_VIEW_SET"; continuity="OVERLAP_REQUIRED"
    end
    when spec~id="AUDIO.SPECTRAL_INTEGRITY.HARMONIC_OBSERVATION" then do
      shard="SAMPLE_RANGE"; state="WINDOW_STATE"; access="SEQUENTIAL_WINDOW"
      before=4096; after=4096; merge="MEASUREMENT_SET"; continuity="OVERLAP_REQUIRED"
    end
    when spec~id="QUAL.AUDIO.SPECTRAL_INTERLEAVE_POSITIVE_CONTROL" then do
      shard="SOURCE_SET"; state="GLOBAL"; access="REFERENCE_ONLY"
      before=0; after=0; merge="QUALIFICATION_REPORT_SET"; continuity="NONE"
    end
    otherwise nop
  end

  return .MediaWorkShape~new(spec~id,shard,state,access,before,after,merge,continuity,materialization)

::requires "MediaMethodologyExecution.cls"
