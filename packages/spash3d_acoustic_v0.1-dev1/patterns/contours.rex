/* contours.rex -- continuous pitch contours (the "lines") in one FD stretch, per pitch window, 10 ms frames.
 * A contour: consecutive frames whose pitch moves < 3 % per 10 ms, lasting >= 80 ms.  Contours in different
 * windows at the same time with pitch ratio 2 or 3 (+-4 %) are one voice's harmonics: folded onto the lowest.
 * Reconnaissance for the pattern work (Tom Dyer's 7-step plan, 6 Nov 2026).  Coding: Claude (Opus 5.5).
 * usage: contours.rex workDir cleanedF32 clipStartClock fileStartClock windows */
numeric digits 16
parse arg w cln a0 f0c wins
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
a=hms2sec(a0); tf=hms2sec(f0c)
segs=.array~new
loop wv over wins~makeArray(',')
  parse var wv lo '-' hi
  x=prov~harmonicF0(cln,w'/ct_h.tsv',8000,512,80,lo,hi,20,2000,0.3)
  s=.stream~new(w'/ct_h.tsv'); s~open('READ'); h=s~linein; run=.array~new; lt=-1; lf=0
  do while s~lines>0
    parse value s~linein with t '09'x f0 '09'x con
    if f0>0 & lf>0 then if abs(f0/lf-1)<0.03 & t-lt<0.015 then do; run~append(t f0); lt=t; lf=f0; iterate; end
    call closeRun
    if f0>0 then do; run~append(t f0); lt=t; lf=f0; end; else do; lt=-1; lf=0; end
  end
  s~close; call closeRun
end
segs=segs~sort
say segs~items 'contours >= 80 ms'
say 'pos        clock         len_s  median_Hz  window'
loop sg over segs
  parse var sg ta tb fm wl
  p=a+ta-tf; m=trunc(p/60)
  say (m':'right(format(p-m*60,,2),5,'0'))~left(11)||sec2hms(a+ta)~left(14)||format(tb-ta,,2)~left(7)||format(fm,,0)~left(11)||wl
end
exit 0
closeRun:
  if run~items>=8 then do
    fz=.array~new; loop rv over run; parse var rv . rf; fz~append(rf); end; fz=fz~sortWith(.NumericComparator~new)
    parse value run[1] with ra .; parse value run[run~items] with rb .
    segs~append(right(format(ra,,2),8,'0') rb fz[(fz~items+1)%2] wv)
  end
  run=.array~new
  return
::requires 'FeedChain.cls'
::requires 'AudioV9SpatialNativeProvider.cls'
