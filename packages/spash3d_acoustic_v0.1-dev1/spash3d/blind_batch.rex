/* blind_batch.rex -- blind listening batch: top SPASH call matches mixed with random FD controls, shuffled.
 * Architecture: Tom Dyer (blind-control protocol agreed 31 Oct 2026).  Coding: Claude (Opus 5.5).
 * Top: highest likeness across the result TSVs (rank, fd_time, likeness), >= 30 s from each other and from
 *      already-labelled clips.  Random: uniform over the FD chain, same 30 s exclusion.  Seeded, reproducible.
 * Clips: FD, 6 s starting 1 s before the time, +22 dB with -1 dBFS limiter (as cut_events.rex).
 * The key (which clip is which) goes to keyTsv and is NOT put in the clip folder.
 * usage: blind_batch.rex outDir keyTsv nTop nRand seed labelsTsv resultTsv [resultTsv ...]
 */
numeric digits 16
parse arg outDir keyTsv nTop nRand seed labF rest
ch=fcfdChains(value('SPASH_PCM',,'ENVIRONMENT'),'CONTINUOUS')
used=.array~new; used~append(hms2sec('122142')+0.218)
s=.stream~new(labF); s~open('READ'); h=s~linein
do while s~lines>0; c=s~linein~makeArray('09'x); if c~items>=2 then used~append(toSec(c[2])); end
s~close
/* candidates from all result files */
/* nTop = N (global top N) or PN (top N from EACH result file, for coverage across the timeline) */
perFile=(nTop~left(1)='P'); if perFile then nTop=nTop~substr(2)
pick=.array~new; cand=.array~new
do f over rest~space~makeArray(' ')
  s=.stream~new(f); s~open('READ'); h=s~linein; fc=.array~new
  do while s~lines>0; c=s~linein~makeArray('09'x); if c~items>=3 then fc~append(c[3]'|'toSec(c[2])); end
  s~close
  if perFile then call takeTop fc~sortWith(.DescendingComparator~new), nTop
  else do x over fc; cand~append(x); end
end
if \perFile then call takeTop cand~sortWith(.DescendingComparator~new), nTop
/* random controls */
call random ,,seed
t0=ch['FD']~startSec+30; t1=ch['FD']~endSec-30; got=0; tries=0
do while got<nRand & tries<10000
  tries+=1; r=(random(0,99999)*100000+random(0,99999))/1e10
  t=t0+r*(t1-t0); t=trunc(t*1000)/1000
  if \far(t,used,30) then iterate
  pick~append('RANDOM|'t'|NA'); used~append(t); got+=1
end
/* shuffle (Fisher-Yates, same seeded stream) */
do i=pick~items to 2 by -1
  j=random(1,i); tmp=pick[i]; pick[i]=pick[j]; pick[j]=tmp
end
k=.stream~new(keyTsv); k~open('WRITE REPLACE'); k~lineout('clip'||'09'x||'fd_time'||'09'x||'source'||'09'x||'likeness'||'09'x||'seed='seed)
do i=1 to pick~items
  parse value pick[i] with src '|' t '|' lk
  nm=right(i,2,'0'); f=outDir'/'nm'_FD'
  ch['FD']~writeWindow(t-1,48000,f'.f32')
  address system 'ffmpeg -v error -nostdin -y -f f32le -ar 8000 -ac 1 -i "'f'.f32" -af "volume=22dB,alimiter=limit=0.89:level=disabled" -c:a pcm_s16le "'f'.wav"'
  call sysFileDelete f'.f32'
  k~lineout(nm'09'x||sec2hms(t)'09'x||src'09'x||lk)
end
k~close
say pick~items 'clips written to' outDir '; key in' keyTsv
exit 0
takeTop: procedure expose pick used
  use arg list, n
  got=0
  do x over list
    parse var x lk '|' t
    if \far(t,used,30) then iterate
    pick~append('TOP|'t'|'lk); used~append(t); got+=1
    if got>=n then leave
  end
  return
toSec: procedure
  use arg v; parse var v hh ':' mm ':' ss; return hh*3600+mm*60+ss
far: procedure
  use arg t, used, gap
  do u over used; if abs(t-u)<gap then return 0; end
  return 1
::requires 'FeedChain.cls'
