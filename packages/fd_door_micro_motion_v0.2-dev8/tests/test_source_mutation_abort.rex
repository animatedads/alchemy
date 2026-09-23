/* Worker must fail closed when its bound source guard reports mutation. */
parse arg root .
if root='' then root='.'
source=root||'/tests/synthetic_night_tiny.mp4'
prefix=root||'/qualification/mutation_abort'
stateDir=root||'/qualification/mutation_abort_state'
address system 'rm -rf '||quote(stateDir)||' '||quote(prefix)||'.*'
cfg=.FDDoorMicroMotionConfig~new
cfg~referenceMediaMs=0; cfg~bootstrapFrameXLo=0.25; cfg~bootstrapFrameXHi=0.38; cfg~fullSearchXLo=0.02; cfg~fullSearchXHi=0.66
cfg~maximumFrames=30; cfg~sourceStabilityPollFrames=1
guard=.FailingGuard~new
w=.FDDoorMicroMotionWorker~new(source,cfg,prefix,stateDir,'test:mutation', '', 'camera_ffmpeg_avformat.bridge.json','camera_ffmpeg_avcodec.bridge.json','camera_ffmpeg_avutil.bridge.json',guard)
status=w~run
if status<>'SOURCE_MUTATED' then call fail 'status='||status
run=readOne(prefix||'.run.tsv')
if run==.nil then call fail 'missing abort run TSV'
if run['status']<>'SOURCE_MUTATED' then call fail 'run status='||run['status']
if run['source_guard_mutation_detected']<>'1' then call fail 'mutation provenance absent'
/* Startup instability is control-plane provenance only: it must not overwrite
   a prior scientific .run.tsv if this is a failed RESUME. */
prefix2=root||'/qualification/preflight_unstable'
stateDir2=root||'/qualification/preflight_unstable_state'
address system 'rm -rf '||quote(stateDir2)||' '||quote(prefix2)||'.*'
/* Seed an existing scientific run artifact to model a failed RESUME. */
sentinel=.CSVStream~new(prefix2||'.run.tsv',.false); sentinel~delimiter='09'x; sentinel~open('write replace')
sentinel~csvLineOut(.array~of('sentinel','value')); sentinel~csvLineOut(.array~of('preserve','yes')); sentinel~close
resumeMarker=stateDir2||'/prior.checkpoint.tsv'
g2=.PreflightFailGuard~new
w2=.FDDoorMicroMotionWorker~new(source,cfg,prefix2,stateDir2,'test:preflight', resumeMarker, 'camera_ffmpeg_avformat.bridge.json','camera_ffmpeg_avcodec.bridge.json','camera_ffmpeg_avutil.bridge.json',g2)
status2=w2~run
if status2<>'SOURCE_NOT_STABLE_AT_START' then call fail 'preflight status='||status2
sentinelAfter=readOne(prefix2||'.run.tsv')
if sentinelAfter==.nil | sentinelAfter['value']<>'yes' then call fail 'preflight overwrote prior scientific run TSV'
preflight=.FDControlFile~read(stateDir2||'/source.guard.failure.tsv')
if preflight==.nil then call fail 'preflight control provenance missing'
if preflight~get('status')<>'SOURCE_NOT_STABLE_AT_START' then call fail 'preflight control status='||preflight~get('status')
if preflight~get('source_guard_mutation_detected')<>'1' then call fail 'preflight mutation provenance absent'
if preflight~get('resume_checkpoint_path')<>resumeMarker then call fail 'preflight resume provenance missing'

say 'PASS source mutation abort checks='||run['source_guard_checks'] 'preflight='||status2
exit 0

readOne: procedure
  use arg path
  inp=.CSVStream~new(path,.false); inp~delimiter='09'x; inp~open('read')
  if inp~state<>'READY' then return .nil
  header=inp~csvLineIn; row=inp~csvLineIn; inp~close
  if header==.nil | row==.nil then return .nil
  d=.directory~new
  do i=1 to header~items
    v=''; if row~items>=i then v=row[i]
    d[header[i]]=v
  end
  return d
quote: procedure
  parse arg x
  return "'"||x~changestr("'","'\\''")||"'"
fail: procedure
  parse arg m
  say 'FAIL' m
  exit 1

::class FailingGuard
::attribute provider get
::attribute status get
::attribute checks get
::attribute targetIdentity get
::attribute targetSize get
::attribute targetMtimeSec get
::attribute targetMtimeNsec get
::attribute linkTarget get
::attribute lastError get
::attribute mutationDetected get
::method init
  expose provider status checks targetIdentity targetSize targetMtimeSec targetMtimeNsec linkTarget lastError mutationDetected
  provider='TEST'; status='INIT'; checks=0; targetIdentity='1:2:REGULAR'; targetSize=100; targetMtimeSec=1; targetMtimeNsec=2; linkTarget=''; lastError=''; mutationDetected=.false
::method establish
  expose status checks
  checks+=2; status='STABLE'; return .true
::method check
  expose status checks mutationDetected
  checks+=1
  if checks>=4 then do; status='SOURCE_MUTATED'; mutationDetected=.true; return .false; end
  status='STABLE'; return .true

::class PreflightFailGuard
::attribute provider get
::attribute status get
::attribute checks get
::attribute targetIdentity get
::attribute targetSize get
::attribute targetMtimeSec get
::attribute targetMtimeNsec get
::attribute linkTarget get
::attribute lastError get
::attribute mutationDetected get
::method init
  expose provider status checks targetIdentity targetSize targetMtimeSec targetMtimeNsec linkTarget lastError mutationDetected
  provider='TEST'; status='INIT'; checks=0; targetIdentity='1:2:REGULAR'; targetSize=100; targetMtimeSec=1; targetMtimeNsec=2; linkTarget=''; lastError=''; mutationDetected=.false
::method establish
  expose status checks mutationDetected
  checks=2; status='SOURCE_NOT_STABLE_AT_START'; mutationDetected=.true; return .false
::method check
  expose status checks
  checks+=1; status='SOURCE_NOT_STABLE_AT_START'; return .false

::requires 'csvStream.cls'
::requires 'FDDoorMicroMotion.cls'
