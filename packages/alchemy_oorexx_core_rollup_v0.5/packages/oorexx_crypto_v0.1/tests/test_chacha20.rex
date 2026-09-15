call main
exit 0
main:
  key = "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"
  nonce = "000000000000004a00000000"
  plain = "Ladies and Gentlemen of the class of '99: If I could offer you only one tip for the future, sunscreen would be it."
  expected = "6e2e359a2568f98041ba0728dd0d6981e97e7aec1d4360c20a27afccfd9fae0b" ||,
             "f91b65c5524733ab8f593dabcd62b3571639d624e65152ab8f530c359f0861d8" ||,
             "07ca0dbf500d6a6156a38e088a22b65e52bc514d16ccf806818ce91ab7793736" ||,
             "5af90bbf74a35be6b40b8eedf2785e42874d"
  cipher = .ChaCha20~encrypt(plain, key, nonce)
  call assertEq expected, c2x(cipher)~lower, "RFC 8439 ChaCha20"
  call assertEq plain, .ChaCha20~decrypt(cipher, key, nonce), "ChaCha20 round trip"
  say "PASS test_chacha20"
  return
assertEq: procedure; use arg e,a,label; if e \== a then raise syntax 88.900 array(label || " expected=" || e || " actual=" || a); return
::requires "crypto.cls"
