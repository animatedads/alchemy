::class DemoLegalRules public
::attribute generation get

::method init
  expose generation
  provider = .LegalSha512DigestProvider~new("runtime-registry-sha512")
  verifier = .LegalSourceVerifier~new(provider, "demo-source-verifier-v0.7")
  text11 = "Rate changes require the contractual process."
  text12 = "Scheduling changes require the contractual process."
  sourceText = "Demo contract v2" || '0a'x || "Clause 11. " || text11 || '0a'x || "Clause 12. " || text12
  sourceDoc = .directory~new
  sourceDoc["kind"] = "DEMO_CONTRACT_SOURCE"
  sourceDoc["content"] = sourceText

  unit = .LegalCompilationUnit~new("DEMO-LEGAL-V2", "2", "demo-fixture-compiler", "0.10")
  identity = .LegalSourceIdentity~new("DEMO-CONTRACT", "CONTRACT", "demo-v2", "urn:demo:contract:v2", "sha512:" || provider~digest(sourceText), "DEMO-PARTIES", "*", "VERIFIED")
  source = .NormativeSource~new("DEMO-CONTRACT", "CONTRACT", "Demo contract v2", "DEMO-PARTIES")
  ignored = unit~addSource(identity, source)

  ref11 = .LegalProvisionReference~new("DEMO-CONTRACT", "11", "demo-v2", "clause 11", "sha512:" || provider~digest(text11), text11, "VERIFIED")
  provision11 = .LegalProvision~new("DEMO-CONTRACT", "11", "ACTIVE", "BASE", text11)
  ignored = unit~addProvision(ref11, provision11)
  ref12 = .LegalProvisionReference~new("DEMO-CONTRACT", "12", "demo-v2", "clause 12", "sha512:" || provider~digest(text12), text12, "VERIFIED")
  provision12 = .LegalProvision~new("DEMO-CONTRACT", "12", "ACTIVE", "BASE", text12)
  ignored = unit~addProvision(ref12, provision12)

  sourceMaterial = .LegalVerificationMaterial~fromText(sourceDoc, sourceText, "urn:demo:contract:v2", "RAW_NORMATIVE_SOURCE")
  ignored = unit~verifySource("DEMO-CONTRACT", sourceMaterial, verifier)
  ignored = unit~verifyProvision("DEMO-CONTRACT", "11", .LegalVerificationMaterial~fromText(sourceDoc, text11, "clause 11", "PROVISION_LEXICAL_TEXT"), verifier)
  ignored = unit~verifyProvision("DEMO-CONTRACT", "12", .LegalVerificationMaterial~fromText(sourceDoc, text12, "clause 12", "PROVISION_LEXICAL_TEXT"), verifier)

  authorityIdentity = unit~sourceIdentity("DEMO-CONTRACT")
  authorityClaim = .LegalSourceAuthorityClaim~new("DEMO-SOURCE-CLAIM", "DEMO-SOURCE-POLICY", authorityIdentity~sourceId, authorityIdentity~sourceKind, authorityIdentity~expressionId, authorityIdentity~canonicalUri, authorityIdentity~contentDigest, authorityIdentity~authority, authorityIdentity~jurisdictionId, "2026-08-22T00:00:00Z", authorityIdentity~canonicalUri)
  authoritySignature = .LegalSourceAuthoritySignature~new("DEMO-SIGNER", "TEST-SIG", "TESTSIG|demo-key|" || authorityClaim~canonicalText)
  authorityAttestation = .LegalSourceAuthorityAttestation~new(authorityClaim, .array~of(authoritySignature))
  authorityBind = unit~addSourceAuthorityAttestation("DEMO-CONTRACT", authorityAttestation)
  if \authorityBind~ok then raise syntax 88.900 array("Demo source authority attestation failed")

  norm1 = .LegalNorm~new("DEMO-C-11", source~sourceId, "11", "CONTRACT_TERM", "RATE_CHANGE", "CONTRACT_BREACH")
  ignored = norm1~addCondition(.LegalPredicate~new("RATE_CHANGE", "KNOWN_TRUE"))
  proposal1 = .LegalCompileProposal~new("P-DEMO-C-11", "NORM", norm1, "demo-fixture", "DETERMINISTIC")
  ignored = proposal1~addEvidenceReference(ref11)
  ignored = unit~addProposal(proposal1)

  norm2 = .LegalNorm~new("DEMO-C-12", source~sourceId, "12", "CONTRACT_TERM", "SCHEDULING_CHANGE", "REQUIRES_OBLIGATION")
  ignored = norm2~addCondition(.LegalPredicate~new("FORCED_BLOCKS", "KNOWN_TRUE"))
  proposal2 = .LegalCompileProposal~new("P-DEMO-C-12", "NORM", norm2, "demo-fixture", "DETERMINISTIC")
  ignored = proposal2~addEvidenceReference(ref12)
  ignored = unit~addProposal(proposal2)

  compileReport = .LegalRuleCompiler~new~compile(unit)
  if \compileReport~ok then raise syntax 88.900 array("Demo v2 legal compilation failed")
  generation = compileReport~generation

::method legalGeneration
  expose generation
  return generation

::method runtimeSelfTest
  expose generation
  if \generation~publicationEligible then return .false
  return generation~normCount = 2

::requires "LegalRuntimeCryptoBridge.cls"
