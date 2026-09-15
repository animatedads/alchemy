::class DemoLegalRulesUnattested public
::attribute generation get

::method init
  expose generation
  provider = .LegalSha512DigestProvider~new("runtime-registry-sha512")
  verifier = .LegalSourceVerifier~new(provider, "demo-unattested-source-verifier")
  text = "Rate changes require the contractual process."
  sourceText = "Demo unattested contract" || '0a'x || "Clause 11. " || text
  sourceDoc = .directory~new
  sourceDoc["content"] = sourceText

  unit = .LegalCompilationUnit~new("DEMO-LEGAL-UNATTESTED", "1", "demo-fixture-compiler", "0.10")
  identity = .LegalSourceIdentity~new("DEMO-CONTRACT", "CONTRACT", "demo-unattested", "urn:demo:contract:unattested", "sha512:" || provider~digest(sourceText), "DEMO-PARTIES", "*", "VERIFIED")
  source = .NormativeSource~new("DEMO-CONTRACT", "CONTRACT", "Demo unattested contract", "DEMO-PARTIES")
  ignored = unit~addSource(identity, source)
  reference = .LegalProvisionReference~new("DEMO-CONTRACT", "11", "demo-unattested", "clause 11", "sha512:" || provider~digest(text), text, "VERIFIED")
  provision = .LegalProvision~new("DEMO-CONTRACT", "11", "ACTIVE", "BASE", text)
  ignored = unit~addProvision(reference, provision)
  ignored = unit~verifySource("DEMO-CONTRACT", .LegalVerificationMaterial~fromText(sourceDoc, sourceText, "urn:demo:contract:unattested", "RAW_NORMATIVE_SOURCE"), verifier)
  ignored = unit~verifyProvision("DEMO-CONTRACT", "11", .LegalVerificationMaterial~fromText(sourceDoc, text, "clause 11", "PROVISION_LEXICAL_TEXT"), verifier)
  norm = .LegalNorm~new("DEMO-C-11", "DEMO-CONTRACT", "11", "CONTRACT_TERM", "RATE_CHANGE", "CONTRACT_BREACH")
  proposal = .LegalCompileProposal~new("P-DEMO-C-11", "NORM", norm, "demo-fixture", "DETERMINISTIC")
  ignored = proposal~addEvidenceReference(reference)
  ignored = unit~addProposal(proposal)
  report = .LegalRuleCompiler~new~compile(unit)
  if \report~ok then raise syntax 88.900 array("unattested compilation failed")
  generation = report~generation

::method legalGeneration
  expose generation
  return generation

::method runtimeSelfTest
  expose generation
  if \generation~publicationEligible then return .false
  if generation~sourceAuthorityAttestationsPresent then return .false
  return generation~normCount = 1

::requires "LegalRuntimeCryptoBridge.cls"
