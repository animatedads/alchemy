/* door_bangs.rex -- candidate door thumps: sharp FD onsets also heard coherently on FC; lag vs door-source prediction.
 * Architecture: Tom Dyer (door thumps as anchors, cross-checked with FD micro-movement records).
 * Coding: Claude (Opus 5.5), 31 Oct 2026.
 * Onsets: Audio V9 native loud-event scan per FD file (out/clock/onsets_*.tsv). For each onset with peak/baseline >= minRatio:
 *   250 ms of broadband FD and FC around it (FC via clock model) -> native xcorr +-80 ms -> lag, score.
 * Door source (FD_to_stairwell door centre, plan px 430,350, z 4.0) -> Physics World direct-path prediction +26 ms;
 *   residual = measured lag - prediction = clock residual for that file if the event is the door.
 * usage: door_bangs.rex pcmDir onsetDir outTsv [minRatio]
 */
numeric digits 20
parse arg pcmDir onsetDir outTsv minRatio .
if minRatio='' then minRatio=30
parse value value('SPASH_CLOCK',,'ENVIRONMENT') with cA cB
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
ch=fcfdChains(pcmDir,'CONTINUOUS')
/* Physics World prediction for the door source */
freq=.array~of(400,1000,2150); sc=.F11SceneV04~new(freq)
e=.AcousticEmissionSpectrum~new; do f over freq; e~addBand(.AcousticEmissionBand~new(f,0.001)); end
parse value .F11SceneV04~pxToM(430,350) with dx dy
r=sc~solver~solve(sc~point(dx,dy,4.0),e,sc~receivers,0.150)
pred=(r~receiver('FC')~firstArrival~delay-r~receiver('FD')~firstArrival~delay)*1000
say 'door source' format(dx,,2) format(dy,,2) '4.0  predicted FC-FD first-arrival lag' format(pred,,2) 'ms'
work=value('SPASH_WORK',,'ENVIRONMENT'); a=work'/db_fd.f32'; b=work'/db_fc.f32'
o=.stream~new(outTsv); o~open('WRITE REPLACE')
o~lineout('fd_time'||'09'x||'fc_time'||'09'x||'fd_file'||'09'x||'fd_peak'||'09'x||'fd_peak_to_baseline'||'09'x||'lag_ms'||'09'x||'score'||'09'x||'residual_vs_door_ms'||'09'x||'fc_over_fd_db')
lead=value('SPASH_LEAD_FEED',,'ENVIRONMENT'); if lead='' then lead='FD'
do f over ch[lead]~files
  nm=filespec('name',f['PATH'])
  s=.stream~new(onsetDir'/onsets_'nm'.tsv'); if s~query('exists')='' then iterate
  s~open('READ'); h=s~linein
  do while s~lines>0
    l=s~linein; if l='' then iterate
    parse var l . '09'x . '09'x ms '09'x . '09'x . '09'x . '09'x pk '09'x . '09'x . '09'x . '09'x ratio '09'x .
    if ratio<minRatio then iterate
    t=f['START']+ms/1000
    off=cA+cB*(t-hms2sec('120000'))/3600
    if lead='FC' then t=t-off      /* t is always the FD-clock time of the event */
    if t<ch['FC']~startSec+1 | t>ch['FC']~endSec-1 | t<ch['FD']~startSec+1 | t>ch['FD']~endSec-1 then iterate
    ch['FD']~writeWindow(t-0.05,2000,a); ch['FC']~writeWindow(t+off-0.05,2000,b)
    x=prov~xcorr(a,b,-640,640,1,1)
    best=-9; bi=1; do i=1 to x['SCORES']~items; if x['SCORES'][i]>best then do; best=x['SCORES'][i]; bi=i; end; end
    lag=x['LAGS'][bi]/8
    m=prov~measure(a,b,8000,10,1)
    if m~rmsA>0 & m~rmsB>0 then lv=format(20*RxCalcLog10(m~rmsB/m~rmsA,16),,1); else lv='NA'
    o~lineout(sec2hms(t)'09'x||sec2hms(t+off)'09'x||nm'09'x||format(pk,,4)'09'x||format(ratio,,1)'09'x||format(lag,,2)'09'x||format(best,,3)'09'x||format(lag-pred,,2)'09'x||lv)
  end
  s~close
end
o~close
exit 0
::requires 'FeedChain.cls'
::requires 'AudioV9SpatialNativeProvider.cls'
::requires 'F11SceneV04.cls'
::requires 'rxmath' LIBRARY
