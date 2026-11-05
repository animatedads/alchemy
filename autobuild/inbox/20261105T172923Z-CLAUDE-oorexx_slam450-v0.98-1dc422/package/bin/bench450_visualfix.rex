/* SLAM 450 v0.92 visual-fix bench: how well does the 50 m grid place SLAM?
 * Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-04.
 * usage: rexx bench450_visualfix.rex COURSE seed samples out.csv
 * Random legal poses in the course field (8-85 m, any heading). Belief =
 * truth + up to 150 m of error (what dead reckoning drifts to), gyro
 * heading = truth. For each pose: grid fix with the altimeter OFF (all
 * layers) and ON (nearest layer), then the landmark refinement. Writes one
 * row per sample and prints the error distribution and timings. */
numeric digits 16
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
parse arg course seed n out .
.local['SLAM450.GROUND']='GROUND'
g=.Slam450Ground~new(value('SLAM450_HARBOUR_WORDS',,'ENVIRONMENT'),.array~of(-1500,1500,-2000,1000))
w=.Slam450World~new(seed,course,.false,g)
cam=.Slam450Camera~new(w)
fb=w~fieldBox
files=.array~new;do a over .array~of(15,40,70);files~append('data/'course~lower'_visualfix_50m_alt'a'.txt');end
set=.Slam450VisualFixSet~new(files);lms=.Slam450Landmarks~new(w)
noT=.directory~new;do t=1 to 5;noT[t]='BENCH';end
call SysFileDelete out
call lineout out,'i,x,y,z,heading,bel_err_m,off_accept,off_err_m,on_accept,on_err_m,on_layer,lm_ok,lm_err_m,lm_name,lm_range_m,t_lookup_off_s,t_lookup_on_s'
call random ,,seed
eOff=.array~new;eOn=.array~new;eLm=.array~new;accOff=0;accOn=0;lmOk=0;tOff=0;tOn=0;done=0
do i=1 to n*20
  if done>=n then leave
  x=fb[1]+random(0,1000)/1000*(fb[2]-fb[1]);y=fb[3]+random(0,1000)/1000*(fb[4]-fb[3])
  z=8+random(0,77);h=random(0,359)
  p=.array~of(x,y,z,h)
  if \w~safePoint(p,3) then iterate
  done+=1
  a=random(0,359);d=random(0,150)
  bx=x+d*RxCalcSin(a,16);by=y+d*RxCalcCos(a,16)
  f=cam~renderAt(p,480,121,.false,noT)
  s=.Slam450VisualFix~surfaceOf(f)
  t0=time('E');rOff=set~lookup(s,bx,by,h);tOff+=time('E')-t0
  t0=time('E')
  agl=z-w~surfaceBelow(p);amsl=agl+set~groundAt(bx,by)
  rOn=set~lookup(s,bx,by,h,amsl);tOn+=time('E')-t0
  e1='';e2='';e3='';lmn='';lmr='';ok=0
  if rOff['ACCEPT'] then do;accOff+=1;e1=HSq(rOff['X']-x,rOff['Y']-y);eOff~append(e1);end
  if rOn['ACCEPT'] then do
    accOn+=1;e2=HSq(rOn['X']-x,rOn['Y']-y);eOn~append(e2)
    det=cam~renderAt(p,960,242,.false,noT)
    lm=lms~refine(det,rOn['X'],rOn['Y'],h,agl+set~groundAt(rOn['X'],rOn['Y']))
    if lm['OK'] then do
      if (lm['X']-rOn['X'])**2+(lm['Y']-rOn['Y'])**2<80**2 & lm['RANGE']<=300 then do
        /* fused: the mean of the grid fix and the landmark fix */
        fxx=(lm['X']+rOn['X'])/2;fyy=(lm['Y']+rOn['Y'])/2
        ok=1;lmOk+=1;e3=HSq(fxx-x,fyy-y);eLm~append(e3);lmn=lm['NAME'];lmr=format(lm['RANGE'],,0)
      end
    end
  end
  lay='';if rOn~hasIndex('LAYER') then lay=rOn['LAYER']
  call lineout out,done','format(x,,1)','format(y,,1)','z','h','d','rOff['ACCEPT']','fmt(e1)','rOn['ACCEPT']','fmt(e2)','lay','ok','fmt(e3)','lmn','lmr','format(tOff/done,,3)','format(tOn/done,,3)
end
call stream out,'C','CLOSE'
say 'BENCH' course 'SAMPLES' done 'GRID_POINTS' set~points 'GRID_BYTES' set~dataBytes
say 'ALTIMETER_OFF accept' format(100*accOff/done,,1)'%' stats(eOff) 'lookup_s' format(tOff/done,,3)
say 'ALTIMETER_ON  accept' format(100*accOn/done,,1)'%' stats(eOn) 'lookup_s' format(tOn/done,,3)
say 'FUSED(<=300m) used' format(100*lmOk/done,,1)'%' stats(eLm)
exit 0
fmt: if arg(1)=='' then return '';return format(arg(1),,1)
HSq: return RxCalcSqrt(arg(1)**2+arg(2)**2,16)
stats: procedure
  use arg a
  if a~items=0 then return 'n=0'
  b=a~copy;b=b~sortWith(.NumericComparator~new)
  m=b[(b~items+1)%2];p90=b[max(1,trunc(0.9*b~items))]
  s=0;do v over b;s+=v;end
  w50=0;do v over b;if v<=50 then w50+=1;end
  return 'n='||b~items 'median_m' format(m,,1) 'p90_m' format(p90,,1) 'mean_m' format(s/b~items,,1) 'within50' format(100*w50/b~items,,0)'%'
::requires 'Slam450Flight.cls'
::requires 'Slam450VisualFix.cls'
