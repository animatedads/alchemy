/*
 * LegalInterrogation.cls
 * legal.interrogation/0.1 (package dev3)
 *
 * Upstream authoring/interrogation layer for Legal Effect.
 * It does not decide executable legal effect and does not self-certify proposals.
 */

::class LegalInterrogationResult public
::attribute ok
::attribute code
::attribute detail
::attribute value

::method init
  use strict arg ok, code, detail = "", value = .nil
  self~ok = ok
  self~code = code
  self~detail = detail
  self~value = value

::method success class
  use strict arg value = .nil, code = "OK", detail = ""
  return self~new(.true, code, detail, value)

::method failure class
  use strict arg code, detail = "", value = .nil
  return self~new(.false, code, detail, value)


::class LegalInterrogationEvidenceLink public
::attribute kind
::attribute sourceObject
::attribute locator
::attribute note

::method init
  use strict arg kind, sourceObject, locator = "", note = ""
  self~kind = kind
  self~sourceObject = sourceObject
  self~locator = locator
  self~note = note


::class LegalInterrogationAnswer public
::attribute answerObject
::attribute explanation
::attribute disposition
::attribute evidence
::attribute answeredBy

::method init
  use strict arg answerObject, explanation = "", disposition = "ANSWERED", evidence = .nil, answeredBy = ""
  if evidence == .nil then evidence = .array~new
  self~answerObject = answerObject
  self~explanation = explanation
  self~disposition = disposition~upper
  self~evidence = evidence
  self~answeredBy = answeredBy


::class LegalInterrogationAnswerReview public
::attribute decision
::attribute rationale
::attribute reviewedBy
::attribute evidence

::method init
  use strict arg decision, rationale = "", reviewedBy = "", evidence = .nil
  if evidence == .nil then evidence = .array~new
  self~decision = decision~upper
  self~rationale = rationale
  self~reviewedBy = reviewedBy
  self~evidence = evidence


::class LegalInterrogationQuestion public
::attribute id
::attribute kind
::attribute phase
::attribute text
::attribute subjectRef
::attribute required
::attribute expectedAnswerKind
::attribute uncertaintyKind
::attribute answer
::attribute answerHistory
::attribute reviewHistory
::attribute state
::attribute reopenReason

::method init
  use strict arg id, kind, phase, text, subjectRef = "", required = .true, expectedAnswerKind = "FREEFORM", uncertaintyKind = "SEMANTIC"
  self~id = id
  self~kind = kind~upper
  self~phase = phase~upper
  self~text = text
  self~subjectRef = subjectRef
  self~required = required
  self~expectedAnswerKind = expectedAnswerKind~upper
  self~uncertaintyKind = uncertaintyKind~upper
  self~answer = .nil
  self~answerHistory = .array~new
  self~reviewHistory = .array~new
  self~state = "OPEN"
  self~reopenReason = ""

::method answerQuestion
  use strict arg answer
  if \answer~isA(.LegalInterrogationAnswer) then return .LegalInterrogationResult~failure("BAD_ANSWER", "Expected LegalInterrogationAnswer")
  if self~state == "ACCEPTED" then return .LegalInterrogationResult~failure("QUESTION_CLOSED", self~id)
  allowed = " ANSWERED QUALIFIED REQUIRES_LEGAL_REVIEW AMBIGUOUS UNRESOLVED "
  if allowed~pos(" " || answer~disposition || " ") == 0 then return .LegalInterrogationResult~failure("BAD_ANSWER_DISPOSITION", answer~disposition)
  self~answer = answer
  self~answerHistory~append(answer)
  select
    when answer~disposition == "REQUIRES_LEGAL_REVIEW" then self~state = "REVIEW_REQUIRED"
    when answer~disposition == "AMBIGUOUS" then self~state = "REVIEW_REQUIRED"
    when answer~disposition == "UNRESOLVED" then self~state = "REVIEW_REQUIRED"
    otherwise self~state = "ANSWERED"
  end
  return .LegalInterrogationResult~success(self)

::method reviewAnswer
  use strict arg review
  if self~answer == .nil then return .LegalInterrogationResult~failure("UNANSWERED", self~id)
  if \review~isA(.LegalInterrogationAnswerReview) then return .LegalInterrogationResult~failure("BAD_REVIEW", self~id)
  allowed = " ACCEPT REVISE REJECT REQUIRES_LEGAL_REVIEW "
  if allowed~pos(" " || review~decision || " ") == 0 then return .LegalInterrogationResult~failure("BAD_REVIEW_DECISION", review~decision)
  self~reviewHistory~append(review)
  select
    when review~decision == "ACCEPT" then self~state = "ACCEPTED"
    when review~decision == "REVISE" then self~state = "OPEN"
    when review~decision == "REJECT" then self~state = "OPEN"
    when review~decision == "REQUIRES_LEGAL_REVIEW" then self~state = "REVIEW_REQUIRED"
    otherwise return .LegalInterrogationResult~failure("BAD_REVIEW_DECISION", review~decision)
  end
  return .LegalInterrogationResult~success(self)

::method accept
  if self~answer == .nil then return .LegalInterrogationResult~failure("UNANSWERED", self~id)
  if self~state == "REVIEW_REQUIRED" then return .LegalInterrogationResult~failure("REVIEW_REQUIRED", self~id)
  self~state = "ACCEPTED"
  return .LegalInterrogationResult~success(self)

::method reopen
  use strict arg reason = ""
  if self~state \== "ACCEPTED" then return .LegalInterrogationResult~failure("QUESTION_NOT_ACCEPTED", self~id)
  self~state = "OPEN"
  self~answer = .nil
  self~reopenReason = reason
  return .LegalInterrogationResult~success(self, "QUESTION_REOPENED", reason)


::class LegalInterrogationProposition public
::attribute id
::attribute clauseId
::attribute text
::attribute propositionKind
::attribute subject
::attribute predicate
::attribute object
::attribute modality
::attribute conditions
::attribute exceptions
::attribute evidence
::attribute state
::attribute rationale
::attribute challengeSeeded
::attribute supersededBy
::attribute supersessionReason

::method init
  use strict arg id, clauseId, text, propositionKind = "NORMATIVE", subject = "", predicate = "", object = "", modality = ""
  self~id = id
  self~clauseId = clauseId
  self~text = text
  self~propositionKind = propositionKind~upper
  self~subject = subject
  self~predicate = predicate
  self~object = object
  self~modality = modality~upper
  self~conditions = .array~new
  self~exceptions = .array~new
  self~evidence = .array~new
  self~state = "PROPOSED"
  self~rationale = ""
  self~challengeSeeded = .false
  self~supersededBy = ""
  self~supersessionReason = ""

::method addCondition
  use strict arg condition
  self~conditions~append(condition)
  return self

::method addException
  use strict arg exception
  self~exceptions~append(exception)
  return self

::method addEvidence
  use strict arg evidence
  self~evidence~append(evidence)
  return self

::method markChallengeSeeded
  self~challengeSeeded = .true
  return self

::method invalidate
  use strict arg rationale = ""
  if self~state == "SUPERSEDED" then return .LegalInterrogationResult~failure("PROPOSITION_SUPERSEDED", self~id)
  self~state = "STALE"
  self~rationale = rationale
  self~challengeSeeded = .false
  return .LegalInterrogationResult~success(self, "PROPOSITION_INVALIDATED", rationale)

::method supersede
  use strict arg replacementId = "", rationale = ""
  if self~state == "SUPERSEDED" then return .LegalInterrogationResult~failure("PROPOSITION_ALREADY_SUPERSEDED", self~id)
  self~state = "SUPERSEDED"
  self~supersededBy = replacementId
  self~supersessionReason = rationale
  return .LegalInterrogationResult~success(self, "PROPOSITION_SUPERSEDED", rationale)

::method isActive
  return self~state \== "SUPERSEDED"

::method resolve
  use strict arg state, rationale = ""
  if self~state == "SUPERSEDED" then return .LegalInterrogationResult~failure("PROPOSITION_SUPERSEDED", self~id)
  state = state~upper
  allowed = " SUPPORTED PARTIALLY_SUPPORTED CONTRADICTED UNRESOLVED REQUIRES_LEGAL_REVIEW "
  if allowed~pos(" " || state || " ") == 0 then return .LegalInterrogationResult~failure("BAD_PROPOSITION_STATE", state)
  self~state = state
  self~rationale = rationale
  return .LegalInterrogationResult~success(self)


::class LegalPropositionTest public
::attribute id
::attribute clauseId
::attribute propositionId
::attribute testKind
::attribute assertion
::attribute reason
::attribute evidence
::attribute superseded
::attribute supersededByPropositionId
::attribute supersessionReason

::method result
  expose testOutcome
  return testOutcome

::method init
  expose testOutcome
  use strict arg id, clauseId, propositionId, testKind, assertion
  self~id = id
  self~clauseId = clauseId
  self~propositionId = propositionId
  self~testKind = testKind~upper
  self~assertion = assertion
  testOutcome = "UNRESOLVED"
  self~reason = ""
  self~evidence = .array~new
  self~superseded = .false
  self~supersededByPropositionId = ""
  self~supersessionReason = ""

::method invalidate
  expose testOutcome
  use strict arg reason = ""
  if self~superseded then return .LegalInterrogationResult~failure("TEST_SUPERSEDED", self~id)
  testOutcome = "STALE"
  self~reason = reason
  return .LegalInterrogationResult~success(self, "TEST_INVALIDATED", reason)

::method supersede
  use strict arg replacementPropositionId = "", reason = ""
  self~superseded = .true
  self~supersededByPropositionId = replacementPropositionId
  self~supersessionReason = reason
  return .LegalInterrogationResult~success(self, "TEST_SUPERSEDED", reason)

::method resolve
  expose testOutcome
  use strict arg outcome, reason = "", evidence = .nil
  if self~superseded then return .LegalInterrogationResult~failure("TEST_SUPERSEDED", self~id)
  outcome = outcome~upper
  allowed = " SUPPORTED CONTRADICTED PARTIALLY_SUPPORTED CONDITIONALLY_SUPPORTED UNRESOLVED REQUIRES_LEGAL_REVIEW "
  if allowed~pos(" " || outcome || " ") == 0 then return .LegalInterrogationResult~failure("BAD_TEST_RESULT", outcome)
  testOutcome = outcome
  self~reason = reason
  if evidence \== .nil then self~evidence = evidence
  return .LegalInterrogationResult~success(self)


::class LegalInterrogationClause public
::attribute id
::attribute sourceObject
::attribute sourceLocator
::attribute exactText
::attribute questions
::attribute propositions
::attribute propositionTests
::attribute notes
::attribute baseQuestionsSeeded

::method init
  use strict arg id, sourceObject, sourceLocator, exactText
  self~id = id
  self~sourceObject = sourceObject
  self~sourceLocator = sourceLocator
  self~exactText = exactText
  self~questions = .array~new
  self~propositions = .array~new
  self~propositionTests = .array~new
  self~notes = .array~new
  self~baseQuestionsSeeded = .false

::method addQuestion
  use strict arg question
  if \question~isA(.LegalInterrogationQuestion) then return .LegalInterrogationResult~failure("BAD_QUESTION", self~id)
  if self~questionById(question~id) \== .nil then return .LegalInterrogationResult~failure("DUPLICATE_QUESTION", question~id)
  self~questions~append(question)
  return .LegalInterrogationResult~success(question)

::method addProposition
  use strict arg proposition
  if \proposition~isA(.LegalInterrogationProposition) then return .LegalInterrogationResult~failure("BAD_PROPOSITION", self~id)
  if proposition~clauseId \== self~id then return .LegalInterrogationResult~failure("WRONG_CLAUSE", proposition~id)
  if self~propositionById(proposition~id) \== .nil then return .LegalInterrogationResult~failure("DUPLICATE_PROPOSITION", proposition~id)
  self~propositions~append(proposition)
  return .LegalInterrogationResult~success(proposition)

::method addPropositionTest
  use strict arg test
  if \test~isA(.LegalPropositionTest) then return .LegalInterrogationResult~failure("BAD_TEST", self~id)
  if test~clauseId \== self~id then return .LegalInterrogationResult~failure("WRONG_CLAUSE", test~id)
  self~propositionTests~append(test)
  return .LegalInterrogationResult~success(test)

::method questionById
  use strict arg id
  do q over self~questions
    if q~id == id then return q
  end
  return .nil

::method propositionById
  use strict arg id
  do p over self~propositions
    if p~id == id then return p
  end
  return .nil

::method propositionTestById
  use strict arg id
  do t over self~propositionTests
    if t~id == id then return t
  end
  return .nil

::method activePropositions
  a = .array~new
  do p over self~propositions
    if p~isActive then a~append(p)
  end
  return a

::method supersededPropositions
  a = .array~new
  do p over self~propositions
    if \p~isActive then a~append(p)
  end
  return a

::method invalidateDerivedSemantics
  use strict arg reason = ""
  do p over self~propositions
    if p~isActive then p~invalidate(reason)
  end
  do t over self~propositionTests
    if \t~superseded then t~invalidate(reason)
  end
  return .LegalInterrogationResult~success(self, "CLAUSE_SEMANTICS_INVALIDATED", reason)

::method supersedeProposition
  use strict arg propositionId, replacementId = "", reason = ""
  if replacementId == propositionId then return .LegalInterrogationResult~failure("SELF_SUPERSESSION", propositionId)
  old = self~propositionById(propositionId)
  if old == .nil then return .LegalInterrogationResult~failure("PROPOSITION_NOT_FOUND", propositionId)
  if replacementId \== "" then do
    replacement = self~propositionById(replacementId)
    if replacement == .nil then return .LegalInterrogationResult~failure("REPLACEMENT_PROPOSITION_NOT_FOUND", replacementId)
    if \replacement~isActive then return .LegalInterrogationResult~failure("REPLACEMENT_PROPOSITION_SUPERSEDED", replacementId)
  end
  r = old~supersede(replacementId, reason)
  if \r~ok then return r
  do t over self~propositionTests
    if t~propositionId == propositionId then t~supersede(replacementId, reason)
  end
  return .LegalInterrogationResult~success(old, "PROPOSITION_SUPERSEDED", reason)

::method openRequiredQuestions
  a = .array~new
  do q over self~questions
    if q~required, q~state \== "ACCEPTED" then a~append(q)
  end
  return a

::method reviewQuestions
  a = .array~new
  do q over self~questions
    if q~state == "REVIEW_REQUIRED" then a~append(q)
  end
  return a

::method unresolvedPropositions
  a = .array~new
  do p over self~propositions
    if p~isActive then do
      if p~state == "PROPOSED" | p~state == "UNRESOLVED" | p~state == "REQUIRES_LEGAL_REVIEW" | p~state == "STALE" then a~append(p)
    end
  end
  return a

::method unresolvedTests
  a = .array~new
  do t over self~propositionTests
    if \t~superseded then do
      if t~result == "UNRESOLVED" | t~result == "REQUIRES_LEGAL_REVIEW" | t~result == "STALE" then a~append(t)
    end
  end
  return a

::method semanticReviewRequired
  do q over self~questions
    if q~state == "REVIEW_REQUIRED", q~uncertaintyKind == "SEMANTIC" then return .true
  end
  do p over self~propositions
    if p~isActive, p~state == "REQUIRES_LEGAL_REVIEW" then return .true
  end
  do t over self~propositionTests
    if \t~superseded, t~result == "REQUIRES_LEGAL_REVIEW" then return .true
  end
  return .false

::method closureState
  if self~semanticReviewRequired then return "REVIEW_REQUIRED"
  if self~openRequiredQuestions~items > 0 then return "INCOMPLETE"
  active = self~activePropositions
  if active~items == 0 then return "INCOMPLETE"
  do p over active
    if \p~challengeSeeded then return "INCOMPLETE"
  end
  if self~unresolvedPropositions~items > 0 then return "INCOMPLETE"
  if self~unresolvedTests~items > 0 then return "INCOMPLETE"
  qualified = .false
  do q over self~questions
    if q~answer \== .nil then do
      if q~answer~disposition == "QUALIFIED" then qualified = .true
    end
  end
  do p over active
    if p~state == "PARTIALLY_SUPPORTED" then qualified = .true
    if p~state == "CONTRADICTED" then return "REVIEW_REQUIRED"
  end
  do t over self~propositionTests
    if \t~superseded then if t~result == "PARTIALLY_SUPPORTED" | t~result == "CONDITIONALLY_SUPPORTED" then qualified = .true
  end
  if qualified then return "ESTABLISHED_WITH_QUALIFICATIONS"
  return "ESTABLISHED"

::method eligibleForCompilation
  s = self~closureState
  return s == "ESTABLISHED" | s == "ESTABLISHED_WITH_QUALIFICATIONS"


::class LegalInterrogationSession public
::attribute id
::attribute sourceIdentity
::attribute sourceObject
::attribute documentKind
::attribute clauses
::attribute crossClauseQuestions
::attribute state
::attribute reconciliationSeeded
::attribute negotiationHistory
::attribute sourceLocator
::attribute sourceEvidence
::attribute revision
::attribute lastMutation

::method init
  use strict arg id, sourceIdentity, sourceObject, documentKind = "UNKNOWN", sourceLocator = "", sourceEvidence = .nil
  self~id = id
  self~sourceIdentity = sourceIdentity
  self~sourceObject = sourceObject
  self~documentKind = documentKind~upper
  self~clauses = .array~new
  self~crossClauseQuestions = .array~new
  self~state = "AUTHORING"
  self~reconciliationSeeded = .false
  self~negotiationHistory = .array~new
  self~sourceLocator = sourceLocator
  if sourceEvidence == .nil then sourceEvidence = .array~new
  self~sourceEvidence = sourceEvidence
  self~revision = 0
  self~lastMutation = ""

::method addNegotiationRecord
  use strict arg record
  self~negotiationHistory~append(record)
  return record

::method touch
  use strict arg reason = ""
  self~revision = self~revision + 1
  self~lastMutation = reason
  return self~revision

::method addClause
  use strict arg clause
  if \clause~isA(.LegalInterrogationClause) then return .LegalInterrogationResult~failure("BAD_CLAUSE", self~id)
  if self~clauseById(clause~id) \== .nil then return .LegalInterrogationResult~failure("DUPLICATE_CLAUSE", clause~id)
  self~clauses~append(clause)
  return .LegalInterrogationResult~success(clause)

::method addCrossClauseQuestion
  use strict arg question
  self~crossClauseQuestions~append(question)
  return .LegalInterrogationResult~success(question)

::method clauseById
  use strict arg id
  do c over self~clauses
    if c~id == id then return c
  end
  return .nil

::method openCrossClauseQuestions
  a = .array~new
  do q over self~crossClauseQuestions
    if q~required, q~state \== "ACCEPTED" then a~append(q)
  end
  return a

::method closureState
  if self~clauses~items == 0 then return "INCOMPLETE"
  qualified = .false
  do c over self~clauses
    s = c~closureState
    if s == "REVIEW_REQUIRED" then return "REVIEW_REQUIRED"
    if s == "INCOMPLETE" then return "INCOMPLETE"
    if s == "ESTABLISHED_WITH_QUALIFICATIONS" then qualified = .true
  end
  if \self~reconciliationSeeded then return "INCOMPLETE"
  do q over self~crossClauseQuestions
    if q~state == "REVIEW_REQUIRED" then return "REVIEW_REQUIRED"
    if q~required, q~state \== "ACCEPTED" then return "INCOMPLETE"
    if q~answer \== .nil then if q~answer~disposition == "QUALIFIED" then qualified = .true
  end
  if qualified then return "ESTABLISHED_WITH_QUALIFICATIONS"
  return "ESTABLISHED"

::method eligibleForCompilation
  s = self~closureState
  return s == "ESTABLISHED" | s == "ESTABLISHED_WITH_QUALIFICATIONS"


::class LegalInterrogationIntention public
::attribute name
::attribute subjectRef
::attribute reason
::attribute priority

::method init
  use strict arg name, subjectRef = "", reason = "", priority = 100
  self~name = name~upper
  self~subjectRef = subjectRef
  self~reason = reason
  self~priority = priority


::class LegalInterrogationIntentionProvider public
::method discover
  use strict arg session
  intentions = .array~new
  if \session~isA(.LegalInterrogationSession) then return intentions

  if session~clauses~items == 0 then do
    intentions~append(.LegalInterrogationIntention~new("INGEST_CLAUSE", session~id, "No clauses have been captured", 10))
    return intentions
  end

  do clause over session~clauses
    open = clause~openRequiredQuestions
    if open~items > 0 then do
      q = open[1]
      select
        when q~state == "ANSWERED" then intentions~append(.LegalInterrogationIntention~new("REVIEW_" || q~kind, q~id, "Review the proposed answer before it enters the legal record: " || q~text, 20))
        when q~state == "REVIEW_REQUIRED" then intentions~append(.LegalInterrogationIntention~new("REFER_LEGAL_REVIEW", q~id, q~text, 20))
        otherwise intentions~append(.LegalInterrogationIntention~new("ANSWER_" || q~kind, q~id, q~text, 20))
      end
      iterate
    end
    if clause~propositions~items == 0 then do
      intentions~append(.LegalInterrogationIntention~new("PROPOSE_LEGAL_PROPOSITION", clause~id, "Clause has no structured proposition", 30))
      iterate
    end
    challengeFound = .false
    do p over clause~propositions
      if \p~challengeSeeded then do
        intentions~append(.LegalInterrogationIntention~new("CHALLENGE_PROPOSITION", p~id, "Proposition has not yet passed structured challenge", 40))
        challengeFound = .true
        leave
      end
    end
    if challengeFound then iterate
    if clause~unresolvedPropositions~items > 0 then do
      p = clause~unresolvedPropositions[1]
      intentions~append(.LegalInterrogationIntention~new("RESOLVE_PROPOSITION", p~id, "Proposition has not been established", 45))
      iterate
    end
    if clause~unresolvedTests~items > 0 then do
      t = clause~unresolvedTests[1]
      intentions~append(.LegalInterrogationIntention~new("RESOLVE_PROPOSITION_TEST", t~id, t~assertion, 50))
      iterate
    end
    if clause~closureState == "REVIEW_REQUIRED" then do
      intentions~append(.LegalInterrogationIntention~new("REFER_LEGAL_REVIEW", clause~id, "Semantic uncertainty or contradiction remains", 60))
      iterate
    end
  end

  clausesReady = .true
  do clause over session~clauses
    cs = clause~closureState
    if cs == "INCOMPLETE" | cs == "REVIEW_REQUIRED" then clausesReady = .false
  end
  if clausesReady then do
    if \session~reconciliationSeeded then do
      intentions~append(.LegalInterrogationIntention~new("START_DOCUMENT_RECONCILIATION", session~id, "Cross-clause reconciliation has not been seeded", 65))
    end
    else if session~openCrossClauseQuestions~items > 0 then do
      q = session~openCrossClauseQuestions[1]
      select
        when q~state == "ANSWERED" then intentions~append(.LegalInterrogationIntention~new("REVIEW_" || q~kind, q~id, "Review reconciliation answer: " || q~text, 70))
        when q~state == "REVIEW_REQUIRED" then intentions~append(.LegalInterrogationIntention~new("REFER_LEGAL_REVIEW", q~id, q~text, 70))
        otherwise intentions~append(.LegalInterrogationIntention~new("ANSWER_" || q~kind, q~id, q~text, 70))
      end
    end
  end

  if session~eligibleForCompilation then intentions~append(.LegalInterrogationIntention~new("HANDOFF_LEGAL_COMPILATION", session~id, "Interrogation closure established", 90))
  return intentions


::class LegalInterrogationQuestionSnapshot public
::attribute id
::attribute kind
::attribute phase
::attribute text
::attribute subjectRef
::attribute state
::attribute answerObject
::attribute answerExplanation
::attribute answerDisposition
::attribute answerEvidence
::attribute answeredBy
::attribute reviewDecision
::attribute reviewRationale
::attribute reviewEvidence
::attribute reviewedBy
::method init
  use strict arg question
  self~id = question~id; self~kind = question~kind; self~phase = question~phase
  self~text = question~text; self~subjectRef = question~subjectRef; self~state = question~state
  self~answerObject = .nil; self~answerExplanation = ""; self~answerDisposition = ""; self~answerEvidence = .array~new; self~answeredBy = ""
  self~reviewDecision = ""; self~reviewRationale = ""; self~reviewEvidence = .array~new; self~reviewedBy = ""
  if question~answer \== .nil then do
    self~answerObject = question~answer~answerObject
    self~answerExplanation = question~answer~explanation
    self~answerDisposition = question~answer~disposition
    self~answeredBy = question~answer~answeredBy
    do item over question~answer~evidence; self~answerEvidence~append(item); end
  end
  if question~reviewHistory~items > 0 then do
    review = question~reviewHistory[question~reviewHistory~items]
    self~reviewDecision = review~decision; self~reviewRationale = review~rationale; self~reviewedBy = review~reviewedBy
    do item over review~evidence; self~reviewEvidence~append(item); end
  end

::class LegalInterrogationPropositionSnapshot public
::attribute id
::attribute clauseId
::attribute text
::attribute propositionKind
::attribute subject
::attribute predicate
::attribute object
::attribute modality
::attribute conditions
::attribute exceptions
::attribute evidence
::attribute state
::attribute rationale
::attribute supersededBy
::attribute supersessionReason
::method init
  use strict arg proposition
  self~id = proposition~id; self~clauseId = proposition~clauseId; self~text = proposition~text
  self~propositionKind = proposition~propositionKind; self~subject = proposition~subject; self~predicate = proposition~predicate
  self~object = proposition~object; self~modality = proposition~modality; self~state = proposition~state; self~rationale = proposition~rationale
  self~supersededBy = proposition~supersededBy; self~supersessionReason = proposition~supersessionReason
  self~conditions = .array~new; do item over proposition~conditions; self~conditions~append(item); end
  self~exceptions = .array~new; do item over proposition~exceptions; self~exceptions~append(item); end
  self~evidence = .array~new; do item over proposition~evidence; self~evidence~append(item); end

::class LegalInterrogationTestSnapshot public
::attribute id
::attribute clauseId
::attribute propositionId
::attribute testKind
::attribute assertion
::attribute reason
::attribute evidence
::attribute superseded
::attribute supersededByPropositionId
::method result
  expose testOutcome
  return testOutcome
::method init
  expose testOutcome
  use strict arg test
  self~id = test~id; self~clauseId = test~clauseId; self~propositionId = test~propositionId
  self~testKind = test~testKind; self~assertion = test~assertion; testOutcome = test~result; self~reason = test~reason
  self~superseded = test~superseded; self~supersededByPropositionId = test~supersededByPropositionId
  self~evidence = .array~new; do item over test~evidence; self~evidence~append(item); end

::class LegalInterrogationClauseSnapshot public
::attribute id
::attribute sourceObject
::attribute sourceLocator
::attribute exactText
::attribute closureState
::attribute questions
::attribute propositions
::attribute supersededPropositions
::attribute propositionTests
::method init
  use strict arg clause
  self~id = clause~id; self~sourceObject = clause~sourceObject; self~sourceLocator = clause~sourceLocator; self~exactText = clause~exactText
  self~closureState = clause~closureState
  self~questions = .array~new
  do q over clause~questions; self~questions~append(.LegalInterrogationQuestionSnapshot~new(q)); end
  self~propositions = .array~new
  do p over clause~activePropositions; self~propositions~append(.LegalInterrogationPropositionSnapshot~new(p)); end
  self~supersededPropositions = .array~new
  do p over clause~supersededPropositions; self~supersededPropositions~append(.LegalInterrogationPropositionSnapshot~new(p)); end
  self~propositionTests = .array~new
  do t over clause~propositionTests; self~propositionTests~append(.LegalInterrogationTestSnapshot~new(t)); end

::class LegalInterrogationCompileHandoff public
::attribute session
::attribute sessionId
::attribute handoffRevision
::attribute sourceIdentity
::attribute sourceObject
::attribute sourceLocator
::attribute sourceEvidence
::attribute clauses
::attribute reconciliation
::attribute closureState
::attribute authoritative

::method init
  use strict arg session
  self~session = session
  self~sessionId = session~id
  self~handoffRevision = session~revision
  self~sourceIdentity = session~sourceIdentity
  self~sourceObject = session~sourceObject
  self~sourceLocator = session~sourceLocator
  self~sourceEvidence = .array~new; do item over session~sourceEvidence; self~sourceEvidence~append(item); end
  self~clauses = .array~new; do clause over session~clauses; self~clauses~append(.LegalInterrogationClauseSnapshot~new(clause)); end
  self~reconciliation = .array~new; do q over session~crossClauseQuestions; self~reconciliation~append(.LegalInterrogationQuestionSnapshot~new(q)); end
  self~closureState = session~closureState
  self~authoritative = .false

::method stale
  return self~session~revision \== self~handoffRevision

::method emitWith
  use strict arg adapter
  if self~stale then return .LegalInterrogationResult~failure("STALE_HANDOFF", "Session revision changed after handoff")
  if \self~session~eligibleForCompilation then return .LegalInterrogationResult~failure("NOT_READY_FOR_COMPILATION", self~session~closureState)
  if \adapter~hasMethod("BUILDLEGALCOMPILEPROPOSAL") then return .LegalInterrogationResult~failure("BAD_COMPILE_ADAPTER", "Adapter must implement buildLegalCompileProposal(handoff)")
  proposal = adapter~buildLegalCompileProposal(self)
  if proposal~isA(.LegalInterrogationResult) then return proposal
  return .LegalInterrogationResult~success(proposal, "COMPILE_PROPOSAL_CREATED", "Proposal remains non-authoritative until accepted by Legal Effect compiler")


::class LegalInterrogationDirector public
::attribute questionSerial
::attribute propositionSerial
::attribute testSerial

::method init
  self~questionSerial = 0
  self~propositionSerial = 0
  self~testSerial = 0

::method seedClauseQuestions
  use strict arg clause
  if clause~baseQuestionsSeeded then return .LegalInterrogationResult~failure("INTERROGATION_ALREADY_SEEDED", clause~id)
  specs = .array~new
  specs~append("EXPLAIN_CLAUSE|MEANING|Explain this clause in neutral terms without adding facts not present in the source.|FREEFORM|SEMANTIC")
  specs~append("WHO_AFFECTED|SCOPE|Who does this clause affect, and who acquires a right, duty, power, permission or exposure?|PARTY_SET|SEMANTIC")
  specs~append("CAPACITY|SCOPE|In what legal capacity does each affected actor appear here?|FREEFORM|SEMANTIC")
  specs~append("CLASSIFY_EFFECT|MEANING|What kind of legal proposition is asserted: obligation, prohibition, permission, right, power, status, contract term, definition, condition or other?|CLASSIFICATION|SEMANTIC")
  specs~append("TRIGGER|LOGIC|What event, state or act triggers the proposed effect?|FREEFORM|SEMANTIC")
  specs~append("CONDITIONS|LOGIC|What conditions must hold before the proposed effect applies?|FREEFORM|SEMANTIC")
  specs~append("EXCEPTIONS|LOGIC|What exceptions, carve-outs or exclusions prevent the proposed effect from applying?|FREEFORM|SEMANTIC")
  specs~append("DEFINITIONS|DEPENDENCY|Which defined terms materially control the proposed meaning, and where are they defined?|FREEFORM|SEMANTIC")
  specs~append("DEPENDENCIES|DEPENDENCY|Which other clauses, schedules, instruments or external rules are required to interpret this clause?|FREEFORM|SEMANTIC")
  specs~append("CONSEQUENCE_COMPLIANCE|CONSEQUENCE|What legal consequence is proposed if the clause is satisfied or complied with?|FREEFORM|SEMANTIC")
  specs~append("CONSEQUENCE_BREACH|CONSEQUENCE|What legal consequence is proposed if the clause is breached or its condition fails?|FREEFORM|SEMANTIC")
  specs~append("UNCERTAINTY|MEANING|What remains ambiguous, undefined, fact-dependent or in need of legal review?|FREEFORM|SEMANTIC")

  do spec over specs
    parse var spec kind '|' phase '|' text '|' expected '|' uncertainty
    q = self~newQuestion(kind, phase, text, clause~id, .true, expected, uncertainty)
    clause~addQuestion(q)
  end
  clause~baseQuestionsSeeded = .true
  return .LegalInterrogationResult~success(clause)

::method newQuestion
  use strict arg kind, phase, text, subjectRef = "", required = .true, expected = "FREEFORM", uncertainty = "SEMANTIC"
  self~questionSerial = self~questionSerial + 1
  id = "Q" || self~questionSerial
  return .LegalInterrogationQuestion~new(id, kind, phase, text, subjectRef, required, expected, uncertainty)

::method newProposition
  use strict arg clause, text, propositionKind = "NORMATIVE", subject = "", predicate = "", object = "", modality = ""
  self~propositionSerial = self~propositionSerial + 1
  id = "P" || self~propositionSerial
  p = .LegalInterrogationProposition~new(id, clause~id, text, propositionKind, subject, predicate, object, modality)
  r = clause~addProposition(p)
  if \r~ok then return r
  return .LegalInterrogationResult~success(p)

::method challengeProposition
  use strict arg clause, proposition
  if proposition~challengeSeeded then return .LegalInterrogationResult~failure("CHALLENGE_ALREADY_SEEDED", proposition~id)
  prompts = .array~new
  prompts~append("SOURCE_SUPPORT|What exact source language supports proposition " || proposition~id || "?")
  prompts~append("CONDITION_COMPLETENESS|Have all conditions on proposition " || proposition~id || " been captured?")
  prompts~append("EXCEPTION_COMPLETENESS|Have all exceptions or carve-outs to proposition " || proposition~id || " been captured?")
  prompts~append("CONVERSE_TEST|Does the converse of proposition " || proposition~id || " also follow, or would that add meaning not present in the source?")
  prompts~append("NECESSITY_TEST|Is the stated antecedent necessary for the consequence in proposition " || proposition~id || "?")
  prompts~append("SUFFICIENCY_TEST|Is the stated antecedent sufficient for the consequence in proposition " || proposition~id || "?")
  prompts~append("FALSIFICATION_TEST|What source text or fact would make proposition " || proposition~id || " false or inapplicable?")
  do prompt over prompts
    parse var prompt kind '|' text
    q = self~newQuestion(kind, "LOGIC", text, proposition~id, .true, "FREEFORM", "SEMANTIC")
    clause~addQuestion(q)
  end
  proposition~markChallengeSeeded
  return .LegalInterrogationResult~success(proposition)

::method newPropositionTest
  use strict arg clause, proposition, testKind, assertion
  if \proposition~isActive then return .LegalInterrogationResult~failure("PROPOSITION_SUPERSEDED", proposition~id)
  self~testSerial = self~testSerial + 1
  id = "T" || self~testSerial
  t = .LegalPropositionTest~new(id, clause~id, proposition~id, testKind, assertion)
  r = clause~addPropositionTest(t)
  if \r~ok then return r
  return .LegalInterrogationResult~success(t)

::method seedDocumentReconciliation
  use strict arg session
  if session~reconciliationSeeded then return .LegalInterrogationResult~failure("RECONCILIATION_ALREADY_SEEDED", session~id)
  specs = .array~new
  specs~append("CROSS_DEFINITION|Do definitions elsewhere in the document alter any established clause proposition?")
  specs~append("CROSS_EXCEPTION|Does another clause create an exception, carve-out or special case to an established proposition?")
  specs~append("CROSS_PRECEDENCE|Does any precedence, order-of-precedence or conflict clause alter which proposition controls?")
  specs~append("CROSS_SURVIVAL|Do termination, survival, expiry or amendment provisions change when any established effect operates?")
  specs~append("CROSS_CONSISTENCY|Do any established clause propositions conflict when evaluated together?")
  do spec over specs
    parse var spec kind '|' text
    q = self~newQuestion(kind, "RECONCILIATION", text, session~id, .true, "FREEFORM", "SEMANTIC")
    session~addCrossClauseQuestion(q)
  end
  session~reconciliationSeeded = .true
  return .LegalInterrogationResult~success(session)

::method makeHandoff
  use strict arg session
  if \session~eligibleForCompilation then return .LegalInterrogationResult~failure("NOT_READY_FOR_COMPILATION", session~closureState)
  return .LegalInterrogationResult~success(.LegalInterrogationCompileHandoff~new(session), "HANDOFF_READY", "Non-authoritative authoring handoff")
