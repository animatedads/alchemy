key = "44"~copies(64)
transcript = .QueueSocketSessionCrypto~transcript("QM.A", "QM.B", "A.TO.B", "wire-b", "k1", "11"~copies(32), "22"~copies(32))
a = .QueueSocketSessionCrypto~new(key, transcript)
b = .QueueSocketSessionCrypto~new(key, transcript)
plaintext = "secret-queue-payload:" || "00ff10"
sealed = a~seal("C2S", plaintext)
if sealed~pos(plaintext) > 0 then call fail "plaintext leaked into secure frame"
opened = b~open("C2S", sealed)
if \opened~ok then call fail "roundtrip open failed " || opened~code
if opened~value \= plaintext then call fail "roundtrip plaintext mismatch"
row = .QueueRecordCodec~decode(sealed)
tampered = .QueueRecordCodec~encode("SECURE", .array~of(row[2], row[3], row[4], "00"~copies(64)))
bad = b~open("C2S", tampered)
if bad~ok | bad~code \= "SECURE_AUTHENTICATION_FAILED" then call fail "tampered secure frame accepted"
wrongDirection = b~open("S2C", sealed)
if wrongDirection~ok then call fail "wrong direction frame accepted"
sealedReverse = a~seal("S2C", plaintext)
if sealedReverse = sealed then call fail "direction separation produced identical secure frames"
transcript2 = .QueueSocketSessionCrypto~transcript("QM.A", "QM.B", "A.TO.B", "wire-b", "k1", "12"~copies(32), "22"~copies(32))
c = .QueueSocketSessionCrypto~new(key, transcript2)
sealedFresh = c~seal("C2S", plaintext)
if sealedFresh = sealed then call fail "fresh-session separation produced identical secure frames"
replayedAcrossSession = c~open("C2S", sealed)
if replayedAcrossSession~ok then call fail "secure frame replayed into a different session"
if replayedAcrossSession~code \= "SECURE_AUTHENTICATION_FAILED" then call fail "cross-session replay returned unexpected code " || replayedAcrossSession~code
say "OBJECT QUEUE FABRIC V0.9-dev6 SECURE SESSION CRYPTO: OK"
exit 0
fail: procedure
  parse arg message
  say "FAILED:" message
  exit 91
::requires "ObjectQueueSocketTransport.cls"
