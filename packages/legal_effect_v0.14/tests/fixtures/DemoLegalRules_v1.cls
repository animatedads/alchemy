::class DemoLegalRules public
::attribute generation get

::method init
  expose generation
  provider = .LegalSha512DigestProvider~new("runtime-registry-sha512")
  verifier = .LegalSourceVerifier~new(provider, "demo-source-verifier-v0.7")
  text = "Rate changes require the contractual process."
  sourceText = "Demo contract v1" || '0a'x || "Clause 11. " || text
  sourceDoc = .directory~new
  sourceDoc["kind"] = "DEMO_CONTRACT_SOURCE"
  sourceDoc["content"] = sourceText

  unit = .LegalCompilationUnit~new("DEMO-LEGAL-V1", "1", "demo-fixture-compiler", "0.10")
  identity = .LegalSourceIdentity~new("DEMO-CONTRACT", "CONTRACT", "demo-v1", "urn:demo:contract:v1", "sha512:" || provider~digest(sourceText), "DEMO-PARTIES", "*", "VERIFIED")
  source = .NormativeSource~new("DEMO-CONTRACT", "CONTRACT", "Demo contract v1", "DEMO-PARTIES")
  ignored = unit~addSource(identity, source)

  reference = .LegalProvisionReference~new("DEMO-CONTRACT", "11", "demo-v1", "clause 11", "sha512:" || provider~digest(text), text, "VERIFIED")
  provision = .LegalProvision~new("DEMO-CONTRACT", "11", "ACTIVE", "BASE", text)
  ignored = unit~addProvision(reference, provision)

  sourceMaterial = .LegalVerificationMaterial~fromText(sourceDoc, sourceText, "urn:demo:contract:v1", "RAW_NORMATIVE_SOURCE")
  sourceVerify = unit~verifySource("DEMO-CONTRACT", sourceMaterial, verifier)
  if \sourceVerify~ok then raise syntax 88.900 array("Demo v1 source verification failed")
  provisionMaterial = .LegalVerificationMaterial~fromText(sourceDoc, text, "clause 11", "PROVISION_LEXICAL_TEXT")
  provisionVerify = unit~verifyProvision("DEMO-CONTRACT", "11", provisionMaterial, verifier)
  if \provisionVerify~ok then raise syntax 88.900 array("Demo v1 provision verification failed")

  authorityIdentity = unit~sourceIdentity("DEMO-CONTRACT")
  authorityClaim = .LegalSourceAuthorityClaim~new("DEMO-SOURCE-CLAIM", "DEMO-SOURCE-POLICY", authorityIdentity~sourceId, authorityIdentity~sourceKind, authorityIdentity~expressionId, authorityIdentity~canonicalUri, authorityIdentity~contentDigest, authorityIdentity~authority, authorityIdentity~jurisdictionId, "2026-08-22T00:00:00Z", authorityIdentity~canonicalUri)
  authoritySignature = .LegalSourceAuthoritySignature~new("DEMO-SIGNER", "TEST-SIG", "TESTSIG|demo-key|" || authorityClaim~canonicalText)
  authorityAttestation = .LegalSourceAuthorityAttestation~new(authorityClaim, .array~of(authoritySignature))
  authorityBind = unit~addSourceAuthorityAttestation("DEMO-CONTRACT", authorityAttestation)
  if \authorityBind~ok then raise syntax 88.900 array("Demo source authority attestation failed")

  norm = .LegalNorm~new("DEMO-C-11", source~sourceId, "11", "CONTRACT_TERM", "RATE_CHANGE", "CONTRACT_BREACH")
  ignored = norm~addCondition(.LegalPredicate~new("RATE_CHANGE", "KNOWN_TRUE"))
  proposal = .LegalCompileProposal~new("P-DEMO-C-11", "NORM", norm, "demo-fixture", "DETERMINISTIC")
  ignored = proposal~addEvidenceReference(reference)
  ignored = unit~addProposal(proposal)

  compileReport = .LegalRuleCompiler~new~compile(unit)
  if \compileReport~ok then raise syntax 88.900 array("Demo v1 legal compilation failed")
  generation = compileReport~generation

::method legalGeneration
  expose generation
  return generation

::method runtimeSelfTest
  expose generation
  if \generation~publicationEligible then return .false
  return generation~normCount = 1

::requires "LegalRuntimeCryptoBridge.cls"
