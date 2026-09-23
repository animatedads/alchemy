parse arg root .
if root='' then root='.'
source=root||'/tests/synthetic_night_tiny.mp4'
qroot=root||'/qualification/migration_equivalence'
basePrefix=qroot||'/baseline/analysis'; baseState=qroot||'/baseline/state'
srcPrefix=qroot||'/source/analysis'; srcState=qroot||'/source/state'
dstPrefix=qroot||'/destination/analysis'; dstState=qroot||'/destination/state'
address system 'rm -rf '||quote(qroot)
address system 'mkdir -p '||quote(qroot||'/baseline')' '||quote(qroot||'/source')' '||quote(qroot||'/destination/media')' '||quote(srcState)' '||quote(dstState)
if rc<>0 then call fail 'qualification directories'

cfg1=makeConfig()
w1=.FDDoorMicroMotionWorker~new(source,cfg1,basePrefix,baseState,'sha256:test-synthetic')
status=w1~run
if status<>'OK' then call fail 'baseline status='||status

/* Place the pause request before launch.  The worker polls only at configured
   safe frame boundaries, so this deterministically pauses after a committed
   frame rather than in the middle of decoder/TSV mutation. */
ctl=.FDCheckpointState~new
ctl~put('command','PAUSE'); ctl~put('request_id','REQ-MIG-EQ'); ctl~put('migration_id','MIG-EQ'); ctl~put('job_id','JOB-EQ'); ctl~put('checkpoint_id','CKPT-EQ'); ctl~put('source_node_id','NODE-S'); ctl~put('source_placement_id','PLACE-S'); ctl~put('source_ownership_epoch','7'); ctl~put('now_epoch_ms','1234567')
.FDControlFile~write(srcState||'/pause.request.tsv',ctl)
cfg2=makeConfig()
w2=.FDDoorMicroMotionWorker~new(source,cfg2,srcPrefix,srcState,'sha256:test-synthetic')
status=w2~run
if status<>'PAUSED' then call fail 'source did not pause status='||status
paused=.FDControlFile~read(srcState||'/paused.tsv')
if paused==.nil then call fail 'paused marker missing'
if paused~get('checkpoint_id','')<>'CKPT-EQ' then call fail 'checkpoint id binding'
bundle=paused~get('checkpoint_transfer_ref',''); digest=paused~get('checkpoint_state_digest','')
if bundle='' | digest='' then call fail 'transfer bundle evidence missing'
if stream(bundle,'C','QUERY EXISTS')=='' then call fail 'transfer bundle file missing'

/* Simulate Storage Fabric delivering identical verified bytes to another node. */
delivered=qroot||'/destination/CKPT-EQ.fdmjob.tar'
.FDFileUtil~copyExact(bundle,delivered)
material=.FDMigrationBundle~materialize(delivered,dstPrefix,dstState,digest,'CKPT-EQ')
if material==.nil then call fail 'bundle materialization'
if material~partCount<>1 then call fail 'materialized part count='||material~partCount
/* Exercise real cross-node path rebasing: same strong source evidence and
   same logical filename, different local path on the destination. */
destinationSource=qroot||'/destination/media/synthetic_night_tiny.mp4'
.FDFileUtil~copyExact(source,destinationSource)
cfg3=makeConfig()
w3=.FDDoorMicroMotionWorker~new(destinationSource,cfg3,dstPrefix,dstState,'sha256:test-synthetic',material~checkpointPath)
status=w3~run
if status<>'OK' then call fail 'destination resume status='||status

/* Scientific evidence must be independent of the migration boundary. */
do kind over .array~of('samples','events','epochs','relocations','exclusions')
  a=basePrefix||'.'||kind||'.tsv'; b=dstPrefix||'.'||kind||'.tsv'
  if stream(a,'C','QUERY EXISTS')=='' | stream(b,'C','QUERY EXISTS')=='' then call fail 'missing merged evidence kind='||kind
  ha=.FDFileUtil~sha256(a); hb=.FDFileUtil~sha256(b)
  if ha<>hb then call fail 'evidence differs after migration kind='||kind||' baseline='||ha||' resumed='||hb
end
say 'PASS migration resume evidence-equivalent digest='digest 'checkpoint='material~checkpointPath
exit 0

makeConfig: procedure
  c=.FDDoorMicroMotionConfig~new
  c~referenceMediaMs=0
  c~bootstrapFrameXLo=0.25; c~bootstrapFrameXHi=0.38; c~fullSearchXLo=0.02; c~fullSearchXHi=0.66
  c~maximumFrames=20; c~controlPollFrames=10; c~decoderPrerollMs=800
  return c

quote: procedure
  parse arg s
  return "'"||s~changestr("'","'\\''")||"'"

fail: procedure
  parse arg m
  say 'FAIL' m
  exit 1
::requires 'FDDoorMicroMotion.cls'
