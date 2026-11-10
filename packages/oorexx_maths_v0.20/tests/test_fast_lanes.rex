/* Maths v0.20: hot-loop lanes, PURE reference. Claude (Opus 5.5). */
numeric digits 20
n=0
lane=.MathBinary64ScalarLane~new
call check abs(lane~sqrt(2)-1.414213562373095)<1e-15,'lane sqrt binary64-equivalent'
call check abs(lane~atan2(1,-1)-3*lane~pi/4)<1e-15,'lane atan2 second quadrant'
call check abs(lane~asin(0.5)-lane~pi/6)<1e-15,'lane asin'
call check abs(lane~degrees(lane~pi)-180)<1e-12,'lane degrees'
call check lane~counts['SQRT']==1 & lane~counts['ATAN2']==1,'lane counts every call'
ev=lane~evidence
call check ev~steps[1]~provider=='RXMATH','lane summary evidence names provider'
signal on syntax name asinOk
x=lane~asin(1.5); call check .false,'asin outside domain fails closed'
asinOk: signal off syntax
n+=1
/* Projector: a point due north, straight ahead, horizon -> centre column. */
g=.array~of(.array~of(.array~of(0,100,0)))
p=.MathPanoramaProjector~new(g,'PURE',9)
e=p~extents(.array~of(0,0,0,0),480,121)
call check e[1][1]==241 & e[1][2]==241,'north ahead projects to centre column'
call check e[1][3]==61 & e[1][4]==61,'horizon projects to middle row'
/* Behind the camera wraps to the edges; a straddling box is wrap-aware. */
behind=.array~of(.array~of(.array~of(-1,-100,0),.array~of(1,-100,0)))
q=.MathPanoramaProjector~new(behind,'PURE',9)~extents(.array~of(0,0,0,0),480,121)
call check q[1]\==.nil,'straddling-the-seam group is visible'
call check q[1][2]-q[1][1]<=2,'seam group stays narrow, not full width'
/* Lane names fail closed. */
signal on syntax name laneOk
x=.MathPanoramaProjector~new(g,'GPU'); call check .false,'unknown lane rejected'
laneOk: signal off syntax
n+=1
say 'PASS oorexx_maths fast lanes PURE' n 'assertions'
exit 0
check:
  parse arg ok,what
  if \ok then do; say 'FAIL' what; exit 1; end
  n+=1; return
::requires 'MathFastLanes.cls'
