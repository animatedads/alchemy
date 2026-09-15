::class DemoCodeEvidenceRules public
::attribute generation get

::method init
  expose generation
  provider = .LegalSha512DigestProvider~new("runtime-registry-sha512")
  verifier = .LegalSourceVerifier~new(provider, "demo-source-verifier-v0.7")
  text = "Evidence-bearing code-analysis findings require review before deployment."
  sourceText = "Synthetic source-evidence deployment review policy" || '0a'x || "Policy 1. " || text
  sourceDoc = .directory~new
  sourceDoc["kind"] = "DEMO_CODE_REVIEW_POLICY"
  sourceDoc["content"] = sourceText

  unit = .LegalCompilationUnit~new("DEMO-CODE-LEGAL-V1", "1", "demo-code-evidence-compiler", "0.10")
  identity = .LegalSourceIdentity~new("DEMO-CODE-REVIEW-POLICY", "POLICY", "demo-code-review-v1", "urn:demo:code-review-policy:v1", "sha512:" || provider~digest(sourceText), "DEMO-AUTHORITY", "*", "VERIFIED")
  source = .NormativeSource~new("DEMO-CODE-REVIEW-POLICY", "POLICY", "Synthetic source-evidence deployment review policy", "DEMO-AUTHORITY")
  addSource = unit~addSource(identity, source)
  if \addSource~ok then raise syntax 88.900 array("Demo code evidence source failed: " || addSource~code)

  reference = .LegalProvisionReference~new(source~sourceId, "1", "demo-code-review-v1", "policy 1", "sha512:" || provider~digest(text), text, "VERIFIED")
  provision = .LegalProvision~new(source~sourceId, "1", "ACTIVE", "BASE", text)
  addProvision = unit~addProvision(reference, provision)
  if \addProvision~ok then raise syntax 88.900 array("Demo code evidence provision failed: " || addProvision~code)

  ignored = unit~verifySource(source~sourceId, .LegalVerificationMaterial~fromText(sourceDoc, sourceText, "urn:demo:code-review-policy:v1", "RAW_NORMATIVE_SOURCE"), verifier)
  ignored = unit~verifyProvision(source~sourceId, "1", .LegalVerificationMaterial~fromText(sourceDoc, text, "policy 1", "PROVISION_LEXICAL_TEXT"), verifier)

  authorityIdentity = unit~sourceIdentity(source~sourceId)
  authorityClaim = .LegalSourceAuthorityClaim~new("DEMO-SOURCE-CLAIM", "DEMO-SOURCE-POLICY", authorityIdentity~sourceId, authorityIdentity~sourceKind, authorityIdentity~expressionId, authorityIdentity~canonicalUri, authorityIdentity~contentDigest, authorityIdentity~authority, authorityIdentity~jurisdictionId, "2026-08-22T00:00:00Z", authorityIdentity~canonicalUri)
  authoritySignature = .LegalSourceAuthoritySignature~new("DEMO-SIGNER", "TEST-SIG", "TESTSIG|demo-key|" || authorityClaim~canonicalText)
  authorityAttestation = .LegalSourceAuthorityAttestation~new(authorityClaim, .array~of(authoritySignature))
  authorityBind = unit~addSourceAuthorityAttestation(source~sourceId, authorityAttestation)
  if \authorityBind~ok then raise syntax 88.900 array("Demo code evidence source authority attestation failed")

  norm = .LegalNorm~new("DEMO-CODE-REVIEW-1", source~sourceId, "1", "OBLIGATION", "DEPLOY", "REVIEW", "SOFTWARE_CHANGE", "Evidence-bearing code-analysis findings require review")
  ignored = norm~addCondition(.LegalPredicate~new("CODE_FINDING", "PRESENT"))
  proposal = .LegalCompileProposal~new("P-DEMO-CODE-REVIEW-1", "NORM", norm, "demo-code-evidence-fixture", "DETERMINISTIC")
  ignored = proposal~addEvidenceReference(reference)
  ignored = unit~addProposal(proposal)

  report = .LegalRuleCompiler~new~compile(unit)
  if \report~ok then raise syntax 88.900 array("Demo code evidence legal compilation failed")
  generation = report~generation

::method legalGeneration
  expose generation
  return generation

::method runtimeSelfTest
  expose generation
  if \generation~publicationEligible then return .false
  if generation~compilationCertificate == .nil then return .false
  return generation~normCount = 1

::requires "LegalRuntimeCryptoBridge.cls"
