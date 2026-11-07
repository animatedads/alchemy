/* v7_reel.rex -- one listening reel per voice profile from the per-clip profile renders.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 5 Nov 2026.
 * For profile `label`: from each clip's frames file, lifted frames are joined into pieces (gaps < 0.3 s bridged),
 * pieces shorter than minS dropped, each piece padded 0.2 s either side and cut from that clip's render;
 * pieces are ranked by mean harmonic contrast (how strongly this voice's harmonics stand out) and the best are
 * kept up to maxMin minutes, then played in time order with 0.4 s silence between.  Index TSV: reel_start_s, reel_end_s, clip, clip_start_s,
 * fc_time (V7 start + 8 h, from index.csv), piece_s.  Output f32 is then given the speech AGC (-16 dBFS target).
 * usage: v7_reel.rex label workDir clipStartTsv outPrefix minS maxMin */
numeric digits 16
parse arg lab w cst outP minS maxMin .
if minS='' then minS=0.25; if maxMin='' then maxMin=10
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
starts=.directory~new; s=.stream~new(cst); s~open('READ')
do while s~lines>0; parse value s~linein with nm '09'x st; starts[nm~changestr('.ogg','')]=st; end
s~close
/* pass 1: candidate pieces from every clip, each with its mean contrast */
cand=.array~new
ids=.array~new; loop k over starts~allIndexes; ids~append(k); end; ids=ids~sort
loop id over ids
  ft=w'/'id'_'lab'.frames.tsv'; if .stream~new(ft)~query('exists')='' then iterate
  cur=''; last=-9; csum=0; cn=0
  fs=.stream~new(ft); fs~open('READ')
  do while fs~lines>0
    parse value fs~linein with t '09'x wt '09'x . '09'x con
    if wt<>1 then iterate
    if cur<>'' & t-last<=0.3 then do; parse var cur a .; cur=a t; csum+=con; cn+=1; end
    else do
      if cur<>'' then call addPiece
      cur=t t; csum=con; cn=1
    end
    last=t
  end
  fs~close; if cur<>'' then call addPiece
end
/* pass 2: best pieces up to maxMin, then time order */
cand=cand~sortWith(.DescendingComparator~new)
keep=.array~new; tot=0
loop c over cand; parse var c sc '|' id '|' a '|' b; if tot+(b-a+0.4)>maxMin*60 then iterate; keep~append(id||'|'||right(format(a,,2),9,'0')||'|'||b); tot+=b-a+0.8; end
keep=keep~sort
reel=outP'_'lab'.raw.f32'; r=.stream~new(reel); r~open('WRITE REPLACE')
ix=.stream~new(outP'_'lab'_index.tsv'); ix~open('WRITE REPLACE')
ix~lineout('reel_start_s'||'09'x||'reel_end_s'||'09'x||'clip'||'09'x||'clip_start_s'||'09'x||'fc_time'||'09'x||'piece_s')
gap=copies('00000000'x,trunc(0.4*8000)); pos=0; pieces=0
loop k over keep
  parse var k id '|' a '|' b; a=a+0
  trk=w'/'id'_'lab'.f32'; nTrk=.stream~new(trk)~query('size')/4
  a0=max(0,a-0.2); b0=min(nTrk/8000,b+0.2); n=trunc((b0-a0)*8000)
  tf=.stream~new(trk); tf~open('READ'); d=tf~charin(trunc(a0*8000)*4+1,n*4); tf~close
  r~charout(d); t1=starts[id]+a0+28800
  hh=t1%3600; mm=(t1-hh*3600)%60; ss=t1-hh*3600-mm*60
  ix~lineout(format(pos,,2)'09'x||format(pos+n/8000,,2)'09'x||id'09'x||format(a0,,2)'09'x||right(hh,2,'0')':'right(mm,2,'0')':'right(format(ss,,2),5,'0')'09'x||format(b-a,,2))
  pos+=n/8000; r~charout(gap); pos+=0.4; pieces+=1
end
r~close; ix~close
if pieces>0 then x=prov~speechAgc(reel,outP'_'lab'.f32',8000,-16,36,10,400,6,-1)
say lab 'reel:' pieces 'of' cand~items 'candidate pieces,' format(pos/60,,1) 'min'
exit 0
addPiece:
  parse var cur a b
  if b-a>=minS then cand~append(format(csum/cn,,4)||'|'||id||'|'||a||'|'||b)
  return
::requires 'AudioV9SpatialNativeProvider.cls'
