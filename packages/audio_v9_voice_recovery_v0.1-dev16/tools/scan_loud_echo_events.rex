numeric digits 30
parse arg fcPath fdPath outPath minPeak minRatio refractoryMs templateMs radiusMs startSerial
if outPath='' then do
  say 'usage: scan_loud_echo_events.rex FC.f32 FD.f32 OUT.tsv [MIN_PEAK] [MIN_RATIO] [REFRACTORY_MS] [TEMPLATE_MS] [RADIUS_MS] [START_SERIAL]'
  exit 2
end
if minPeak='' then minPeak=0.50
if minRatio='' then minRatio=6
if refractoryMs='' then refractoryMs=120
if templateMs='' then templateMs=6
if radiusMs='' then radiusMs=1
if startSerial='' then startSerial=0
root=value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT'); if root='' then root='.'
provider=.AudioV9SpatialNativeProvider~new(root||'/run/native/av9_spatial.bridge.json')
provider~scanLoudEchoEvents(fcPath,fdPath,outPath,8000,minPeak,minRatio,refractoryMs,templateMs,radiusMs,startSerial)
/* Validate the native TSV through the project CSVStream boundary. */
r=.AudioV9TsvReader~new(outPath)
h=r~header
required=.array~of('event_index','local_sample','local_ms','absolute_serial_ms','leader','region_hint','peak_fc','peak_fd','baseline_fc','baseline_fd','peak_to_baseline','fd_minus_fc_samples','fd_minus_fc_ms','cross_score','best_echo_family','best_echo_delay_ms','best_echo_score','echo_match','pattern_hint')
if h~items<required~items then do; say 'FAIL loud echo TSV header too short'; exit 2; end
do i=1 to required~items
  if h[i]\==required[i] then do; say 'FAIL loud echo TSV header field' i h[i] required[i]; exit 2; end
end
count=0
do forever
  row=r~next
  if row==.nil then leave
  count+=1
end
r~close
say 'PASS loud echo scan events='||count||' out='||outPath
exit 0
::requires 'AudioV9SpatialNativeProvider.cls'
::requires 'AudioV9Tsv.cls'
