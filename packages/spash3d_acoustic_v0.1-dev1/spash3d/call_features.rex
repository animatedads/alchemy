/* call_features.rex -- broken video-call layer features (sound-only, no location).
 * Architecture: Tom Dyer (two-layer observation: phone video call + live voices).  Coding: Claude (Opus 5.5), 31 Oct 2026.
 * 10 ms frames (native band blocks 128/80, 16 log bands 300-3900 Hz).
 *  E(t)   speech-band level, dB (bands 300-3400 Hz)
 *  DROP   packet-loss dropout: E falls >= 20 dB in one frame, stays down 2-8 frames, recovers to within 6 dB
 *         of the pre-drop level, inside active speech (pre-drop level >= window median + 10 dB)
 *  EDGE   band-edge ratio, dB: power 3400-3900 Hz over 2000-3400 Hz on active frames (codec cut-off -> very negative)
 * usage: call_features.rex f32 [label]   -> prints one line
 *        (as a routine: call_features(prov, f32) returns 'drops_per_active_s edge_db active_s')
 */
numeric digits 16
parse arg f lab
if f<>'' then do
  prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
  r=callFeatures(prov,f)
  parse var r dps edge act nd
  say left(lab,40) 'dropouts' nd 'per_active_s' dps 'edge_dB' edge 'active_s' act
end
exit 0

::routine callFeatures public
  use arg prov, f
  bl=prov~bandBlocks(f,8000,128,80,1,16,300,3900)
  edges=.array~new; do k=0 to 16; edges~append(300*RxCalcPower(3900/300,k/16,16)); end
  lvA=.array~new; hiA=.array~new; midA=.array~new
  do d over bl
    sp=0; hi=0; mid=0
    do k=1 to 16
      c=RxCalcSqrt(edges[k]*edges[k+1],16); v=max(d['BANDS'][k],0)*(edges[k+1]-edges[k])
      if c<=3400 then sp+=v
      if c>3400 then hi+=v
      if c>=2000 & c<=3400 then mid+=v
    end
    lvA~append(10*RxCalcLog10(max(sp,1e-20),16)); hiA~append(hi); midA~append(mid)
  end
  n=lvA~items; if n<20 then return '0 NA 0 0'
  s=lvA~copy~sortWith(.NumericComparator~new); med=s[(n+1)%2]
  act=0; hs=0; ms=0
  do i=1 to n; if lvA[i]>=med+10 then do; act+=1; hs+=hiA[i]; ms+=midA[i]; end; end
  nd=0; i=2
  do while i<=n-9
    if lvA[i-1]>=med+10 & lvA[i]<=lvA[i-1]-20 then do
      pre=lvA[i-1]; j=i+1; found=0
      do while j<=i+8
        if lvA[j]>=pre-6 & lvA[j]>=lvA[j-1]+15 then do; found=1; leave; end
        j+=1
      end
      if found & j-i>=2 then do; nd+=1; i=j; iterate; end
    end
    i+=1
  end
  actS=act*0.01
  if hs>0 & ms>0 then edge=format(10*RxCalcLog10(hs/ms,16),,1); else edge='NA'
  if actS>0 then dps=format(nd/actS,,2); else dps='0'
  return dps edge format(actS,,2) nd

::requires 'AudioV9SpatialNativeProvider.cls'
::requires 'rxmath' LIBRARY
