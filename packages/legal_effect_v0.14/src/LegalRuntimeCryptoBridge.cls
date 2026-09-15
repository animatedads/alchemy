/* Legal Effect v0.11 - standalone oorexx_crypto bridge. */

::class LegalSha512DigestProvider public
::attribute providerId get

::method init
  expose providerId
  use arg providerIdArg = "oorexx-crypto:SHA512"
  providerId = providerIdArg~string

::method algorithm
  return "SHA512"

::method digest
  use arg material
  return .SHA512~new(material)~digest~lower



::class LegalEd25519SignatureProvider public
::attribute providerId get

::method init
  expose providerId
  use arg providerIdArg = "oorexx-crypto:Ed25519"
  providerId = providerIdArg~string

::method algorithm
  return "ED25519"

::method verify
  use arg message, signatureValue, publicKey
  if length(signatureValue~string) <> 128 then return .false
  if length(publicKey~string) <> 64 then return .false
  signal on syntax name verificationFailed
  valid = .Ed25519~verify(message~string, signatureValue~string, publicKey~string)
  signal off syntax
  return valid
verificationFailed:
  signal off syntax
  return .false

::requires "LegalEffect.cls"
::requires "crypto.cls"
