/* Control-only regression: no world pose or oracle target is supplied to
 * the visual pilot. Hidden square stays hidden in the synthetic test frame. */
numeric digits 16
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
w=.Slam450World~new(46051,'OBSTRUCTED')
t=w~targets[1]
c=.Slam450Camera~new(w)
frame=c~renderAt(.array~of(t[1],t[2],t[3],90),360,91)
if (.Slam450Vision~new)~observe(frame,2)\==.nil then do; say 'FAIL square unexpectedly visible'; exit 7;end
p=.Slam450LearningPilot~new
commands=.directory~new
do step=1 to 140
  command=p~control(frame,2)
  if step=1 | step=30 | step=31 | step=90 | step=91 | step=94 | step=95 | step=134 | step=135 then commands[step]=command
end
checks=0
call verify commands[1][2]==0,'first unseen image scans'
call verify commands[30][2]==0,'full panorama sweep before travel'
call verify commands[31][2]>2,'first long baseline displacement'
call verify commands[90][2]>2,'baseline persists without target'
call verify commands[91][1]<-10 & commands[91][2]==0,'sideways turnaround begins'
call verify commands[94][1]<-10,'sideways turnaround lasts four commands'
call verify commands[95][2]>2,'cross-track leg makes progress'
call verify commands[134][2]>2,'cross-track movement remains bounded'
call verify commands[135][1]>10,'return to original traverse direction'
call verify p~scanSteps==140,'controller maintains local search memory'
say 'SLAM450 EXPLORATION PASS' checks 'checks'
exit 0
verify:
 parse arg condition,explanation
 if \condition then do; say 'FAIL' explanation;exit 7;end
 checks+=1
return
::requires 'Slam450Learning.cls'
