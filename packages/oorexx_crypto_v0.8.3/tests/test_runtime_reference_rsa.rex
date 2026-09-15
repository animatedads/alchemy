numeric digits 2000
mode = value("CRYPTO_REFERENCE_TEST_MODE",, "ENVIRONMENT")
port = value("CRYPTO_REFERENCE_TEST_PORT",, "ENVIRONMENT")
if port == "" then raise syntax 88.900 array("CRYPTO_REFERENCE_TEST_PORT is required")

.RuntimeImplementationSwitch~reset
.CryptoLibraryBuild~referenceSwitch = .nil

toy = .RSA~keypair(61, 53, 17)
expectedToySig = .RSA~sign(65, toy["d"], toy["n"])

broker = .RuntimeImplementationBroker~new
provider = .RuntimeTcpJsonProvider~new("python.crypto.reference", "127.0.0.1", port + 0, 2, 1048576, "")
do op over "crypto.rsa.keypair/1", "crypto.rsa.generate_keypair/1", "crypto.rsa.encrypt/1", "crypto.rsa.decrypt/1", "crypto.rsa.sign/1", "crypto.rsa.verify/1"
  broker~register(op, .RuntimeImplementationReference~new(provider, 100, .true, 1, 1))
end
.RuntimeImplementationSwitch~installBroker(broker)
.CryptoLibraryBuild~referenceSwitch = .RuntimeImplementationSwitch

if mode == "live" then do
  kpToy = .RSA~keypair(61, 53, 17)
  call assertEqual 3233, kpToy["n"], "RSA referenced keypair n"
  call assertEqual 2753, kpToy["d"], "RSA referenced keypair d"
  call assertCompleted broker, "crypto.rsa.keypair/1"

  sigToy = .RSA~sign(65, kpToy["d"], kpToy["n"])
  call assertEqual expectedToySig, sigToy, "RSA referenced raw sign"
  call assertCompleted broker, "crypto.rsa.sign/1"
  call assertEqual 65, .RSA~verify(sigToy, kpToy["e"], kpToy["n"]), "RSA referenced raw verify"
  call assertCompleted broker, "crypto.rsa.verify/1"

  kp = .RSA~generateKeypair(65537)
  call assertTrue length(kp["n"]~string) >= 600, "RSA referenced generated modulus size"
  call assertTrue (kp["e"] * kp["d"]) // kp["phi"] = 1, "RSA referenced generated inverse"
  call assertCompleted broker, "crypto.rsa.generate_keypair/1"

  plain = "runtime-reference RSA"
  cipher = .RSA~encrypt(plain, kp["e"], kp["n"])
  call assertCompleted broker, "crypto.rsa.encrypt/1"
  decoded = .RSA~decrypt(cipher, kp["d"], kp["n"])
  call assertCompleted broker, "crypto.rsa.decrypt/1"
  call assertEqual plain, decoded, "RSA referenced encrypt/decrypt"

  messageInt = 123456789012345678901234567890
  sig = .RSA~sign(messageInt, kp["d"], kp["n"])
  call assertCompleted broker, "crypto.rsa.sign/1"
  recovered = .RSA~verify(sig, kp["e"], kp["n"])
  call assertCompleted broker, "crypto.rsa.verify/1"
  call assertEqual messageInt, recovered, "RSA referenced 2048-bit sign/verify"
end
else if mode == "dead" then do
  sig = .RSA~sign(65, toy["d"], toy["n"])
  call assertEqual expectedToySig, sig, "RSA dead-provider native sign fallback"
  evidence = broker~lastEvidence
  call assertEqual "crypto.rsa.sign/1", evidence~operationId, "RSA dead operation evidence"
  call assertTrue evidence~outcomeCode == "UNAVAILABLE" | evidence~outcomeCode == "CIRCUIT_OPEN", "RSA dead provider fallback evidence"
end
else raise syntax 88.900 array("unknown CRYPTO_REFERENCE_TEST_MODE")

.CryptoLibraryBuild~referenceSwitch = .nil
.RuntimeImplementationSwitch~reset
say "PASS test_runtime_reference_rsa" mode
exit 0

::routine assertCompleted
  use strict arg broker, operationId
  evidence = broker~lastEvidence
  if evidence~operationId \= operationId then raise syntax 88.900 array("FAILED evidence operation expected=" || operationId || " actual=" || evidence~operationId)
  if evidence~outcomeCode \= "COMPLETED" then raise syntax 88.900 array("FAILED provider outcome operation=" || operationId || " outcome=" || evidence~outcomeCode)
  if evidence~providerId \= "python.crypto.reference" then raise syntax 88.900 array("FAILED provider identity operation=" || operationId || " provider=" || evidence~providerId)
  return

::routine assertTrue
  use strict arg condition, label
  if \condition then raise syntax 88.900 array("FAILED: " || label)
  return

::routine assertEqual
  use strict arg expected, actual, label
  if expected \= actual then raise syntax 88.900 array("FAILED: " || label || " expected=" || expected || " actual=" || actual)
  return

::requires "crypto.cls"
::requires "RuntimeTcpJsonProvider.cls"
