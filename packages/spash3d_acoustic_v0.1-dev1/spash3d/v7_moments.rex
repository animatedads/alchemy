/* v7_moments.rex -- the best moments as separate MP3 files, every render of a moment side by side (VLC next/prev).
 * Architecture: Tom Dyer (5 Nov 2026: files, not reels; 6-10 s each to get the ear in).  Coding: Claude (Opus 5.5).
 * Moments: windows of winS s centred on stretches where any of the `labels` profiles locked on (gaps < 0.3 s
 * bridged), merged within a clip up to maxWinS; score = sum of mean contrast x stretch length.  Best nMoments.
 * Per moment, files NN_FC_HH-MM-SS_<letter>_<render>.mp3 from: original ch1, UNION_A, and each profile render;
 * each file gets the native speech AGC (-18 dBFS) and is written as 16 kHz MP3 (container encode only).
 * Also writes moments_index.tsv (NN, fc_time, clip, clip_start_s, length_s, score).
 * usage: v7_moments.rex workDir clipStartTsv outDir nMoments winS maxWinS labels...  */
numeric digits 16
parse arg w cst outD nMom winS maxWinS labs
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
starts=.directory~new; s=.stream~new(cst); s~open('READ')
do while s~lines>0; parse value s~linein with nm '09'x st; starts[nm~changestr('.ogg','')]=st; end
s~close
cand=.array~new
ids=.array~new; loop k over starts~allIndexes; ids~append(k); end; ids=ids~sort
loop id over ids
  trk=w'/'id'_ch1.f32'; if .stream~new(trk)~query('exists')='' then iterate
  clipS=.stream~new(trk)~query('size')/4/8000
  winList=.array~new
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
  winList=winList~sort; merged=.array~new   /* start times zero-padded: text order = time order */
  loop wv over winList
    parse var wv a b sc
    if merged~items>0 then do
      parse value merged[merged~items] with ma mb msc
      a=a+0; if a<=mb & max(mb,b)-ma<=maxWinS then do; merged[merged~items]=ma max(mb,b) (msc+sc); iterate; end
    end
    merged~append(a b sc)
  end
  loop mv over merged; parse var mv a b sc; cand~append(right(format(sc,,4),14,'0')||'|'||id||'|'||a||'|'||b); end
end
cand=cand~sortWith(.DescendingComparator~new)
keep=.array~new
loop c over cand; parse var c sc '|' id '|' a '|' b; keep~append(right(format(starts[id]+a,,2),10,'0')||'|'||id||'|'||a||'|'||b||'|'||sc); if keep~items>=nMom then leave; end
keep=keep~sort
renders=.array~of('ch1|a_original','UNION_A|b_union','VOICE_SM|c_TVmale','VOICE_SF|d_TVfemale','VOICE_M4|e_M4','VOICE_M2|f_M2','VOICE_X1|g_X1')
ix=.stream~new(outD'/moments_index.tsv'); ix~open('WRITE REPLACE')
ix~lineout('NN'||'09'x||'fc_time'||'09'x||'clip'||'09'x||'clip_start_s'||'09'x||'length_s'||'09'x||'score')
nn=0
loop k over keep
  parse var k . '|' id '|' a '|' b '|' sc; a=a+0; nn+=1
  t1=starts[id]+a+28800; hh=t1%3600; mm=(t1-hh*3600)%60; ss=trunc(t1-hh*3600-mm*60)
  tag=right(nn,2,'0')'_FC_'right(hh,2,'0')'-'right(mm,2,'0')'-'right(ss,2,'0')
  ix~lineout(right(nn,2,'0')'09'x||right(hh,2,'0')':'right(mm,2,'0')':'right(format(t1-hh*3600-mm*60,,2),5,'0')'09'x||id'09'x||format(a,,2)'09'x||format(b-a,,1)'09'x||format(sc,,2))
  loop rv over renders
    parse var rv sfx '|' lab
    trk=w'/'id'_'sfx'.f32'; if .stream~new(trk)~query('exists')='' then iterate
    n=trunc((b-a)*8000); tf=.stream~new(trk); tf~open('READ'); d=tf~charin(trunc(a*8000)*4+1,n*4); tf~close
    c=.stream~new(w'/m_cut.f32'); c~open('WRITE REPLACE'); c~charout(d); c~close
    x=prov~speechAgc(w'/m_cut.f32',w'/m_agc.f32',8000,-18,30,10,400,6,-1)
    address system 'ffmpeg -v error -nostdin -y -f f32le -ar 8000 -ac 1 -i "'w'/m_agc.f32" -c:a libmp3lame -b:a 48k -ar 16000 "'outD'/'tag'_'lab'.mp3"'
  end
end
ix~close
say nn 'moments written to' outD
exit 0
addWin:
  parse var cur pa pb
  if pb-pa<0.15 then return
  cc=(pa+pb)/2; a=max(0,cc-winS/2); b=min(clipS,a+winS); a=max(0,b-winS)
  winList~append(right(format(a,,2),9,'0') format(b,,2) (csum/cn)*(pb-pa))
  return
::requires 'AudioV9SpatialNativeProvider.cls'
