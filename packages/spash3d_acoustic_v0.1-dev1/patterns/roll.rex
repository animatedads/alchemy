/* roll.rex -- multi-window pitch "piano roll" of one FD stretch: harmonic-contrast pitch tracked separately in
 * several pitch windows (as the union render does), so overlapping speakers each show.  Reconnaissance.
 * usage: roll.rex pcmDir workDir fromClock toClock windows(lo-hi,lo-hi,...) */
numeric digits 16
parse arg pcm w fromT toT wins
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
ch=fdChainFull(pcm); a=hms2sec(fromT); b=hms2sec(toT); t0f=ch~files[1]['START']; n=trunc((b-a)*8000)
x=ch~writeWindow(a,n,w'/rl_raw.f32')
x=prov~speechAgc(w'/rl_raw.f32',w'/rl_amp.f32',8000,-20,36,10,400,6,-1)
nb=prov~suppressTonalBursts(w'/rl_amp.f32',w'/rl_scr.f32',w'/rl_s.tsv')
x=prov~enhance(w'/rl_scr.f32',w'/rl_cln.f32',8000,256,64,1.5,0.98,1.0,0.1,90,3600)
cols=.array~new
loop wv over wins~makeArray(',')
  parse var wv lo '-' hi
  x=prov~harmonicF0(w'/rl_cln.f32',w'/rl_h.tsv',8000,512,80,lo,hi,20,2000,0.3)
  d=.directory~new; s=.stream~new(w'/rl_h.tsv'); s~open('READ'); h=s~linein
  do while s~lines>0
    parse value s~linein with t '09'x f0 '09'x con
    if f0<=0 then iterate
    k=trunc(t*10); if \d~hasIndex(k) then d[k]=.array~new
    d[k]~append(f0)
  end
  s~close; cols~append(d)
end
hdr='pos      clock        '; loop wv over wins~makeArray(','); hdr=hdr||wv~left(11); end; say hdr
loop k=0 to trunc((b-a)*10)-1
  p=a+k/10-t0f; m=trunc(p/60); line=(m':'right(format(p-m*60,,1),4,'0'))~left(9)||sec2hms(a+k/10)~left(13)
  any=0
  loop d over cols
    if d~hasIndex(k) then do; z=d[k]~sortWith(.NumericComparator~new); line=line||format(z[(z~items+1)%2],,0)~left(11); any=1; end
    else line=line||'.'~left(11)
  end
  say line
end
::requires 'FdChain.cls'
::requires 'AudioV9SpatialNativeProvider.cls'
