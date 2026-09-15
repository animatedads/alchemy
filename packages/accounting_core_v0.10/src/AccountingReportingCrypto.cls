/* Optional Crypto v0.8.3 adapter for accounting.reporting.attestation/0.1. */
::options digits 50

::class AccountingEd25519ReportingProofProvider public
::attribute schemeRef get
::attribute digestAlgorithmRef get
::attribute keyRef get
::attribute keyIdentity get
::method init
  expose schemeRef digestAlgorithmRef keyRef keyIdentity privateSeedHex publicKeyHex
  use arg privateSeedArg, publicKeyArg, keyRefArg, keyIdentityArg
  schemeRef = "ED25519"
  digestAlgorithmRef = "SHA256"
  privateSeedHex = .AccountingUtil~requireText(privateSeedArg, "Ed25519 private seed")~lower
  publicKeyHex = .AccountingUtil~requireText(publicKeyArg, "Ed25519 public key")~lower
  keyRef = .AccountingUtil~requireText(keyRefArg, "reporting proof keyRef")
  keyIdentity = .AccountingUtil~requireText(keyIdentityArg, "reporting proof keyIdentity")

::method createProof
  expose schemeRef digestAlgorithmRef keyRef keyIdentity privateSeedHex
  use arg payload
  digest = .SHA256~new(payload~string)~digest
  signature = .Ed25519~sign(payload~string, privateSeedHex)
  return .AccountingReportingProof~new(schemeRef, digestAlgorithmRef, digest, signature, keyRef, keyIdentity)

::method verifyProof
  expose schemeRef digestAlgorithmRef keyRef keyIdentity publicKeyHex
  use arg payload, proof
  if proof == .nil | \proof~isA(.AccountingReportingProof) then return .false
  if proof~schemeRef \= schemeRef | proof~digestAlgorithmRef \= digestAlgorithmRef then return .false
  if proof~keyRef \= keyRef | proof~keyIdentity \= keyIdentity then return .false
  if proof~digestValue \= .SHA256~new(payload~string)~digest then return .false
  return .Ed25519~verify(payload~string, proof~proofValue, publicKeyHex)

::class AccountingEd25519ReportingProofVerifier public
::attribute schemeRef get
::attribute digestAlgorithmRef get
::attribute keyRef get
::attribute keyIdentity get
::method init
  expose schemeRef digestAlgorithmRef keyRef keyIdentity publicKeyHex
  use arg publicKeyArg, keyRefArg, keyIdentityArg
  schemeRef = "ED25519"
  digestAlgorithmRef = "SHA256"
  publicKeyHex = .AccountingUtil~requireText(publicKeyArg, "Ed25519 public key")~lower
  keyRef = .AccountingUtil~requireText(keyRefArg, "reporting proof keyRef")
  keyIdentity = .AccountingUtil~requireText(keyIdentityArg, "reporting proof keyIdentity")

::method verifyProof
  expose schemeRef digestAlgorithmRef keyRef keyIdentity publicKeyHex
  use arg payload, proof
  if proof == .nil | \proof~isA(.AccountingReportingProof) then return .false
  if proof~schemeRef \= schemeRef | proof~digestAlgorithmRef \= digestAlgorithmRef then return .false
  if proof~keyRef \= keyRef | proof~keyIdentity \= keyIdentity then return .false
  if proof~digestValue \= .SHA256~new(payload~string)~digest then return .false
  return .Ed25519~verify(payload~string, proof~proofValue, publicKeyHex)

::requires "AccountingReportingEvidence.cls"
::requires "crypto.cls"
