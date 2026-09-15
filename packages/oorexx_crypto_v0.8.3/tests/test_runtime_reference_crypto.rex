mode = value("CRYPTO_REFERENCE_TEST_MODE",, "ENVIRONMENT")
port = value("CRYPTO_REFERENCE_TEST_PORT",, "ENVIRONMENT")
if port == "" then raise syntax 88.900 array("CRYPTO_REFERENCE_TEST_PORT is required")

/* Establish native expected values with no broker installed. */
.RuntimeImplementationSwitch~reset
.CryptoLibraryBuild~referenceSwitch = .nil
g = .Ed25519~G
expectedMul = g~multiply(9)
expectedAdd = g~add(g)
seed = "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60"
message = ""
expectedEdPublic = "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"
expectedEdSignature = "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555" ||,
                      "fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b"
alicePrivate = 123456789012345678901234567890
bobPrivate = 98765432109876543210987654321
expectedAlicePublic = .X25519~publicKey(alicePrivate)
expectedBobPublic = .X25519~publicKey(bobPrivate)
expectedSecret = .X25519~sharedSecret(alicePrivate, expectedBobPublic)

broker = .RuntimeImplementationBroker~new
provider = .RuntimeTcpJsonProvider~new("python.crypto.reference", "127.0.0.1", port + 0, 1, 1048576, "")
refMul = .RuntimeImplementationReference~new(provider, 100, .true, 1, 1)
broker~register("crypto.edwards25519.multiply/1", refMul)
refEdKeypair = .RuntimeImplementationReference~new(provider, 100, .true, 1, 1)
refEdSign = .RuntimeImplementationReference~new(provider, 100, .true, 1, 1)
refEdVerify = .RuntimeImplementationReference~new(provider, 100, .true, 1, 1)
broker~register("crypto.ed25519.keypair/1", refEdKeypair)
broker~register("crypto.ed25519.sign/1", refEdSign)
broker~register("crypto.ed25519.verify/1", refEdVerify)
refXPublic = .RuntimeImplementationReference~new(provider, 100, .true, 1, 1)
refXSecret = .RuntimeImplementationReference~new(provider, 100, .true, 1, 1)
broker~register("crypto.x25519.public_key/1", refXPublic)
broker~register("crypto.x25519.shared_secret/1", refXSecret)
.RuntimeImplementationSwitch~installBroker(broker)
.CryptoLibraryBuild~referenceSwitch = .RuntimeImplementationSwitch

actualMul = g~multiply(9)
call assertPoint expectedMul, actualMul, "multiply equivalence"

if mode == "live" then do
  evidence = broker~lastEvidence
  call assertEqual "crypto.edwards25519.multiply/1", evidence~operationId, "live operation evidence"
  call assertEqual "COMPLETED", evidence~outcomeCode, "live provider completed"
  call assertEqual "python.crypto.reference", evidence~providerId, "live provider identity"

  actualEdKeypair = .Ed25519~keypair(seed)
  call assertEqual expectedEdPublic, actualEdKeypair["public"], "Ed25519 whole keypair RFC equivalence"
  call assertEqual "COMPLETED", broker~lastEvidence~outcomeCode, "Ed25519 keypair provider completed"
  call assertEqual "crypto.ed25519.keypair/1", broker~lastEvidence~operationId, "Ed25519 keypair provider operation"
  actualEdSignature = .Ed25519~sign(message, seed)
  call assertEqual expectedEdSignature, actualEdSignature, "Ed25519 whole sign reference equivalence"
  call assertEqual "COMPLETED", broker~lastEvidence~outcomeCode, "Ed25519 sign provider completed"
  call assertTrue .Ed25519~verify(message, actualEdSignature, expectedEdPublic), "Ed25519 whole verify reference true"
  call assertEqual "COMPLETED", broker~lastEvidence~outcomeCode, "Ed25519 verify provider completed"

  actualAlicePublic = .X25519~publicKey(alicePrivate)
  call assertEqual expectedAlicePublic, actualAlicePublic, "X25519 public-key reference equivalence"
  call assertEqual "COMPLETED", broker~lastEvidence~outcomeCode, "X25519 public-key provider completed"
  actualSecret = .X25519~sharedSecret(alicePrivate, expectedBobPublic)
  call assertEqual expectedSecret, actualSecret, "X25519 shared-secret reference equivalence"
  call assertEqual "COMPLETED", broker~lastEvidence~outcomeCode, "X25519 shared-secret provider completed"

  /* The same TCP service deliberately returns an invalid point for add.  The public
   * method must reject the provider path and execute its private native body. */
  refAdd = .RuntimeImplementationReference~new(provider, 100, .true, 1, 1)
  broker~register("crypto.edwards25519.add/1", refAdd)
  actualAdd = g~add(g)
  call assertPoint expectedAdd, actualAdd, "malformed provider falls back"
  evidence = broker~lastEvidence
  call assertEqual "RESULT_VALIDATION_FAILED", evidence~outcomeCode, "invalid provider result evidence"
end
else if mode == "dead" then do
  evidence = broker~lastEvidence
  call assertEqual "crypto.edwards25519.multiply/1", evidence~operationId, "dead operation evidence"
  call assertTrue evidence~outcomeCode == "UNAVAILABLE" | evidence~outcomeCode == "CIRCUIT_OPEN", "dead service records fallback path"
end
else raise syntax 88.900 array("unknown CRYPTO_REFERENCE_TEST_MODE")

.CryptoLibraryBuild~referenceSwitch = .nil
.RuntimeImplementationSwitch~reset
say "PASS test_runtime_reference_crypto" mode
exit 0

::routine assertPoint
  use strict arg expected, actual, label
  if expected~x \= actual~x | expected~y \= actual~y then raise syntax 88.900 array("FAILED: " || label)
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
