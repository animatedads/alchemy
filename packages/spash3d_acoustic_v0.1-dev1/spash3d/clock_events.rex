/* clock_events.rex -- FD/FC clock offset from independently detected loud onsets.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).
 * Onsets: Audio V9 native loud-event scan run on each feed on its own (A=B=same file).
 * Then every FD/FC onset pair within +-maxSec is histogrammed; a true shared clock offset
 * shows as one dominant bin, physical TDOA (<= 27.5 ms for the 9.43 m baseline) sits inside it.
 * usage: clock_events.rex pcmDir outDir [minPeak] [minRatio] [maxSec] [binMs]
 */
numeric digits 20
parse arg pcmDir outDir minPeak minRatio maxSec binMs .
if minPeak='' then minPeak=0.01; if minRatio='' then minRatio=12; if maxSec='' then maxSec=120; if binMs='' then binMs=50
ch=fcfdChains(pcmDir)
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
ev=.directory~new
do feed over .array~of('FD','FC')
  list=.array~new
  do f over ch[feed]~files
    out=outDir'/onsets_'filespec('name',f['PATH'])'.tsv'
    prov~scanLoudEchoEvents(f['PATH'],f['PATH'],out,8000,minPeak,minRatio,500,6,2,0)
    s=.stream~new(out); s~open('READ'); hdr=s~linein
    do while s~lines>0
      l=s~linein; if l='' then iterate
      parse var l . '09'x . '09'x ms '09'x . '09'x . '09'x . '09'x pk '09'x . '09'x . '09'x . '09'x ratio '09'x .
      d=.directory~new; d['T']=f['START']+ms/1000; d['PEAK']=pk; d['RATIO']=ratio; list~append(d)
    end
    s~close
  end
  ev[feed]=list
  say feed 'onsets' list~items
end
/* histogram of FC - FD differences */
hist=.directory~new; fdl=ev['FD']; fcl=ev['FC']
j0=1
do i=1 to fdl~items
  t=fdl[i]['T']
  do while j0<=fcl~items; if fcl[j0]['T']>=t-maxSec then leave; j0+=1; end
  do j=j0 to fcl~items
    d=fcl[j]['T']-t; if d>maxSec then leave
    b=trunc(d*1000/binMs + 1e6 + 0.5) - 1e6
    if hist~hasIndex(b) then hist[b]=hist[b]+1; else hist[b]=1
  end
end
/* rank bins */
bins=hist~allIndexes; best=.array~new
do b over bins; best~append(right(hist[b],8,'0') b); end
best=best~sort
o=.stream~new(outDir'/clock_event_histogram.tsv'); o~open('WRITE REPLACE')
o~lineout('fc_minus_fd_ms'||'09'x||'pairs')
do k=best~items to max(1,best~items-19) by -1
  parse value best[k] with c b
  o~lineout(b*binMs||'09'x||c+0); say 'offset' b*binMs 'ms pairs' c+0
end
o~close
tot=0; do b over bins; tot+=hist[b]; end
say 'total pairs' tot 'bins' bins~items 'mean per bin' format(tot/bins~items,,2)
exit 0
::requires 'FeedChain.cls'
::requires 'AudioV9SpatialNativeProvider.cls'
