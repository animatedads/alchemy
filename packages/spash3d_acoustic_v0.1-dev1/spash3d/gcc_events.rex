/* gcc_events.rex -- GCC-PHAT FC-FD delay for propagating events (wind excluded), 160 ms at the onset, 300-3400 Hz.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 31 Oct 2026.
 * Input: one or more onset2_*.tsv files (onset_tdoa output with class column). FD clock times; FC via the clock model.
 * Output columns: fd_time fc_file lag_ms sharp second_lag_ms second_sharp fc_over_fd_db class
 * usage: gcc_events.rex outTsv in1.tsv [in2.tsv ...]
 */
numeric digits 16
parse arg outF rest
parse value value('SPASH_CLOCK',,'ENVIRONMENT') with cA cB
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
ch=fcfdChains(value('SPASH_PCM',,'ENVIRONMENT'),'CONTINUOUS')
work=value('SPASH_WORK',,'ENVIRONMENT'); a=work'/g_fd.f32'; b=work'/g_fc.f32'
o=.stream~new(outF); o~open('WRITE REPLACE')
o~lineout('fd_time'||'09'x||'fc_file'||'09'x||'lag_ms'||'09'x||'sharp'||'09'x||'second_lag_ms'||'09'x||'second_sharp'||'09'x||'fc_over_fd_db'||'09'x||'class')
seen=.set~new
do inF over rest~space~makeArray(' ')
  s=.stream~new(inF); s~open('READ'); h=s~linein
  do while s~lines>0
    c=s~linein~makeArray('09'x); if c~items<11 then iterate
    if c[11]='WIND_FC' | seen~hasIndex(c[1]) then iterate
    seen~put(c[1])
    parse value c[1] with hh ':' mm ':' ss
    t=hh*3600+mm*60+ss; off=cA+cB*(t-hms2sec('120000'))/3600
    ch['FD']~writeWindow(t-0.03,1280,a); ch['FC']~writeWindow(t+off-0.03,1280,b)
    r=prov~gccPhat(a,b,8000,720,300,3400)
    m=prov~measure(a,b,8000,10,1)
    if m~rmsA>0 & m~rmsB>0 then lv=format(20*RxCalcLog10(m~rmsB/m~rmsA,16),,1); else lv='NA'
    o~lineout(c[1]'09'x||c[2]'09'x||format(r[1]['LAG']/8,,2)'09'x||format(r[1]['SHARP'],,1)'09'x||format(r[2]['LAG']/8,,2)'09'x||format(r[2]['SHARP'],,1)'09'x||lv'09'x||c[11])
  end
  s~close
end
o~close
exit 0
::requires 'FeedChain.cls'
::requires 'AudioV9SpatialNativeProvider.cls'
::requires 'rxmath' LIBRARY
