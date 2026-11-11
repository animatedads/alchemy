/* call_edges.rex -- abrupt on/off edges per active second (broken video call vs live voice).
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 31 Oct 2026.
 * 10 ms speech-band level (native band blocks 128/80, 300-3400 Hz); med = window median.
 * abrupt rise: L[i]-L[i-1] >= 12 dB and L[i] >= med+12; abrupt fall: L[i-1]-L[i] >= 12 dB and L[i-1] >= med+12.
 * active = frames >= med+8.  Output: edges, active_s, edges_per_active_s, bursts (runs of >= 3 active frames).
 */
numeric digits 16
parse arg f lab
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
say left(lab,36) callEdges(prov,f)
exit 0
::routine callEdges public
  use arg prov, f
  bl=prov~bandBlocks(f,8000,128,80,1,1,300,3400)
  lv=.array~new; do d over bl; lv~append(10*RxCalcLog10(max(d['BANDS'][1],1e-20),16)); end
  n=lv~items; s=lv~copy~sortWith(.NumericComparator~new); med=s[(n+1)%2]
  ed=0; act=0; bursts=0; run=0
  do i=2 to n
    if lv[i]-lv[i-1]>=12 & lv[i]>=med+12 then ed+=1
    if lv[i-1]-lv[i]>=12 & lv[i-1]>=med+12 then ed+=1
    if lv[i]>=med+8 then do; act+=1; run+=1; end
    else do; if run>=3 then bursts+=1; run=0; end
  end
  actS=act*0.01; if actS>0 then eps=format(ed/actS,,2); else eps='0'
  return 'edges' ed 'active_s' format(actS,,2) 'edges_per_active_s' eps 'bursts' bursts
::requires 'AudioV9SpatialNativeProvider.cls'
::requires 'rxmath' LIBRARY
