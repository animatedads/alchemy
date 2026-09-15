say "LEGAL EFFECT V0.14 -> HARDWORLD V0.18 PROMOTION COMPAT START"
a = .LegalHardWorldV018Compat~new
exit a~run

::class LegalHardWorldV018Compat
::method run
  provider = .LegalSha512DigestProvider~new("runtime-registry-sha512")
  verifier = .LegalSourceVerifier~new(provider, "legal-v07-hardworld-v018")

  sourceText = "A verified provision prohibits ACT."
  source = .NormativeSource~new("LAW", "CONTRACT", "verified law", "TEST-AUTH")
  sourceMaterial = .LegalVerificationMaterial~fromText(source, sourceText, "memory:hardworld-v018-law", "RAW_TEXT")
  sourceDigest = "sha512:" || provider~digest(sourceMaterial~material)
  identity = .LegalSourceIdentity~new("LAW", "CONTRACT", "expr-1", "memory:hardworld-v018-law", sourceDigest, "TEST-AUTH", "*", "VERIFIED")
  sourceEvidence = verifier~bindSource(identity, sourceMaterial)
  call assertTrue sourceEvidence~verified, "source verified"

  provision = .LegalProvision~new("LAW", "1", "ACTIVE", "BASE", sourceText)
  provisionMaterial = .LegalVerificationMaterial~fromText(provision, sourceText, "clause 1", "RAW_TEXT")
  provisionDigest = "sha512:" || provider~digest(provisionMaterial~material)
  reference = .LegalProvisionReference~new("LAW", "1", "expr-1", "clause 1", provisionDigest, sourceText, "VERIFIED")
  provisionEvidence = verifier~bindProvision(reference, provisionMaterial, sourceEvidence)
  call assertTrue provisionEvidence~verified, "provision verified"

  unit = .LegalCompilationUnit~new("COMPILED-G", "0.7", "compat-compiler", "1")
  call mustOk unit~addSource(identity, source), "add source"
  call mustOk unit~addProvision(reference, provision), "add provision"
  norm = .LegalNorm~new("LAW-N", "LAW", "1", "CONTRACT_TERM", "ACT", "PROHIBITED")
  proposal = .LegalCompileProposal~new("LAW-P", "NORM", norm, "compat-test", "HUMAN", "1")
  call mustOk proposal~addEvidenceReference(reference), "add evidence reference"
  call mustOk unit~addProposal(proposal), "add proposal"

  report = .LegalRuleCompiler~new~compile(unit)
  call assertTrue report~ok, "verified compilation succeeds"
  generation = report~generation
  call assertTrue generation~publicationEligible, "compiled generation publication eligible"

  context = .LegalContext~new("E", "2026-08-20")
  ignored = context~bindSource("LAW", "compat")
  pinned = .LegalEffectV05PinnedEvaluator~evaluate(.LegalEffectEngine~new, .LegalAction~new("ACT"), generation, context)
  if \pinned~ok then say "  pinned_failure=" || pinned~code || " " || pinned~detail
  call assertTrue pinned~ok, "HardWorld v0.18 pinned evaluator accepts v0.7 public surface"
  promotions = .LegalEffectV05PromotionAdapter~promotionsFrom(pinned~envelope)
  blocked = findPromotion(promotions, "LEGAL_ACTION_BLOCKED")
  call assertTrue blocked \== .nil, "blocked promotion exists"
  call assertEqual "AUTHORIZED", blocked~promotionStatus, "promotion authorized"
  call assertTrue hasBasis(blocked, "LEGAL_COMPILATION_CERTIFICATE"), "compiler certificate basis retained"
  call assertTrue hasBasis(blocked, "LEGAL_VERIFIED_SOURCE"), "verified source basis retained"
  call assertTrue hasBasis(blocked, "LEGAL_VERIFIED_PROVISION"), "verified provision basis retained"
  call assertTrue blocked~authority~pos("LEGAL_EFFECT/0.5/") = 1, "v0.18 compatibility adapter namespace remains explicit"

  say "  legal_api=" || .LegalEffectBuild~API_VERSION
  say "  adapter_authority=" || blocked~authority
  say "  disposition=" || pinned~envelope~assessment~status
  say "LEGAL EFFECT V0.14 -> HARDWORLD V0.18 PROMOTION COMPAT: OK"
  return 0

::routine findPromotion
  use arg setObject, target
  do promotion over setObject~promotions
    if promotion~targetFactName == target then return promotion
  end
  return .nil

::routine hasBasis
  use arg promotion, kind
  do item over promotion~basis
    if item~basisKind == kind then return .true
  end
  return .false

::routine mustOk
  use arg resultObject, label
  if \resultObject~ok then raise syntax 88.900 array(label || ": " || resultObject~code || " " || resultObject~detail)
  return 0

::routine assertTrue
  use arg condition, label
  if \condition then raise syntax 88.900 array("ASSERT TRUE FAILED: " || label)
  return 0

::routine assertEqual
  use arg expected, actual, label
  if expected \== actual then raise syntax 88.900 array("ASSERT EQUAL FAILED: " || label || " expected=" || expected || " actual=" || actual)
  return 0

::requires "LegalRuntimeCryptoBridge.cls"
::requires "LegalEffectV05PromotionAdapter.cls"
