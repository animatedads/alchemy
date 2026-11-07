/* pitch_hist.rex -- harmonic-contrast pitch histogram of one stretch of a clip (who is speaking, at what pitch).
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 5 Nov 2026.
 * usage: pitch_hist.rex pcm.f32 fromS toS loHz hiHz minContrast workDir */
numeric digits 16
parse arg pcm a b lo hi mc w
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
x=prov~harmonicF0(pcm,w'/ph.tsv',8000,512,80,lo,hi,20,2000,mc)
hb=.bag~new; n=0; s=.stream~new(w'/ph.tsv'); s~open('READ'); h=s~linein
do while s~lines>0
  parse value s~linein with t '09'x f0 '09'x con
  if t<a | t>b | f0<=0 then iterate
  hb~put(trunc(f0/10)*10); n+=1
end
s~close
say n 'voiced frames in' a||'-'||b 's,' lo'-'hi 'Hz, contrast >=' mc
loop k over hb~uniqueIndexes~sortWith(.NumericComparator~new)
  say right(k,4)'-'right(k+9,3) 'Hz' right(hb~items(k),4) copies('#',hb~items(k))
end
::requires 'AudioV9SpatialNativeProvider.cls'
