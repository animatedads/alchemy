/* blocks.rex -- steps 1-4 of the pattern plan on one stretch: blocks (continuous pitch lines), harmonic folding,
 * then pattern collections at widening bucket levels.
 * Architecture: Tom Dyer (6 Nov 2026: aggressive pattern similarity on sub-spectrum blocks; start with simple
 *   patterns, gross up the buckets level by level; a pattern is pitch and pulse).  Coding: Claude (Opus 5.5).
 * 1 Lines: native harmonic-contrast pitch tracked separately in each window (so overlapping voices each get one);
 *   a block = consecutive 10 ms frames moving < 3 % per frame, >= 60 ms.
 * 2 Folding: blocks overlapping in time (>= 50 % of the shorter) at pitch ratio 2 or 3 (+-4 %) are one voice; the
 *   block with the higher mean contrast (its comb fits more harmonics) is kept as the voice, the other dropped.
 * 3 Levels: pitch bucket width 1/24, 1/12, 1/6, 1/3 octave; a collection = the blocks sharing a bucket (a Bag of
 *   bucket keys); pulse = median gap between consecutive blocks of a collection.
 * usage: blocks.rex cleanedF32 cleanStartClock fileStartClock windows */
numeric digits 16
parse arg cln c0 fs wins
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
a=hms2sec(c0); tf=hms2sec(fs); w=filespec('location',cln)
blocks=.array~new
loop wv over wins~makeArray(',')
  parse var wv lo '-' hi
  x=prov~harmonicF0(cln,w'bk_h.tsv',8000,512,80,lo,hi,20,2000,0.3)
  s=.stream~new(w'bk_h.tsv'); s~open('READ'); h=s~linein; run=.array~new; lt=-1; lf=0
  do while s~lines>0
    parse value s~linein with t '09'x f0 '09'x con
    if f0>0 & lf>0 then if abs(f0/lf-1)<0.03 & t-lt<0.015 then do; run~append(t f0 con); lt=t; lf=f0; iterate; end
    call closeRun
    if f0>0 then do; run~append(t f0 con); lt=t; lf=f0; end; else do; lt=-1; lf=0; end
  end
  s~close; call closeRun
end
/* 2 harmonic folding */
dropped=.set~new
loop i=1 to blocks~items
  parse value blocks[i] with ai bi fi ci .
  loop j=1 to blocks~items
    if i=j then iterate
    parse value blocks[j] with aj bj fj cj .
    ov=min(bi,bj)-max(ai,aj); if ov<=0 then iterate
    if ov<0.5*min(bi-ai,bj-aj) then iterate
    r=max(fi,fj)/min(fi,fj); h=0
    loop m=2 to 3; if abs(r/m-1)<0.04 then h=m; end
    if h=0 then iterate
    if ci<cj then dropped~put(i)                       /* the weaker comb is the other one's harmonic */
  end
end
kept=.array~new; loop i=1 to blocks~items; if \dropped~hasIndex(i) then kept~append(blocks[i]); end
kept=kept~sort
say blocks~items 'blocks;' dropped~items 'folded as harmonics;' kept~items 'voice blocks'
say 'pos     clip_s  len   F0     slope_st/s  contrast'
loop b over kept
  parse var b ba bb bf bc bs
  p=a+ba-tf; m=trunc(p/60)
  say (m':'right(format(p-m*60,,2),5,'0'))~left(8)||format(a+ba-hms2sec('00:31:42.25'),,2)~left(8)||format(bb-ba,,2)~left(6)||format(bf,,0)~left(7)||format(bs,,1)~left(12)||format(bc,,2)
end
/* 3 levels */
loop lv over .array~of(24,12,6,3)
  bag=.bag~new; members=.directory~new
  loop b over kept
    parse var b ba bb bf .
    k=trunc(lv*RxCalcLog(bf/60,16)/RxCalcLog(2,16)); bag~put(k)
    if \members~hasIndex(k) then members[k]=.array~new; members[k]~append(ba bf)
  end
  multi=0; line=''
  loop k over bag~uniqueIndexes~sortWith(.NumericComparator~new)
    n=bag~items(k); if n>=2 then multi+=1
    lo=format(60*RxCalcPower(2,k/lv,16),,0); hi=format(60*RxCalcPower(2,(k+1)/lv,16),,0)   /* Rexx ** takes whole exponents only */
    gaps=.array~new; prev=''
    loop mv over members[k]~sort; parse var mv ta .; if prev<>'' then gaps~append(ta-prev); prev=ta; end
    pulse='-'; if gaps~items>0 then do; gaps=gaps~sortWith(.NumericComparator~new); pulse=format(gaps[(gaps~items+1)%2],,2)'s'; end
    line=line lo'-'hi'Hz:'n'('pulse')'
  end
  say ''; say 'level 1/'lv 'octave:' bag~uniqueIndexes~items 'collections,' multi 'with >= 2 blocks'; say ' ' line
end
exit 0
closeRun:
  if run~items>=6 then do
    fz=.array~new; cs=0; loop rv over run; parse var rv . rf rc; fz~append(rf); cs+=rc; end
    parse value run[1] with ra rf1 .; parse value run[run~items] with rb rfn .
    fs2=fz~sortWith(.NumericComparator~new)
    slope=12*RxCalcLog(rfn/rf1,16)/RxCalcLog(2,16)/max(rb-ra,0.01)
    blocks~append(right(format(ra,,3),9,'0') rb fs2[(fs2~items+1)%2] cs/run~items slope)
  end
  run=.array~new
  return
::requires 'FeedChain.cls'
::requires 'AudioV9SpatialNativeProvider.cls'
::requires 'rxmath' LIBRARY
