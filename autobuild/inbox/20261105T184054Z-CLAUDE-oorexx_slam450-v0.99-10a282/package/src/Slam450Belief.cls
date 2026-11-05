/* SLAM 450 v0.92 - where each pilot BELIEVES it is, and what it believes it
 * has searched.
 *
 * Architecture: Tom Dyer ("both need an idea, based on their internally kept
 * guesses or knowledge of their location, as to what space they have
 * searched"; "they can probably identify something at 500 metres").
 * Written by: Claude (Opus 5.5), 2026-11-04.
 *
 * One object per aircraft. It never reads truth to build the belief:
 *   - SLAM pilots: dead reckoning from the known start pose plus the pilot's
 *     OWN executed commands (yaw, forward airspeed, side). Wind is unknown to
 *     it, so the belief drifts with the wind - that drift is the point.
 *   - LLM pilots: the "where" map pixel and "sure" the model reports; between
 *     reports the belief is carried forward by the same dead reckoning.
 * Coverage: every 50 m cell whose centre lies within the identification
 * range (500 m) of a BELIEVED position counts as searched. Occlusion is not
 * known to the pilot, so it is not used here either.
 * Sightings: the pilot's own belief of where a target is (map pixels for an
 * LLM, bearing + size-range from its believed position for SLAM).
 * Together these are the pilot's FLIGHT BOOK (Tom Dyer: "we provide them a
 * flight book to write those beliefs").
 * Truth enters only in logError()/logSighting(), which writes belief-vs-truth to the
 * ORACLE-side log for after-race scoring; nothing from it flows back.
 */
::class Slam450Belief public
::attribute x get
::attribute y get
::attribute heading get
::attribute sure get
::attribute source get
::method init
  expose x y heading sure source crop cells cell idRange startTick reports errSum errN within50 brier book rays
  use strict arg startPose,mapCrop,identifyRange=500,cellSize=50
  x=startPose[1];y=startPose[2];heading=startPose[4]
  sure=1;source='START';crop=mapCrop;idRange=identifyRange;cell=cellSize
  cells=.directory~new;startTick=0;reports=0;book=.directory~new;rays=.directory~new
  errSum=0;errN=0;within50=0;brier=0
  self~markSearched(0)

::method deadReckon
  /* One tick of flight from the pilot's own command: yaw deg, forward m/s
     (airspeed), side m/s. Heading is integrated from yaw (a gyro). */
  expose x y heading sure source reportTick
  use strict arg tick,cmd
  numeric digits 16
  heading=(heading+cmd[1])//360;if heading<0 then heading+=360
  f=cmd[2];s=0;if cmd~items>=4 then s=cmd[4]
  x+=f*RxCalcSin(heading,16)+s*RxCalcCos(heading,16)
  y+=f*RxCalcCos(heading,16)-s*RxCalcSin(heading,16)
  /* a report this tick stays visible in the log as REPORT_DR */
  reported=.false;if var('reportTick') then reported=(reportTick==tick & (source=='REPORT' | source~left(6)=='VISFIX' | source~right(8)=='_HEADING'))
  was=source
  sure=max(0,sure-0.01);source='DR';if reported then source=was'_DR'
  self~markSearched(tick)
  return .true

::method report
  /* An LLM's own position report in map pixels (x right, y down). */
  expose x y sure source reports crop reportTick
  use strict arg tick,px,py,confidence
  numeric digits 16
  if \datatype(px,'N') | \datatype(py,'N') then return .false
  if px<0 | py<0 | px>(crop[2]-crop[1])*crop[5] | py>(crop[4]-crop[3])*crop[5] then return .false
  x=crop[1]+px/crop[5];y=crop[4]-py/crop[5]
  sure=1;if datatype(confidence,'N') then sure=max(0,min(1,confidence))
  source='REPORT';reports+=1;reportTick=tick
  self~markSearched(tick)
  return .true

::method fix
  /* v0.92 visual fix (Slam450VisualFix): the pilot's own camera matched to
     the precomputed 50 m grid (and, altimeter on, a landmark range). Resets
     position, and heading when one is given. Logged as the source. */
  expose x y heading sure source reportTick
  use strict arg tick,fx,fy,fheading=.nil,how='VISFIX',confidence=0.9
  x=fx;y=fy
  if datatype(fheading,'N') then heading=fheading
  sure=confidence;source=how;reportTick=tick
  self~markSearched(tick)
  return .true

::method headingFix
  /* v0.93: an absolute heading from a sky body (Sun or Moon) seen in the
     pilot's own camera against the ephemeris; position is not touched. */
  expose heading source reportTick
  use strict arg tick,fheading,how='SUN_HEADING'
  heading=fheading//360;if heading<0 then heading+=360
  source=how;reportTick=tick
  return .true

::method markSearched private
  expose x y cells cell idRange crop
  use strict arg tick
  numeric digits 16
  r=idRange
  c0=trunc((x-r-crop[1])/cell);c1=trunc((x+r-crop[1])/cell)
  r0=trunc((y-r-crop[3])/cell);r1=trunc((y+r-crop[3])/cell)
  nc=trunc((crop[2]-crop[1])/cell);nr=trunc((crop[4]-crop[3])/cell)
  do cc=max(0,c0) to min(nc-1,c1)
    do rr=max(0,r0) to min(nr-1,r1)
      cx=crop[1]+(cc+0.5)*cell;cy=crop[3]+(rr+0.5)*cell
      if (cx-x)**2+(cy-y)**2>r*r then iterate
      k=cc'.'rr
      if \cells~hasIndex(k) then cells[k]=tick
    end
  end

::method coverage
  /* Fraction of the map's 50 m cells this pilot believes it has searched. */
  expose cells cell crop
  total=trunc((crop[2]-crop[1])/cell)*trunc((crop[4]-crop[3])/cell)
  if total=0 then return 0
  return cells~items/total

::method sectors
  /* 3 columns x 5 rows of the map (A..C, 1..5 from the top-left), with the
     percent of each this pilot believes it has searched. */
  expose cells cell crop
  numeric digits 16
  nc=trunc((crop[2]-crop[1])/cell);nr=trunc((crop[4]-crop[3])/cell)
  out=.array~new
  do sr=0 to 4
    do sc=0 to 2
      c0=trunc(sc*nc/3);c1=trunc((sc+1)*nc/3)-1
      /* rows count from the TOP of the map (north) */
      r1=nr-1-trunc(sr*nr/5);r0=nr-trunc((sr+1)*nr/5)
      n=0;seen=0
      do cc=c0 to c1;do rr=r0 to r1;n+=1;if cells~hasIndex(cc'.'rr) then seen+=1;end;end
      d=.directory~new
      d['NAME']='ABC'~substr(sc+1,1)||(sr+1)
      d['PCT']=0;if n>0 then d['PCT']=trunc(100*seen/n)
      d['PX0']=trunc(c0*cell*crop[5]);d['PX1']=trunc((c1+1)*cell*crop[5])
      d['PY0']=trunc((nr-1-r1)*cell*crop[5]);d['PY1']=trunc((nr-r0)*cell*crop[5])
      d['CX']=crop[1]+(c0+c1+1)/2*cell;d['CY']=crop[3]+(r0+r1+1)/2*cell
      out~append(d)
    end
  end
  return out

::method sectorText
  /* What the LLM is shown: its OWN searched-space record. */
  t='Searched space (from YOUR OWN position reports and turns; your belief, not truth), percent of each map sector'||,
    ' that has been within 500 m of where you believed you were:'
  do d over self~sectors
    t=t d['NAME']'(x'd['PX0']'-'d['PX1']',y'd['PY0']'-'d['PY1']')='d['PCT']'%'
  end
  return t

::method leastSearched
  /* Centre (x,y) of the least-searched sector, nearest first on ties. */
  expose x y
  numeric digits 16
  best=.nil
  do d over self~sectors
    dist=(d['CX']-x)**2+(d['CY']-y)**2
    if best==.nil then do;best=d;bd=dist;iterate;end
    if d['PCT']<best['PCT'] | (d['PCT']=best['PCT'] & dist<bd) then do;best=d;bd=dist;end
  end
  return .array~of(best['CX'],best['CY'],best['PCT'],best['NAME'])

::method sight
  /* Write a target sighting into the book: world x,y believed. */
  expose book
  use strict arg tick,target,bx,by,via
  if \datatype(target,'W') | \datatype(bx,'N') | \datatype(by,'N') then return .false
  if target<1 | target>5 then return .false
  d=.directory~new;d['TICK']=tick;d['X']=bx;d['Y']=by;d['VIA']=via
  book[target]=d
  return .true

::method sightPixel
  /* LLM: a sighting reported as a map pixel. */
  expose crop
  use strict arg tick,target,px,py,via
  if \datatype(px,'N') | \datatype(py,'N') then return .false
  return self~sight(tick,target,crop[1]+px/crop[5],crop[4]-py/crop[5],via)

::method sightBearing
  /* SLAM: bearing off the nose (deg) and range (m) from the believed pose. */
  expose x y heading
  use strict arg tick,target,az,range,via
  numeric digits 16
  b=heading+az
  return self~sight(tick,target,x+range*RxCalcSin(b,16),y+range*RxCalcCos(b,16),via)

::method addRay
  /* SLAM, target too small to range: keep the bearing ray from the believed
     position; two rays >= 10 deg apart (within 60 s) cross at the target -
     triangulation, written to the book as SLAM_TRIANG. */
  expose x y heading rays
  use strict arg tick,target,az
  numeric digits 16
  b=(heading+az)//360;if b<0 then b+=360
  if \rays~hasIndex(target) then rays[target]=.array~new
  q=rays[target]
  /* drop rays older than 60 s */
  kept=.array~new;do r over q;if tick-r[4]<=60 then kept~append(r);end
  q=kept;rays[target]=q
  ray=.array~of(x,y,b,tick)
  done=.false
  do r over q
    d=abs(b-r[3])//360;if d>180 then d=360-d
    if d<10 | d>170 then iterate
    /* solve (x,y)+t1*u1 = (rx,ry)+t2*u2 */
    u1x=RxCalcSin(b,16);u1y=RxCalcCos(b,16);u2x=RxCalcSin(r[3],16);u2y=RxCalcCos(r[3],16)
    den=u1x*(-u2y)-u1y*(-u2x)
    if abs(den)<1e-9 then iterate
    ex=r[1]-x;ey=r[2]-y
    t1=(ex*(-u2y)-ey*(-u2x))/den
    t2=(u1x*ey-u1y*ex)/den
    if t1<=0 | t2<=0 | t1>1500 then iterate
    ignored=self~sight(tick,target,x+t1*u1x,y+t1*u1y,'SLAM_TRIANG')
    done=.true;leave
  end
  q~append(ray)
  return done

::method sighting
  /* The book's entry for a target (directory TICK X Y VIA) or .nil. */
  expose book
  use strict arg target
  if book~hasIndex(target) then return book[target]
  return .nil

::method forget
  expose book
  use strict arg target
  if book~hasIndex(target) then book~remove(target)
  return .true

::method bookText
  /* What the LLM reads back: its own flight book. */
  expose x y heading sure crop book
  numeric digits 16
  px=format((x-crop[1])*crop[5],,0);py=format((crop[4]-y)*crop[5],,0)
  t='FLIGHT BOOK (what you wrote or worked out; not truth): believed position map x='px 'y='py,
    'sure' format(sure,,2)', gyro heading' format(heading,,0)'deg (integrated from your own turns; it drifts).'
  if book~items>0 then do
    t=t 'Target sightings:'
    do k over book~allIndexes~sort
      d=book[k]
      t=t 'T'k 'at x='format((d['X']-crop[1])*crop[5],,0) 'y='format((crop[4]-d['Y'])*crop[5],,0) '(t'd['TICK'] d['VIA']');'
    end
  end
  return t||'0a'x||self~sectorText

::method logSighting
  /* ORACLE side: each book entry vs the target's true position now. */
  expose book
  use strict arg file,tick,targets,claimed
  numeric digits 16
  if stream(file,'C','QUERY EXISTS')=='' then call lineout file,'tick,target,written_tick,via,bel_x,bel_y,true_x,true_y,error_m'
  do k over book~allIndexes~sort
    if claimed~hasIndex(k) then iterate
    d=book[k];t=targets[k]
    e=HSqrt((d['X']-t[1])**2+(d['Y']-t[2])**2)
    call lineout file,tick','k','d['TICK']','d['VIA']','format(d['X'],,1)','format(d['Y'],,1)','format(t[1],,1)','format(t[2],,1)','format(e,,1)
  end
  call stream file,'C','CLOSE'
  return .true

::method logError
  /* ORACLE side, after the decision: belief vs truth for scoring only.
     "Correct" is encouraged by scoring both accuracy and honest sureness. */
  expose x y sure source errSum errN within50 brier
  use strict arg file,tick,truth
  numeric digits 16
  e=HSqrt((x-truth[1])**2+(y-truth[2])**2)
  errSum+=e;errN+=1
  hit=(e<=50);within50+=hit
  brier+=(sure-hit)**2
  if stream(file,'C','QUERY EXISTS')=='' then call lineout file,'tick,source,bel_x,bel_y,bel_heading,sure,true_x,true_y,true_heading,error_m,coverage'
  call lineout file,tick','source','format(x,,2)','format(y,,2)','format(self~heading,,1)','format(sure,,2)','format(truth[1],,2)','format(truth[2],,2)','format(truth[4],,1)','format(e,,2)','format(self~coverage,,4)
  call stream file,'C','CLOSE'
  return e

::method summary
  expose errSum errN within50 brier reports
  if errN=0 then return 'no samples'
  return 'mean_error_m' format(errSum/errN,,1) 'within_50m' format(100*within50/errN,,1)'%' 'brier' format(brier/errN,,3) 'reports' reports 'coverage' format(100*self~coverage,,1)'%'

::routine HSqrt
  use strict arg v
  numeric digits 16
  if v<=0 then return 0
  return RxCalcSqrt(v,16)
