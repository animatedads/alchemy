call test
exit 0

test:
  ctx=.MathContext~decimal(30)
  cam=.Vision3DCameraModel~new(101,101,50,50,50,50,ctx,.Math3DConvention~openGL,'TEST-CAM')
  pose=.MathTransform3D~identity(ctx,.Math3DConvention~openGL)
  r=cam~rayForPixel(50,50,pose)
  call assertNear r~direction~x,0,'centre ray x'
  call assertNear r~direction~y,0,'centre ray y'
  call assertNear r~direction~z,-1,'centre ray z'
  rr=cam~rayForPixel(100,50,pose)
  call assertTrue rr~direction~x>0,'right image point produces positive camera X'
  say 'PASS test_camera_rays'
  return

assertNear: procedure
  use arg actual,expected,label
  if abs(actual-expected)>'1E-10' then do; say 'FAIL' label actual expected; exit 1; end
  say 'PASS' label
  return
assertTrue: procedure
  use arg ok,label
  if \ok then do; say 'FAIL' label; exit 1; end
  say 'PASS' label
  return

::requires 'Vision3DReconstruction.cls'
