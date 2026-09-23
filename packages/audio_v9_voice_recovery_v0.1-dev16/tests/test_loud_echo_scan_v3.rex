numeric digits 30
root=value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT'); if root='' then root='.'
fc=root||'/run/test/loud_fc.f32'; fd=root||'/run/test/loud_fd.f32'; out=root||'/run/test/loud_echo_v3.tsv'
provider=.AudioV9SpatialNativeProvider~new(root||'/run/native/av9_spatial.bridge.json')
provider~scanLoudEchoEventsV3(fc,fd,out,8000,0.001,6,120,6,4,63832500000,0.70,6,80,3)
r=.AudioV9TsvReader~new(out)
h=r~header; idx=.directory~new; do i=1 to h~items; idx[h[i]]=i; end
rows=.array~new; do forever; row=r~next; if row==.nil then leave; rows~append(row); end; r~close
call assert rows~items>=5,'v3 detects five synthetic events'
call assert idx['cross_boundary']>0,'cross boundary column present'
call assert idx['fc_global_1_lag_samples']>0,'prior-free FC recurrence column present'
call assert idx['fd_global_4_score']>0,'four prior-free FD peaks retained'
door=selfRow(rows,idx,2000)
call assert door[idx['trigger_feed']]='FD','door retains v2 trigger semantics'
call assert hasLag(door,idx,'fd',187,3),'door prior-free FD search recovers ~23.32 ms replica'
call assert hasLag(door,idx,'fd',466,3),'door prior-free FD search recovers ~58.30 ms replica'
road=selfRow(rows,idx,5000)
call assert hasLag(road,idx,'fc',140,3),'road prior-free FC search recovers 17.50 ms replica'
free=selfRow(rows,idx,8000)
call assert hasLag(free,idx,'fc',280,3),'unconstrained event recovers 35 ms recurrence without named-family centre'
edge=selfRow(rows,idx,11000)
call assert edge[idx['cross_boundary']]+0=1,'exact +/-35 ms cross-feed result is flagged censored'
call assert abs(edge[idx['fd_minus_fc_samples']]+0)=280,'cross-feed boundary fixture lands at 280 samples'
call assert edge[idx['cross_search_radius_ms']]+0=35,'cross-feed search radius recorded'
call assert edge[idx['fc_global_search_complete']]+0=1,'FC global search complete'
call assert edge[idx['fd_global_search_complete']]+0=1,'FD global search complete'
call assert edge[idx['global_min_ms']]+0=6 & edge[idx['global_max_ms']]+0=80,'global search bounds recorded'
say 'PASS loud echo v3 survey assertions=15 events='||rows~items
exit 0
selfRow: procedure
  use strict arg rows,idx,targetMs
  best=.nil; dist=1e99
  do row over rows; d=abs((row[idx['local_ms']]+0)-targetMs); if d<dist then do; dist=d; best=row; end; end
  if best==.nil | dist>10 then do; say 'FAIL missing event near' targetMs; exit 1; end
  return best
hasLag: procedure
  use strict arg row,idx,feed,target,tolerance
  do k=1 to 4
    name=feed||'_global_'||k||'_lag_samples'
    if abs((row[idx[name]]+0)-target)<=tolerance then return .true
  end
  return .false
assert: procedure
  use strict arg condition,label
  if \condition then do; say 'FAIL' label; exit 1; end
return
::requires 'AudioV9SpatialNativeProvider.cls'
::requires 'AudioV9Tsv.cls'
