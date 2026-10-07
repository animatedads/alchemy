numeric digits 20
ctx=.Maths~defaultContext
world=.PhysicalWorld~new(.OpticalMedium~air,.AcousticMedium~air)
medium=world~ambientAcoustic
s=.AcousticVehicleNoiseSpectrum~new(78)
call assert s~validate,'78 dB spectrum recombines'
cs=s~components
call near cs[1]~sourceSplDb,'72.771212547196624',0.000001,'low level'
call near cs[2]~sourceSplDb,'75.78151250383644',0.000001,'mid level'
call near cs[3]~sourceSplDb,68,0.000001,'high level'
origin=.MathVector3~new(0,0,0,ctx);v=.MathVector3~new('11.111111111111111',0,0,ctx)
car=.AcousticMovingVehicle~new('car',origin,v,4,1.5,0.5)
call near car~centerAt('0.09')~x,1,0.000001,'1m in .09s'
call near car~timeAtX(6),'0.54',0.000001,'6m sample crossing time'
call near car~centerAt(car~timeAtX(6))~x,6,0.000001,'continuous sample crossing'
ext=car~centerExtentAt(car~timeAtX(6));call near ext['FRONT']~x,8,0.000001,'4m car front extent';call near ext['REAR']~x,4,0.000001,'4m car rear extent'
mic=.MathVector3~new(10,0,4.8,ctx);src=car~sourcePositionAt(0)
f=.AcousticDoppler~movingSourceObserved(1000,medium~soundSpeed,v,src,mic)
call assert f>1000,'approach raises pitch'
f2=.AcousticDoppler~movingSourceObserved(1000,medium~soundSpeed,v*(-1),src,mic)
call assert f2<1000,'recede lowers pitch'
zero=.MathVector3~new(0,10,0,ctx)
f3=.AcousticDoppler~movingSourceObserved(1000,medium~soundSpeed,v,origin,zero)
call near f3,1000,0.000001,'transverse no shift'
say 'PASS acoustic moving vehicle'
exit 0
assert: procedure; parse arg ok,msg;if \ok then do;say 'FAIL' msg;exit 1;end;return
near: procedure; parse arg a,b,t,msg;if abs(a-b)>t then do;say 'FAIL' msg a b;exit 1;end;return
::requires 'AcousticMovingVehicle.cls'
