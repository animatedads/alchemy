/* SPASH: ooRexx execution seam over Audio V9 / Media Methodologies / Physics.
 * No independent FFT, denoiser, virtual microphone renderer or Python DSP.
 * Architecture Tom Dyer; implementation ChatGPT GPT-6, 2026-10-31.
 */
::class SpashVirtualAudioExecution public
::method init
  expose _registry _twoMic _physics
  use strict arg providerRegistry, observedTwoMicModel, physicsMatcher=.nil
  if providerRegistry==.nil | observedTwoMicModel==.nil then raise syntax 88.900 array('Media registry and Audio V9 two-mic model required')
  _registry=providerRegistry; _twoMic=observedTwoMicModel; _physics=physicsMatcher
::method methods
  return .array~of('AUDIO.MULTIPATH.PATH_ESTIMATE', -
    'AUDIO.MULTIPATH.SPECTRAL_TRACK', -
    'AUDIO.MULTIPATH.MOTION_COHERENCE', -
    'AUDIO.MULTIPATH.PHYSICS_COMPATIBILITY', -
    'AUDIO.RECON.MULTIPATH_VIRTUAL_MIC')
::method isSha private
  use strict arg value
  if value==.nil then return .false
  if \(value~isA(.string)) then return .false
  if length(value)<>64 then return .false
  return verify(translate(value),'0123456789ABCDEF')=0
::method isFeed private
  use strict arg feed
  if \feed~isA(.directory) then return .false
  if \feed~hasIndex('FEED_ID') | \feed~hasIndex('SOURCE_SHA256') | \feed~hasIndex('SOURCE_AUTHORITY') then return .false
  if feed['FEED_ID']=='' then return .false
  if \self~isSha(feed['SOURCE_SHA256']) then return .false
  if feed['SOURCE_AUTHORITY']\=='ORIGINAL_OBSERVED_AUDIO' then return .false
  return .true
::method plan
  expose _registry
  use strict arg keypointId,observedFeeds,startSample,sampleCount,sampleRate,clockEvidence=.nil,measuredPaths=.nil,requestedListeningGainDb=32
  if keypointId=='' then raise syntax 88.900 array('keypoint identity required')
  if \observedFeeds~isA(.array) then raise syntax 88.900 array('observed feed array required')
  if observedFeeds~items<1 | observedFeeds~items>2 then raise syntax 88.900 array('one or two original observed audio feeds required')
  ids=.directory~new; digests=.directory~new
  do feed over observedFeeds
    if \self~isFeed(feed) then raise syntax 88.900 array('source authority or hash unqualified')
    if ids~hasIndex(feed['FEED_ID']) then raise syntax 88.900 array('duplicate physical feed',feed['FEED_ID'])
    ids[feed['FEED_ID']]=.true
    if digests~hasIndex(feed['SOURCE_SHA256']) then raise syntax 88.900 array('two derived channels are not independent microphone sources')
    digests[feed['SOURCE_SHA256']]=.true
  end
  if \datatype(startSample,'N') | \datatype(sampleCount,'N') | \datatype(sampleRate,'N') then raise syntax 88.900 array('numeric sample range')
  if startSample<0 | startSample<>trunc(startSample) | sampleCount<=0 | sampleCount<>trunc(sampleCount) | sampleRate<=0 then raise syntax 88.900 array('invalid original sample geometry')
  if measuredPaths==.nil then measuredPaths=.array~new
  if \measuredPaths~isA(.array) then raise syntax 88.900 array('measured path evidence must be Array')
  do measuredPath over measuredPaths
    if \measuredPath~isA(.directory) then raise syntax 88.900 array('measured path record required')
    if measuredPath['AUTHORITY']\=='OBSERVED_COHERENT_AUDIO_PATH' then raise syntax 88.900 array('no derived or virtual path as measurement')
    if \measuredPath~hasIndex('SOURCE_SHA256') then raise syntax 88.900 array('path source hash required')
    if \digests~hasIndex(measuredPath['SOURCE_SHA256']) then raise syntax 88.900 array('path must bind original feed source hash')
    if measuredPath['PATH_ID']==.nil | measuredPath['METHOD_ID']==.nil then raise syntax 88.900 array('path identity and method ID required')
  end
  clockId='UNKNOWN'; clockVerified=.false
  if clockEvidence \== .nil then do
    if \clockEvidence~isA(.directory) then raise syntax 88.900 array('clock evidence record required')
    if clockEvidence['AUTHORITY']\=='OBSERVED_CROSS_FEED_ALIGNMENT' then raise syntax 88.900 array('unverified clock evidence')
    clockId=clockEvidence['CLOCK_MODEL_ID']
    if clockId==.nil | clockId=='' | clockId=='UNKNOWN' then raise syntax 88.900 array('explicit measured clock ID required')
    err=clockEvidence['UNCERTAINTY_MS']
    if err==.nil then raise syntax 88.900 array('clock uncertainty required')
    if \datatype(err,'N') then raise syntax 88.900 array('numeric clock uncertainty required')
    if err<=0 then raise syntax 88.900 array('positive clock uncertainty required')
    clockVerified=.true
  end
  if \datatype(requestedListeningGainDb,'N') then raise syntax 88.900 array('listening gain numeric')
  if requestedListeningGainDb<0 | requestedListeningGainDb>64 then raise syntax 88.900 array('bounded listening gain')
  out=.directory~new; steps=.array~new
  out['SCHEMA']='spash.virtual-audio.execution/0.1'
  out['KEYPOINT_ID']=keypointId
  out['ORIGINAL_FEEDS']=observedFeeds~copy
  out['START_SAMPLE']=startSample;out['SAMPLE_COUNT']=sampleCount;out['SAMPLE_RATE_HZ']=sampleRate
  out['CLOCK_MODEL_ID']=clockId;out['OBSERVED_FEED_COUNT']=observedFeeds~items
  out['MEASURED_COHERENT_PATH_COUNT']=measuredPaths~items
  out['MEASURED_PATH_REFERENCES']=measuredPaths~copy
  out['CLOCK_VERIFIED']=clockVerified
  out['SOURCE_AUTHORITY']='ORIGINAL_OBSERVED_AUDIO_ONLY'
  out['REFERENCE_POI1_POLICY']='NO_GAIN_NO_FILTER_NO_MUTATION'
  out['GAIN_APPLIES_TO']='DERIVED_LISTENING_COPY_ONLY'
  out['REQUESTED_LISTENING_GAIN_DB']=requestedListeningGainDb
  out['EVIDENCE_GAIN_DB']=0
  out['DSP_OWNER']='AUDIO_V9_NATIVE_AND_FOREIGN_RUNTIME'
  out['FFT_OWNER']='AUDIO_V9_SPECTRAL_FIELD_AND_OOREXX_MATHS'
  out['PHYSICS_OWNER']='OOREXX_PHYSICS_WORLD_F11'
  out['MEMORY_OWNER']='MEMORY_FABRIC_RESIDENT_BLOCKS'
  out['ALLOW_PYTHON_PRODUCTION_DSP']=.false
  methods=self~methods
  do i=1 to methods~items
    id=methods[i]
    if \_registry~supports(id) then raise syntax 88.900 array('missing registered Audio V9 method',id)
    profile=_registry~profile(id)
    if profile==.nil then raise syntax 88.900 array('unresolved Audio V9 method profile',id)
    step=.directory~new
    step['METHODOLOGY_ID']=id
    step['IMPLEMENTATION_PROFILE']=profile
    step['OWNER']='MEDIA_METHODOLOGIES_WITH_AUDIO_V9_PROVIDER'
    if id='AUDIO.RECON.MULTIPATH_VIRTUAL_MIC' & measuredPaths~items=0 then step['ADMISSION']='NOT_APPLICABLE_NO_COHERENT_PATH'
    else step['ADMISSION']='PROVIDER_EXECUTION_REQUEST_ONLY'
    steps~append(step)
  end
  out['STAGES']=steps
  out['PATH_STATE']='MEASURED_COHERENT_PATHS' ; if measuredPaths~items=0 then out['PATH_STATE']='UNTESTED'
  if observedFeeds~items<2 then out['SPATIAL_STATUS']='NOT_READY_ONE_OBSERVED_MIC'
  else if \clockVerified then out['SPATIAL_STATUS']='NOT_READY_NO_OBSERVED_CLOCK_MODEL'
  else if measuredPaths~items=0 then out['SPATIAL_STATUS']='NOT_READY_NO_MEASURED_PATH'
  else out['SPATIAL_STATUS']='READY_FOR_AUDIO_V9_AND_PHYSICS_EVALUATION'
  out['OUTPUT_AUTHORITY']='EXECUTION_PLAN_NOT_RECONSTRUCTED_AUDIO'
  return out
::method virtualField
  expose _twoMic
  use strict arg sourceHypothesis, positionsByRole, emissionMs=0
  if \positionsByRole~isA(.directory) then raise syntax 88.900 array('four keyed virtual positions required')
  roles=.array~of('PREDICTED_SOURCE','STREET','STAIRWELL','OTHER_FLAT')
  if positionsByRole~items<>4 then raise syntax 88.900 array('exactly four virtual viewpoint roles required')
  positions=.array~new
  do role over roles
    p=positionsByRole~at(role)
    if p==.nil then raise syntax 88.900 array('missing virtual viewpoint',role)
    positions~append(p)
  end
  predicted=_twoMic~virtualMicrophones(sourceHypothesis,positions,emissionMs)
  if \predicted~isA(.array) then raise syntax 88.900 array('provider virtual result must be array')
  if predicted~items<>4 then raise syntax 88.900 array('provider must return four predictions')
  output=.array~new
  do i=1 to 4
    item=predicted[i]
    if \item~isA(.directory) then raise syntax 88.900 array('virtual prediction directory required')
    if item['AUTHORITY']\=='MODEL_ONLY' then raise syntax 88.900 array('virtual prediction promoted to physical observation')
    row=.directory~new
    row['ROLE']=roles[i];row['PREDICTION']=item
    row['SOURCE']='OOREXX_PHYSICS_OR_SPASH_3D_MODEL'
    row['AUTHORITY']='MODEL_ONLY'
    output~append(row)
  end
  return output
::method comparePhysics
  expose _physics
  use strict arg candidateSummary, observedEvidence
  if _physics==.nil then raise syntax 88.900 array('Physics World matcher not injected')
  if candidateSummary==.nil | observedEvidence==.nil then raise syntax 88.900 array('observed evidence and candidate summary required')
  matchObj=_physics~score(candidateSummary,observedEvidence)
  if matchObj==.nil then return .nil /* Physics World fail-closed */
  out=.directory~new
  out['CANDIDATE_ID']=matchObj~candidateId
  out['COMPATIBLE']=matchObj~compatible
  out['TOLERANCE_NORMALIZED_RESIDUAL']=matchObj~score
  out['COMPONENT_COUNT']=matchObj~componentCount
  out['SOURCE']='PHYSICS_WORLD_F11_EVIDENCE_MATCHER'
  out['AUTHORITY']='CANDIDATE_COMPATIBILITY_NOT_SOURCE_LOCALIZATION'
  return out
