/* clip_profile.rex -- 0.5 s FD / FC speech-band level profile (dB over 60 s median) for a sent clip window.
 * Coding: Claude (Opus 5.5). usage: clip_profile.rex HH:MM:SS.sss startOffsetS durS */
numeric digits 16
parse arg tc pre dur .
parse value value('SPASH_CLOCK',,'ENVIRONMENT') with cA cB
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
ch=fcfdChains(value('SPASH_PCM',,'ENVIRONMENT'),'CONTINUOUS'); work=value('SPASH_WORK',,'ENVIRONMENT')
parse var tc hh ':' mm ':' ss; t=hh*3600+mm*60+ss+pre; off=cA+cB*(t-hms2sec('120000'))/3600
prof=.directory~new
do feed over .array~of('FD','FC')
  tt=t; if feed='FC' then tt=t+off
  w=work'/cp_'feed'.f32'; ch[feed]~writeWindow(tt-30,60*8000,w)
  n=60*8000; m=.stream~new(w'.mask.tsv'); m~open('WRITE REPLACE'); m~lineout('s'||'09'x||'e'||'09'x||'lo'||'09'x||'hi'||'09'x||'w'); m~lineout(0'09'x||n'09'x||300'09'x||3400'09'x||1); m~close
  x=prov~renderSelection(w,w'.mask.tsv',w'.sp.f32',8000,256,64)
  bl=prov~bandBlocks(w'.sp.f32',8000,256,200,20,1,300,3400)   /* 0.5 s blocks */
  lv=.array~new; do d over bl; lv~append(10*RxCalcLog10(max(d['BANDS'][1],1e-20),16)); end
  s=lv~copy~sortWith(.NumericComparator~new); med=s[(s~items+1)%2]
  a=.array~new; do k=61 to 60+dur*2; a~append(lv[k]-med); end
  prof[feed]=a
end
say 'clip_s  FD_dB   FC_dB'
do k=1 to dur*2; say format((k-1)/2,,1)~right(6) format(prof['FD'][k],,1)~right(6) format(prof['FC'][k],,1)~right(7); end
::requires 'FeedChain.cls'
::requires 'AudioV9SpatialNativeProvider.cls'
::requires 'rxmath' LIBRARY
