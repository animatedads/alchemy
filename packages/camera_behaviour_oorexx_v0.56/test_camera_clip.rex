/* test_camera_clip.rex */
call assertTrue .CameraConstant~DIRECTION_DOWN = 104, 'direction constant'

camera = .CameraModel~new('CAM-CLIP', 640, 360)
camera~behaviour~installRegularWindows(900, 3600)

measurementPath = 'camera_clip_measurements.tmp'
call stream measurementPath, 'c', 'open write replace'
call lineout measurementPath, 'CLIP|night-walk|900|12|' || .CameraConstant~ENV_NIGHT_ARTIFICIAL
call lineout measurementPath, 'FRAME|900'
call lineout measurementPath, 'OBS|900|100|100|20|50|0.05|0.80'
call lineout measurementPath, 'OBS|900|500|120|120|80|0.60|0.02'
call lineout measurementPath, 'FRAME|901'
call lineout measurementPath, 'OBS|901|102|110|20|50|0.05|0.80'
call lineout measurementPath, 'FRAME|902'
call lineout measurementPath, 'OBS|902|104|122|20|50|0.05|0.80'
call lineout measurementPath, 'FRAME|903'
call lineout measurementPath, 'OBS|903|106|135|20|50|0.05|0.80'
call stream measurementPath, 'c', 'close'

importedClip = .CameraMeasurementImporter~load(measurementPath)
call assertTrue importedClip \== .nil, 'clip imported'
call assertEqual 4, importedClip~frameCount, 'four imported frames'
call assertEqual .CameraConstant~ENV_NIGHT_ARTIFICIAL, importedClip~environmentCode, 'environment retained'

summary = .CameraClipProcessor~process(camera, importedClip)
call assertTrue summary \== .nil, 'summary created'
call assertEqual 4, summary~frameCount, 'summary frame count excludes flush frames'
call assertEqual 1, summary~photometricCount, 'wall light counted as photometric only'
call assertEqual 1, summary~trackCount, 'one structural mover track'
call assertEqual 4, summary~moverObservationCount, 'four mover observations'
call assertTrue summary~eventCount > 0, 'events derived'
call assertTrue summary~encodedBytes > 5, 'real binary event stream measured'
call assertTrue summary~bytesPerEvent > 0, 'bytes per event measured'
call assertEqual 1, summary~directionCount(.CameraConstant~DIRECTION_DOWN), 'dominant direction is down'
call assertEqual 0, summary~directionCount(.CameraConstant~DIRECTION_UP), 'not counted up'
call assertTrue summary~routeCount('R1') = 1, 'route usage summarised'
call assertTrue summary~eventTypeCount(.CameraConstant~EVENT_ENTER) >= 1, 'enter counted'
call assertTrue summary~compactText~pos('tracks=1') > 0, 'compact text includes tracks'

call sysfiledelete measurementPath
say 'CAMERA CLIP SMOKE: OK'
exit 0

assertEqual: procedure
  use arg expected, actual, message
  if expected \= actual then do
    say 'ASSERT EQUAL FAILED:' message 'expected='expected 'actual='actual
    exit 1
  end
  return 1

assertTrue: procedure
  use arg condition, message
  if \ condition then do
    say 'ASSERT TRUE FAILED:' message
    exit 1
  end
  return 1

::requires 'CameraCore.cls'
