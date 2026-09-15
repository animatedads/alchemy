say "LEGAL EFFECT V0.14 COMPILATION SNAPSHOT ATOMICITY START"
a = .CompilationSnapshotAcceptance~new
exit a~run

::class CompilationSnapshotAcceptance
::method init
  expose assertions
  assertions = 0

::method buildUnit private
  use arg includeEvidence = .true
  provider = .LegalSha512DigestProvider~new("runtime-registry-sha512")
  verifier = .LegalSourceVerifier~new(provider, "snapshot-verifier")
  sourceText = "Synthetic atomic compilation law"
  provisionText = "A regulated operator must obtain approval before ACTION-X."
  sourceDoc = .directory~new
  sourceDoc["content"] = sourceText

  unit = .LegalCompilationUnit~new("ATOMIC-G1", "1", "snapshot-compiler", "0.9")
  identity = .LegalSourceIdentity~new("LAW-A", "LEGISLATION", "expr-1", "urn:test:atomic", "sha512:" || provider~digest(sourceText), "AUTH", "TEST-LAND", "VERIFIED")
  source = .NormativeSource~new("LAW-A", "LEGISLATION", "Atomic Law", "AUTH", "TEST-LAND")
  ignored = unit~addSource(identity, source)

  reference = .LegalProvisionReference~new("LAW-A", "1", "expr-1", "s.1", "sha512:" || provider~digest(provisionText), provisionText, "VERIFIED")
  provision = .LegalProvision~new("LAW-A", "1", "ACTIVE", "BASE", provisionText)
  ignored = unit~addProvision(reference, provision)
  ignored = unit~verifySource("LAW-A", .LegalVerificationMaterial~fromText(sourceDoc, sourceText, "urn:test:atomic", "RAW_NORMATIVE_SOURCE"), verifier)
  ignored = unit~verifyProvision("LAW-A", "1", .LegalVerificationMaterial~fromText(sourceDoc, provisionText, "s.1", "PROVISION_LEXICAL_TEXT"), verifier)

  norm = .LegalNorm~new("NORM-A", "LAW-A", "1", "OBLIGATION", "ACTION-X", "REQUIRES_OBLIGATION", "TEST", "atomicity test norm")
  proposal = .LegalCompileProposal~new("P-A", "NORM", norm, "test", "DETERMINISTIC")
  if includeEvidence then ignored = proposal~addEvidenceReference(unit~provisionReference("LAW-A", "1"))
  ignored = unit~addProposal(proposal)

  fixtureData = .directory~new
  fixtureData["unit"] = unit
  fixtureData["callerNorm"] = norm
  fixtureData["callerProposal"] = proposal
  return fixtureData

::method run
  expose assertions
  compiler = .LegalRuleCompiler~new

  fixture = self~buildUnit
  unit = fixture["unit"]
  identityBefore = unit~inputIdentity

  /* Mutating caller-held objects after insertion must not mutate compiler input. */
  callerNorm = fixture["callerNorm"]
  ignored = callerNorm~addCondition(.LegalPredicate~new("LATE_CALLER_MUTATION", "KNOWN_TRUE"))
  callerProposal = fixture["callerProposal"]
  ignored = callerProposal~addEvidenceReference(.LegalProvisionReference~new("BOGUS", "9", "expr", "p.9", "sha512:bogus", "bogus"))
  ok = self~assertEqual(identityBefore, unit~inputIdentity, "caller-held aliases do not alter unit identity")

  /* Mutating a defensive accessor copy must not mutate the unit either. */
  proposalsCopy = unit~proposals
  copiedNorm = proposalsCopy[1]~semanticObject
  ignored = copiedNorm~addCondition(.LegalPredicate~new("ACCESSOR_COPY_MUTATION", "KNOWN_TRUE"))
  ok = self~assertEqual(identityBefore, unit~inputIdentity, "accessor copies cannot alter unit identity")

  freezeResult = unit~freeze
  ok = self~assertTrue(freezeResult~ok, "explicit freeze succeeds")
  ok = self~assertTrue(unit~frozen, "unit reports frozen")
  snapshot = freezeResult~value
  ok = self~assertEqual(snapshot~inputIdentity, unit~inputIdentity, "unit identity is frozen snapshot identity")

  lateNorm = .LegalNorm~new("NORM-LATE", "LAW-A", "1", "OBLIGATION", "ACTION-X", "REQUIRES_OBLIGATION")
  lateProposal = .LegalCompileProposal~new("P-LATE", "NORM", lateNorm, "late", "DETERMINISTIC")
  lateAdd = unit~addProposal(lateProposal)
  ok = self~assertTrue(\lateAdd~ok, "post-freeze proposal rejected")
  ok = self~assertEqual("COMPILATION_UNIT_FROZEN", lateAdd~code, "post-freeze rejection code")

  report = compiler~compile(unit)
  ok = self~assertTrue(report~ok, "compiler consumes already frozen unit")
  ok = self~assertEqual(snapshot~inputIdentity, report~certificate~inputIdentity, "certificate binds frozen snapshot")
  ok = self~assertEqual(1, report~generation~normCount, "late proposal did not enter generation")

  /* Failed compilation is also consumed/frozen; it cannot be repaired in place. */
  badFixture = self~buildUnit(.false)
  badUnit = badFixture["unit"]
  badReport = compiler~compile(badUnit)
  ok = self~assertTrue(\badReport~ok, "invalid input fails")
  afterFailure = badUnit~addProposal(.LegalCompileProposal~new("P-AFTER", "NORM", .LegalNorm~new("N-AFTER", "LAW-A", "1", "OBLIGATION", "ACTION-X", "REQUIRES_OBLIGATION"), "late"))
  ok = self~assertEqual("COMPILATION_UNIT_FROZEN", afterFailure~code, "failed compilation input remains frozen")

  /* The v0.7 subclass/re-entrancy attack is rejected before inputIdentity can run. */
  evil = .MutatingCompilationUnit~new("EVIL-G", "1", "evil", "0.9")
  evilReport = compiler~compile(evil)
  ok = self~assertTrue(\evilReport~ok, "subclassed compilation unit rejected")
  ok = self~assertTrue(self~hasDiagnostic(evilReport, "COMPILATION_UNIT_CLASS_REQUIRED"), "subclass rejection diagnostic")
  ok = self~assertTrue(\evil~attackRan, "malicious inputIdentity override never executed")

  say "  assertions=" || assertions
  say "LEGAL EFFECT V0.14 COMPILATION SNAPSHOT ATOMICITY: OK"
  return 0

::method hasDiagnostic private
  use arg report, code
  do diagnostic over report~diagnostics
    if diagnostic~code = code then return .true
  end
  return .false

::method assertTrue private
  expose assertions
  use arg condition, label
  assertions = assertions + 1
  if \condition then raise syntax 88.900 array(label)
  return .true

::method assertEqual private
  expose assertions
  use arg expected, actual, label
  assertions = assertions + 1
  if expected \== actual then raise syntax 88.900 array(label || " expected=" || expected || " actual=" || actual)
  return .true

::class MutatingCompilationUnit subclass LegalCompilationUnit
::attribute attackRan
::method init
  self~init:super(arg(1), arg(2), arg(3), arg(4))
  self~attackRan = .false
::method inputIdentity
  self~attackRan = .true
  return "STALE-IDENTITY"

::requires "LegalRuntimeCryptoBridge.cls"
