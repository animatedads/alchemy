/* SpashAudioBlocks.cls -- SPASH observations from audio through the Audio V9 native provider.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 31 Oct 2026.
 * Replaces the Python fingerprint (tools/spash_find_similar.py) with: native band blocks (Audio V9 provider)
 * -> sqrt-amplitude band shape -> SpashObservation (SPASH's own ooRexx class) -> SpashExampleSearch.
 * Method foundation 'AV9_NATIVE_BANDBLOCKS_22LOG_80_3800/1' marks these as comparable only with each other.
 */
::options numeric inherit
::class SpashAudioBlocks public
::constant FOUNDATION 'AV9_NATIVE_BANDBLOCKS_22LOG_80_3800/1'
::method observe class
  use strict arg provider, f32Path, sourceId, baseSample=0
  numeric digits 16
  blocks=provider~bandBlocks(f32Path,8000,256,128,10,22,80,3800)
  obs=.array~new; rmsList=.array~new
  edges=.array~new; do b=0 to 22; edges~append(80*RxCalcPower(3800/80,b/22,16)); end
  do i=1 to blocks~items
    d=blocks[i]; bins=.array~new; tot=0; cen=0
    do k=1 to d['BANDS']~items
      v=d['BANDS'][k]; if v<0 then v=0
      a=sqrtN(v); bins~append(a); tot+=a
      cen+=a*sqrtN(edges[k]*edges[k+1])
    end
    if tot<=0 then do; bins[1]=1e-12; tot=1e-12; cen=80*tot; end
    centre=cen/tot
    /* bandwidth: shape-weighted spread around the centre */
    sp=0; do k=1 to bins~items; c=sqrtN(edges[k]*edges[k+1]); sp+=bins[k]*(c-centre)**2; end
    width=max(1,sqrtN(sp/tot))
    o=.SpashObservation~new(sourceId, baseSample+d['START'], 1280, 8000, i-1, centre, width, .nil, bins, d['RMS'], .nil, 'AV9_BANDBLOCKS', self~FOUNDATION)
    obs~append(o); rmsList~append(d['RMS'])
  end
  r=.directory~new; r['OBS']=obs; r['RMS']=rmsList
  return r
/* most active run of n consecutive blocks (query template), like SPASH's active_templates */
::method activeTemplate class
  use strict arg obsDir, n=6
  obs=obsDir['OBS']; rms=obsDir['RMS']
  best=-1; bi=1
  do i=1 to obs~items-n+1
    s=0; do k=i to i+n-1; s+=rms[k]; end
    if s>best then do; best=s; bi=i; end
  end
  return obs~section(bi,n)

::routine sqrtN
  use arg v
  if v<=0 then return 0
  r=v; if r<1e-30 then return 0
  do 80; r2=(r+v/r)/2; if abs(r2-r)<=r*1e-12 then leave; r=r2; end
  return r

::requires 'SpashObservation.cls'
::requires 'rxmath' LIBRARY
