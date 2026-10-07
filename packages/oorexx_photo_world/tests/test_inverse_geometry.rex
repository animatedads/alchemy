numeric digits 20
ctx=.Maths~defaultContext
spec=.XCoverCameraSpecifications~byId('XCOVERPRO')
c=.SurveyCamera~new('C1',.nil,1.60,60,1152,1536,spec,'MAIN')
c~moveTo(3,4,1.60); c~setAngles(17,-6,3)
b=.SurveyBundle~new(.SurveyWorld~new(ctx))
points=.array~of(.MathVector3~new(10,5,2.2,ctx),.MathVector3~new(15,1,5,ctx),.MathVector3~new(8,7,0.5,ctx))
do p over points
  xy=b~project(c,p)
  if xy==.nil then iterate
  parse var xy px py
  ray=.SurveyCameraGeometry~pixelRay(c,px,py)
  v=p-c~pose~position
  crossx=v~y*ray~direction~z-v~z*ray~direction~y
  crossy=v~z*ray~direction~x-v~x*ray~direction~z
  crossz=v~x*ray~direction~y-v~y*ray~direction~x
  err=.Maths~sqrt(crossx*crossx+crossy*crossy+crossz*crossz,ctx)
  if err>0.000001 then do; say 'FAIL inverse ray' err; exit 1; end
end
say 'PASS projection/inverse-ray consistency'
::requires '../rexx/SurveyBundle.cls'
