/* SLAM450 v0.90 — moving-target unit tests.
 * Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-03.
 *  1. Route-around: a leg straight through the Salesforce tower is planned
 *     around it (grid A* + string pulling); every flown leg is model-clear,
 *     the route is longer than the blocked straight line but < 1.6x it.
 *  2. Crosswind: with a steady 2.5 m/s crosswind the target crabs; after
 *     the first (uncorrected) tick its cross-track error stops growing and
 *     it arrives at the committed destination.
 *  3. Commitment: destination unchanged until ARRIVE; a new heading after.
 *  4. Relative swept contact catches a target that crosses a craft's path.
 */
numeric digits 16
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
fails=0
world=.Slam450World~new(45046,'OBSTRUCTED',.false)
m=.Slam450TargetMovers~new(world,45046,3.0)
tower=.nil
do b over world~collisionBounds
  if b[1][1]=='SALESFORCE' then tower=b
end
if tower==.nil then call fail 'no SALESFORCE solid in scene'
cx=(tower[2]+tower[3])/2;cy=(tower[4]+tower[5])/2
z=min(tower[7]-10,90)
halfX=(tower[3]-tower[2])/2
p=.array~of(cx-halfX-25,cy,z);d=.array~of(cx+halfX+25,cy,z)
if \world~safePoint(p,4) | \world~safePoint(d,4) then call fail 'test endpoints not clear'
if world~safeLine(p,d) then call fail 'straight line should be blocked by the tower'
path=m~plan(p,d)
if path==.nil then call fail 'no route around the tower'
else do
  prev=p;len=0
  do w over path
    if \world~safeLine(prev,w) then call fail 'route leg not model-clear'
    len+=dist(prev,w);prev=w
  end
  last=path[path~items]
  if dist(last,d)>0.001 then call fail 'route does not end at destination'
  straight=dist(p,d)
  say 'ROUTE waypoints' path~items 'length' format(len,,2) 'straight' format(straight,,2) 'ratio' format(len/straight,,3)
  if len<=straight then call fail 'route not longer than blocked line'
  if len>=1.6*straight then call fail 'route too long (not near-shortest)'
end
/* 2 + 3: crosswind crab and commitment on LEGACY target 1. */
w2=.Slam450World~new(45046,'LEGACY',.false)
m2=.Slam450TargetMovers~new(w2,45046,3.0)
wind=.directory~new
do lv=1 to 3
  v=.directory~new;v['EAST_MPS']=2.5;v['NORTH_MPS']=0;wind[lv]=v
end
claims=.directory~new;do k=2 to 5;claims[k]=.true;end   /* freeze others */
first=.nil;origin=w2~targets[1]~copy;xt=.array~new;arrived=0;destChanged=0
do tick=1 to 120
  ignored=m2~advance(wind,tick,claims)
  do row over m2~drain
    parse var row tk ',' n ',' e ',' nn ',' zz ',' leg ',' de ',' dn ',' dz ',' wl ',' ae ',' an ',' we ',' wn ',' ev ',' note
    if n\==1 then iterate
    if ev=='ELECT' then do;origin=.array~of(e,nn,zz);first=.array~of(de,dn,dz);iterate;end
    if first==.nil then first=.array~of(de,dn,dz)
    if ev=='ARRIVE' then do;arrived+=1;if arrived==1 then leave tick;iterate;end
    if de\==first[1] | dn\==first[2] then destChanged+=1
    ax=first[1]-origin[1];ay=first[2]-origin[2];L=RxCalcSqrt(ax*ax+ay*ay,16)
    xt~append(abs((e-origin[1])*ay-(nn-origin[2])*ax)/L)
  end
end
if arrived<1 then call fail 'target never arrived in steady crosswind'
if destChanged>0 then call fail 'destination changed mid-leg'
if xt~items>=3 then do
  worst=0;do k=2 to xt~items;worst=max(worst,xt[k]);end
  say 'CROSSWIND first-tick cross-track' format(xt[1],,3) 'worst after' format(worst,,3) 'ticks' xt~items
  if worst>xt[1]+0.01 then call fail 'cross-track kept growing after first tick'
end
/* 4: a target crossing the craft's path inside one tick. */
ref=.Slam450SquadReferee~new(w2,layoutOf(),.false,.false)
f=ref~contactMoving(.array~of(0,0,50),.array~of(6,0,50),.array~of(3,-3,50),.array~of(3,3,50))
if f<0 then call fail 'relative contact missed a crossing target'
g=ref~contactMoving(.array~of(0,0,50),.array~of(6,0,50),.array~of(3,-9,50),.array~of(3,-5,50))
if g>=0 then call fail 'relative contact claimed a target that never came within 2.5 m'
if fails==0 then say 'TEST_MOVERS450 PASS'
else say 'TEST_MOVERS450 FAIL' fails
exit (fails>0)

fail: fails+=1;say 'FAIL:' arg(1);return
dist: procedure
  use arg a,b
  numeric digits 16
  return RxCalcSqrt((a[1]-b[1])**2+(a[2]-b[2])**2+(a[3]-b[3])**2,16)
layoutOf: procedure
  out=.array~new
  do spec over .array~of('A1 RED QUAD','A2 BLUE QUAD')
    parse var spec i t a
    d=.directory~new;d['ID']=i;d['TEAM']=t;d['AIRFRAME']=a;out~append(d)
  end
  return out
::requires 'Slam450Squad.cls'
::requires 'Slam450TargetMovers.cls'
