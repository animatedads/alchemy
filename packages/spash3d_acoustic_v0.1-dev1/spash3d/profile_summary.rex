/* profile_summary.rex -- per-profile summary of a gated V7 voice scan.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 5 Nov 2026.
 * Per profile with strict hits (TONE and NONE excluded): hits, channel split, distinct clips, voiced seconds,
 * median F0 spread, median margin of its own score over the best other profile, hits by FC hour, and its
 * five longest stretches.  usage: profile_summary.rex scan.tsv */
numeric digits 16
parse arg f
s=.stream~new(f); s~open('READ'); hdr=s~linein~makeArray('09'x)
labels=.array~new; do i=9 to 15; labels~append(hdr[i]); end
stats=.directory~new
do while s~lines>0
  c=s~linein~makeArray('09'x); p=c[16]
  if p='TONE' | p='NONE' then iterate
  if \stats~hasIndex(p) then do
    d=.directory~new; d['N']=0; d['CH1']=0; d['CH2']=0; d['CLIPS']=.set~new; d['DUR']=0
    d['F0']=.array~new; d['MARGIN']=.array~new; d['HOURS']=.bag~new; d['RUNS']=.array~new; stats[p]=d
  end
  d=stats[p]; d['N']+=1; d['CH'c[4]]+=1; d['CLIPS']~put(c[1]); dur=c[6]-c[5]; d['DUR']+=dur
  d['F0']~append(c[8]+0); d['HOURS']~put(substr(c[3],1,2))
  own=-9e9; other=-9e9
  do i=9 to 15; v=c[i]+0; if hdr[i]=p then own=v; else other=max(other,v); end
  d['MARGIN']~append(own-other)
  d['RUNS']~append(format(dur,,2)'|'c[3]'|'c[4]'|'c[8])
end
s~close
say 'profile'~left(9) 'hits'~right(5) 'ch1'~right(5) 'ch2'~right(5) 'clips'~right(6) 'voiced_s'~right(9) '  F0 p10/p50/p90 Hz'~left(22) 'margin'~right(7) '  by FC hour'
order=.array~new; do p over stats~allIndexes; order~append(right(stats[p]['N'],6,'0')'|'p); end
order=order~sortWith(.DescendingComparator~new)
loop o over order
  parse var o . '|' p; d=stats[p]
  fz=d['F0']~sortWith(.NumericComparator~new); mz=d['MARGIN']~sortWith(.NumericComparator~new)
  hrs=''; loop h over d['HOURS']~uniqueIndexes~sort; hrs=hrs h':'d['HOURS']~items(h); end
  say p~left(9) d['N']~right(5) d['CH1']~right(5) d['CH2']~right(5) d['CLIPS']~items~right(6) format(d['DUR'],,1)~right(9) ' ' (pct(fz,10)'/'pct(fz,50)'/'pct(fz,90))~left(22) format(pct(mz,50),,2)~right(7) ' 'hrs
end
say ''
loop o over order
  parse var o . '|' p
  rz=stats[p]['RUNS']~sortWith(.DescendingComparator~new)
  line=p~left(9) 'longest:'
  do k=1 to min(5,rz~items); parse value rz[k] with du '|' t '|' ch '|' f0; line=line t'(ch'ch','du's,'format(f0,,0)'Hz)'; end
  say line
end
exit 0
pct: procedure
  use arg a, q
  return format(a[max(1,trunc(a~items*q/100)+1)],,1)
