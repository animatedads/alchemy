/* SLAM450 v0.92 flight book + identification range.
 * Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-04.
 * 1. Identification range (SLAM450.ID_RANGE=500): a target 400 m away is
 *    drawn at least 3x3 px; 600 m away exactly 1 px; 900 m away not at all;
 *    with range 0 (legacy) the 900 m target is still drawn.
 * 2. Belief: dead reckoning follows the pilot's own commands; a map-pixel
 *    report converts to the same world point the GPS would give; coverage
 *    grows from believed (not true) positions; sightings round-trip. */
numeric digits 16
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
fails=0
w=.Slam450World~new(45046,'LEGACY')
cam=.Slam450Camera~new(w)
t1=w~targets[1]
do spec over .array~of('400 9','600 1','900 0')
  parse var spec dist want
  .local['SLAM450.ID_RANGE']=500
  pose=.array~of(t1[1],t1[2]-dist,t1[3],0)
  f=cam~renderAt(pose,960,242)
  n=0;do r over f['PIXELS'];n+=r~countStr('1');end
  if want=9 then do;if n<9 then call fail 'target at' dist 'm should be >= 9 px, got' n;end
  else if n\=want then call fail 'target at' dist 'm should be' want 'px, got' n
end
.local['SLAM450.ID_RANGE']=0
f=cam~renderAt(.array~of(t1[1],t1[2]-900,t1[3],0),960,242)
n=0;do r over f['PIXELS'];n+=r~countStr('1');end
if n<9 then call fail 'legacy (range 0) must still draw the 900 m target, got' n
/* belief */
crop=.array~of(-700,320,-1190,440,0.75)
b=.Slam450Belief~new(.array~of(0,0,30,90),crop,500,50)
do 10;ignored=b~deadReckon(1,.array~of(0,7,0,0));end
if abs(b~x-70)>1e-6 | abs(b~y)>1e-6 then call fail 'DR east 10 s at 7 m/s should be (70,0), got' b~x b~y
ignored=b~deadReckon(11,.array~of(90,5,0,0))
if abs(b~heading-180)>1e-9 | abs(b~y+5)>1e-6 then call fail 'turn right 90 then 5 m south failed' b~heading b~y
px=(100-crop[1])*crop[5];py=(crop[4]-(-300))*crop[5]
ignored=b~report(12,px,py,0.4)
if abs(b~x-100)>1e-6 | abs(b~y+300)>1e-6 | b~sure\=0.4 | b~source\=='REPORT' then call fail 'pixel report should map to (100,-300) sure 0.4'
c=b~coverage
if c<=0 | c>1 then call fail 'coverage out of range' c
ignored=b~sightPixel(12,3,px,py,'OWN_VIEW')
if b~bookText~pos('T3 at x='format(px,,0))=0 then call fail 'sighting not in book text'
ls=b~leastSearched
if ls[3]>=100 then call fail 'least-searched sector should not be full'
if b~sectors~items\=15 then call fail 'expected 15 sectors'
/* triangulation: target at (100,100); rays from (0,0) and (100,0) */
tb=.Slam450Belief~new(.array~of(0,0,30,0),crop,500,50)
ignored=tb~addRay(1,4,45)
ignored=tb~deadReckon(2,.array~of(90,100,0,0))
ignored=tb~deadReckon(3,.array~of(-90,0,0,0))
got=tb~addRay(3,4,0)
sg=tb~sighting(4)
if \got | sg==.nil then call fail 'two rays 45 deg apart must triangulate'
else if abs(sg['X']-100)>1e-6 | abs(sg['Y']-100)>1e-6 | sg['VIA']\=='SLAM_TRIANG' then call fail 'triangulated target should be (100,100), got' sg['X'] sg['Y']
if tb~forget(4)\==.true | tb~sighting(4)\==.nil then call fail 'forget must remove the entry and return .true'
/* LLM pilot camera-choice plumbing returns results (v0.92 runner calls them as functions) */
lp=.Slam450LlmPilot~new('A4','H1','RED','RED','STANDIN','EYES')
if lp~noteView('BLUES_PT')\==.true then call fail 'noteView must return .true'
if lp~takeView\=='' then call fail 'takeView with no choice must return empty'
if lp~attachBook(b)\==.true then call fail 'attachBook must return .true'
if fails==0 then say 'TEST_FLIGHTBOOK_V092 PASS'
else say 'TEST_FLIGHTBOOK_V092 FAIL' fails
exit (fails>0)
fail: fails+=1;say 'FAIL:' arg(1);return
::requires 'Slam450Flight.cls'
::requires 'Slam450Belief.cls'
::requires 'Slam450LlmPilot.cls'
