numeric digits 30
root=value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT'); if root='' then root='.'
plan=root||'/run/test/landmark_summary_plan.tsv'; src=root||'/run/test/loud_echo_v3.tsv'; out=root||'/run/test/landmark_summary.tsv'
header=.array~of('landmark_id','feed','source_path','file_nominal_start','absolute_time','offset_seconds','anchor_subsecond_ms','probe_start_serial','anchor_serial','anchor_serial_ms','probe_end_serial','pre_seconds','post_seconds','annotation_author','observation_class','listening_method','content_cue','follow_on_cue','status')
w=.AudioV9TsvWriter~new(plan,header)
w~write(.array~of('SYNTHETIC','FC_FD','fixture','2023-10-10 00:00:00','2023-10-10 00:00:02',2,0,63832500000,63832500002,63832500002000,63832500020,2,18,'TEST','SYNTHETIC','NONE','fixture','none','TEST'))
w~close
cmd='"'||root||'/tools/run_rexx_pinned.sh" "'||root||'/tools/summarize_search_landmark_v3.rex" "'||plan||'" "'||src||'" "'||out||'" 10'
address system cmd
call ok rc=0,'summary tool exits zero'
r=.AudioV9TsvReader~new(out)
h=r~header; idx=.directory~new; do i=1 to h~items; idx[h[i]]=i; end
row=r~next; extra=r~next; r~close
call ok row\==.nil,'one near-anchor row exists'
call ok extra==.nil,'10 ms window isolates first event'
call ok row[idx['landmark_id']]='SYNTHETIC','landmark id propagated'
call ok abs((row[idx['anchor_delta_ms']]+0)-1.875)<0.0001,'subsample event delta preserved'
call ok row[idx['trigger_feed']]='FD','v3 evidence fields preserved'
call ok row[idx['fd_global_1_score']]+0>0.99,'prior-free v3 peak preserved in summary'
say 'PASS search landmark v3 summary assertions=7 delta_ms='||row[idx['anchor_delta_ms']]
exit 0
ok: procedure
  use arg condition,label
  if condition then return
  say 'FAIL 'label
  exit 1
::requires 'AudioV9Tsv.cls'
