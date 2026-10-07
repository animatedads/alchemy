assertions = 0
say "OBJECT QUEUE FABRIC V0.8 ED25519 CHECKPOINT START"

seed = "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60"
publicKey = "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"
hmacKey = "0b"~copies(20)

authority = .QueueEd25519CheckpointAuthority~new("audit-rfc8032", seed, publicKey)
writer = .QueueHmacSha512RecordProtector~new("fixture-key", hmacKey, authority, 1)
protected = writer~protect("JOURNAL", "checkpointed")
fields = .QueueRecordCodec~decode(protected)
call assertEqual "audit-rfc8032", fields[8], "checkpoint key id"
call assertEqual 128, fields[9]~length, "Ed25519 signature length"
call assertEqual 1, authority~signedCheckpoints, "checkpoint signature generated"

verifier = .QueueEd25519CheckpointAuthority~new("audit-rfc8032", "", publicKey)
reader = .QueueHmacSha512RecordProtector~new("fixture-key", hmacKey, verifier, 1)
ignore = reader~beginRead("JOURNAL")
call assertEqual "checkpointed", reader~unprotect("JOURNAL", protected), "checkpoint verifies before payload return"
ignore = reader~finishRead("JOURNAL")
call assertEqual 1, verifier~verifiedCheckpoints, "checkpoint signature verified"

/* Altering a signed checkpoint must fail even when the HMAC secret is known. */
call assertTrue expectTamperedCheckpointFailure(protected, hmacKey, publicKey), "tampered Ed25519 checkpoint rejected"

say "OBJECT QUEUE FABRIC V0.8 ED25519 CHECKPOINT: OK"
say "assertions=" || assertions
exit 0

expectTamperedCheckpointFailure: procedure
  use arg protected, hmacKey, publicKey
  fields = .QueueRecordCodec~decode(protected)
  sig = fields[9]
  if sig~left(1) = "0" then sig = "1" || sig~substr(2)
  else sig = "0" || sig~substr(2)
  fields[9] = sig
  rebuiltFields = .array~new
  do i = 2 to fields~items
    rebuiltFields~append(fields[i])
  end
  tampered = .QueueRecordCodec~encode("QAUTH2", rebuiltFields)
  signal on syntax name rejected
  verifier = .QueueEd25519CheckpointAuthority~new("audit-rfc8032", "", publicKey)
  reader = .QueueHmacSha512RecordProtector~new("fixture-key", hmacKey, verifier, 1)
  ignore = reader~beginRead("JOURNAL")
  value = reader~unprotect("JOURNAL", tampered)
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
