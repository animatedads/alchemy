/* Maths v0.21: MathTerrainPanorama NUMPY lane vs PURE reference.
 * Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-03.
 * Seeded rolling terrain (60 x 60 cells of 50 m, rotated 3 degrees) with
 * water and unknown patches; 12 random cameras; pixel-level land/not-land
 * agreement must reach 99.99% (the v0.20 projector's standard). */
numeric digits 20
if \.MathPanoramaProjector~numpyAvailable then do; say 'SKIP NUMPY lane unavailable'; exit 0; end
seed=4242
cols=60;rows=60;h=.array~new;k=.array~new
do r=1 to rows
  do c=1 to cols
    i=(r-1)*cols+c
    v=40*rxs(c/7)*rxs(r/9)+20*rnd()
    if v<5 then do;h[i]=0;k[i]=0;end
    else do;h[i]=format(v,,1);k[i]=1;end
    if rnd()<0.02 then k[i]=-1
  end
end
a=3;ca=RxCalcCos(a);sa=RxCalcSin(a)
colV=.array~of(50*ca,50*sa);rowV=.array~of(50*sa,-50*ca)
pure=.MathTerrainPanorama~new(h,k,cols,rows,.array~of(-1500,1500),colV,rowV,3000,'PURE',16)
fast=.MathTerrainPanorama~new(h,k,cols,rows,.array~of(-1500,1500),colV,rowV,3000,'NUMPY')
if fast~lane<>'NUMPY' then do; say 'FAIL lane not NUMPY'; exit 1; end
W=240;H=61;total=0;diff=0;tp=0;tn=0;landPx=0
do f=1 to 12
  cam=.array~of(rnd()*1600-800,rnd()*1600-800,15+rnd()*90,rnd()*360)
  t=time('E'); p=pure~runs(cam,W,H); tp+=time('E')-t
  t=time('E'); q=fast~runs(cam,W,H); tn+=time('E')-t
  do col=1 to W
    mp=mask(p[col],H);mq=mask(q[col],H)
    do y=1 to H
      total+=1
      if substr(mp,y,1)=='1' then landPx+=1
      if substr(mp,y,1)<>substr(mq,y,1) then diff+=1
    end
  end
end
/* rowRuns: the transposed form must agree pixel for pixel too. */
rdiff=0;rtotal=0
do f=1 to 3
  cam=.array~of(rnd()*1600-800,rnd()*1600-800,15+rnd()*90,rnd()*360)
  p=pure~rowRuns(cam,W,H);q=fast~rowRuns(cam,W,H)
  do y=1 to H
    rtotal+=W
    if rowmask(p[y],W)<>rowmask(q[y],W) then rdiff+=1
  end
end
if rdiff>0 then do; say 'FAIL rowRuns NUMPY/PURE rows differ' rdiff; exit 1; end
if landPx*10<total then do; say 'FAIL fixture shows too little land' landPx 'of' total; exit 1; end
if diff*10000>total then do; say 'FAIL NUMPY/PURE pixel agreement' diff 'of' total; exit 1; end
say 'PASS oorexx_maths terrain panorama NUMPY agreement' total-diff'/'total 'land' landPx 'PURE' format(tp/12,,3)'s/frame NUMPY' format(tn/12,,4)'s/frame'
exit 0
mask: procedure
  use arg runs,H
  m='0'~copies(H)
  do r over runs;m=overlay('1'~copies(r[2]-r[1]+1),m,r[1]);end
  return m
rowmask: procedure
  use arg runs,W
  m='0'~copies(W)
  do r over runs;m=overlay('1'~copies(r[2]-r[1]+1),m,r[1]);end
  return m
rnd: seed=(seed*16807)//2147483647; return seed/2147483647
rxs: return RxCalcSin(arg(1)*57.29577951308232)
::requires 'MathFastLanes.cls'
::requires 'rxmath' LIBRARY
