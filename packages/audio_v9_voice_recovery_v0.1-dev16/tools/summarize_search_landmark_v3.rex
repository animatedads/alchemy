numeric digits 30
parse arg planPath echoPath outPath windowMs
if outPath='' then do
  say 'usage: summarize_search_landmark_v3.rex LANDMARK_PLAN.tsv LOUD_EVENT_ECHOES_V3.tsv OUT.tsv [WINDOW_MS]'
  exit 2
end
if windowMs='' then windowMs=2000
windowMs=windowMs+0
if windowMs<0 | windowMs>60000 then do; say 'FAIL anchor summary window must be 0..60000 ms'; exit 2; end
planExpected=.array~of('landmark_id','feed','source_path','file_nominal_start','absolute_time','offset_seconds','anchor_subsecond_ms','probe_start_serial','anchor_serial','anchor_serial_ms','probe_end_serial','pre_seconds','post_seconds','annotation_author','observation_class','listening_method','content_cue','follow_on_cue','status')
p=.AudioV9TsvReader~new(planPath,planExpected)
plan=p~next; extra=p~next; p~close
if plan==.nil | extra\==.nil then do; say 'FAIL landmark plan must contain exactly one row'; exit 2; end
anchorMs=plan[10]+0
r=.AudioV9TsvReader~new(echoPath)
h=r~header
idx=.directory~new; do i=1 to h~items; idx[h[i]]=i; end
required=.array~of('event_index','absolute_serial_ms','trigger_feed','leader','fd_minus_fc_ms','cross_score','best_echo_feed','best_echo_family','best_echo_delay_ms','best_echo_score','ambiguity_hint','cross_boundary','fc_global_1_lag_ms','fc_global_1_score','fd_global_1_lag_ms','fd_global_1_score')
do name over required
  if \idx~hasIndex(name) then do; say 'FAIL v3 landmark summary missing column' name; exit 2; end
end
outHeader=.array~of('landmark_id','anchor_serial_ms','anchor_delta_ms')
do i=1 to h~items; outHeader~append(h[i]); end
w=.AudioV9TsvWriter~new(outPath,outHeader)
count=0; nearestAbs=1e99; nearestDelta=''; nearestIndex=''
do forever
  row=r~next; if row==.nil then leave
  delta=(row[idx['absolute_serial_ms']]+0)-anchorMs
  ad=abs(delta)
  if ad<nearestAbs then do; nearestAbs=ad; nearestDelta=delta; nearestIndex=row[idx['event_index']]; end
  if ad<=windowMs then do
    out=.array~of(plan[1],anchorMs,delta)
    do i=1 to row~items; out~append(row[i]); end
    w~write(out); count+=1
  end
end
r~close; w~close
if nearestIndex='' then say 'PASS landmark v3 summary rows=0 nearest=NONE out='||outPath
else say 'PASS landmark v3 summary rows='||count||' nearest_event='||nearestIndex||' nearest_delta_ms='||nearestDelta||' out='||outPath
exit 0
::requires 'AudioV9Tsv.cls'
