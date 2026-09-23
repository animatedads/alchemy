/* Real decoder + real coherent POSIX source guard. */
parse arg root .
if root='' then root='.'
source=root||'/tests/synthetic_night_tiny.mp4'
prefix=root||'/qualification/posix_guard_worker'
stateDir=root||'/qualification/posix_guard_worker_state'
address system 'rm -rf '||quote(stateDir)||' '||quote(prefix)||'.*'
cfg=.FDDoorMicroMotionConfig~new
cfg~referenceMediaMs=0; cfg~bootstrapFrameXLo=0.25; cfg~bootstrapFrameXHi=0.38; cfg~fullSearchXLo=0.02; cfg~fullSearchXHi=0.66
cfg~maximumFrames=5; cfg~sourceStabilityQuietMs=50; cfg~sourceStabilityPollFrames=2
posix=.PosixGapFactory~create
guard=.FDSourceStabilityGuard~new(posix,source,cfg~sourceStabilityQuietMs,cfg~sourceStabilityPollFrames)
w=.FDDoorMicroMotionWorker~new(source,cfg,prefix,stateDir,'sha256:synthetic-test','', 'camera_ffmpeg_avformat.bridge.json','camera_ffmpeg_avcodec.bridge.json','camera_ffmpeg_avutil.bridge.json',guard)
status=w~run
if status<>'OK' then call fail 'worker status='||status||' guard='||guard~status||' error='||guard~lastError
run=readOne(prefix||'.run.tsv')
if run==.nil then call fail 'missing run TSV'
if run['source_guard_provider']<>'rxposixgap+rxunixsys' then call fail 'provider='||run['source_guard_provider']
if run['source_guard_status']<>'STABLE' then call fail 'guard status='||run['source_guard_status']
if (run['source_guard_checks']+0)<5 then call fail 'too few checks='||run['source_guard_checks']
if run['source_local_identity']='' | (run['source_local_size']+0)<=0 then call fail 'missing source identity evidence'
if run['source_guard_mutation_detected']<>'0' then call fail 'false mutation flag'
say 'PASS real POSIX-guarded worker checks='||run['source_guard_checks'] 'identity='||run['source_local_identity']
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
::requires 'csvStream.cls'
::requires 'FDDoorMicroMotion.cls'
::requires 'PosixGap.cls'
