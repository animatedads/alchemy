/* tone_lines.rex -- strongest persistent spectral lines (native band blocks, 240 log bands 100-3800 Hz, 2048 FFT).
 * Coding: Claude (Opus 5.5). */
numeric digits 16
parse arg rest
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
nb=64
do f over rest~space~makeArray(' ')
  bl=prov~bandBlocks(f,8000,2048,512,4,nb,100,3800)
  acc=.array~new; do k=1 to nb; acc[k]=0; end
  do d over bl; do k=1 to nb; acc[k]=acc[k]+d['BANDS'][k]; end; end
  med=sortv(acc)[nb%2]
  line=''
  do 6
    bi=1; do k=1 to nb; if acc[k]>acc[bi] then bi=k; end
    hz=100*RxCalcPower(38,(bi-0.5)/nb,16)
    line=line format(hz,,0)'Hz('format(10*RxCalcLog10(acc[bi]/med,16),,0)'dB)'
    acc[bi]=0
  end
  say left(f,32) line
end
exit
sortv: procedure
  use arg a; b=a~copy; return b~sortWith(.NumericComparator~new)
::requires 'AudioV9SpatialNativeProvider.cls'
::requires 'rxmath' LIBRARY
