/* clock_envelope.rex -- FD/FC clock offset from band-limited envelope correlation over the whole overlap.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 31 Oct 2026.
 * Band split: Audio V9 native render_select (STFT 256/64, hard band box).
 * Envelope: Audio V9 native envelope (proposed addition), 800-sample bins = 10 Hz, log dB, 3 s detrend.
 * Correlation: Audio V9 native xcorr (proposed addition); positive lag => FC later than FD.
 * usage: clock_envelope.rex pcmDir workDir outDir [maxLagSec]
 */
numeric digits 20
parse arg pcmDir workDir outDir maxLagSec .
if maxLagSec='' then maxLagSec=900
p=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
bands=.array~of('LOW 60 250', 'SPEECH 300 3400')
mode=value('SPASH_CHAIN_MODE',,'ENVIRONMENT'); if mode='' then mode='NAME'
ch=fcfdChains(pcmDir,mode)
o=.stream~new(outDir'/clock_envelope.tsv'); o~open('WRITE REPLACE')
o~lineout('band'||'09'x||'rank'||'09'x||'fc_minus_fd_s'||'09'x||'score'||'09'x||'zscore')
do band over bands
  parse var band bname lo hi
  env=.directory~new
  do feed over .array~of('FD','FC')
    ec=.FeedChain~new(feed,10)
    do f over ch[feed]~files
      base=filespec('name',f['PATH'])~changestr('.f32','')
      sel=workDir'/'base'_'bname'.f32'; envf=workDir'/'base'_'bname'.env.f32'
      if \sysFileExists(envf) then do
        mask=workDir'/'base'_'bname'.mask.tsv'
        m=.stream~new(mask); m~open('WRITE REPLACE'); m~lineout('start'||'09'x||'end'||'09'x||'lo_hz'||'09'x||'hi_hz'||'09'x||'weight')
        m~lineout('0'||'09'x||f['SAMPLES']||'09'x||lo||'09'x||hi||'09'x||'1'); m~close
        x=p~renderSelection(f['PATH'],mask,sel,8000,256,64)
        nb=p~envelope(sel,envf,800,1,31)
        call sysFileDelete sel
      end
      ec~add(envf,f['START'])
    end
    env[feed]=ec
  end
  t0=max(env['FD']~startSec,env['FC']~startSec); t1=min(env['FD']~endSec,env['FC']~endSec)
  n=trunc((t1-t0)*10)
  a=workDir'/ov_FD_'bname'.f32'; b=workDir'/ov_FC_'bname'.f32'
  env['FD']~writeWindow(t0,n,a); env['FC']~writeWindow(t0,n,b)
  r=p~xcorr(a,b,-maxLagSec*10,maxLagSec*10,1,1)
  sc=r['SCORES']; lg=r['LAGS']
  /* robust background: mean and sd of the curve */
  s=0; ss=0; k=sc~items
  do i=1 to k; s+=sc[i]; ss+=sc[i]**2; end
  mu=s/k; sd=sqrt(ss/k-mu**2)
  /* top 5 separated peaks */
  used=.array~new
  do rank=1 to 5
    best=-9; bi=0
    do i=1 to k
      if sc[i]<=best then iterate
      near=.false; do u over used; if abs(i-u)<50 then do; near=.true; leave; end; end
      if \near then do; best=sc[i]; bi=i; end
    end
    used~append(bi)
    z=(best-mu)/sd
    line=bname'09'x||rank'09'x||format(lg[bi]/10,,1)'09'x||format(best,,4)'09'x||format(z,,1)
    o~lineout(line); say line 'overlap' format((t1-t0)/3600,,2)'h'
  end
end
o~close
exit 0

::routine sqrt
  use arg x
  if x<=0 then return 0
  r=x; do 60; r=(r+x/r)/2; end
  return r
::requires 'FeedChain.cls'
::requires 'AudioV9SpatialNativeProvider.cls'
