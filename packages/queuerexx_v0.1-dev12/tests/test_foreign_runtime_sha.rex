parse arg directBridge compatBridge
if directBridge == "" | compatBridge == "" then call fail "bridge paths required"
ignore = value(.QueueCryptoAcceleration~ENV_DIRECT_BRIDGE, directBridge, "ENVIRONMENT")
ignore = value(.QueueCryptoAcceleration~ENV_COMPAT_BRIDGE, compatBridge, "ENVIRONMENT")
if .QueueCryptoAcceleration~installed then call fail "fixture expected provider to be installed lazily"
material = '00610062ff00010203'x
expected = '6b7f2d24560b2fc85dfb3d33882e5b6b4e88608c88e04bcd2c4e6cde6fd75640'
r = .QueueDigestProvider~new~digestWithEvidence(material)
if r~digest <> expected then call fail "SHA-256 mismatch"
if \r~accelerated then call fail "SHA-256 did not use Foreign Runtime provider"
if r~providerId <> .QueueCryptoProvider~FOREIGN_OPENSSL then call fail "unexpected provider " || r~providerId
if r~outcomeCode <> .QueueCryptoOutcome~COMPLETED then call fail "unexpected outcome " || r~outcomeCode
say "PASS QueueRexx SHA-256 lazily prefers Crypto Foreign Runtime/OpenSSL provider"
exit 0
fail: procedure
  parse arg m
  say "FAIL" m
  exit 1
::requires "QueueRexxCrypto.cls"
