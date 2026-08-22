/* Reference vectors for SipHash-2-4-128, key bytes 00..0f. */
key = "000102030405060708090a0b0c0d0e0f"
mac = .WLUSipHash128~new("test-key", key)

call assertEq "a3817f04ba25a8e66df67214c7550293", mac~sign(""), "empty vector"
call assertEq "da87c1d86b99af44347659119b22fc45", mac~sign("00"x), "one-byte vector"
call assertEq "8177228da4a45dc7fca38bdef60affe4", mac~sign("0001"x), "two-byte vector"
call assertEq "9c70b60c5267a94e5f33b6b02985ed51", mac~sign("000102"x), "three-byte vector"

msg = "reservation|AI_GPT|QPADEV0037|143"
tag = mac~sign(msg)
call assertTrue mac~verify(msg, tag), "valid tag"
call assertTrue \mac~verify(msg || "X", tag), "tampered message rejected"
call assertTrue \mac~verify(msg, tag~overlay("0", 1)), "tampered tag rejected"

ring = .WLUFastMacKeyRing~new
ignore = ring~addKey("k1", key)
proof = ring~sign(msg)
call assertEq "SIPHASH-2-4-128", proof~algorithm, "proof algorithm"
call assertEq "k1", proof~keyId, "proof key id"
call assertTrue ring~verify(msg, proof), "key ring verification"

say "PASS test_fast_mac"
exit 0

assertEq: procedure
  use arg expected, actual, label
  if expected \== actual then do
    say "FAIL" label "expected="expected "actual="actual
    exit 1
  end
  return

assertTrue: procedure
  use arg condition, label
  if \condition then do
    say "FAIL" label
    exit 1
  end
  return

::requires "WLUFastMac.cls"
