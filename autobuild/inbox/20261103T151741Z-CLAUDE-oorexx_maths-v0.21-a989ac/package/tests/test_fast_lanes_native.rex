/* Maths v0.20: NUMPY panorama lane vs PURE reference on a seeded scene. */
numeric digits 20
if \.MathPanoramaProjector~numpyAvailable then do; say 'SKIP NUMPY lane unavailable'; exit 0; end
seed=12345
groups=.array~new
do b=1 to 150
  cx=rnd()*800-400; cy=rnd()*800-400; cz=rnd()*60; s=1+rnd()*20
  g=.array~new
  do k=0 to 7
    g~append(.array~of(cx+s*(k//2), cy+s*((k%2)//2), cz+s*(k%4)))
  end
  groups~append(g)
end
pure=.MathPanoramaProjector~new(groups,'PURE',16)
fast=.MathPanoramaProjector~new(groups,'NUMPY')
if fast~lane<>'NUMPY' then do; say 'FAIL lane not NUMPY'; exit 1; end
total=0;diff=0;tp=0;tn=0
do f=1 to 40
  cam=.array~of(rnd()*600-300,rnd()*600-300,5+rnd()*80,rnd()*360)
  t=time('E'); a=pure~extents(cam,480,121); tp+=time('E')-t
  t=time('E'); b=fast~extents(cam,480,121); tn+=time('E')-t
  do i=1 to groups~items
    total+=1
    if a[i]==.nil & b[i]==.nil then iterate
    if a[i]==.nil | b[i]==.nil then do; diff+=1; iterate; end
    do k=1 to 4; if a[i][k]<>b[i][k] then do; diff+=1; leave; end; end
  end
end
if diff*10000>total then do; say 'FAIL NUMPY/PURE agreement' diff 'of' total; exit 1; end
say 'PASS oorexx_maths fast lanes NUMPY agreement' total-diff'/'total 'PURE' format(tp/40,,4)'s/frame NUMPY' format(tn/40,,4)'s/frame'
exit 0
rnd: seed=(seed*16807)//2147483647; return seed/2147483647
::requires 'MathFastLanes.cls'
