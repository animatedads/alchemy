call main
exit 0
main:
  key = "000102030405060708090a0b0c0d0e0f"
  mac = .SipHash128~new("vector-key", key)
  call assertEq "a3817f04ba25a8e66df67214c7550293", mac~mac(""), "siphashx24 len0"
  call assertEq "da87c1d86b99af44347659119b22fc45", mac~mac("00"x), "siphashx24 len1"
  call assertEq "8177228da4a45dc7fca38bdef60affe4", mac~mac("0001"x), "siphashx24 len2"
  call assertEq "9c70b60c5267a94e5f33b6b02985ed51", mac~mac("000102"x), "siphashx24 len3"
  msg = "short authenticated WLU record"
  tag = mac~sign(msg)
  call assertTrue mac~verify(msg, tag), "sign alias verifies"
  call assertFalse mac~verify(msg || "!", tag), "tampered message rejected"
  ring = .CryptoMacKeyRing~new
  ring~addKey("k1", key)
  ring~addKey("k2", "101112131415161718191a1b1c1d1e1f")
  p1 = ring~sign(msg)
  call assertEq "k1", p1~keyId, "first key active"
  call assertTrue ring~verify(msg, p1), "first proof verifies"
  ring~activate("k2")
  p2 = ring~sign(msg)
  call assertEq "k2", p2~keyId, "rotation active"
  call assertTrue ring~verify(msg, p1), "old proof remains verifiable"
  call assertTrue ring~verify(msg, p2), "new proof verifies"
  say "PASS test_siphash128"
  return
assertEq: procedure; use arg e,a,label; if e \== a then raise syntax 88.900 array(label || " expected=" || e || " actual=" || a); return
assertTrue: procedure; use arg v,label; if \v then raise syntax 88.900 array(label); return
assertFalse: procedure; use arg v,label; if v then raise syntax 88.900 array(label); return
::requires "crypto.cls"
