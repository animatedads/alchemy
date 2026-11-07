/* Spash3DWindow.cls -- SPASH 3D acoustic map for one analysis window.
 * Architecture: Tom Dyer (four virtual microphones, best-path, banded spectral blocks, 3D echo reconstruction).
 * Coding: Claude (Opus 5.5), 31 Oct 2026.
 *
 * Inputs : original FD and FC decoded PCM (continuous chains), FC->FD clock model, Physics World map table.
 * DSP    : Audio V9 native provider (band selection, correlation curves, aligned rendering).
 * Physics: Physics World F11 v0.4 scene predictions (acoustic_map_table.rex output).
 * Scores (kept separate, then combined):
 *   INTER  - measured FD/FC band correlation read at every predicted FC-arrival minus FD-arrival lag
 *            (top 3 x top 3 arrivals, amplitude weighted), after a single clock-residual delta for the window.
 *   INTRA  - each feed's band autocorrelation read at the predicted gaps between its own arrivals (clock free).
 * Labels : the clock residual delta is a nuisance parameter fitted per window; positions are model hypotheses
 *          ranked by measured evidence, not independent observations.  Nothing is gated.
 */
::options numeric inherit

::class Spash3DWindow public
::method bands class
  /* name lo hi ampBand */
  return .array~of('B1 200 400 400','B2 400 650 400','B3 650 1000 1000','B4 1000 1500 1000', -
                   'B5 1500 2150 2150','B6 2150 2950 2150','B7 2950 3800 2150')

/* --- Physics World map table ------------------------------------------------------------- */
::method loadMap class
  use strict arg paths   /* array of TSV paths */
  pts=.directory~new
  do path over paths
    s=.stream~new(path); s~open('READ'); hdr=s~linein
    do while s~lines>0
      l=s~linein; if l='' then iterate
      f=l~makeArray('09'x)
      id=f[1]
      if \pts~hasIndex(id) then do
        d=.directory~new; d['ID']=id; d['X']=f[2]+0; d['Y']=f[3]+0; d['Z']=f[4]+0; d['REGION']=f[5]; d['ROOM']=f[6]
        d['FD']=.array~new; d['FC']=.array~new; pts[id]=d
      end
      a=.directory~new; a['DELAY']=f[9]+0; a['KIND']=f[10]
      a['A400']=f[11]+0; a['A1000']=f[12]+0; a['A2150']=f[13]+0
      pts[id][f[7]]~append(a)
    end
    s~close
  end
  /* keep arrivals within 30 dB of the strongest (per receiver, 1 kHz), sorted by amplitude */
  do id over pts~allIndexes
    do rn over .array~of('FD','FC')
      arr=pts[id][rn]; mx=0
      do a over arr; if a['A1000']>mx then mx=a['A1000']; end
      keep=.array~new
      do a over arr; if mx>0 then do; if a['A1000']>=mx*0.0316 then keep~append(a); end; end
      /* sort by amplitude desc (insertion) */
      srt=.array~new
      do a over keep
        ins=.false
        do j=1 to srt~items; if a['A1000']>srt[j]['A1000'] then do; if j=1 then srt~insert(a,.nil); else srt~insert(a,j-1); ins=.true; leave; end; end
        if \ins then srt~append(a)
      end
      pts[id][rn]=srt
    end
  end
  return pts

/* --- band curves for a window ------------------------------------------------------------- */
::method curves class
  use strict arg prov, fdPath, fcPath, workDir, tag, maxInterMs=120, maxIntraMs=150
  n=stream(fdPath,'C','QUERY SIZE')%4
  res=.directory~new
  do b over self~bands
    parse var b name lo hi amp
    mask=workDir'/'tag'_'name'.mask.tsv'
    m=.stream~new(mask); m~open('WRITE REPLACE'); m~lineout('start'||'09'x||'end'||'09'x||'lo'||'09'x||'hi'||'09'x||'w')
    m~lineout('0'||'09'x||n||'09'x||lo||'09'x||hi||'09'x||'1'); m~close
    fdb=workDir'/'tag'_fd_'name'.f32'; fcb=workDir'/'tag'_fc_'name'.f32'
    x=prov~renderSelection(fdPath,mask,fdb,8000,256,64); x=prov~renderSelection(fcPath,mask,fcb,8000,256,64)
    centre=RxCalcSqrt(lo*hi,16); half=max(1,trunc(8000/(2*centre)+0.5))
    li=maxInterMs*8; la=maxIntraMs*8
    ci=prov~xcorr(fdb,fcb,-li,li,1,1)
    rd=prov~xcorr(fdb,fdb,0,la,1,1)
    rc=prov~xcorr(fcb,fcb,0,la,1,1)
    d=.directory~new; d['NAME']=name; d['AMP']='A'amp; d['HALF']=half
    /* Excess over background, so a position scores only where the curve has a real peak:
       INTER minus its mean over all lags; autocorrelation minus a +-8 ms local mean (excluding the centre). */
    d['INTER']=excessFlat(envelope(ci['SCORES'],half)); d['INTER_OFF']=li          /* index = lag + li + 1 */
    d['RFD']=excessLocal(envelope(rd['SCORES'],half),64,half); d['RFC']=excessLocal(envelope(rc['SCORES'],half),64,half)
    d['GAPMIN_MS']=max(2,1500/(hi-lo))     /* inside the band's main lobe a gap is not resolvable */
    mm=prov~measure(fdb,fcb,8000,10,1); d['RMS_FD']=mm~rmsA; d['RMS_FC']=mm~rmsB
    d['FDB']=fdb; d['FCB']=fcb
    res[name]=d
  end
  return res

/* --- scoring -------------------------------------------------------------------------------- */
::method score class
  use strict arg pts, cur, deltaMinMs=(-60), deltaMaxMs=60, deltaStepMs=1
  bands=self~bands
  /* precompute per point: inter pairs (lag ms, weight per amp band) and intra pairs */
  prep=.array~new
  do id over pts~allIndexes
    p=pts[id]; fd=p['FD']; fc=p['FC']
    if fd~items=0 | fc~items=0 then iterate
    inter=.array~new
    do i=1 to min(3,fd~items); do j=1 to min(3,fc~items)
      pr=.directory~new; pr['LAG']=fc[j]['DELAY']-fd[i]['DELAY']
      do ab over .array~of('A400','A1000','A2150'); pr[ab]=fd[i][ab]*fc[j][ab]; end
      inter~append(pr)
    end; end
    intra=.array~new
    do rn over .array~of('FD','FC')
      arr=p[rn]
      do i=1 to min(6,arr~items); do j=i+1 to min(6,arr~items)
        g=abs(arr[j]['DELAY']-arr[i]['DELAY']); if g<2 then iterate
        pr=.directory~new; pr['GAP']=g; pr['RX']=rn
        do ab over .array~of('A400','A1000','A2150'); pr[ab]=arr[i][ab]*arr[j][ab]; end
        intra~append(pr)
      end; end
    end
    q=.directory~new; q['P']=p; q['INTER']=inter; q['INTRA']=intra; prep~append(q)
  end
  /* intra score per point (clock free) */
  do q over prep
    s=0; wsum=0
    do b over bands
      parse var b name . . amp
      c=cur[name]
      do pr over q['INTRA']
        w=pr['A'amp]; if w<=0 then iterate
        if pr['GAP']<c['GAPMIN_MS'] then iterate
        lagS=trunc(pr['GAP']*8+0.5)
        if pr['RX']='FD' then arr=c['RFD']; else arr=c['RFC']
        if lagS+1>arr~items then iterate
        s+=w*arr[lagS+1]; wsum+=w
      end
    end
    if wsum>0 then q['SINTRA']=s/wsum; else q['SINTRA']=0
    /* SPASH_TERMS=INTER disables the within-feed echo term (voiced speech pitch periods 4-12 ms confound it) */
    if value('SPASH_TERMS',,'ENVIRONMENT')~upper='INTER' then q['SINTRA']=0
  end
  /* Scale each evidence type by its spread across positions, so neither dominates by units alone. */
  sIntra=spread(prep,'SINTRA',.nil,cur,bands,self)
  do q over prep; q['I0']=self~interAt(q,cur,0,bands); end
  sInter=spread(prep,'I0',.nil,cur,bands,self)
  /* Clock residual delta: Gaussian prior sigma 38 ms (clock-model residual RMS); maximise best position. */
  bestD=0; bestV=-1e9
  do delta=deltaMinMs to deltaMaxMs by deltaStepMs
    top=-1e9
    do q over prep
      v=self~interAt(q,cur,delta,bands)/sInter+q['SINTRA']/sIntra
      if v>top then top=v
    end
    top=top-0.5*(delta/38)**2
    if top>bestV then do; bestV=top; bestD=delta; end
  end
  out=.array~new
  do q over prep
    si=self~interAt(q,cur,bestD,bands)
    r=.directory~new; r['P']=q['P']; r['SINTER']=si; r['SINTRA']=q['SINTRA']; r['S']=si/sInter+q['SINTRA']/sIntra
    r['PRED_LEVEL_DB']=predLevel(q['P'])
    out~append(r)
  end
  /* sort desc by S */
  srt=.array~new
  do r over out
    ins=.false
    do j=1 to srt~items; if r['S']>srt[j]['S'] then do; if j=1 then srt~insert(r,.nil); else srt~insert(r,j-1); ins=.true; leave; end; end
    if \ins then srt~append(r)
  end
  res=.directory~new; res['DELTA']=bestD; res['RANKED']=srt
  return res
::method interAt class
  use strict arg q, cur, delta, bands
  s=0; wsum=0
  do b over bands
    parse var b name . . amp
    c=cur[name]; arr=c['INTER']; off=c['INTER_OFF']
    do pr over q['INTER']
      w=pr['A'amp]; if w<=0 then iterate
      idx=trunc((pr['LAG']+delta)*8+0.5)+off+1
      if idx<1 | idx>arr~items then iterate
      s+=w*arr[idx]; wsum+=w
    end
  end
  if wsum>0 then return s/wsum
  return 0

::routine spread
  use arg prep, key
  s=0; ss=0; n=prep~items
  do q over prep; v=q[key]; s+=v; ss+=v*v; end
  var=ss/n-(s/n)**2
  if var<=0 then return 1
  r=var; do 60; r=(r+var/r)/2; end
  return r
::routine predLevel
  /* Physics World predicted FC/FD level at 1 kHz (all retained arrivals, power sum), dB */
  use arg p
  a=0; b=0
  do x over p['FC']; a+=x['A1000']**2; end
  do x over p['FD']; b+=x['A1000']**2; end
  if a<=0 | b<=0 then return 'NA'
  return format(10*RxCalcLog10(a/b,16),,1)
::routine excessFlat
  use arg x
  s=0; do v over x; s+=v; end; mu=s/x~items
  out=.array~new(x~items); do i=1 to x~items; out[i]=max(0,x[i]-mu); end
  return out
::routine excessLocal
  use arg x, w, guard
  n=x~items; out=.array~new(n)
  /* prefix sums for fast local means */
  ps=.array~new(n+1); ps[1]=0; do i=1 to n; ps[i+1]=ps[i]+x[i]; end
  do i=1 to n
    lo=max(1,i-w); hi=min(n,i+w); gl=max(1,i-guard); gh=min(n,i+guard)
    tot=ps[hi+1]-ps[lo]-(ps[gh+1]-ps[gl]); cnt=(hi-lo+1)-(gh-gl+1)
    if cnt<=0 then bg=0; else bg=tot/cnt
    out[i]=max(0,x[i]-bg)
  end
  return out
::routine envelope
  /* max |x| over +-half samples: a phase-free envelope of a band-limited correlation curve */
  use arg x, half
  n=x~items; out=.array~new(n)
  do i=1 to n
    m=0
    do k=max(1,i-half) to min(n,i+half); v=abs(x[k]); if v>m then m=v; end
    out[i]=m
  end
  return out

::requires 'rxmath' LIBRARY
