numeric digits 30
root=value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT'); if root='' then root='.'
fc=root||'/run/test/loud_fc.f32'; fd=root||'/run/test/loud_fd.f32'; out=root||'/run/test/loud_echo_v2.tsv'
provider=.AudioV9SpatialNativeProvider~new(root||'/run/native/av9_spatial.bridge.json')
provider~scanLoudEchoEventsV2(fc,fd,out,8000,0.001,6,120,6,4,63832500000,0.70)
r=.AudioV9TsvReader~new(out)
h=r~header; idx=.directory~new
do i=1 to h~items; idx[h[i]]=i; end
rows=.array~new
do forever; row=r~next; if row==.nil then leave; rows~append(row); end
r~close
call assert rows~items>=4,'v2 detects low-gain feed-relative event in addition to dev11 fixtures'
call assert idx['trigger_feed']>0,'trigger_feed column present'
call assert idx['best_echo_feed']>0,'best_echo_feed column present'
call assert idx['strong_family_count']>0,'strong family ambiguity column present'
call assert idx['boundary_hit_count']>0,'boundary evidence column present'
door=selfRow(rows,idx,2000)
call assert door[idx['trigger_feed']]='FD','door trigger is independently FD-relative'
call assert door[idx['leader']]='FD','door acoustic leader remains FD'
call assert abs((door[idx['fd_minus_fc_samples']]+0)+177)<=2,'door cross-feed delay recovered'
call assert door[idx['strong_family_count']]+0>=1,'door retains strong family evidence'
road=selfRow(rows,idx,5000)
call assert road[idx['trigger_feed']]='FC','road trigger is independently FC-relative'
call assert road[idx['leader']]='FC','road acoustic leader remains FC'
call assert abs((road[idx['fd_minus_fc_samples']]+0)-140)<=2,'road cross-feed delay recovered'
low=selfRow(rows,idx,10000)
call assert low[idx['trigger_feed']]='FD','sub-0.50 event admitted from FD own baseline'
call assert low[idx['peak_fd']]+0<0.50,'low-gain qualification event stays below dev11 absolute floor'
call assert low[idx['peak_to_baseline_fd']]+0>6,'low-gain FD event passes feed-relative ratio'
call assert low[idx['boundary_hit_count']]+0>=1,'search-boundary clipping is explicit evidence'
call assert low[idx['search_radius_ms']]+0=4,'wider bounded radius recorded in row'
call assert low[idx['best_second_margin']]+0>=0,'ambiguity margin retained as evidence'
say 'PASS loud echo v2 survey assertions=19 events='||rows~items
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
