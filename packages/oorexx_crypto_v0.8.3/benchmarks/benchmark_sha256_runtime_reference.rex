port = value("CRYPTO_REFERENCE_TEST_PORT",, "ENVIRONMENT")
if port == "" then raise syntax 88.900 array("CRYPTO_REFERENCE_TEST_PORT is required")

sizes = .array~of(16, 1024, 4096, 16384)

do size over sizes
  payload = "a"~copies(size)

  .RuntimeImplementationSwitch~reset
  .CryptoLibraryBuild~referenceSwitch = .nil
  call time "R"
  nativeDigest = .SHA256~new(payload)~digest
  nativeSeconds = time("E")

  broker = .RuntimeImplementationBroker~new
  provider = .RuntimeTcpJsonProvider~new("python.crypto.reference", "127.0.0.1", port + 0, 3, 8388608, "")
  broker~register("crypto.sha256.digest/1", .RuntimeImplementationReference~new(provider, 100, .true, 1, 1))
  .RuntimeImplementationSwitch~installBroker(broker)
  .CryptoLibraryBuild~referenceSwitch = .RuntimeImplementationSwitch

  call time "R"
  refDigest = .SHA256~new(payload)~digest
  refSeconds = time("E")
  call assertCompleted broker, "crypto.sha256.digest/1"
  if nativeDigest \= refDigest then raise syntax 88.900 array("SHA-256 native/reference mismatch at bytes=" || size)

  say "bytes=" || size,
      "native_ms=" || format(nativeSeconds*1000,,3),
      "reference_ms=" || format(refSeconds*1000,,3),
      "speedup=" || format(nativeSeconds/refSeconds,,2) || "x"
end

.CryptoLibraryBuild~referenceSwitch = .nil
.RuntimeImplementationSwitch~reset
say "PASS SHA-256 runtime-reference performance benchmark"
exit 0

::routine assertCompleted
  use strict arg broker, operationId
  evidence = broker~lastEvidence
  if evidence~operationId \= operationId | evidence~outcomeCode \= "COMPLETED" | evidence~providerId \= "python.crypto.reference" then raise syntax 88.900 array("reference operation did not complete: " || operationId || " outcome=" || evidence~outcomeCode)
  return

::requires "crypto.cls"
::requires "RuntimeTcpJsonProvider.cls"
