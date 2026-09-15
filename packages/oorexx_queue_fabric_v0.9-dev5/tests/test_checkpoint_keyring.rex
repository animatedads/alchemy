assertions = 0
say "OBJECT QUEUE FABRIC V0.8 CHECKPOINT KEY RING START"

publicKey = "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"
signature = "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555" ||,
            "fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b"

oldAuthority = .QueueEd25519CheckpointAuthority~new("audit-old", "", publicKey)
newAuthority = .QueueEd25519CheckpointAuthority~new("audit-new", "", publicKey)
ring = .QueueEd25519CheckpointKeyRing~new(oldAuthority)
call assertEqual "audit-old", ring~keyId, "first authority becomes active"
call assertTrue ring~addAuthority(newAuthority), "second checkpoint key is trusted"
call assertTrue ring~hasKey("audit-old"), "historical checkpoint key retained"
call assertTrue ring~hasKey("audit-new"), "new checkpoint key retained"
call assertTrue ring~verifyCheckpointFor("audit-old", "", signature), "historical checkpoint signature dispatches by key id"
call assertTrue \ring~verifyCheckpointFor("missing", "", signature), "unknown checkpoint key id is rejected"
call assertTrue ring~activate("audit-new"), "new checkpoint key can be activated"
call assertEqual "audit-new", ring~keyId, "active checkpoint key changes"
call assertTrue \ring~canSign, "verify-only active checkpoint key reports cannot sign"
call assertTrue expectRequiredCheckpointSigningFailure(ring), "writer fails rather than emitting a required unsigned checkpoint"
call assertTrue expectDuplicateBindingFailure(ring, publicKey), "checkpoint key id cannot be rebound to a different authority object"

say "OBJECT QUEUE FABRIC V0.8 CHECKPOINT KEY RING: OK"
say "assertions=" || assertions
exit 0

expectRequiredCheckpointSigningFailure: procedure
  use arg ring
  signal on syntax name rejected
  protector = .QueueHmacSha512RecordProtector~new("hmac", "44"~copies(64), ring, 1)
  value = protector~protect("JOURNAL", "must-checkpoint")
  signal off syntax
  return .false
rejected:
  signal off syntax
  return .true

expectDuplicateBindingFailure: procedure
  use arg ring, publicKey
  signal on syntax name rejected
  duplicate = .QueueEd25519CheckpointAuthority~new("audit-new", "", publicKey)
  ignore = ring~addAuthority(duplicate)
  signal off syntax
  return .false
rejected:
  signal off syntax
  return .true

assertTrue: procedure expose assertions
  use arg condition, label
  assertions += 1
  if \condition then do
    say "ASSERT FAILED:" label
    exit 1
  end
  return

assertEqual: procedure expose assertions
  use arg expected, actual, label
  assertions += 1
  if expected \== actual then do
    say "ASSERT FAILED:" label "expected=" expected "actual=" actual
    exit 1
  end
  return

::requires "ObjectQueueCrypto.cls"
