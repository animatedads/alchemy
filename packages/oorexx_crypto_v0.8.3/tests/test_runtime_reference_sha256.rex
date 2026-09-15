mode = value("CRYPTO_REFERENCE_TEST_MODE",, "ENVIRONMENT")
port = value("CRYPTO_REFERENCE_TEST_PORT",, "ENVIRONMENT")
if port == "" then raise syntax 88.900 array("CRYPTO_REFERENCE_TEST_PORT is required")

.RuntimeImplementationSwitch~reset
.CryptoLibraryBuild~referenceSwitch = .nil
expectedAbc = .SHA256~new("abc")~digest
expectedInvalid = .SHA256~new("runtime-reference-invalid-sha256")~digest

broker = .RuntimeImplementationBroker~new
provider = .RuntimeTcpJsonProvider~new("python.crypto.reference", "127.0.0.1", port + 0, 2, 8388608, "")
broker~register("crypto.sha256.digest/1", .RuntimeImplementationReference~new(provider, 100, .true, 1, 1))
.RuntimeImplementationSwitch~installBroker(broker)
.CryptoLibraryBuild~referenceSwitch = .RuntimeImplementationSwitch

actual = .SHA256~new("abc")~digest
call assertEqual expectedAbc, actual, "SHA-256 reference equivalence"

if mode == "live" then do
  call assertCompleted broker, "crypto.sha256.digest/1"

  sh = .SHA256~new("a")
  sh~update("b")
  sh~update("c")
  call assertEqual expectedAbc, sh~digest, "SHA-256 referenced streaming facade"
  call assertCompleted broker, "crypto.sha256.digest/1"

  invalid = .SHA256~new("runtime-reference-invalid-sha256")~digest
  call assertEqual expectedInvalid, invalid, "SHA-256 invalid provider result native fallback"
  evidence = broker~lastEvidence
  call assertEqual "RESULT_VALIDATION_FAILED", evidence~outcomeCode, "SHA-256 invalid result evidence"
end
else if mode == "dead" then do
  evidence = broker~lastEvidence
  call assertEqual "crypto.sha256.digest/1", evidence~operationId, "SHA-256 dead operation evidence"
  call assertTrue evidence~outcomeCode == "UNAVAILABLE" | evidence~outcomeCode == "CIRCUIT_OPEN", "SHA-256 dead provider fallback evidence"
end
else raise syntax 88.900 array("unknown CRYPTO_REFERENCE_TEST_MODE")

.CryptoLibraryBuild~referenceSwitch = .nil
.RuntimeImplementationSwitch~reset
say "PASS test_runtime_reference_sha256" mode
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
