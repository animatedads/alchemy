numeric digits 30
parse arg landmarkId outPath preSeconds postSeconds
if outPath='' then do
  say 'usage: plan_search_landmark.rex LANDMARK_ID OUT.tsv [PRE_SECONDS] [POST_SECONDS]'
  exit 2
end
root=value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT'); if root='' then root='.'
path=root||'/reference/SEARCH_LANDMARKS.tsv'
expected=.array~of('landmark_id','feed','source_path','file_nominal_start','absolute_time','offset_seconds','anchor_subsecond_ms','default_pre_seconds','default_post_seconds','annotation_author','observation_class','listening_method','content_cue','follow_on_cue','status')
r=.AudioV9TsvReader~new(path,expected)
found=.nil
do forever
  row=r~next
  if row==.nil then leave
  if row[1]==landmarkId then do; found=row; leave; end
end
r~close
if found==.nil then do; say 'FAIL unknown search landmark' landmarkId; exit 2; end
if preSeconds='' then preSeconds=found[8]
if postSeconds='' then postSeconds=found[9]
preSeconds=preSeconds+0; postSeconds=postSeconds+0
if preSeconds<0 | postSeconds<0 then do; say 'FAIL landmark window bounds must be non-negative'; exit 2; end
if preSeconds+postSeconds>600 then do; say 'FAIL landmark window is bounded to 600 seconds'; exit 2; end
subMs=found[7]+0
if subMs<0 | subMs>=1000 | subMs<>subMs~trunc then do; say 'FAIL anchor_subsecond_ms must be integer 0..999'; exit 2; end
fileSerial=.AudioV9VoiceClock~parse(found[4]); eventSerial=.AudioV9VoiceClock~parse(found[5])
actualOffset=eventSerial-fileSerial
if actualOffset<>found[6]+0 then do
  say 'FAIL landmark filename/time offset mismatch expected='||found[6]||' actual='||actualOffset
  exit 2
end
anchorSerialMs=eventSerial*1000+subMs
startSerial=eventSerial-preSeconds; endSerial=eventSerial+postSeconds
header=.array~of('landmark_id','feed','source_path','file_nominal_start','absolute_time','offset_seconds','anchor_subsecond_ms','probe_start_serial','anchor_serial','anchor_serial_ms','probe_end_serial','pre_seconds','post_seconds','annotation_author','observation_class','listening_method','content_cue','follow_on_cue','status')
w=.AudioV9TsvWriter~new(outPath,header)
w~write(.array~of(found[1],found[2],found[3],found[4],found[5],found[6],subMs,startSerial,eventSerial,anchorSerialMs,endSerial,preSeconds,postSeconds,found[10],found[11],found[12],found[13],found[14],found[15]))
w~close
/* Stable machine-readable stdout protocol for the shell runner. */
say startSerial endSerial eventSerial found[2] anchorSerialMs
exit 0
::requires 'AudioV9VoiceCampaign.cls'
::requires 'AudioV9Tsv.cls'
