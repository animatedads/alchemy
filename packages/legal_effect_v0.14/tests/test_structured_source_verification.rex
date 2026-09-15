parse arg structuredRoot
if structuredRoot = "" then raise syntax 88.900 array("structured relation root required")
say "LEGAL EFFECT V0.14 STRUCTURED SOURCE VERIFICATION START"
a = .StructuredSourceVerificationAcceptance~new
exit a~run

::class StructuredSourceVerificationAcceptance
::method init
  expose assertions
  assertions = 0

::method run
  expose assertions
  provider = .LegalSha512DigestProvider~new("runtime-registry-sha512")
  verifier = .LegalSourceVerifier~new(provider, "legal-source-verifier-v0.7")

  xmlText = '<Policy xmlns="urn:test:policy"><Rule id="1">Evidence-bearing findings require review before deployment.</Rule></Policy>'
  doc = .XmlDocumentContext~fromText(xmlText, "memory:legal-policy.xml")
  doc~registerNamespace("p", "urn:test:policy")
  rules = doc~xpath("/p:Policy/p:Rule")
  ok = self~assertEqual(1, rules~count, "one XML provision node")
  ruleNode = rules~nodes[1]

  sourceMaterial = .LegalVerificationMaterial~fromXmlDocument(doc)
  provisionMaterial = .LegalVerificationMaterial~fromXmlNode(ruleNode)
  sourceDigest = "sha512:" || provider~digest(sourceMaterial~material)
  provisionDigest = "sha512:" || provider~digest(provisionMaterial~material)

  unit = .LegalCompilationUnit~new("XML-LEGAL-G1", "1", "compiler-v07", "0.6")
  identity = .LegalSourceIdentity~new("XML-POLICY", "POLICY", "xml-policy-v1", "memory:legal-policy.xml", sourceDigest, "TEST-AUTH", "*", "VERIFIED")
  source = .NormativeSource~new("XML-POLICY", "POLICY", "XML review policy", "TEST-AUTH")
  ignored = unit~addSource(identity, source)
  text = ruleNode~text
  reference = .LegalProvisionReference~new("XML-POLICY", "1", "xml-policy-v1", ruleNode~path, provisionDigest, text, "VERIFIED")
  provision = .LegalProvision~new("XML-POLICY", "1", "ACTIVE", "BASE", text)
  ignored = unit~addProvision(reference, provision)
  sourceResult = unit~verifySource("XML-POLICY", sourceMaterial, verifier)
  ok = self~assertTrue(sourceResult~ok, "XML source verification binds")
  provisionResult = unit~verifyProvision("XML-POLICY", "1", provisionMaterial, verifier)
  ok = self~assertTrue(provisionResult~ok, "XML provision verification binds")
  ok = self~assertTrue(sourceResult~value~sourceObject == doc, "XML document object retained by verification evidence")
  ok = self~assertTrue(provisionResult~value~sourceObject == ruleNode, "XML node object retained by provision evidence")
  ok = self~assertEqual("XML_SOURCE_TEXT", sourceResult~value~materialRepresentation, "XML document representation explicit")
  ok = self~assertEqual("XML_SOURCE_SPAN", provisionResult~value~materialRepresentation, "XML node source-span representation explicit")
  ok = self~assertTrue(provisionResult~value~locator~pos("Rule") > 0, "XML node path retained")
  ok = self~assertTrue(provisionMaterial~material~pos('<Rule id="1">') > 0, "XML provision digest covers exact source span including markup")

  norm = .LegalNorm~new("XML-REVIEW", "XML-POLICY", "1", "OBLIGATION", "DEPLOY", "REVIEW", "TEST", "source verified XML rule")
  proposal = .LegalCompileProposal~new("P-XML-REVIEW", "NORM", norm, "xml-extractor", "DETERMINISTIC", "1")
  ignored = proposal~addEvidenceReference(reference)
  ignored = unit~addProposal(proposal)
  report = .LegalRuleCompiler~new~compile(unit)
  ok = self~assertTrue(report~ok, "XML-source-evidence compilation succeeds")

  /* Structured Relation v0.8 distinguishes a remote blob claim from bytes
     actually attested against Git object identity.  A matching SHA-512 over
     carried bytes is not sufficient legal-source verification when the rich
     source object itself says its claimed Git blob is still unverified. */
  claimedRemote = .RemoteSourceFileRevision~new("example/repo", "deadbeef", "src/demo.c", "1111111111111111111111111111111111111111", "int demo = 1;", "https://example.invalid/demo.c", "2026-08-20T00:00:00Z")
  claimedMaterial = .LegalVerificationMaterial~fromGitFileRevision(claimedRemote)
  claimedDigest = "sha512:" || provider~digest(claimedMaterial~material)
  claimedIdentity = .LegalSourceIdentity~new("REMOTE-CLAIM", "CODE_EVIDENCE", "remote-claim-v1", claimedRemote~path, claimedDigest, "PUBLIC-GIT", "*", "VERIFIED")
  claimedEvidence = verifier~bindSource(claimedIdentity, claimedMaterial)
  ok = self~assertTrue(\claimedEvidence~verified, "claimed remote Git blob is not promoted by SHA-512 alone")
  ok = self~assertEqual("GIT_BLOB_ATTESTATION_REQUIRED", claimedEvidence~statusCode, "claimed remote Git blob requires v0.8 attestation")

  mismatchRemote = .RemoteSourceFileRevision~new("example/repo", "deadbeef", "src/demo.c", "1111111111111111111111111111111111111111", "int demo = 2;", "https://example.invalid/demo.c", "2026-08-20T00:00:00Z")
  ignoredVerify = mismatchRemote~verifyBlobIdentity
  mismatchMaterial = .LegalVerificationMaterial~fromGitFileRevision(mismatchRemote)
  mismatchDigest = "sha512:" || provider~digest(mismatchMaterial~material)
  mismatchIdentity = .LegalSourceIdentity~new("REMOTE-MISMATCH", "CODE_EVIDENCE", "remote-mismatch-v1", mismatchRemote~path, mismatchDigest, "PUBLIC-GIT", "*", "VERIFIED")
  mismatchEvidence = verifier~bindSource(mismatchIdentity, mismatchMaterial)
  ok = self~assertTrue(\mismatchEvidence~verified, "mismatched remote Git blob rejected")
  ok = self~assertEqual("GIT_BLOB_ATTESTATION_MISMATCH", mismatchEvidence~statusCode, "remote Git mismatch remains explicit")

  unboundRemote = .RemoteSourceFileRevision~new("example/repo", "deadbeef", "src/demo.c", "", "int demo = 3;", "https://example.invalid/demo.c", "2026-08-20T00:00:00Z")
  unboundMaterial = .LegalVerificationMaterial~fromGitFileRevision(unboundRemote)
  unboundDigest = "sha512:" || provider~digest(unboundMaterial~material)
  unboundIdentity = .LegalSourceIdentity~new("REMOTE-UNBOUND", "CODE_EVIDENCE", "remote-unbound-v1", unboundRemote~path, unboundDigest, "PUBLIC-GIT", "*", "VERIFIED")
  unboundEvidence = verifier~bindSource(unboundIdentity, unboundMaterial)
  ok = self~assertTrue(\unboundEvidence~verified, "remote revision without blob identity rejected")
  ok = self~assertEqual("GIT_BLOB_IDENTITY_REQUIRED", unboundEvidence~statusCode, "remote Git identity requirement explicit")

  semanticChange = .BitcoinCorePublicCorpus~semantic35688
  beforeSpan = semanticChange~beforeOperation~sourceSpan
  beforeRevision = beforeSpan~fileRevision
  ok = self~assertEqual("GIT_BLOB_BOUND", beforeRevision~provenance["identityStrength"], "Bitcoin v0.8 base snapshot is Git-blob attested")
  gitMaterial = .LegalVerificationMaterial~fromGitFileRevision(beforeRevision)
  gitDigest = "sha512:" || provider~digest(gitMaterial~material)
  gitIdentity = .LegalSourceIdentity~new("BTC-HMAC-BASE", "CODE_EVIDENCE", "bitcoin-35688-base", beforeRevision~path, gitDigest, "PUBLIC-GIT", "*", "VERIFIED")
  gitEvidence = verifier~bindSource(gitIdentity, gitMaterial)
  ok = self~assertTrue(gitEvidence~verified, "Git blob source verifies")
  ok = self~assertTrue(gitEvidence~sourceObject == beforeRevision, "Git file revision retained, not replaced by bytes")
  ok = self~assertEqual("GIT_BLOB_CONTENT", gitEvidence~materialRepresentation, "Git blob representation explicit")
  ok = self~assertEqual("0796bbeb3271a210ed7ed5d85a82fc76939db61a", beforeRevision~blobSha, "public Bitcoin blob identity retained")

  spanMaterial = .LegalVerificationMaterial~fromGitSourceSpan(beforeSpan)
  spanDigest = "sha512:" || provider~digest(spanMaterial~material)
  spanRef = .LegalProvisionReference~new("BTC-HMAC-BASE", "COPY", "bitcoin-35688-base", beforeSpan~path, spanDigest, beforeSpan~lexicalValue, "VERIFIED")
  spanEvidence = verifier~bindProvision(spanRef, spanMaterial, gitEvidence)
  ok = self~assertTrue(spanEvidence~verified, "Git source span verifies")
  ok = self~assertTrue(spanEvidence~sourceObject == beforeSpan, "Git source-span object retained")
  ok = self~assertTrue(spanEvidence~parentEvidence == gitEvidence, "Git provision/span verification links parent blob verification")
  ok = self~assertTrue(spanEvidence~locator~pos("hmac_sha256.cpp") > 0, "Git source locator retained")

  say "LEGAL EFFECT V0.14 STRUCTURED SOURCE VERIFICATION: OK assertions=" || assertions
  return 0

::method assertTrue
  expose assertions
  use arg condition, label
  assertions = assertions + 1
  if \condition then raise syntax 88.900 array(label)
  return .true

::method assertEqual
  expose assertions
  use arg expected, actual, label
  assertions = assertions + 1
  if expected \== actual then raise syntax 88.900 array(label || " expected=" || expected || " actual=" || actual)
  return .true

::requires "LegalRuntimeCryptoBridge.cls"
::requires "XmlNativeSource.cls"
::requires "BitcoinCorePublicCorpus.cls"
