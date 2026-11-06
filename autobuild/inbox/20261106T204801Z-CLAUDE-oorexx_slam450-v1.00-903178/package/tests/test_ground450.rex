/* SLAM450 v0.91 — real-ground test. Architecture: Tom Dyer. Written by: Claude (Opus 5.5).
 * Loads Power SLAM v0.40 heights + water words through the estate classes,
 * checks the verified affine fast path, known places, fail-closed X/outside,
 * exact segment clearance and that the race start and LEGACY/QUAYSIDE
 * starts are clear of the ground. */
numeric digits 16
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
fails=0
dir=value('SLAM450_HARBOUR_WORDS',,'ENVIRONMENT')
t0=time('E')
g=.Slam450Ground~new(dir,.array~of(-1500,1500,-2000,1000))
say 'GROUND loaded' format(time('E')-t0,,2)'s residual' format(g~maxResidual,,4)'m checked' g~checkedPoints 'excluded' g~excludedPoints
if g~maxResidual>=1 then call fail 'affine residual'
if g~checkedPoints<350 then call fail 'too few verified points'
/* Scene (0,0) is the reference -33.852, 151.210, on the harbour near the bridge. */
c=g~cellAt(0,0);say 'ORIGIN role' c['ROLE'] 'top' c['TOP_M']
if c['ROLE']\=='W' then call fail 'scene origin should be harbour water'
/* Observatory Hill (-33.8597,151.2045): y=(-33.8597+33.852)*111200, x=(151.2045-151.21)*92300 */
x=(151.2045-151.210)*92300;y=(-33.8597+33.852)*111200
c=g~cellAt(x,y);say 'OBSERVATORY HILL role' c['ROLE'] 'height' c['HEIGHT_M']
if c['ROLE']\=='L' | c['HEIGHT_M']<30 then call fail 'Observatory Hill should be high land'
/* Fort Denison (-33.8548,151.2256): low but classified land (DEM alone would call it water). */
x=(151.2256-151.210)*92300;y=(-33.8548+33.852)*111200
c=g~cellAt(x,y);say 'FORT DENISON role' c['ROLE'] 'height' c['HEIGHT_M']
if c['ROLE']\=='L' then call fail 'Fort Denison should be land'
/* Far outside the grid fails closed. */
if g~surface(60000,60000)<1e8 then call fail 'outside grid must be no-fly'
/* Exact segment test: a low line from water onto Observatory Hill is blocked,
   the same line high above it is clear. */
a=.array~of(0,0,20);b=.array~of((151.2045-151.210)*92300,(-33.8597+33.852)*111200,20)
if g~segmentClear(a,b,0) then call fail 'low segment into Observatory Hill not blocked'
a[3]=200;b[3]=200
if \g~segmentClear(a,b,2) then call fail 'high segment over the hill blocked'
/* Starts clear of ground. */
if \g~pointClear(.array~of(270,-610,65),2) then call fail 'LEGACY start in ground'
if \g~pointClear(.array~of(250,-880,30),2) then call fail 'QUAYSIDE start in ground'
r=g~rasterLocal
if r['HEIGHTS']~items\=r['COLUMNS']*r['ROWS'] then call fail 'raster size'
if fails==0 then say 'TEST_GROUND450 PASS'
else say 'TEST_GROUND450 FAIL' fails
exit (fails>0)
fail: fails+=1;say 'FAIL:' arg(1);return
::requires 'Slam450Ground.cls'
