call assertEq .SHA1~new("")~digest, "da39a3ee5e6b4b0d3255bfef95601890afd80709", "SHA1 empty"
call assertEq .SHA1~new("abc")~digest, "a9993e364706816aba3e25717850c26c9cd0d89d", "SHA1 abc"
call assertEq .AuthHMAC~sha1("0b"x~copies(20),"Hi There"), "b617318655057264e28bc0b6fb378c8ef146be00", "RFC2202 HMAC-SHA1"
call assertEq .AuthHMAC~sha256("0b"x~copies(20),"Hi There"), "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7", "RFC4231 HMAC-SHA256"
call assertEq .AuthHMAC~sha512("0b"x~copies(20),"Hi There"), "87aa7cdea5ef619d4ff0b4241a1d6cb02379f4e2ce4ec2787ad0b30545e17cde" ||,
  "daa833b7d6b8a702038b274eaea3f4e4be9d914eeb61f1702e696c203a126854", "RFC4231 HMAC-SHA512"
say "PASS crypto auth primitives"
exit 0

assertEq: procedure
  use arg actual, expected, label
  if actual \== expected then do
    say "FAIL" label
    say " expected:" expected
    say " actual:  " actual
    exit 1
  end
  return

::requires "CryptoAuth.cls"
