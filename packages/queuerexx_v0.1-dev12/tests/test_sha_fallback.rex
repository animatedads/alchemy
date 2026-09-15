material = '00610062ff00010203'x
expected = '6b7f2d24560b2fc85dfb3d33882e5b6b4e88608c88e04bcd2c4e6cde6fd75640'
/* No bridge environment is supplied to this process.  The normal Crypto API
 * must remain usable through its pure ooRexx fallback. */
ignore = value(.QueueCryptoAcceleration~ENV_DIRECT_BRIDGE, "", "ENVIRONMENT")
ignore = value(.QueueCryptoAcceleration~ENV_COMPAT_BRIDGE, "", "ENVIRONMENT")
r = .QueueDigestProvider~new~digestWithEvidence(material)
if r~digest <> expected then call fail "fallback SHA-256 mismatch"
if r~accelerated then call fail "fallback unexpectedly reported acceleration"
say "PASS QueueRexx SHA-256 pure ooRexx fallback remains available"
exit 0
fail: procedure
  parse arg m
  say "FAIL" m
  exit 1
::requires "QueueRexxCrypto.cls"
