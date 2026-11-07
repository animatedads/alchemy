/* v7_reel_windows.rex -- listening reel of 6-10 s windows (enough to "get the ear in").
 * Architecture: Tom Dyer (5 Nov 2026: clips need at least 6-10 s each).  Coding: Claude (Opus 5.5).
 * Pieces where the profile(s) locked on are found in each clip's frames file(s) exactly as before; each piece
 * opens a window of winS seconds centred on it (clamped to the clip); overlapping windows in a clip merge (a
 * merged window may grow up to maxWinS).  Window score = sum over its pieces of mean contrast x piece length.
 * Best windows up to maxMin minutes, played in time order with 0.8 s gaps, from the render `trackSuffix`.
 * Index TSV: reel_start_s reel_end_s clip clip_start_s fc_time window_s score.
 * usage: v7_reel_windows.rex name workDir clipStartTsv outPrefix trackSuffix winS maxWinS maxMin label [label ...]
 *   trackSuffix: the per-clip render file suffix, e.g. VOICE_SM or UNION_A; labels: frames files to read. */
numeric digits 16
parse arg name w cst outP trackSfx winS maxWinS maxMin labs
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
starts=.directory~new; s=.stream~new(cst); s~open('READ')
do while s~lines>0; parse value s~linein with nm '09'x st; starts[nm~changestr('.ogg','')]=st; end
s~close
cand=.array~new
ids=.array~new; loop k over starts~allIndexes; ids~append(k); end; ids=ids~sort
loop id over ids
  trk=w'/'id'_'trackSfx'.f32'; if .stream~new(trk)~query('exists')='' then iterate
  clipS=.stream~new(trk)~query('size')/4/8000
  wins=.array~new
  loop lab over labs~space~makeArray(' ')
    ft=w'/'id'_'lab'.frames.tsv'; if .stream~new(ft)~query('exists')='' then iterate
    fs=.stream~new(ft); fs~open('READ'); cur=''; last=-9; csum=0; cn=0
    do while fs~lines>0
      parse value fs~linein with t '09'x wt '09'x . '09'x con
      if wt<>1 then iterate
      if cur<>'' & t-last<=0.3 then do; parse var cur a .; cur=a t; csum+=con; cn+=1; end
      else do; if cur<>'' then call addWin; cur=t t; csum=con; cn=1; end
      last=t
    end
    fs~close; if cur<>'' then call addWin
  end
  /* merge overlapping windows in this clip */
  wins=wins~sortWith(.NumericComparator~new)
  merged=.array~new
  loop wv over wins
    parse var wv a b sc
    if merged~items>0 then do
      parse value merged[merged~items] with ma mb msc
      if a<=mb & b-ma<=maxWinS then do; merged[merged~items]=ma max(mb,b) (msc+sc); iterate; end
    end
    merged~append(a b sc)
  end
  loop mv over merged; parse var mv a b sc; cand~append(right(format(sc,,4),14,'0')||'|'||id||'|'||a||'|'||b); end
end
cand=cand~sortWith(.DescendingComparator~new)
keep=.array~new; tot=0
loop c over cand; parse var c sc '|' id '|' a '|' b; if tot+(b-a+0.8)>maxMin*60 then iterate; keep~append(id||'|'||right(format(a,,2),9,'0')||'|'||b||'|'||sc); tot+=b-a+0.8; end
keep=keep~sort
reel=outP'_'name'.raw.f32'; r=.stream~new(reel); r~open('WRITE REPLACE')
ix=.stream~new(outP'_'name'_index.tsv'); ix~open('WRITE REPLACE')
ix~lineout('reel_start_s'||'09'x||'reel_end_s'||'09'x||'clip'||'09'x||'clip_start_s'||'09'x||'fc_time'||'09'x||'window_s'||'09'x||'score')
gap=copies('00000000'x,trunc(0.8*8000)); pos=0; n0=0
loop k over keep
  parse var k id '|' a '|' b '|' sc; a=a+0
  trk=w'/'id'_'trackSfx'.f32'; n=trunc((b-a)*8000)
  tf=.stream~new(trk); tf~open('READ'); d=tf~charin(trunc(a*8000)*4+1,n*4); tf~close
  r~charout(d); t1=starts[id]+a+28800; hh=t1%3600; mm=(t1-hh*3600)%60; ss=t1-hh*3600-mm*60
  ix~lineout(format(pos,,1)'09'x||format(pos+n/8000,,1)'09'x||id'09'x||format(a,,2)'09'x||right(hh,2,'0')':'right(mm,2,'0')':'right(format(ss,,2),5,'0')'09'x||format(b-a,,1)'09'x||format(sc,,2))
  pos+=n/8000; r~charout(gap); pos+=0.8; n0+=1
end
r~close; ix~close
if n0>0 then x=prov~speechAgc(reel,outP'_'name'.f32',8000,-16,36,10,400,6,-1)
say name 'reel:' n0 'windows of' cand~items 'candidates,' format(pos/60,,1) 'min'
exit 0
addWin:
  parse var cur pa pb
  if pb-pa<0.15 then return
  c=(pa+pb)/2; a=max(0,c-winS/2); b=min(clipS,a+winS); a=max(0,b-winS)
  wins~append(format(a,,2) format(b,,2) (csum/cn)*(pb-pa))
  return
::requires 'AudioV9SpatialNativeProvider.cls'
