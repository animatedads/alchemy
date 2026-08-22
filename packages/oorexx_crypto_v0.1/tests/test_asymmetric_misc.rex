call main
exit 0
main:
  alicePrivate = 123456789012345678901234567890
  bobPrivate = 98765432109876543210987654321
  alicePublic = .X25519~publicKey(alicePrivate)
  bobPublic = .X25519~publicKey(bobPrivate)
  aSecret = .X25519~sharedSecret(alicePrivate, bobPublic)
  bSecret = .X25519~sharedSecret(bobPrivate, alicePublic)
  call assertEq aSecret, bSecret, "X25519 DH symmetry"
  kp = .RSA~keypair(61, 53, 17)
  call assertEq 3233, kp["n"], "RSA n"
  call assertEq 2753, kp["d"], "RSA d"
  sig = .RSA~sign(65, kp["d"], kp["n"])
  call assertEq 65, .RSA~verify(sig, kp["e"], kp["n"]), "RSA raw sign/verify"
  say "PASS test_asymmetric_misc"
  return
assertEq: procedure; use arg e,a,label; if e \== a then raise syntax 88.900 array(label || " expected=" || e || " actual=" || a); return
::requires "crypto.cls"
