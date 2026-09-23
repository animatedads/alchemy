numeric digits 30
root=value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT'); if root='' then root='.'
fc=root||'/run/test/loud_fc.f32'; fd=root||'/run/test/loud_fd.f32'; out=root||'/run/test/loud_echo.tsv'
provider=.AudioV9SpatialNativeProvider~new(root||'/run/native/av9_spatial.bridge.json')
provider~scanLoudEchoEvents(fc,fd,out,8000,0.50,6,120,6,1,63832500000)
r=.AudioV9TsvReader~new(out)
h=r~header; idx=.directory~new
do i=1 to h~items; idx[h[i]]=i; end
rows=.array~new
do forever; row=r~next; if row==.nil then leave; rows~append(row); end
r~close
call assert rows~items>=3,'three synthetic high-peak events detected'
call assert abs((rows[1][idx['absolute_serial_ms']]+0)-(63832500000*1000+rows[1][idx['local_ms']]+0))<0.001,'absolute serial timestamp is preserved'
door=selfRow(rows,idx,2000)
call assert door[idx['leader']]='FD','door fixture leads at FD'
call assert abs((door[idx['fd_minus_fc_samples']]+0)+177)<=2,'door FC/FD delay recovered'
call assert door[idx['cross_score']]+0>0.85,'door cross-feed match strong'
call assert door[idx['fd_DIVIDER_RETURN_23_32']]+0>0.80,'door 23.32 ms FD echo matched'
call assert door[idx['fd_STAIRWELL_LONG_58_30']]+0>0.80,'door 58.30 ms FD echo matched'
call assert door[idx['pattern_hint']]='FD_STAIRWELL_PATTERN','door classified as FD stairwell pattern'
road=selfRow(rows,idx,5000)
call assert road[idx['leader']]='FC','road fixture leads at FC'
call assert abs((road[idx['fd_minus_fc_samples']]+0)-140)<=2,'road FC/FD delay recovered'
call assert road[idx['cross_score']]+0>0.85,'road cross-feed match strong'
call assert road[idx['fc_BOX_WALL_17_50']]+0>0.80,'road 17.50 ms FC echo matched'
call assert road[idx['pattern_hint']]='FC_ROAD_SIDE_PATTERN','road classified as FC road-side pattern'
cat=selfRow(rows,idx,8000)
call assert cat[idx['cross_score']]+0>0.80,'mobile fixture still cross-feed matched'
call assert cat[idx['echo_match']]='WEAK_OR_UNMODELED','mobile fixture does not get a strong modeled echo'
call assert cat[idx['pattern_hint']]='UNRESOLVED_PATTERN','mobile fixture pattern remains unresolved'
say 'PASS loud echo survey assertions=16 events='||rows~items
exit 0
selfRow: procedure
  use strict arg rows,idx,targetMs
  best=.nil; dist=1e99
  do row over rows
    d=abs((row[idx['local_ms']]+0)-targetMs)
    if d<dist then do; dist=d; best=row; end
  end
  if best==.nil | dist>10 then do; say 'FAIL missing event near' targetMs; exit 1; end
  return best
assert: procedure
  use strict arg condition,label
  if \condition then do; say 'FAIL' label; exit 1; end
return
::requires 'AudioV9SpatialNativeProvider.cls'
::requires 'AudioV9Tsv.cls'
