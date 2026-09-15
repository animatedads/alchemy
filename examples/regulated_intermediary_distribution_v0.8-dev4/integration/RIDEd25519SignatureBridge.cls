/* oorexx_crypto-backed verifier/signing test adapter.  Production private keys
 * should live in customer/device/provider/HSM signing authorities, not in RID. */
::class RIDEd25519SignatureVerifier public
::method verify
  use arg message, signatureHex, publicKeyHex, algorithm = "ED25519"
  if .RIDCanonical~token(algorithm) <> "ED25519" then return .false
  return .Ed25519~verify(message~string, signatureHex~string~lower, publicKeyHex~string~lower)
::method signForTest
  use arg message, privateSeedHex, algorithm = "ED25519"
  if .RIDCanonical~token(algorithm) <> "ED25519" then raise syntax 88.987 array("Unsupported signing algorithm")
  return .Ed25519~sign(message~string, privateSeedHex~string~lower)

::requires "RIDDigitalSigning.cls"
::requires "crypto.cls"
