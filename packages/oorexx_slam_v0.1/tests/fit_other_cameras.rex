/* Run with REXX_PATH and rxmath available. No original photographs redistributed. */
numeric digits 20
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
f=.HarbourOtherCameraFit~new
say 'POWER SLAM OTHER-CAMERA v0.14 native ooRexx approximate fit'
do key over .array~of('BLUES_TOWER','NORTH_SHORE')
  do subset over .array~of('BRIDGE')
    r=f~fitSite(key,subset,40)
  p=r['POSE'];g=f~geodetic(p)
  say 'CAMERA' key 'TRAIN' r['TRAIN_SET'] 'POINTS' r['SAMPLE_COUNT'] 'CHI2' format(r['CHI2'],4,3)
  say 'POSE lat lon z yaw pitch focal_px hfov:' g[1] g[2] p[3] p[4] p[5] p[6] f~activeHorizontalFov(p[6])
  say 'STATUS:' f~qualify(key,r) 'SAMPLE_BOUNDARY_STATUS:' r['STATUS']
  a=f~holdouts(key,p)
    do t over a
      say 'REFERENCE_POINT' t[1] 'ERROR_PX' format(t[2],6,2) 'PROJ' format(t[3],6,1) format(t[4],6,1)
    end
  end
end
::requires 'SlamHarbourOtherCameraFit.cls'