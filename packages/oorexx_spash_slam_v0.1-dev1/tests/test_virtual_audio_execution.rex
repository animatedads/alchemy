/* Self-contained seam qualification. Injects provider spies; no new DSP. */
numeric digits 20
r=.SpashTestRegistry~new
m=.SpashTestVirtualModel~new
p=.SpashTestPhysics~new
x=.SpashVirtualAudioExecution~new(r,m,p)
a=.directory~new;a['FEED_ID']='FD';a['SOURCE_SHA256']=copies('a',64);a['SOURCE_AUTHORITY']='ORIGINAL_OBSERVED_AUDIO'
b=.directory~new;b['FEED_ID']='FC';b['SOURCE_SHA256']=copies('b',64);b['SOURCE_AUTHORITY']='ORIGINAL_OBSERVED_AUDIO'
.environment~put(0,'SPASH_CHECKS')
clockEvidence=.directory~new;clockEvidence['CLOCK_MODEL_ID']='MEASURED_CLOCK';clockEvidence['AUTHORITY']='OBSERVED_CROSS_FEED_ALIGNMENT';clockEvidence['UNCERTAINTY_MS']=1
pathEvidence=.directory~new;pathEvidence['PATH_ID']='PATH-1';pathEvidence['AUTHORITY']='OBSERVED_COHERENT_AUDIO_PATH';pathEvidence['SOURCE_SHA256']=a['SOURCE_SHA256'];pathEvidence['METHOD_ID']='AUDIO.MULTIPATH.PATH_ESTIMATE'
paths=.array~of(pathEvidence)

call check x~methods~items=5,'five named V9 multipath methods'
plan=x~plan('POI1',.array~of(a,b),0,8000,8000,clockEvidence,paths,32)
call check plan['DSP_OWNER']='AUDIO_V9_NATIVE_AND_FOREIGN_RUNTIME','DSP stays with native V9'
call check plan['FFT_OWNER']='AUDIO_V9_SPECTRAL_FIELD_AND_OOREXX_MATHS','FFT stays with existing providers'
call check plan['MEMORY_OWNER']='MEMORY_FABRIC_RESIDENT_BLOCKS','resident block policy'
call check plan['ALLOW_PYTHON_PRODUCTION_DSP']==.false,'Python production DSP prohibited'
call check plan['REFERENCE_POI1_POLICY']='NO_GAIN_NO_FILTER_NO_MUTATION','POI1 never altered'
call check plan['EVIDENCE_GAIN_DB']=0,'evidence stream zero gain'
call check plan['REQUESTED_LISTENING_GAIN_DB']=32,'32dB derived listening policy only'
call check plan['CLOCK_VERIFIED']==.true,'clock evidence verified externally'
call check plan['MEASURED_COHERENT_PATH_COUNT']=1,'observed path record retained'
call check plan['SPATIAL_STATUS']='READY_FOR_AUDIO_V9_AND_PHYSICS_EVALUATION','gated dual feed ready'
call check plan['STAGES']~items=5,'all registered stages'
call check r~calls=5,'registry consulted for every method'
unready=x~plan('ONLY_FD',.array~of(a),0,8000,8000,.nil,.nil)
call check unready['SPATIAL_STATUS']='NOT_READY_ONE_OBSERVED_MIC','one physical mic no 3D solve'
call check unready['STAGES'][5]['ADMISSION']='NOT_APPLICABLE_NO_COHERENT_PATH','virtual reconstruction needs observed path'
clock=x~plan('NO_CLOCK',.array~of(a,b),0,8000,8000,.nil,paths)
call check clock['SPATIAL_STATUS']='NOT_READY_NO_OBSERVED_CLOCK_MODEL','clock cannot be guessed'
none=x~plan('NO_PATH',.array~of(a,b),0,8000,8000,clockEvidence,.nil)
call check none['SPATIAL_STATUS']='NOT_READY_NO_MEASURED_PATH','no virtual audio without coherent path'
spots=.directory~new
spots['PREDICTED_SOURCE']='p0';spots['STREET']='p1';spots['STAIRWELL']='p2';spots['OTHER_FLAT']='p3'
field=x~virtualField('src',spots,0)
call check field~items=4,'four prescribed viewpoints'
call check field[1]['AUTHORITY']='MODEL_ONLY','all virtual predictions model only'
call check field[4]['ROLE']='OTHER_FLAT','other flat viewpoint preserved'
call check m~called=1,'existing virtual provider invoked once'
res=x~comparePhysics('summary','observed')
call check res['AUTHORITY']='CANDIDATE_COMPATIBILITY_NOT_SOURCE_LOCALIZATION','Physics result not a localization claim'
call check res['COMPATIBLE']==.true,'Physics compatibility delegated'
call check p~called=1,'external Physics matcher used'
if .environment~at('SPASH_CHECKS')<>24 then do;say 'FAIL count' .environment~at('SPASH_CHECKS');exit 2;end
say 'SPASH native virtual-audio execution seam PASS' .environment~at('SPASH_CHECKS') 'checks'
exit 0
::routine check
  use strict arg result,caption
  if \result then do;say 'FAIL:' caption;exit 2;end
  .environment~put(.environment~at('SPASH_CHECKS')+1,'SPASH_CHECKS')
  say 'PASS:' caption
::class SpashTestRegistry
::method init; expose calls;calls=0
::method supports
  use strict arg id
  return pos(id,'AUDIO.MULTIPATH.PATH_ESTIMATE|AUDIO.MULTIPATH.SPECTRAL_TRACK|AUDIO.MULTIPATH.MOTION_COHERENCE|AUDIO.MULTIPATH.PHYSICS_COMPATIBILITY|AUDIO.RECON.MULTIPATH_VIRTUAL_MIC')>0
::method profile
  expose calls
  use strict arg id
  calls=calls+1
  return 'PROFILE:'||id
::attribute calls get
::class SpashTestVirtualModel
::method init; expose called;called=0
::method virtualMicrophones
  expose called
  use strict arg source,positions,emission
  called=called+1
  out=.array~new
  do i=1 to positions~items
    d=.directory~new;d['AUTHORITY']='MODEL_ONLY';d['MIC_ID']=positions[i];d['PREDICTED_ARRIVAL_MS']=i*10
    out~append(d)
  end
  return out
::attribute called get
::class SpashTestPhysics
::method init;expose called;called=0
::method score
  expose called
  use strict arg summary,observed
  called=called+1
  return .SpashTestPhysicsResult~new
::attribute called get
::class SpashTestPhysicsResult
::method candidateId;return 'H1'
::method compatible;return .true
::method score;return .125
::method componentCount;return 4
::requires 'SpashVirtualAudioExecution.cls'
