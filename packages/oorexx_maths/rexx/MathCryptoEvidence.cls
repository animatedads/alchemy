/* Optional SHA-256 sealing of canonical mathematical evidence using ooRexx Crypto. */
::class MathEvidenceSealer public
::method sha256 class
  use strict arg evidence
  digest=.CryptoHash~hashString(evidence~canonical,'SHA256')
  seal=.MathSeal~new('SHA-256',digest,'MathEvidence~canonical/v2')
  evidence~attachSeal(seal)
  return seal
::method verify class
  use strict arg evidence
  seal=evidence~seal
  if seal == .nil then return .false
  if seal~algorithm<>'SHA-256' then return .false
  expected=.CryptoHash~hashString(evidence~canonical,'SHA256')
  return .CryptoUtils~secureEquals(expected,seal~digest)


::class MathProofSealer public
::method sha256 class
  use strict arg proof
  digest=.CryptoHash~hashString(proof~canonical,'SHA256')
  seal=.MathSeal~new('SHA-256',digest,'MathProof~canonical/v3')
  proof~attachSeal(seal)
  return seal
::method verify class
  use strict arg proof
  seal=proof~seal
  if seal == .nil then return .false
  if seal~algorithm<>'SHA-256' then return .false
  expected=.CryptoHash~hashString(proof~canonical,'SHA256')
  return .CryptoUtils~secureEquals(expected,seal~digest)

::requires 'MathsBootstrap.cls'
::requires 'crypto.cls'
