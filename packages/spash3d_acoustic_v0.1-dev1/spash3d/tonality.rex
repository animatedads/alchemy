/* tonality.rex -- spectral flatness per 160 ms block (native band blocks, 64 log bands 100-3800 Hz).
 * Low flatness = tonal (horn/klaxon/siren); speech and noise are flatter. Coding: Claude (Opus 5.5). */
numeric digits 16
parse arg rest
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
do f over rest~space~makeArray(' ')
  bl=prov~bandBlocks(f,8000,512,128,10,64,100,3800)
  minF=9; sumF=0; loud=0; tonal=0; mx=0
  do d over bl; if d['RMS']>mx then mx=d['RMS']; end
  do d over bl
    lg=0; ar=0; n=0
    do v over d['BANDS']; v=max(v,1e-20); lg+=RxCalcLog(v,16); ar+=v; n+=1; end
    flat=RxCalcExp(lg/n,16)/(ar/n)
    if d['RMS']>=mx*0.3 then do; loud+=1; sumF+=flat; if flat<minF then minF=flat; if flat<0.05 then tonal+=1; end
  end
  say left(f,48) 'loud_blocks' right(loud,4) 'mean_flatness' format(sumF/max(1,loud),,3) 'min' format(minF,,4) 'tonal_blocks(<0.05)' tonal
end
::requires 'AudioV9SpatialNativeProvider.cls'
::requires 'rxmath' LIBRARY
