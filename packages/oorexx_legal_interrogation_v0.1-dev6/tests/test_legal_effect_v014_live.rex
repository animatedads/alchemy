/* Real Legal Effect v0.14 bridge qualification.
 * Requires LegalEffect.cls and AlchemyObject.cls on REXX_PATH.
 */

call AssertTrue .LegalEffectBuild~API_VERSION = "legal.effect/0.10", "Legal Effect public API identity"

provider = .LegalInterrogationTestDigestProvider~new
verifier = .LegalSourceVerifier~new(provider, "legal-interrogation-dev6-test-verifier")
sourceText = "Synthetic contract source for Legal Interrogation dev6 qualification."
sourceId = "LI-DEV6-CONTRACT"
identity = .LegalSourceIdentity~new(sourceId, "CONTRACT", "expr-v1", "urn:test:li-dev6", "test:" || sourceText~lower, "PARTIES", "GB", "UNVERIFIED")
source = .NormativeSource~new(sourceId, "CONTRACT", "Synthetic dev6 contract", "PARTIES", "GB")
sourceMaterial = .LegalVerificationMaterial~fromText(source, sourceText, "urn:test:li-dev6", "RAW_TEXT")
sourceEvidence = verifier~bindSource(identity, sourceMaterial)
call AssertTrue sourceEvidence~verified, "source identity verified by real Legal Effect verifier"
call AssertTrue identity~cryptographicallyVerified, "source identity carries verifier-issued evidence"

session = .LegalInterrogationSession~new("DEV6", identity, source, "CONTRACT", "urn:test:li-dev6", .array~of(sourceEvidence))
clauseText = "Customer must not assign the Agreement to a non-Affiliate without Supplier's prior written consent."
clause = .LegalInterrogationClause~new("C12", source, "urn:test:li-dev6#C12", clauseText)
call MustOk session~addClause(clause), "add clause"

director = .LegalInterrogationDirector~new
call MustOk director~seedClauseQuestions(clause), "seed base questions"
pOutcome = director~newProposition(clause, "If Customer assigns to a non-Affiliate without prior written Supplier consent, the assignment is prohibited.", "NORMATIVE", "Customer", "ASSIGN", "Agreement", "PROHIBITION")
call MustOk pOutcome, "create proposition"
proposition = pOutcome~value
proposition~addCondition(.LegalPredicate~new("NON_AFFILIATE_ASSIGNMENT", "KNOWN_TRUE"))
proposition~addException(.LegalPredicate~new("SUPPLIER_WRITTEN_CONSENT", "KNOWN_TRUE"))
call MustOk director~challengeProposition(clause, proposition), "seed proposition challenge"
call CloseQuestions clause~questions
call MustOk proposition~resolve("SUPPORTED", "fixture proposition survives structured challenge"), "resolve proposition"

tOutcome = director~newPropositionTest(clause, proposition, "IMPLICATION", "non-affiliate assignment without consent -> prohibited")
call MustOk tOutcome, "create proposition test"
call MustOk tOutcome~value~resolve("SUPPORTED", "fixture source supports implication"), "resolve proposition test"

call MustOk director~seedDocumentReconciliation(session), "seed reconciliation"
call CloseQuestions session~crossClauseQuestions
call AssertTrue session~eligibleForCompilation, "session closes before Legal Effect bridge"

hOutcome = director~makeHandoff(session)
call MustOk hOutcome, "create handoff"
handoff = hOutcome~value
adapter = .LegalInterrogationLegalEffectV014Adapter~new(verifier)
emitOutcome = handoff~emitWith(adapter)
call MustOk emitOutcome, "build real Legal Effect compilation unit"
compilation = emitOutcome~value
call AssertTrue compilation~isA(.LegalInterrogationLegalEffectCompilation), "bridge returns typed compilation wrapper"
call AssertTrue compilation~authoritative = .false, "pre-compile wrapper is non-authoritative"
call AssertTrue compilation~proposalCount = 1, "one supported proposition becomes one LegalCompileProposal"
call AssertTrue compilation~unit~proposals~items = 1, "real LegalCompilationUnit contains proposal"
call AssertTrue compilation~unit~provisionReference(sourceId, "C12")~verificationState = "VERIFIED", "clause provision verified"

compileReport = compilation~compile
call AssertTrue compileReport~ok, "real LegalRuleCompiler accepts verified bridge material"
call AssertTrue compilation~authoritative, "wrapper marks compiler-certified result authoritative"
call AssertTrue compileReport~generation~publicationEligible, "compiled generation is publication eligible"
call AssertTrue compileReport~generation~norms~items = 1, "compiled generation contains one norm"
compiledNorm = compileReport~generation~norms[1]
call AssertTrue compiledNorm~normType = "PROHIBITION", "modality maps to LegalNorm type"
call AssertTrue compiledNorm~disposition = "PROHIBITED", "modality maps to Legal Effect disposition"
call AssertTrue compiledNorm~actionCode = "ASSIGN", "predicate maps to action code"

/* Fail closed: source identity that merely asserts VERIFIED without evidence is rejected. */
badIdentity = .LegalSourceIdentity~new("BAD", "CONTRACT", "expr", "urn:test:bad", "test:bad", "PARTIES", "GB", "VERIFIED")
badSource = .NormativeSource~new("BAD", "CONTRACT", "Bad fixture")
badSession = .LegalInterrogationSession~new("BAD", badIdentity, badSource, "CONTRACT", "urn:test:bad")
badClause = .LegalInterrogationClause~new("B1", badSource, "urn:test:bad#B1", "Bad clause")
call MustOk badSession~addClause(badClause), "add bad clause"
call MustOk director~seedClauseQuestions(badClause), "seed bad questions"
badP = director~newProposition(badClause, "Bad proposition", "NORMATIVE", "X", "ACT", "Y", "PROHIBITION")~value
call MustOk director~challengeProposition(badClause, badP), "challenge bad proposition"
call CloseQuestions badClause~questions
call MustOk badP~resolve("SUPPORTED", "synthetic"), "resolve bad proposition"
call MustOk director~seedDocumentReconciliation(badSession), "seed bad reconciliation"
call CloseQuestions badSession~crossClauseQuestions
badHandoff = director~makeHandoff(badSession)~value
badOutcome = badHandoff~emitWith(adapter)
call AssertTrue \badOutcome~ok, "unverified source identity is rejected"
call AssertTrue badOutcome~code = "LEGAL_SOURCE_VERIFICATION_REQUIRED", "rejection code identifies source verification boundary"

say "LEGAL INTERROGATION LEGAL EFFECT V0.14 LIVE TEST: PASS"
exit 0

CloseQuestions:
  use arg questions
  do q over questions
    if q~state == "OPEN" then do
      answer = .LegalInterrogationAnswer~new(.nil, "fixture answer", "ANSWERED", .array~new, "test-proposer")
      call MustOk q~answerQuestion(answer), "answer" q~id
    end
    if q~state == "ANSWERED" then do
      review = .LegalInterrogationAnswerReview~new("ACCEPT", "fixture reviewer accepted", "test-reviewer", .array~new)
      call MustOk q~reviewAnswer(review), "review" q~id
    end
  end
  return

MustOk:
  use arg outcome, label
  if outcome~ok then return
  say "FAIL:" label "code=" outcome~code "detail=" outcome~detail
  exit 1

AssertTrue:
  use arg condition, label
  if condition then return
  say "FAIL:" label
  exit 1

::class LegalInterrogationTestDigestProvider public
::method algorithm
  return "TEST"
::method digest
  use strict arg material
  return material~string

::requires "LegalInterrogationLegalEffectV014.cls"
