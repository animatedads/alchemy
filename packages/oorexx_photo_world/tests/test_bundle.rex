numeric digits 20
ctx=.Maths~defaultContext
w=.SurveyWorld~new(ctx)
spec=.XCoverCameraSpecifications~byId('XCOVERPRO')
c=.SurveyCamera~new('C1',.nil,1.60,60,3000,4000,spec,'MAIN'); c~moveTo(0,0,1.6); c~setAngles(0,0,0); w~addCamera(c)
p=.SurveyWorldPoint~new('P',.MathVector3~new(10,0,1.6,ctx))
b=.SurveyBundle~new(w); b~addFeature(p)
photo=.SurveyPhotoObservation~new('PHOTO',3000,4000,c); b~addPhoto(photo)
xy=b~project(c,p~position); parse var xy x y
if abs(x-1500)>0.001 | abs(y-2000)>0.001 then do; say 'FAIL centre projection' xy; exit 1; end
b~addObservation(.SurveyBundleObservation~new('PHOTO','P',1500,2000))
if b~rmsReprojectionError>0.001 then do; say 'FAIL residual'; exit 1; end
say 'PASS bundle projection'
::requires '../rexx/SurveyBundle.cls'
