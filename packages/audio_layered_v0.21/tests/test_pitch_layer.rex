/* test_pitch_layer.rex */
call testPitch
say 'PITCH LAYER: OK'
exit 0

testPitch:
  r = .AudioRecording~new('ANNIE-GLASGOW', 11646)
  raw = r~addRawFeed('RAW', 11646, 'annie.ogg', 'adult speech benchmark', .directory~new)

  v = r~createPitchView('PITCH-F0', 'fundamental frequency assessment', 'framewise F0 plus assessed regions', '', '', 0, 'speaker pitch', .directory~new)
  s = r~createPitchSeries('F0-A', 'PITCH-F0', 'PYIN', 'dense F0 evidence', .directory~new)

  src = .array~of('RAW')
  r~addPitchObservation('F0-A', 'P0', 900, 182.4, 0.91, 0.96, 'PYIN', src, .directory~new)
  r~addPitchObservation('F0-A', 'P1', 1100, 186.1, 0.93, 0.98, 'PYIN', src, .directory~new)
  r~addPitchObservation('F0-A', 'P2', 1450, 201.7, 0.88, 0.95, 'PYIN', src, .directory~new)
  r~addPitchObservation('F0-A', 'P3', 2050, 0, 0.40, 0.08, 'PYIN', src, .directory~new)

  r~addPitchBoundary('PITCH-F0', 'PB1', 800, 1800, 'rising pitch', 190.3, 178.0, 208.0, 0.84, 'test', src, 'RISING', 0.94, .directory~new, 'frame summary')

  ids = .array~of('PITCH-F0')
  cut = r~throughCut(1000, 1600, ids)
  cv = cut~view('PITCH-F0')
  call assertEq 1, cv~elementCount, 'one assessed pitch boundary intersects'
  call assertEq 2, cv~pitchObservationCount, 'two dense F0 observations survive cut'
  obs = cv~pitchObservations
  call assertEq 100, obs[1]~cutRelativeTimeMs, 'first cut relative pitch time'
  call assertEq 450, obs[2]~cutRelativeTimeMs, 'second cut relative pitch time'
  call assertEq 'RISING', cv~elements[1]~attributes['contour'], 'pitch contour preserved'
  call assertEq 190.3, cv~elements[1]~attributes['median_hz'], 'median F0 preserved'
  return

assertEq:
  use arg expected, actual, label
  if expected \= actual then do
    say 'FAIL:' label 'expected='expected 'actual='actual
    exit 1
  end
  return

::requires '../AudioCore.cls'
