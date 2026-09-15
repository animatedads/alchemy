port = value("CRYPTO_REFERENCE_TEST_PORT",, "ENVIRONMENT")
if port == "" then raise syntax 88.900 array("CRYPTO_REFERENCE_TEST_PORT is required")

broker = .RuntimeImplementationBroker~new
provider = .RuntimeTcpJsonProvider~new("python.crypto.reference", "127.0.0.1", port + 0, 3, 1048576, "")
do op over "crypto.rsa.generate_keypair/1", "crypto.rsa.sign/1", "crypto.rsa.verify/1", "crypto.rsa.encrypt/1", "crypto.rsa.decrypt/1"
  broker~register(op, .RuntimeImplementationReference~new(provider, 100, .true, 1, 1))
end
.RuntimeImplementationSwitch~installBroker(broker)
.CryptoLibraryBuild~referenceSwitch = .RuntimeImplementationSwitch

call time "R"
kp = .RSA~generateKeypair(65537)
refKeygen = time("E")
call assertCompleted broker, "crypto.rsa.generate_keypair/1"

messageInt = 1234567890123456789012345678901234567890
call time "R"
refSig = .RSA~sign(messageInt, kp["d"], kp["n"])
refSign = time("E")
call assertCompleted broker, "crypto.rsa.sign/1"

call time "R"
refRecovered = .RSA~verify(refSig, kp["e"], kp["n"])
refVerify = time("E")
call assertCompleted broker, "crypto.rsa.verify/1"
if refRecovered \= messageInt then raise syntax 88.900 array("referenced RSA verify mismatch")

plain = "RSA runtime reference performance"
call time "R"
refCipher = .RSA~encrypt(plain, kp["e"], kp["n"])
refEncrypt = time("E")
call assertCompleted broker, "crypto.rsa.encrypt/1"
call time "R"
refPlain = .RSA~decrypt(refCipher, kp["d"], kp["n"])
refDecrypt = time("E")
call assertCompleted broker, "crypto.rsa.decrypt/1"
if refPlain \= plain then raise syntax 88.900 array("referenced RSA decrypt mismatch")

/* Same key and operands, with Runtime Reference disabled. */
.CryptoLibraryBuild~referenceSwitch = .nil
.RuntimeImplementationSwitch~reset
call time "R"
nativeSig = .RSA~sign(messageInt, kp["d"], kp["n"])
nativeSign = time("E")
if nativeSig \= refSig then raise syntax 88.900 array("native/reference RSA sign mismatch")
call time "R"
nativeRecovered = .RSA~verify(nativeSig, kp["e"], kp["n"])
nativeVerify = time("E")
if nativeRecovered \= messageInt then raise syntax 88.900 array("native RSA verify mismatch")
call time "R"
nativeCipher = .RSA~encrypt(plain, kp["e"], kp["n"])
nativeEncrypt = time("E")
if nativeCipher \= refCipher then raise syntax 88.900 array("native/reference RSA encrypt mismatch")
call time "R"
nativePlain = .RSA~decrypt(nativeCipher, kp["d"], kp["n"])
nativeDecrypt = time("E")
if nativePlain \= plain then raise syntax 88.900 array("native RSA decrypt mismatch")

say "RSA-2048 Runtime Reference benchmark (single operation, same key)"
say "provider key generation:" format(refKeygen*1000,,3) "ms"
say "sign native:         " format(nativeSign*1000,,3) "ms"
say "sign reference:      " format(refSign*1000,,3) "ms"
say "sign speedup:        " format(nativeSign/refSign,,2) "x"
say "verify native:       " format(nativeVerify*1000,,3) "ms"
say "verify reference:    " format(refVerify*1000,,3) "ms"
say "verify speedup:      " format(nativeVerify/refVerify,,2) "x"
say "encrypt native:      " format(nativeEncrypt*1000,,3) "ms"
say "encrypt reference:   " format(refEncrypt*1000,,3) "ms"
say "encrypt speedup:     " format(nativeEncrypt/refEncrypt,,2) "x"
say "decrypt native:      " format(nativeDecrypt*1000,,3) "ms"
say "decrypt reference:   " format(refDecrypt*1000,,3) "ms"
say "decrypt speedup:     " format(nativeDecrypt/refDecrypt,,2) "x"
say "PASS RSA runtime-reference performance benchmark"
exit 0

::routine assertCompleted
  use strict arg broker, operationId
  evidence = broker~lastEvidence
  if evidence~operationId \= operationId | evidence~outcomeCode \= "COMPLETED" | evidence~providerId \= "python.crypto.reference" then raise syntax 88.900 array("reference operation did not complete: " || operationId)
  return

::requires "crypto.cls"
::requires "RuntimeTcpJsonProvider.cls"
