/* test_speaker_embedding_layer.rex */
call testSpeakerEmbedding
say 'SPEAKER EMBEDDING LAYER: OK'
exit 0

testSpeakerEmbedding:
  r = .AudioRecording~new('ADULT-SPEAKER-BENCH', 12000)
  raw = r~addRawFeed('RAW', 12000, 'adult.wav', 'adult speech', .directory~new)
  group = r~createSourceGroup('G-A', 'foreground adult speaker hypothesis', .array~new, 'near microphone', 0.90, 'test', .directory~new)

  prep = .directory~new
  prep['sample_rate_hz'] = 16000
  prep['channels'] = 'MONO'
  prep['normalization'] = 'MODEL_ADAPTER'
  model = r~createSpeakerModel('ECAPA-VOX', 'SPEECHBRAIN', 'ECAPA-TDNN', 'speechbrain/spkrec-ecapa-voxceleb', 'UNPINNED-TEST', 3, 16000, 'MONO', prep, 'COSINE_SIMILARITY', 0.25, .directory~new)

  v = r~createSpeakerEmbeddingView('SPK-ECAPA', 'speaker embedding evidence', 'ECAPA-TDNN embeddings; identity is not implied', 'G-A', 'H-SPK-1', 1, 'foreground speaker', .directory~new)
  src = .array~of('RAW')
  a = .array~of(0.10, 0.20, 0.30)
  b = .array~of(0.11, 0.19, 0.31)
  e1 = r~addSpeakerEmbedding('E1', 'SPK-ECAPA', 'ECAPA-VOX', 1000, 3000, src, 'G-A', a, 0.93, 1800, 'SPEECHBRAIN_ECAPA', 'prep-sha-1', .directory~new)
  e2 = r~addSpeakerEmbedding('E2', 'SPK-ECAPA', 'ECAPA-VOX', 5000, 7000, src, 'G-A', b, 0.91, 1750, 'SPEECHBRAIN_ECAPA', 'prep-sha-1', .directory~new)
  call assertEq 3, e1~dimension, 'embedding dimension'

  c = r~addSpeakerComparison('C1', 'SPK-ECAPA', 'ECAPA-VOX', 'E1', 'E2', 0.87, 'COSINE_SIMILARITY', 0.25, 'SAME_SPEAKER_SUPPORT', '', 0.82, .directory~new)
  call assertEq 'SAME_SPEAKER_SUPPORT', c~decision, 'comparison decision is evidence label'
  call assertEq 0.87, c~score, 'comparison score retained'

  ids = .array~of('SPK-ECAPA')
  cut = r~throughCut(1500, 2500, ids)
  cv = cut~view('SPK-ECAPA')
  call assertEq 1, cv~elementCount, 'speaker boundary intersects cut'
  call assertEq 1, cv~speakerEmbeddingCount, 'speaker embedding intersects cut'
  ce = cv~speakerEmbeddings[1]
  call assertEq 0, ce~cutRelativeStartMs, 'speaker cut relative start'
  call assertEq 500, ce~embeddingOffsetStartMs, 'offset into original embedding'
  call assertEq 0, ce~cutRelativeEndMs - 1000, 'speaker cut relative end'
  call assertEq 3, ce~dimension, 'cut keeps model dimension metadata'
  return

assertEq:
  use arg expected, actual, label
  if expected \= actual then do
    say 'FAIL:' label 'expected='expected 'actual='actual
    exit 1
  end
  return

::requires '../AudioCore.cls'
