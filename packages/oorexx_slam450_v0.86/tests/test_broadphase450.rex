numeric digits 16
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
w=.Slam450World~new(45042,'LOOP')
checks=0
/* Compare broad-phase against existing exact firstHit (presence, not name).
 * Different short and long rays exercise rotated station, bridge and wharves. */
do i=1 to 5
 a=w~targets[i]
 do j=1 to 5
  b=w~targets[j]
  fast=w~fastCollision(a,b)
  slow=.HarbourRayOcclusion~firstHit(w~scene,a,b)
  if (fast=='')\==(slow=='') then do
   say 'FAIL ray' i j 'fast' fast 'original' slow;exit 8
  end
  checks+=1
 end
end
a=w~pose
b=.array~of(-750,-900,90)
do i=1 to 30
  b[1]+=27;b[2]+=17;b[3]=15+(i//9)*15
  fast=w~fastCollision(a,b)
  slow=.HarbourRayOcclusion~firstHit(w~scene,a,b)
  if (fast=='')\==(slow=='') then do
    say 'FAIL sweep' i 'fast' fast 'original' slow;exit 8
  end
  checks+=1
end
say 'SLAM450 BROADPHASE PASS' checks 'paired exact checks'
exit 0
::requires 'Slam450Flight.cls'
