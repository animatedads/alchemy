call main
exit 0
main:
  call expectBadSipHashLength
  call expectBadSipHashHex
  call expectBadHmacHex
  call assertFalse .HMACSHA512~verify("00", "x", "abcd"), "short HMAC tag rejected"
  mac = .SipHash128~new("k", "000102030405060708090a0b0c0d0e0f")
  call assertFalse mac~verify("x", "abcd"), "short SipHash tag rejected"
  say "PASS test_input_validation"
  return
expectBadSipHashLength: procedure
  signal on syntax name caught
  ignore = .SipHash128~new("k", "00")
  signal off syntax
  raise syntax 88.900 array("bad SipHash length accepted")
caught: signal off syntax; return
expectBadSipHashHex: procedure
  signal on syntax name caught
  ignore = .SipHash128~new("k", "zz0102030405060708090a0b0c0d0e0f")
  signal off syntax
  raise syntax 88.900 array("bad SipHash hex accepted")
caught: signal off syntax; return
expectBadHmacHex: procedure
  signal on syntax name caught
  ignore = .HMACSHA512~digest("zz", "x")
  signal off syntax
  raise syntax 88.900 array("bad HMAC hex accepted")
caught: signal off syntax; return
assertFalse: procedure; use arg v,label; if v then raise syntax 88.900 array(label); return
::requires "crypto.cls"
