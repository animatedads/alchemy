/* Native ooRexx geometry qualification: stand-alone orientation test vectors.
 * The production fromYawDegrees path explicitly delegates to canonical Maths.
 */
numeric digits 30
checks=0
call assertEqual .ApronOrientation~new(0,0,1)~cosine,1,'zero yaw'
car=.ApronCarBox~new(.ApronOrientation~new(0,0,1))
cam=.ApronCamera~new(1920,1080,1200,1200,1.5)
c=car~plateCentreAt(0,12,10,0)
call assertNear c[1],0,'1E-15','start x'
call assertNear c[2],12,'1E-15','start y'
call assertNear c[3],.55,'1E-15','plate height'
call assertNear car~plateCornersAt(c)[1][1],-.26,'1E-15','plate width at yaw0'
p=cam~project(0,12,.55)
call assertNear p[1],960,'1E-10','optical centre X'
call assertNear p[2],635,'1E-10','projection 3D Y'
drive=.ApronDriveBy~new(cam,car,0,12,36,25,10000)
call assertEqual drive~speed,10,'km/h to m/s'
q=drive~exposureSample(1,4,9)
call assertEqual q~items,4,'quad length'
call assertNear q[1][1],957.413793103448275862068965517,'1E-9','glyph projection x'
v=drive~blurVector(1)
call assertNear v[1],0,'1E-10','approaching directly gives zero centre X blur'
call assertNear v[2],0.8475,'.1','approach enlarges plate and moves centre vertically'
flat=.ApronDriveBy~new(cam,car,0,12,0,25,10000)
f=flat~blurVector(1)
call assertNear f[1],0,'1E-20','stationary horizontal blur zero'
call assertNear f[2],0,'1E-20','stationary vertical blur zero'
oblique=.ApronCarBox~new(.ApronOrientation~new(30,.5,'0.86602540378443864676372317075294'))
dr2=.ApronDriveBy~new(cam,oblique,-1,12,72,25,10000)
vv=dr2~blurVector(1)
call assertTrue abs(vv[1])>5,'72kmh oblique has significant motion blur'
call assertTrue car~bodyCornersAt(c)~items=8,'car has 8 box corners'
call assertEqual car~glyphCornersAt(c,.010)~items,4,'narrow glyph 1 can be modelled'
call assertTrue .ApronDriveBy~new(cam,car,0,12,36,25,1000)~exposureUs< -
   .ApronDriveBy~new(cam,car,0,12,36,25,10000)~exposureUs,'independent shutter durations'
say 'PASS' checks 'Apron SLAM 3D geometry checks'
exit 0
assertEqual: procedure expose checks
 use strict arg actual,expected,why
 if actual<>expected then do; say 'FAIL' why 'got' actual 'wanted' expected; exit 1; end
 checks=checks+1
 return
assertNear: procedure expose checks
 use strict arg actual,expected,tolerance,why
 if abs(actual-expected)>tolerance then do; say 'FAIL' why 'got' actual 'wanted' expected; exit 1; end
 checks=checks+1
 return
assertTrue: procedure expose checks
 use strict arg condition,why
 if \condition then do; say 'FAIL' why; exit 1; end
 checks=checks+1
 return
::requires '../src/ApronGeometry.cls'