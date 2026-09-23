numeric digits 30
parse arg fcPath fdPath outPath minAbsPeak minRatio refractoryMs templateMs radiusMs startSerial strongScore globalMinMs globalMaxMs globalSeparationMs
if outPath='' then do
  say 'usage: scan_loud_echo_events_v3.rex FC.f32 FD.f32 OUT.tsv [MIN_ABS_PEAK] [MIN_RATIO] [REFRACTORY_MS] [TEMPLATE_MS] [RADIUS_MS] [START_SERIAL] [STRONG_SCORE] [GLOBAL_MIN_MS] [GLOBAL_MAX_MS] [GLOBAL_SEPARATION_MS]'
  exit 2
end
if minAbsPeak='' then minAbsPeak=0.001
if minRatio='' then minRatio=6
if refractoryMs='' then refractoryMs=120
if templateMs='' then templateMs=6
if radiusMs='' then radiusMs=4
if startSerial='' then startSerial=0
if strongScore='' then strongScore=0.70
if globalMinMs='' then globalMinMs=6
if globalMaxMs='' then globalMaxMs=80
if globalSeparationMs='' then globalSeparationMs=3
root=value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT'); if root='' then root='.'
provider=.AudioV9SpatialNativeProvider~new(root||'/run/native/av9_spatial.bridge.json')
provider~scanLoudEchoEventsV3(fcPath,fdPath,outPath,8000,minAbsPeak,minRatio,refractoryMs,templateMs,radiusMs,startSerial,strongScore,globalMinMs,globalMaxMs,globalSeparationMs)
r=.AudioV9TsvReader~new(outPath)
h=r~header
required=.array~of('event_index','local_sample','local_ms','absolute_serial_ms','trigger_feed','leader','region_hint','peak_fc','peak_fd','baseline_fc','baseline_fd','peak_to_baseline_fc','peak_to_baseline_fd','trigger_peak_to_baseline','fd_minus_fc_samples','fd_minus_fc_ms','cross_score','best_echo_feed','best_echo_family','best_echo_delay_ms','best_echo_score','second_echo_score','best_second_margin','strong_family_count','strong_feed_hypothesis_count','boundary_hit_count','best_echo_boundary','search_radius_ms','strong_score','echo_match','ambiguity_hint','pattern_hint')
if h~items<required~items+35 then do; say 'FAIL loud echo v3 TSV header too short'; exit 2; end
do i=1 to required~items
  if h[i]\==required[i] then do; say 'FAIL loud echo v3 inherited field' i h[i] required[i]; exit 2; end
end
idx=.directory~new; do i=1 to h~items; idx[h[i]]=i; end
extra=.array~of('cross_boundary','cross_search_radius_ms','fc_local_nonzero','fd_local_nonzero','fc_baseline_coverage_ms','fd_baseline_coverage_ms','fc_global_search_complete','fd_global_search_complete','global_min_ms','global_max_ms','global_separation_ms','fc_global_1_lag_samples','fc_global_1_lag_ms','fc_global_1_score','fd_global_1_lag_samples','fd_global_1_lag_ms','fd_global_1_score')
do k over extra; if \idx~hasIndex(k) then do; say 'FAIL loud echo v3 field missing' k; exit 2; end; end
count=0
do forever
  row=r~next; if row==.nil then leave; count+=1
end
r~close
say 'PASS loud echo v3 scan events='||count||' out='||outPath
exit 0
::requires 'AudioV9SpatialNativeProvider.cls'
::requires 'AudioV9Tsv.cls'
