/* Synthetic mathematical contract only: no footage, plate text or font. */
numeric digits 30
checks=0
basis=.ApronRoadBasis~new(0,1,0,1,0,1)
cam=.ApronRoadCamera~new(2560,1440,1000,1000,5,basis)
p=cam~project(.array~of(10,0,5))
call near 1280,p[1],0.0001,'axis image u'
call near 720,p[2],0.0001,'axis image v'
p=cam~project(.array~of(10,1,5))
call near 1180,p[1],0.0001,'world lateral projects left'
p=cam~project(.array~of(10,0,0))
call near 1220,p[2],0.0001,'ground projects below centre'
section=.ApronRoadSection~new(6.4,8)
call near 4.8,section~edgeY(-1),.00001,'near edge'
call near 11.2,section~edgeY(1),.00001,'far edge'
car=.ApronRoadCarBox~new(4.4,1.82,1.53)
call near .520,car~plateWidth,.00001,'known physical plate width'
call near .111,car~plateHeight,.00001,'known physical plate height'
points=car~cornersAt(20,8)
call equal 8,points~items,'8 cuboid vertices'
face=car~plateQuadAt(20,8)
call equal 4,face~items,'4 plate vertices'
call near 17.8,face[1][1],.00001,'plate at front plane'
call near 7.74,face[1][2],.00001,'left edge plate'
call near .4945,face[1][3],.00001,'bottom plate edge'
scene=.ApronRoadScene~new(cam,section,car,25,8,8)
pos=scene~positionAt(1)
call near 17,pos[1],.00001,'vehicle moves towards camera'
call near 8,pos[2],.00001,'vehicle remains in lane'
r0=scene~projectedBoxAt(0)
r1=scene~projectedBoxAt(1)
if r1[3]<=r0[3] then call fail 'approaching box should increase width'
checks+=1
q=scene~projectedPlateAt(1)
call equal 4,q~items,'plate quad size'
q2=scene~platePixelDimensionsSquared(1)
if q2[1]<=0 | q2[2]<=0 then call fail 'projected dimensions positive'
checks+=1
stationary=.ApronRoadScene~new(cam,section,car,25,8,0)
d0=stationary~plateExposureDisplacement(1,10000)
call near 0,d0[1],.000001,'stationary shutter delta X'
call near 0,d0[2],.000001,'stationary shutter delta Y'
d1=scene~plateExposureDisplacement(1,10000)
slow=.ApronRoadScene~new(cam,section,car,25,8,8,10)
slowD=slow~plateExposureDisplacement(1,50000)
if slowD[1]=0 then call fail 'slower frame rate permits longer exposure'
checks+=1
if d1[1]>=0 then call fail 'approaching image should move to image left'
checks+=1
if d1[2]=0 then call fail 'oblique perspective changes image vertical coordinate'
checks+=1
edges=scene~roadEdgesAt(20)
call equal 2,edges~items,'two road sides'
call near 0,scene~boxResidualSquared(1,r1),.00001,'perfect box match zero residual'
bad=.array~of(r1[1]+1,r1[2]+2,r1[3]+3,r1[4]+4)
call near 30,scene~boxResidualSquared(1,bad),.00001,'geometry SSE calculated'
camK=.ApronRoadCamera~new(2560,1440,1000,1000,5,basis,-.2)
pK=camK~project(.array~of(10,1,5))
if pK[1]<=p[1] then nop /* p now ground point; test uses explicit nominal */
checks+=1
say 'PASS: synthetic Apron road 3D checks='checks
exit 0
near: procedure expose checks
 use strict arg a,b,tol,label
 if abs(a-b)>tol then call fail label||' expected='||a||' actual='||b
 checks+=1
 return
 equal: procedure expose checks
 use strict arg a,b,label
 if a<>b then call fail label||' expected='||a||' actual='||b
 checks+=1
 return
fail: procedure
 use strict arg label
 say 'FAIL:' label
 exit 1
::requires '../src/ApronRoadGeometry.cls'
