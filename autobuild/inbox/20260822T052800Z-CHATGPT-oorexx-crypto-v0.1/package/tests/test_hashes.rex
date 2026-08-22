call main
exit 0
main:
  call assertEq "d41d8cd98f00b204e9800998ecf8427e", .MD5~new("")~digest, "MD5 empty"
  call assertEq "900150983cd24fb0d6963f7d28e17f72", .MD5~new("abc")~digest, "MD5 abc"
  md = .MD5~new("a"); md~update("b"); md~update("c")
  call assertEq "900150983cd24fb0d6963f7d28e17f72", md~digest, "MD5 streaming"
  expected = "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a" ||,
             "2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f"
  call assertEq expected, .SHA512~new("abc")~digest, "SHA-512 abc"
  sh = .SHA512~new("a"); sh~update("b"); sh~update("c")
  call assertEq expected, sh~digest, "SHA-512 streaming"
  call assertEq expected, .CryptoHash~hashString("abc", "SHA512"), "CryptoHash convenience"
  say "PASS test_hashes"
  return
assertEq: procedure; use arg e,a,label; if e \== a then raise syntax 88.900 array(label || " expected=" || e || " actual=" || a); return
::requires "crypto.cls"
