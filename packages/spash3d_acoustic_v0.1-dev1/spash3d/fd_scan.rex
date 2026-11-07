/* fd_scan.rex -- run the voice profiles over one whole FD original (amp, filter, then pitch per profile) and
 * keep the lifted frames, on the FD chain clock, for picking FD's own moments.
 * Architecture: Tom Dyer (5 Nov 2026: FD is far clearer; find what FD heard).  Coding: Claude (Opus 5.5).
 * Chunks of chunkS s with 2 s overlap each side; per chunk: native speech AGC (-20 dBFS, +36 dB max), screech
 * suppression, enhancer (90-3600 Hz), speech tilt (as moment_render.rex); per profile: harmonic-contrast pitch in
 * the profile's window (>= 0.3), bucket probability >= its p20, 386.8/193.4 Hz device excluded.  Only the chunk
 * core is kept, so frames are not counted twice.
 * Writes outDir/<tp>_<label>.lifted.tsv: chain_time f0 contrast (lifted frames only).
 * FD chain: fdChainFull (FdChain.cls) -- TP7 at 11:14:49, later files at previous end + 0.08 s, earlier files
 *   (TP6 back to TP1) ending 0.08 s before the next.
 * usage: fd_scan.rex tpName pcmDir workDir outDir chunkS profile [profile ...] */
numeric digits 16
parse arg tpName pcm w outD chunkS profs
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
fd=fdChainFull(pcm)   /* FdChain.cls: TP1-TP9, same placement as before for TP6-TP9 */
me=.nil; loop f over fd~files; if filespec('name',f['PATH'])=tpName'.f32' then me=f; end
if me=.nil then do; say 'no' tpName 'in the FD chain'; exit 1; end
profA=.array~new; loop pf over profs~space~makeArray(' '); profA~append(.VoiceProfile~load(pf)); end
floors=.directory~new; outs=.directory~new
loop vp over profA
  floors[vp~label]=vp~pitchFloor(20)
  o=.stream~new(outD'/'tpName'_'vp~label'.lifted.tsv'); o~open('WRITE REPLACE'); outs[vp~label]=o
end
ov=2; tm=w'/'tpName'_tilt.tsv'; nChunk=0
loop c0=me['START'] to me['END'] by chunkS
  c1=min(c0+chunkS,me['END']); a=max(me['START'],c0-ov); b=min(me['END'],c1+ov); n=trunc((b-a)*8000)
  raw=w'/'tpName'_raw.f32'; x=fd~writeWindow(a,n,raw)
  x=prov~speechAgc(raw,w'/'tpName'_amp.f32',8000,-20,36,10,400,6,-1)
  nb=prov~suppressTonalBursts(w'/'tpName'_amp.f32',w'/'tpName'_scr.f32',w'/'tpName'_screech.tsv')
  x=prov~enhance(w'/'tpName'_scr.f32',w'/'tpName'_enh.f32',8000,256,64,1.5,0.98,1.0,0.1,90,3600)
  ts=.stream~new(tm); ts~open('WRITE REPLACE'); ts~lineout('start'||'09'x||'end'||'09'x||'lo'||'09'x||'hi'||'09'x||'w')
  loop row over .array~of('90 3600 0.15','250 3600 0.4','600 3600 0.8','1200 3600 1')
    parse var row tlo thi tw; ts~lineout('0'||'09'x||n||'09'x||tlo||'09'x||thi||'09'x||tw)
  end
  ts~close
  cln=w'/'tpName'_cln.f32'; x=prov~renderSelection(w'/'tpName'_enh.f32',tm,cln,8000,256,64)
  loop vp over profA
    lab=vp~label; ht=w'/'tpName'_h.tsv'; x=prov~harmonicF0(cln,ht,8000,512,80,vp~winLo,vp~winHi,20,2000,0.3)
    hs=.stream~new(ht); hs~open('READ'); hdr=hs~linein
    do while hs~lines>0
      parse value hs~linein with t '09'x f0 '09'x con
      if f0<=0 then iterate
      ct=a+t; if ct<c0 | ct>=c1 then iterate
      k=.VoiceProfile~bucket(f0); if k<=0 then iterate
      if vp~pitch[k]<floors[lab] then iterate
      if abs(f0/386.8-1)<0.01 | abs(f0/193.4-1)<0.01 then iterate
      outs[lab]~lineout(format(ct,,3)'09'x||f0'09'x||con)
    end
    hs~close
  end
  nChunk+=1
end
loop o over outs~allItems; o~close; end
say tpName nChunk 'chunks' sec2hms(me['START']) '-' sec2hms(me['END'])
::requires 'FdChain.cls'
::requires 'VoiceProfile.cls'
::requires 'AudioV9SpatialNativeProvider.cls'
