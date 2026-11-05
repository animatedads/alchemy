/* Native geometry and scenario regression: oracle-only course data. */
numeric digits 16
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
count=0
w=.Slam450World~new(45042,'LOOP')
call check w~targets~items=5,'five targets'
/* v0.92: Power SLAM v0.41's bridge arch (86 opt-in solids, ARCH_/HANGER_)
   is applied on top of the v0.40 set, so 125 base + 86 arch = 211. */
base=0;arch=0
do bx over w~scene~boxes
  n=bx[1]~upper
  if n~left(5)=='ARCH_' | n~left(7)=='HANGER_' then arch+=1;else base+=1
end
call check base=125,'Git v0.40 approach has 125 solids (v0.40 base)'
call check arch=86,'v0.41 arch adds 86 solids'
/* At least one turn bends through more than 60 degrees. */
sharp=.false
do i=2 to 4
 a=w~targets[i-1];b=w~targets[i];c=w~targets[i+1]
 dx1=b[1]-a[1];dy1=b[2]-a[2]
 dx2=c[1]-b[1];dy2=c[2]-b[2]
 dot=(dx1*dx2+dy1*dy2)/(HSqrt(dx1*dx1+dy1*dy1)*HSqrt(dx2*dx2+dy2*dy2))
 if dot<0.5 then sharp=.true
end
call check sharp,'route contains a real reversal or bend'
call check w~courseAreas[1]=='QUAY' & w~courseAreas[5]=='QUAY','revisit quay'
call check w~courseAreas[2]=='BRIDGE' & w~courseAreas[3]=='OPERA' & w~courseAreas[4]=='BLUES','specified sequence'
do i=1 to 5
 t=w~targets[i]
 call check t[3]>=10 & t[3]<=150,'altitude band'
 call check w~safePoint(t,3),'model-clear target'
end
call check w~distance(w~targets[1],w~targets[5])<140,'revisit region'
w2=.Slam450World~new(45042,'LOOP')
do i=1 to 5
 call check w~distance(w~targets[i],w2~targets[i])<0.00001,'seeded repeatability'
end
a=.Slam450World~new(45043,'WIDE')
b=.Slam450World~new(45044,'WIDE')
call check a~courseAreas[5]==a~courseAreas[1],'WIDE revisits start area'
call check b~courseAreas[5]==b~courseAreas[1],'WIDE revisits start area'
call check a~targets~items=5 & b~targets~items=5,'wide generated'
call check a~courseAreas[1]\==a~courseAreas[2],'distinct sectors'
call check a~courseAreas[2]\==a~courseAreas[3],'distinct sectors follow'
call check a~distance(a~targets[1],b~targets[1])>1,'different seeds different routes'
say 'SLAM450 COURSE PASS' count 'checks'
exit 0
check:
 parse arg ok,desc
 if \ok then do;say 'FAIL' desc;exit 7;end
 count+=1
return
::requires 'Slam450Flight.cls'
