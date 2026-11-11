/* multitrack.rex -- one whole FD original split into spectral brackets, one audio track per bracket, muxed into a
 * single multitrack Ogg (VLC: Audio > Audio Track switches between them).
 * Architecture: Tom Dyer (6 Nov 2026: run TP1; output a multitrack ogg, each track a spectral bracket).
 * Coding: Claude (Opus 5.5).
 *   amp     native speech AGC (-20 dBFS, up to +36 dB)
 *   filter  screech suppression; enhancer (90-3600 Hz) -> pitch input (no tilt: men's fundamentals stay
 *           trackable); + speech tilt (as moment_render.rex) -> the signal each track is cut from
 *   pitch   native multiF0: up to 4 simultaneous pitches per 10 ms frame, each voice's harmonics cancelled
 *           before the next is found (60-500 Hz, 15 harmonics, strength >= 3.0 = harmonic peaks 3x the noise floor,
 *           later picks >= 0.25 x the first)
 *   lines   per bracket, a pitch is voice only on a continuous line: < 3 % change per frame, gaps <= 30 ms
 *           bridged, >= 60 ms long (pending frames wait in a Queue until the line proves itself)
 *   tracks  native voice mask per bracket on its own lines (other tones at floorDb, width 15 Hz, 40 ms smoothing),
 *           native speech AGC (-18 dBFS, up to +48 dB); plus a reference track: the filtered signal, no mask
 *   mux     Ogg Opus, one stream per track, 8 kHz content, bitRate each, stream titles = bracket names
 * usage: multitrack.rex tpName pcmDir workDir outOgg floorDb bitRate brackets
 *   brackets: name:lo-hi,name:lo-hi,...  e.g. voice_0-150Hz:60-150,voice_151-190Hz:151-190 */
numeric digits 16
parse arg tpName pcm w outOgg fl br bks
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
ch=fdChainFull(pcm); me=.nil; loop f over ch~files; if filespec('name',f['PATH'])=tpName'.f32' then me=f; end
if me=.nil then do; say 'no' tpName 'in the FD chain'; exit 1; end
src=me['PATH']; n=me['SAMPLES']; base=w'/'tpName
say tpName 'start' sec2hms(me['START']) 'length' sec2hms(n/8000)
x=prov~speechAgc(src,base'_amp.f32',8000,-20,36,10,400,6,-1)
nb=prov~suppressTonalBursts(base'_amp.f32',base'_scr.f32',base'_screech.tsv'); call sysFileDelete base'_amp.f32'
x=prov~enhance(base'_scr.f32',base'_enh.f32',8000,256,64,1.5,0.98,1.0,0.1,90,3600); call sysFileDelete base'_scr.f32'
tm=.stream~new(base'_tilt.tsv'); tm~open('WRITE REPLACE'); tm~lineout('start'||'09'x||'end'||'09'x||'lo'||'09'x||'hi'||'09'x||'w')
loop row over .array~of('90 3600 0.15','250 3600 0.4','600 3600 0.8','1200 3600 1')
  parse var row tlo thi tw; tm~lineout('0'||'09'x||n||'09'x||tlo||'09'x||thi||'09'x||tw)
end
tm~close
cln=base'_cln.f32'; x=prov~renderSelection(base'_enh.f32',base'_tilt.tsv',cln,8000,256,64)
nf=prov~multiF0(base'_enh.f32',base'_mf.tsv',8000,1024,80,60,500,15,4,3.0,0.25); call sysFileDelete base'_enh.f32'
say tpName 'multi-pitch frames' nf
/* brackets: one state directory each */
bkA=.array~new
loop bv over bks~makeArray(',')
  parse var bv nm ':' lo '-' hi
  bk=.directory~new; bk['NAME']=nm; bk['LO']=lo; bk['HI']=hi; bk['LAST']=0; bk['GAP']=0; bk['OK']=.false; bk['PEND']=.queue~new; bk['VOICED']=0
  o=.stream~new(base'_'nm'.frames.tsv'); o~open('WRITE REPLACE'); bk['OUT']=o; bkA~append(bk)
end
s=.stream~new(base'_mf.tsv'); s~open('READ'); h=s~linein
do while s~lines>0
  c=s~linein~makeArray('09'x); t=c[1]
  loop bk over bkA
    pick=0; bd=9
    loop i=2 to c~items by 2
      pf=c[i]; if pf<bk['LO'] | pf>=bk['HI'] then iterate
      if bk['LAST']>0 then d=abs(pf/bk['LAST']-1); else d=1-c[i+1]/100     /* no line yet: strongest */
      if d<bd then do; bd=d; pick=pf; end
    end
    if pick>0 then if bk['LAST']>0 then if abs(pick/bk['LAST']-1)>=0.03 then do; call endLine bk; end
    if pick>0 then do
      bk['LAST']=pick; bk['GAP']=0
      if bk['OK'] then do; bk['OUT']~lineout(t'09'x||'1'||'09'x||pick||'09'x||'1'); bk['VOICED']+=1; end
      else do
        bk['PEND']~queue(t pick)
        if bk['PEND']~items>=6 then do; bk['OK']=.true; call flush bk, 1; end
      end
    end
    else if bk['LAST']>0 & bk['GAP']<3 then do                   /* bridge a short gap */
      bk['GAP']+=1
      if bk['OK'] then bk['OUT']~lineout(t'09'x||'1'||'09'x||'0'||'09'x||'1'); else bk['PEND']~queue(t 0)
    end
    else do; if bk['LAST']>0 then call endLine bk; bk['OUT']~lineout(t'09'x||'0'||'09'x||'0'||'09'x||'0'); end
  end
end
s~close
loop bk over bkA; call endLine bk; bk['OUT']~close; end
call sysFileDelete base'_mf.tsv'
flat=base'_flat.shape'; q=.stream~new(flat); q~open('WRITE REPLACE'); q~lineout('100'||'09'x||'1'); q~lineout('3800'||'09'x||'1'); q~close
ins=''; maps=''; meta=''; k=0
loop bk over bkA
  ft=base'_'bk['NAME']'.frames.tsv'
  x=prov~voiceMask(cln,base'_m.f32',ft,flat,8000,512,128,fl,15,40,100,3800,0)
  x=prov~speechAgc(base'_m.f32',base'_t'k'.f32',8000,-18,48,10,400,6,-1); call sysFileDelete base'_m.f32'; call sysFileDelete ft
  say bk['NAME'] format(bk['VOICED']/100,,1) 's of voice line'
  ins=ins '-f f32le -ar 8000 -ac 1 -i "'base'_t'k'.f32"'; maps=maps '-map' k':a'; meta=meta '-metadata:s:a:'k' title='bk['NAME']; k+=1
end
x=prov~speechAgc(cln,base'_t'k'.f32',8000,-18,48,10,400,6,-1); call sysFileDelete cln
ins=ins '-f f32le -ar 8000 -ac 1 -i "'base'_t'k'.f32"'; maps=maps '-map' k':a'; meta=meta '-metadata:s:a:'k' title=reference_cleaned_no_mask'
address system 'ffmpeg -v error -nostdin -y'ins maps '-c:a libopus -b:a' br '-application voip' meta '-metadata title="FD' tpName sec2hms(me['START'])' spectral brackets" "'outOgg'"'
loop i=0 to k; call sysFileDelete base'_t'i'.f32'; end
say tpName 'written' outOgg
exit 0
flush:   /* internal label: names are its own (fl*) */
  use arg flB, flW
  do while flB['PEND']~items>0
    parse value flB['PEND']~pull with flT flF
    if flW=1 then do; flB['OUT']~lineout(flT'09'x||'1'||'09'x||flF||'09'x||'1'); flB['VOICED']+=1; end
    else flB['OUT']~lineout(flT'09'x||'0'||'09'x||'0'||'09'x||'0')
  end
  return
endLine:   /* close the bracket's current line: unproven pending frames are not voice */
  use arg elB
  if \elB['OK'] then call flush elB, 0
  elB['OK']=.false; elB['LAST']=0; elB['GAP']=0
  return
::requires 'FdChain.cls'
::requires 'AudioV9SpatialNativeProvider.cls'
