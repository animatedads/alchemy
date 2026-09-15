/* Higher-order grammar + calendar learned-world generation freeze tests. */

say 'CAMERA GRAMMAR CALENDAR GENERATION SMOKE START'

camera = .CameraModel~new('CAMGRAMCAL', 640, 360)
camera~behaviour~addWindow(.CameraBehaviourWindow~new(43200, 3600))

/* Learn a pair of spatial zones through track endpoints. */
t1 = buildTrack('T1', 1000, 100, 120, 20, 0, 30, 20)
ignoredZones = camera~spatialModel~learnTrackEndpoints(t1)
call assertEqual 'two live zones', 2, camera~spatialModel~zones~zoneCount

/* Learn higher-order interaction/sequence vocabulary explicitly. */
ep1 = camera~episodeModel~learnSequence('55,58,56')
ep1Again = camera~episodeModel~learnSequence('55,58,56')
motif1 = camera~motifModel~learnSequence('E:50:R:R1>Z:Z1>P:EP1')
motif1Again = camera~motifModel~learnSequence('E:50:R:R1>Z:Z1>P:EP1')

/* Weekday context learns its own overlapping-window distributions. */
weekday = .CameraConstant~DAY_WEEKDAY
ignoredSummary = camera~calendarBehaviour~observeSummary(weekday)
ignoredSummary = camera~calendarBehaviour~observeSummary(weekday)
ignoredSummary = camera~calendarBehaviour~observeSummary(weekday)
ignoredMetric = camera~calendarBehaviour~observeMetric(weekday, camera~behaviour, 43200, 'TRACK_RATE', 10)
ignoredMetric = camera~calendarBehaviour~observeMetric(weekday, camera~behaviour, 43300, 'TRACK_RATE', 12)
ignoredMotif = camera~calendarBehaviour~observeMotif(weekday, camera~behaviour, 43200, motif1~id)

g1 = camera~publishGeneration(44000)
call assertEqual 'generation v6', '6', g1~version
call assertEqual 'g1 zones', 2, g1~zoneCount
call assertEqual 'g1 episodes', 1, g1~episodeCount
call assertEqual 'g1 motifs', 1, g1~motifCount
call assertEqual 'g1 calendar contexts', 1, g1~calendarContextCount
call assertEqual 'episode sample count frozen', 2, g1~episode(ep1~id)~sampleCount
call assertEqual 'motif sample count frozen', 2, g1~motif(motif1~id)~sampleCount

weekdaySnap = g1~calendarBehaviour~context(weekday)
call assertTrue 'weekday context frozen', weekdaySnap \== .nil
call assertEqual 'weekday summary support frozen', 3, weekdaySnap~sampleCount
weekdayWindow = weekdaySnap~behaviourModel~windowAtCentre(43200)
call assertTrue 'weekday window frozen', weekdayWindow \== .nil
trackRate = weekdayWindow~metric('TRACK_RATE')
call assertTrue 'weekday track-rate metric frozen', trackRate \== .nil
call assertEqual 'weekday track-rate samples frozen', 2, trackRate~sampleCount

g1Canonical = g1~semanticCanonicalText

/* Mutate every newly frozen live surface after G1. */
t2 = buildTrack('T2', 2000, 400, 250, 15, 0, 30, 20)
ignoredZones2 = camera~spatialModel~learnTrackEndpoints(t2)
ep2 = camera~episodeModel~learnSequence('55,58,58,56')
ignoredEP = camera~episodeModel~learnSequence('55,58,56')
motif2 = camera~motifModel~learnSequence('E:50:R:R2>Z:Z3>P:EP2')
ignoredM = camera~motifModel~learnSequence('E:50:R:R1>Z:Z1>P:EP1')

weekend = .CameraConstant~DAY_WEEKEND
ignoredSummary2 = camera~calendarBehaviour~observeSummary(weekend)
ignoredMetric2 = camera~calendarBehaviour~observeMetric(weekday, camera~behaviour, 43200, 'TRACK_RATE', 100)
ignoredMetric3 = camera~calendarBehaviour~observeMetric(weekend, camera~behaviour, 43200, 'TRACK_RATE', 3)

call assertEqual 'g1 zones unchanged', 2, g1~zoneCount
call assertEqual 'g1 episodes unchanged', 1, g1~episodeCount
call assertEqual 'g1 motifs unchanged', 1, g1~motifCount
call assertEqual 'g1 calendar contexts unchanged', 1, g1~calendarContextCount
call assertEqual 'g1 episode count unchanged', 2, g1~episode(ep1~id)~sampleCount
call assertEqual 'g1 motif count unchanged', 2, g1~motif(motif1~id)~sampleCount
call assertEqual 'g1 weekday metric support unchanged', 2, trackRate~sampleCount
call assertTrue 'g1 has no weekend context', g1~calendarBehaviour~context(weekend) == .nil
call assertEqual 'g1 semantic identity stable', g1Canonical, g1~semanticCanonicalText

/* G2 sees all of the new learned vocabulary/context. */
g2 = camera~publishGeneration(45000)
call assertTrue 'g2 gained zones', g2~zoneCount > g1~zoneCount
call assertEqual 'g2 two episodes', 2, g2~episodeCount
call assertEqual 'g2 two motifs', 2, g2~motifCount
call assertEqual 'g2 two calendar contexts', 2, g2~calendarContextCount
call assertEqual 'g2 old episode sample advanced', 3, g2~episode(ep1~id)~sampleCount
call assertEqual 'g2 old motif sample advanced', 3, g2~motif(motif1~id)~sampleCount
call assertTrue 'g2 weekday metric support advanced', g2~calendarBehaviour~context(weekday)~behaviourModel~windowAtCentre(43200)~metric('TRACK_RATE')~sampleCount > 2
call assertTrue 'g2 weekend context exists', g2~calendarBehaviour~context(weekend) \== .nil

/* Collection access is defensive. */
zonesCopy = g1~zones
zonesCopy~empty
call assertEqual 'g1 zone collection defended', 2, g1~zoneCount
motifsCopy = g1~motifs
motifsCopy~empty
call assertEqual 'g1 motif collection defended', 1, g1~motifCount

say '  G1 zones/episodes/motifs/calendar:' g1~zoneCount g1~episodeCount g1~motifCount g1~calendarContextCount
say '  G2 zones/episodes/motifs/calendar:' g2~zoneCount g2~episodeCount g2~motifCount g2~calendarContextCount
say 'CAMERA GRAMMAR CALENDAR GENERATION SMOKE: OK'
exit 0

buildTrack: procedure
  use arg id, startTimestamp, startX, startY, stepX, stepY, width, height
  track = .CameraTrack~new(id)
  do pointIndex = 0 to 4
    call addPoint track, startTimestamp + pointIndex, startX + (stepX * pointIndex), startY + (stepY * pointIndex), width, height
  end
  return track

addPoint: procedure
  use arg track, timestamp, x, y, width, height
  observation = .CameraObservation~new(timestamp, .CameraBox~new('OBS', x, y, width, height), 1, 1)
  ignoredCount = track~addObservation(observation)
  return

assertEqual: procedure
  use arg label, expected, actual
  if expected == actual then return .true
  say 'ASSERT FAILED:' label
  say '  expected:' expected
  say '  actual:  ' actual
  exit 1

assertTrue: procedure
  use arg label, actual
  if actual then return .true
  say 'ASSERT FAILED:' label
  say '  expected: true'
  say '  actual:  ' actual
  exit 1

::requires 'CameraCore.cls'
