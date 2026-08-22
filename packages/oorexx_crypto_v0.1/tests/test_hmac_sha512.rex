call main
exit 0
main:
  key = "0b"~copies(20)
  expected = "87aa7cdea5ef619d4ff0b4241a1d6cb02379f4e2ce4ec2787ad0b30545e17cde" ||,
             "daa833b7d6b8a702038b274eaea3f4e4be9d914eeb61f1702e696c203a126854"
  actual = .HMACSHA512~digest(key, "Hi There")
  call assertEq expected, actual, "RFC 4231 case 1"
  call assertTrue .HMACSHA512~verify(key, "Hi There", expected), "valid HMAC"
  call assertFalse .HMACSHA512~verify(key, "Hi There!", expected), "tampered message"
  call assertFalse .HMACSHA512~verify(key, "Hi There", "0" || expected~substr(2)), "tampered tag"
  call assertTrue .CryptoUtils~secureEquals("abc", "abc"), "equal"
  call assertFalse .CryptoUtils~secureEquals("abc", "abd"), "unequal"
  say "PASS test_hmac_sha512"
  return
assertEq: procedure; use arg e,a,label; if e \== a then raise syntax 88.900 array(label || " expected=" || e || " actual=" || a); return
assertTrue: procedure; use arg v,label; if \v then raise syntax 88.900 array(label); return
assertFalse: procedure; use arg v,label; if v then raise syntax 88.900 array(label); return
::requires "crypto.cls"
