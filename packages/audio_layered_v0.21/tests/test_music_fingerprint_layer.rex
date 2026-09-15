call testMain
exit 0

testMain:
  rec = .AudioRecording~new('music-test', 120000)
  meta = .directory~new
  rec~addRawFeed('raw', 120000, 'sample.wav', 'raw audio', meta)

  attrs = .directory~new
  view = rec~createMusicFingerprintView('music-id', 'music fingerprint evidence', 'Chromaprint + provider lookup', '', '', 0, 'known-recording identification', attrs)

  prep = .directory~new
  prep['channel_policy'] = 'MONO'
  prep['normalization'] = 'PROVIDER_DEFAULT'
  model = rec~createFingerprintModel('chromaprint-v1', 'AcoustID', 'CHROMAPRINT', 'fpcalc/pyacoustid', '1', 11025, prep, .directory~new)

  sources = .array~of('raw')
  fp = rec~addMusicFingerprint('fp-1', 'music-id', 'chromaprint-v1', 4000, 14000, sources, 'AQABTESTFINGERPRINT', 'CHROMAPRINT_BASE64', 10, 0.93, 'sha256:prep', .directory~new)

  recordings = .array~of('mb-recording-1')
  releases = .array~new
  query = .directory~new
  query['meta'] = 'recordingids'
  query['duration'] = '10'
  ident = rec~addMusicIdentification('id-1', 'music-id', 'fp-1', 'AcoustID', 'v2', 0.98, 'MATCH', 'acoustid-track-1', recordings, releases, query, 'sha256:response', 0.90, .directory~new)

  ids = .array~of('music-id')
  cut = rec~throughCut(8000, 10000, ids)
  cv = cut~view('music-id')

  call assertEq 1, cv~musicFingerprintCount, 'cut fingerprint count'
  c = cv~musicFingerprints[1]
  call assertEq 4000, c~originalStartMs, 'original start'
  call assertEq 14000, c~originalEndMs, 'original end'
  call assertEq 8000, c~clippedStartMs, 'clip start'
  call assertEq 10000, c~clippedEndMs, 'clip end'
  call assertEq 0, c~cutRelativeStartMs, 'relative start'
  call assertEq 2000, c~cutRelativeEndMs, 'relative end'
  call assertEq 4000, c~fingerprintOffsetStartMs, 'offset start'
  call assertEq 6000, c~fingerprintOffsetEndMs, 'offset end'
  call assertEq 'acoustid-track-1', ident~acoustidTrackId, 'provider track id'
  call assertEq 'mb-recording-1', ident~recordingIds[1], 'recording id'

  say 'MUSIC FINGERPRINT LAYER: OK'
  return

assertEq:
  use arg expected, actual, label
  if expected \= actual then do
    say 'FAIL:' label 'expected='expected 'actual='actual
    exit 1
  end
  return

::requires '../AudioCore.cls'
