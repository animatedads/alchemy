/* SLAM450 v0.90 — slow-moving committed targets.
 * Architecture: Tom Dyer. Implementation: Claude (Opus 5.5), 2026-11-03.
 *
 * Each of the five targets behaves as a slow, single-minded aircraft:
 *   1. ELECT   a heading, a destination point on that heading (50-130 m)
 *              and a flight level within a 1-in-2 climb gradient, inside
 *              the course box. It commits to that destination.
 *   2. PLAN    the shortest route around buildings, land and sea: straight
 *              line if it is model-clear, otherwise grid A* (10 m cells at
 *              the destination flight level) followed by line-of-sight
 *              string pulling. Exact shortest paths around oriented
 *              cuboids need the obstacle silhouette (a visibility graph at
 *              every flight level); grid A* + string pulling is the
 *              standard near-optimal any-angle method and stays within a
 *              few per cent of it at 10 m resolution.
 *   3. FLY     every tick: re-aim at the current waypoint from its exact
 *              position (accurate spatial awareness), crab against the
 *              drift it MEASURED over the previous tick (it cannot know the
 *              coming gust), climb/descend to stay on the planned 3-D line.
 *              The full wind moves it (a point mass in an air mass), so
 *              every gust change shows up as a course correction.
 *   4. ARRIVE  within 2 m of the destination, then elect a new one.
 * It never deviates for, or even looks at, any aircraft or other target.
 * Each target has its own random stream, so its path is the same in every
 * run with the same seed until the tick it is claimed: the cross-run proof
 * that no target ever reacted to an aircraft (tests/audit_movers450.py).
 *
 * Simulator-private: nothing here is visible to any pilot or navigator.
 */
::class Slam450TargetMovers public
::attribute airspeed get
::attribute box get
::attribute legs get
::method init
  expose world states airspeed box pending legs climbLimit
  use strict arg scenario,baseSeed,speed=3.0
  numeric digits 16
  world=scenario;airspeed=speed;pending=.array~new;legs=0
  climbLimit=2.0
  /* Course box: the initial target spread plus 40 m, flight levels 15-140 m. */
  xlo=1e9;xhi=-1e9;ylo=1e9;yhi=-1e9
  do t over world~targets
    xlo=min(xlo,t[1]);xhi=max(xhi,t[1]);ylo=min(ylo,t[2]);yhi=max(yhi,t[2])
  end
  box=.array~of(xlo-40,xhi+40,ylo-40,yhi+40,15,140)
  states=.array~new
  do i=1 to world~targets~items
    s=.directory~new
    s['SEED']=(baseSeed*31+7919*i)//2147483647
    if s['SEED']<=0 then s['SEED']=s['SEED']+2147483646
    s['PATH']=.array~new;s['DEST']=.nil;s['LEG']=0
    s['DRIFT_E']=0;s['DRIFT_N']=0;s['HEADING']=0
    states[i]=s
    self~elect(i,0)
  end

::method random private
  expose states
  use strict arg i
  numeric digits 16
  s=states[i]
  s['SEED']=(s['SEED']*16807)//2147483647
  return s['SEED']/2147483647

::method elect private
  /* Choose and commit to a new destination for target i. */
  expose world states box pending legs
  use strict arg i,tick
  numeric digits 16
  t=world~targets;p=t[i];s=states[i];searches=0
  do tries=1 to 150
    hdg=360*self~random(i)
    dist=50+80*self~random(i)
    zD=p[3]+(2*self~random(i)-1)*0.5*dist
    zD=max(box[5],min(box[6],zD))
    dest=.array~of(p[1]+dist*RxCalcSin(hdg),p[2]+dist*RxCalcCos(hdg),zD)
    if dest[1]<box[1] | dest[1]>box[2] then iterate
    if dest[2]<box[3] | dest[2]>box[4] then iterate
    if \world~safePoint(dest,4) then iterate
    /* A* is the expensive part: allow it on at most 8 candidate legs per
     * election; after that only model-clear straight legs are accepted. */
    if \world~safeLine(p,dest) then do
      if searches>=8 then iterate
      searches+=1
    end
    path=self~plan(p,dest)
    if path==.nil then iterate
    s['DEST']=dest;s['PATH']=path;s['LEG']=s['LEG']+1;s['HEADING']=hdg
    legs+=1
    pending~append(self~row(tick,i,p,'ELECT',0,0,0,0,'heading='format(hdg,,1) 'tries='tries 'waypoints='path~items))
    return .true
  end
  s['DEST']=.nil;s['PATH']=.array~new
  pending~append(self~row(tick,i,p,'NO_LEG',0,0,0,0,'no safe destination in 150 tries'))
  return .false

::method plan
  /* Route from p to dest: array of 3-D waypoints ending at dest, or .nil. */
  expose world box
  use strict arg p,dest
  numeric digits 16
  if world~safeLine(p,dest) then return .array~of(dest)
  cell=10;zD=dest[3]
  open=.array~new;g=.directory~new;from=.directory~new;closed=.directory~new
  node=.directory~new
  startKey='S';node[startKey]=p;g[startKey]=0;open~append(startKey)
  goalKey='';expansions=0
  do while open~items>0 & expansions<1500
    /* Lowest f = g + straight-line distance to dest. */
    best=1;bestF=1e20
    do k=1 to open~items
      key=open[k];f=g[key]+self~dist(node[key],dest)
      if f<bestF then do;bestF=f;best=k;end
    end
    key=open[best];open~delete(best)
    if closed~hasIndex(key) then iterate
    closed[key]=.true;expansions+=1
    here=node[key]
    if self~dist(here,dest)<=3*cell then do
      if world~safeLine(here,dest) then do;goalKey=key;leave;end
    end
    if key=='S' then do;ci=0;cj=0;end
    else parse var key ci ',' cj
    do di=-1 to 1
      do dj=-1 to 1
        if di==0 & dj==0 then iterate
        ni=ci+di;nj=cj+dj;nk=ni','nj
        if closed~hasIndex(nk) then iterate
        q=.array~of(p[1]+ni*cell,p[2]+nj*cell,zD)
        if q[1]<box[1] | q[1]>box[2] then iterate
        if q[2]<box[3] | q[2]>box[4] then iterate
        if \node~hasIndex(nk) then do
          if \world~safePoint(q,4) then do;closed[nk]=.true;iterate;end
          node[nk]=q
        end
        if \world~safeLine(here,q) then iterate
        cost=g[key]+self~dist(here,q)
        if g~hasIndex(nk) then if g[nk]<=cost then iterate
        g[nk]=cost;from[nk]=key;open~append(nk)
      end
    end
  end
  if goalKey=='' then return .nil
  /* Reconstruct S..goal, then dest. */
  chain=.array~new;key=goalKey
  do while key\=='S';chain~append(node[key]);key=from[key];end
  raw=.array~of(p)
  do k=chain~items to 1 by -1;raw~append(chain[k]);end
  raw~append(dest)
  /* Line-of-sight string pulling: from each kept point jump to the
   * furthest later point it can see. */
  pulled=.array~of(p);i=1
  do while i<raw~items
    j=raw~items
    do while j>i+1
      if world~safeLine(raw[i],raw[j]) then leave
      j-=1
    end
    pulled~append(raw[j]);i=j
  end
  /* Altitude along the route: linear in route length from p[3] to zD, so
   * the climb gradient never exceeds the elected one; re-certify each leg. */
  total=0
  do k=2 to pulled~items;total+=self~dist(pulled[k-1],pulled[k]);end
  out=.array~new;run=0;prev=p
  do k=2 to pulled~items
    run+=self~dist(pulled[k-1],pulled[k])
    z=p[3]+(zD-p[3])*run/max(0.001,total)
    w=.array~of(pulled[k][1],pulled[k][2],z)
    if \world~safeLine(prev,w) then return .nil
    out~append(w);prev=w
  end
  return out

::method advance
  /* Move every unclaimed target one tick. winds: directory level -> wind
   * directory (EAST_MPS/NORTH_MPS) for THIS tick; claims: directory of
   * claimed target numbers. Updates world~targets in place. */
  expose world states airspeed pending climbLimit
  use strict arg winds,tick,claims
  numeric digits 16
  t=world~targets
  do i=1 to t~items
    if claims~hasIndex(i) then iterate
    s=states[i];p=t[i]
    if s['DEST']==.nil then do
      if \self~elect(i,tick) then iterate
    end
    wp=s['PATH'][1]
    event='FLY'
    if \world~safeLine(p,wp) then do
      /* Drift has taken the waypoint out of sight: re-route to the SAME
       * committed destination; only if that is impossible elect anew. */
      path=self~plan(p,s['DEST'])
      if path==.nil then do
        pending~append(self~row(tick,i,p,'FORCED_REELECT',0,0,0,0,'committed destination unreachable'))
        if \self~elect(i,tick) then iterate
      end
      else do
        s['PATH']=path
        pending~append(self~row(tick,i,p,'REPLAN',0,0,0,0,'waypoints='path~items))
      end
      wp=s['PATH'][1]
    end
    dx=wp[1]-p[1];dy=wp[2]-p[2];dz=wp[3]-p[3]
    dh=RxCalcSqrt(dx*dx+dy*dy,16)
    we=s['DRIFT_E'];wn=s['DRIFT_N']
    /* Air vector that lands exactly on the waypoint under the measured drift. */
    ae=dx-we;an=dy-wn
    if RxCalcSqrt(ae*ae+an*an,16)<=airspeed then do
      vz=max(0-climbLimit,min(climbLimit,dz))
      event='FINAL'
    end
    else do
      ux=dx/dh;uy=dy/dh
      uw=ux*we+uy*wn
      disc=uw*uw-(we*we+wn*wn)+airspeed*airspeed
      sg=-1
      if disc>=0 then sg=uw+RxCalcSqrt(disc,16)
      if sg>0 then do
        ae=sg*ux-we;an=sg*uy-wn
        vz=max(0-climbLimit,min(climbLimit,dz*sg/dh))
      end
      else do
        /* Wind beats airspeed on this track: point straight at the
         * waypoint for maximum headway and say so. */
        ae=airspeed*ux;an=airspeed*uy
        vz=max(0-climbLimit,min(climbLimit,dz*airspeed/dh))
        event='HELD_BY_WIND'
      end
    end
    /* The real air mass this tick. */
    wE=0;wN=0
    lv=self~levelAt(p[3])
    if winds~hasIndex(lv) then do;wE=winds[lv]['EAST_MPS'];wN=winds[lv]['NORTH_MPS'];end
    q=.array~of(p[1]+ae+wE,p[2]+an+wN,p[3]+vz)
    if \world~safeLine(p,q) | \world~safePoint(q,2) then do
      /* Never observed in testing; kept so a target can never enter a
       * solid: it holds and re-routes next tick. */
      q=p;event='SCENE_GUARD'
      s['DRIFT_E']=wE;s['DRIFT_N']=wN
      pending~append(self~row(tick,i,q,event,ae,an,wE,wN,''))
      iterate
    end
    /* Accurate spatial awareness: displacement minus own air vector is the
     * drift actually experienced; it is the estimate for the next tick. */
    s['DRIFT_E']=(q[1]-p[1])-ae;s['DRIFT_N']=(q[2]-p[2])-an
    t[i]=q
    if self~dist(q,wp)<=2 then do
      s['PATH']~delete(1)
      if s['PATH']~items==0 then do
        pending~append(self~row(tick,i,q,'ARRIVE',ae,an,wE,wN,''))
        s['DEST']=.nil
        ignored=self~elect(i,tick)
        iterate
      end
      event='WAYPOINT'
    end
    pending~append(self~row(tick,i,q,event,ae,an,wE,wN,''))
  end
  return t

::method levelAt private
  /* Same bands as Slam450WindField~levelAt. */
  use strict arg z
  if z<55 then return 1
  if z<105 then return 2
  return 3

::method row private
  expose states
  use strict arg tick,i,p,event,ae,an,wE,wN,note
  numeric digits 16
  s=states[i];d=s['DEST']
  de='';dn='';dz=''
  if d\==.nil then do;de=format(d[1],,3);dn=format(d[2],,3);dz=format(d[3],,3);end
  return tick','i','format(p[1],,4)','format(p[2],,4)','format(p[3],,4)','||,
    s['LEG']','de','dn','dz','s['PATH']~items','||,
    format(ae,,4)','format(an,,4)','format(wE,,4)','format(wN,,4)','event','note

::method header class
  return 'tick,target,east_m,north_m,z_m,leg,dest_east_m,dest_north_m,dest_z_m,waypoints_left,'||,
         'air_east_mps,air_north_mps,wind_east_mps,wind_north_mps,event,note'

::method drain
  expose pending
  out=pending;pending=.array~new
  return out

::method dist
  use strict arg a,b
  numeric digits 16
  return RxCalcSqrt((a[1]-b[1])**2+(a[2]-b[2])**2+(a[3]-b[3])**2,16)
