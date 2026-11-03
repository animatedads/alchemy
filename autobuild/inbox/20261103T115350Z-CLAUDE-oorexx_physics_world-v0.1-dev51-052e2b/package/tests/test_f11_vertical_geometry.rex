numeric digits 20
floorZ=3.0
height=2.2
ceilingZ=floorZ+height
micZ=4.8
roadZ=0.0
vehicleSourceZ=0.5
vehicleTopZ=1.5
call near ceilingZ,5.2,0.0000001,'ceiling z'
call near micZ-floorZ,1.8,0.0000001,'mic above floor'
call near ceilingZ-micZ,0.4,0.0000001,'mic below ceiling'
call near micZ-vehicleSourceZ,4.3,0.0000001,'vehicle source vertical separation'
call near micZ-vehicleTopZ,3.3,0.0000001,'vehicle roof vertical separation'
say 'PASS F11 vertical geometry'
exit 0
near: procedure; parse arg a,b,t,msg;if abs(a-b)>t then do;say 'FAIL' msg a b;exit 1;end;return
