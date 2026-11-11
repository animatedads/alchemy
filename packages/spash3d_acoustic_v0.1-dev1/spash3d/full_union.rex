/* full_union.rex -- one whole FD (or FC) original as a cleaned voice-union listening file for review.
 * Architecture: Tom Dyer (6 Nov 2026: full-file audio per TP, cleaned union, no squawks, no cat; ogg).
 * Coding: Claude (Opus 5.5).
 * Whole file, no chunks (no seams):
 *   amp     native speech AGC (-20 dBFS, up to +36 dB)
 *   filter  native tonal-burst (bird screech / squawk) suppression; native enhancer (90-3600 Hz);
 *           speech tilt (as moment_render.rex);
 *           cat calls / klaxon: native harmonic-contrast pitch in 450-990 Hz.  The detector reports a pitch in
 *             that band for ~90 % of FD frames (median contrast 0.55, p90 0.77, p99 1.45 on TP8), so a call is a
 *             frame far above that: contrast >= catCon (1.0); runs >= 0.25 s (gaps <= 0.05 s), padded 0.15 s.
 *             A run with >= 30 % of its strong frames at 2x/3x/4x (+-4 %) the pitch of a voice a profile hears at
 *             the same moment is that voice's harmonic and is kept (6 Nov: about half the first cuts were).
 *             For the rest no voice is lifted there and the union output is cut by catDb;
 *           voices: per profile (SM, SF, M4, M2) harmonic-contrast pitch in the profile's window (>= 0.3),
 *             bucket probability >= its p20, 386.8/193.4 Hz device excluded; a lifted run >= 0.4 s whose pitch
 *             barely moves (p90/p10 < 1.015) is a machine tone / klaxon, not lifted;
 *           native union mask, other tones at -14 dB (20 % of peak);
 *   amp     native speech AGC (-18 dBFS, up to +48 dB); Ogg Opus 16 kHz mono 32 kb/s (container encode only).
 * Log TSV: what was removed and where (file offset and wall-clock on the feed's chain).
 * usage: full_union.rex FD|FC tpName pcmDir workDir outOgg catCon catDb profile [profile ...] */
numeric digits 16
parse arg feed tpName pcm w outOgg catCon catDb profs
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
feed=feed~upper
if feed='FD' then ch=fdChainFull(pcm)   /* FdChain.cls: TP1-TP9, TP6-TP9 placed as before */
else ch=fcfdChains(pcm,'CONTINUOUS')['FC']
me=.nil; loop f over ch~files; if filespec('name',f['PATH'])=tpName'.f32' then me=f; end
if me=.nil then do; say 'no' tpName 'in the' feed 'chain'; exit 1; end
src=me['PATH']; n=me['SAMPLES']; t0=me['START']; base=w'/'tpName
log=.stream~new(outOgg'.removed.tsv'); log~open('WRITE REPLACE')
log~lineout('kind'||'09'x||'file_from'||'09'x||'file_to'||'09'x||'clock_from'||'09'x||'clock_to'||'09'x||'detail')
say tpName 'start' sec2hms(t0) 'length' sec2hms(n/8000)
/* amp, screech, enhancer, tilt */
x=prov~speechAgc(src,base'_amp.f32',8000,-20,36,10,400,6,-1)
nb=prov~suppressTonalBursts(base'_amp.f32',base'_scr.f32',base'_screech.tsv')
sc=.stream~new(base'_screech.tsv'); sc~open('READ'); h=sc~linein; nScr=0
do while sc~lines>0; parse value sc~linein with sa '09'x sb '09'x rest; if sa='' then iterate; nScr+=1; call logRow 'screech', sa, sb, rest~changestr('09'x,' '); end
sc~close
call sysFileDelete base'_amp.f32'
x=prov~enhance(base'_scr.f32',base'_enh.f32',8000,256,64,1.5,0.98,1.0,0.1,90,3600)
call sysFileDelete base'_scr.f32'
tm=.stream~new(base'_tilt.tsv'); tm~open('WRITE REPLACE'); tm~lineout('start'||'09'x||'end'||'09'x||'lo'||'09'x||'hi'||'09'x||'w')
loop row over .array~of('90 3600 0.15','250 3600 0.4','600 3600 0.8','1200 3600 1')
  parse var row tlo thi tw; tm~lineout('0'||'09'x||n||'09'x||tlo||'09'x||thi||'09'x||tw)
end
tm~close
cln=base'_cln.f32'; x=prov~renderSelection(base'_enh.f32',base'_tilt.tsv',cln,8000,256,64)
call sysFileDelete base'_enh.f32'   /* working copies go as soon as the next stage has them (disk allowance) */
/* cat calls */
x=prov~harmonicF0(cln,base'_cat.tsv',8000,512,80,450,990,20,3800,0.3)   /* native upper limit < 1000 Hz */
cats=.array~new; cs=.stream~new(base'_cat.tsv'); cs~open('READ'); h=cs~linein; ca=''; cb=''
do while cs~lines>0
  parse value cs~linein with t '09'x f0 '09'x con
  if f0<=0 | con<catCon then iterate
  if ca<>'' then if t-cb<=0.05 then do; cb=t; iterate; end   /* Rexx & does not short-circuit */
  if ca<>'' then call catRun
  ca=t; cb=t
end
cs~close; if ca<>'' then call catRun
/* the strong frames of each candidate call, keyed by 10 ms frame index (same grid as every pitch track below) */
catIdx=.directory~new; runN=.array~new; runHit=.array~new
loop ri=1 to cats~items; runN[ri]=0; runHit[ri]=0; end
cs=.stream~new(base'_cat.tsv'); cs~open('READ'); h=cs~linein; ri=1
do while cs~lines>0
  parse value cs~linein with t '09'x f0 '09'x con
  if f0<=0 | con<catCon then iterate
  do while ri<=cats~items; parse value cats[ri] with xa xb; if xb<t then ri+=1; else leave; end
  if ri>cats~items then leave
  parse value cats[ri] with xa xb; if t<xa then iterate
  catIdx[format(t*100,,0)]=ri f0; runN[ri]+=1
end
cs~close
/* voices, pass A: each profile's pitch track, kept for pass B.  A call frame whose pitch is 2x/3x/4x (+-4 %) the
   pitch of a voice heard at the same moment is that voice's harmonic, not a cat (night TP1-TP3: about half of the
   first detector's cuts were) */
profA=.array~new; loop pf over profs~space~makeArray(' '); profA~append(.VoiceProfile~load(pf)); end
hitIdx=.set~new
loop vp over profA
  hf=base'_h_'vp~label'.tsv'; x=prov~harmonicF0(cln,hf,8000,512,80,vp~winLo,vp~winHi,20,2000,0.3)
  hs=.stream~new(hf); hs~open('READ'); h=hs~linein
  do while hs~lines>0
    parse value hs~linein with t '09'x f0 '09'x con
    if f0<=0 then iterate
    idx=format(t*100,,0); if \catIdx~hasIndex(idx) then iterate
    parse value catIdx[idx] with . cf
    loop hk=2 to 4; if abs(cf/(f0*hk)-1)<0.04 then do; hitIdx~put(idx); leave; end; end
  end
  hs~close
end
loop idx over hitIdx; parse value catIdx[idx] with ri .; runHit[ri]+=1; end
kept=.array~new; nKept=0
loop ri=1 to cats~items
  parse value cats[ri] with xa xb
  if runN[ri]>0 then if runHit[ri]/runN[ri]>=0.3 then do
    nKept+=1; call logRow 'cat_kept_voice', xa, xb, runHit[ri]'/'runN[ri] 'frames on a voice harmonic'; iterate
  end
  kept~append(xa xb); call logRow 'cat', xa, xb, ''
end
cats=kept
say tpName 'cat calls cut' cats~items '(kept as voice harmonics' nKept') screech bursts' nScr
/* voices, pass B */
ul=.stream~new(base'_union.list'); ul~open('WRITE REPLACE'); nTone=0
loop vp over profA
  lab=vp~label; fl=vp~pitchFloor(20)
  tA=.array~new; fA=.array~new; cA=.array~new; wA=.array~new
  hs=.stream~new(base'_h_'lab'.tsv'); hs~open('READ'); h=hs~linein; ci=1
  do while hs~lines>0
    parse value hs~linein with t '09'x f0 '09'x con
    wt=0
    if f0>0 then do
      k=.VoiceProfile~bucket(f0)
      if k>0 then if vp~pitch[k]>=fl then wt=1
      if abs(f0/386.8-1)<0.01 | abs(f0/193.4-1)<0.01 then wt=0
      if wt=1 then do   /* inside a cat call? (cats in time order, frames in time order) */
        do while ci<=cats~items; parse value cats[ci] with xa xb; if xb<t then ci+=1; else leave; end
        if ci<=cats~items then do; parse value cats[ci] with xa xb; if t>=xa then wt=0; end
      end
    end
    tA~append(t); fA~append(f0); cA~append(con); wA~append(wt)
  end
  hs~close; call sysFileDelete base'_h_'lab'.tsv'
  /* machine tone / klaxon gate on lifted runs */
  i=1; nF=wA~items
  do while i<=nF
    if wA[i]<>1 then do; i+=1; iterate; end
    j=i; do while j<nF; if wA[j+1]=1 & tA[j+1]-tA[j]<=0.3 then j+=1; else leave; end
    if tA[j]-tA[i]>=0.4 then do
      fz=.array~new; do k=i to j; fz~append(fA[k]+0); end
      fz=fz~sortWith(.NumericComparator~new)
      q10=fz[max(1,trunc(fz~items*0.1))]; q90=fz[max(1,trunc(fz~items*0.9))]
      if q90/q10<1.015 then do
        do k=i to j; wA[k]=0; end; nTone+=1
        call logRow 'tone', tA[i], tA[j], lab format(fz[trunc(fz~items/2)+1],,1)'Hz'
      end
    end
    i=j+1
  end
  ft=base'_'lab'.frames.tsv'; o=.stream~new(ft); o~open('WRITE REPLACE')
  loop k=1 to nF; o~lineout(tA[k]'09'x||wA[k]'09'x||fA[k]'09'x||cA[k]); end
  o~close; ul~lineout(ft)
end
ul~close
say tpName 'machine-tone runs dropped' nTone
x=prov~voiceMaskUnion(cln,base'_uni.f32',base'_union.list',8000,512,128,-14,15,40,100,3800)
/* cut the cat calls out of the union output */
cm=.stream~new(base'_catmute.tsv'); cm~open('WRITE REPLACE'); cm~lineout('start'||'09'x||'end'||'09'x||'lo'||'09'x||'hi'||'09'x||'w')
g=RxCalcPower(10,catDb/20,16); pos=0   /* Rexx ** takes whole exponents only */
loop cv over cats
  parse var cv xa xb; sa=trunc(xa*8000); sb=min(n,trunc(xb*8000))
  if sa>pos then cm~lineout(pos'09'x||sa'09'x||'0'||'09'x||'4000'||'09'x||'1')
  cm~lineout(sa'09'x||sb'09'x||'0'||'09'x||'4000'||'09'x||g); pos=sb
end
if pos<n then cm~lineout(pos'09'x||n'09'x||'0'||'09'x||'4000'||'09'x||'1')
cm~close
x=prov~renderSelection(base'_uni.f32',base'_catmute.tsv',base'_unc.f32',8000,256,64)
call sysFileDelete base'_uni.f32'; call sysFileDelete cln
x=prov~speechAgc(base'_unc.f32',base'_out.f32',8000,-18,48,10,400,6,-1)
call sysFileDelete base'_unc.f32'
address system 'ffmpeg -v error -nostdin -y -f f32le -ar 8000 -ac 1 -i "'base'_out.f32" -c:a libopus -b:a 32k -application voip -ar 16000 "'outOgg'"'
call sysFileDelete base'_out.f32'
log~close
say tpName 'written' outOgg
exit 0
catRun:
  if cb-ca>=0.25 then do
    pa=max(0,ca-0.15); pb=cb+0.15
    if cats~items>0 then do; parse value cats[cats~items] with la lb; if pa<=lb then do; cats[cats~items]=la pb; return; end; end
    cats~append(pa pb)
  end
  return
logRow:   /* internal label: shares the caller's variables, so its names are its own */
  use arg logKind, logA, logB, logD
  log~lineout(logKind'09'x||format(logA,,2)'09'x||format(logB,,2)'09'x||sec2hms(t0+logA)'09'x||sec2hms(t0+logB)'09'x||logD)
  return
::requires 'FdChain.cls'
::requires 'VoiceProfile.cls'
::requires 'AudioV9SpatialNativeProvider.cls'
::requires 'rxmath' LIBRARY
