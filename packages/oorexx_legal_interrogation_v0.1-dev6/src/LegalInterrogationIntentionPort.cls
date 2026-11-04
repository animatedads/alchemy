/* Dynamic intention-negotiated front door for Legal Interrogation. */

::class LegalInterrogationPropositionDraft public
::attribute text
::attribute propositionKind
::attribute subject
::attribute predicate
::attribute object
::attribute modality
::attribute conditions
::attribute exceptions
::attribute evidence
::method init
  use strict arg text, propositionKind = "NORMATIVE", subject = "", predicate = "", object = "", modality = ""
  self~text = text; self~propositionKind = propositionKind; self~subject = subject
  self~predicate = predicate; self~object = object; self~modality = modality
  self~conditions = .array~new; self~exceptions = .array~new; self~evidence = .array~new
::method addCondition
  use strict arg condition
  self~conditions~append(condition); return self
::method addException
  use strict arg exception
  self~exceptions~append(exception); return self
::method addEvidence
  use strict arg evidence
  self~evidence~append(evidence); return self

::class LegalInterrogationPropositionResolution public
::attribute state
::attribute rationale
::method init
  use strict arg state, rationale = ""
  self~state = state~upper; self~rationale = rationale

::class LegalInterrogationSupersessionRequest public
::attribute replacementPropositionId
::attribute rationale
::method init
  use strict arg replacementPropositionId = "", rationale = ""
  self~replacementPropositionId = replacementPropositionId
  self~rationale = rationale

::class LegalInterrogationTestDraft public
::attribute propositionId
::attribute testKind
::attribute assertion
::method init
  use strict arg propositionId, testKind, assertion
  self~propositionId = propositionId; self~testKind = testKind~upper; self~assertion = assertion

::class LegalInterrogationTestResolution public
::attribute reason
::attribute evidence
::method result
  expose testOutcome
  return testOutcome
::method init
  expose testOutcome
  use strict arg outcome, reason = "", evidence = .nil
  if evidence == .nil then evidence = .array~new
  testOutcome = outcome~upper; self~reason = reason; self~evidence = evidence

::class LegalInterrogationNegotiationRecord public
::attribute serial
::attribute intentionName
::attribute subjectRef
::attribute actor
::attribute payload
::attribute resultCode
::attribute resultDetail
::attribute beforeState
::attribute afterState
::attribute beforeRevision
::attribute afterRevision
::method init
  use strict arg serial, intentionName, subjectRef, actor, payload, resultCode, resultDetail, beforeState, afterState, beforeRevision, afterRevision
  self~serial = serial; self~intentionName = intentionName; self~subjectRef = subjectRef
  self~actor = actor; self~payload = payload; self~resultCode = resultCode; self~resultDetail = resultDetail
  self~beforeState = beforeState; self~afterState = afterState
  self~beforeRevision = beforeRevision; self~afterRevision = afterRevision

::class LegalInterrogationIntentionSurface public
::attribute providerId
::attribute authority
::attribute generation
::attribute session
::attribute intentions
::attribute queryOperations
::attribute closureState
::method init
  use strict arg providerId, authority, generation, session, intentions, queryOperations
  self~providerId = providerId; self~authority = authority; self~generation = generation
  self~session = session; self~intentions = intentions; self~queryOperations = queryOperations
  self~closureState = session~closureState

::class LegalInterrogationIntentionPort public
::attribute director
::attribute provider
::attribute generation
::attribute executionSerial
::method init
  use strict arg director = .nil, provider = .nil
  if director == .nil then director = .LegalInterrogationDirector~new
  if provider == .nil then provider = .LegalInterrogationIntentionProvider~new
  self~director = director; self~provider = provider; self~generation = 0; self~executionSerial = 0
::method id
  return "legal.interrogation.intentions/0.1"
::method authority
  return "legal.interrogation"
::method objectKinds
  a = .array~new
  a~append("LEGAL_INTERROGATION_SESSION"); a~append("LEGAL_INTERROGATION_CLAUSE")
  a~append("LEGAL_INTERROGATION_PROPOSITION"); a~append("LEGAL_PROPOSITION_TEST")
  return a
::method discover
  use strict arg session
  if \session~isA(.LegalInterrogationSession) then return .LegalInterrogationResult~failure("BAD_SESSION", "LegalInterrogationSession required")
  self~generation = self~generation + 1
  mandatory = self~provider~discover(session)
  queries = .array~new
  do clause over session~clauses
    do q over clause~questions
      if q~state == "ACCEPTED" then queries~append(.LegalInterrogationIntention~new("REOPEN_QUESTION", q~id, "Reopen an accepted answer; downstream clause semantics will be invalidated and must be re-established", 180))
    end
    do proposition over clause~activePropositions
      queries~append(.LegalInterrogationIntention~new("TEST_LEGAL_PROPOSITION", proposition~id, "Test an explicit implication, converse, necessity, sufficiency or other asserted relation against this proposition", 200))
      queries~append(.LegalInterrogationIntention~new("SUPERSEDE_LEGAL_PROPOSITION", proposition~id, "Supersede this proposition with another proposition while retaining audit history", 210))
    end
  end
  do q over session~crossClauseQuestions
    if q~state == "ACCEPTED" then queries~append(.LegalInterrogationIntention~new("REOPEN_QUESTION", q~id, "Reopen an accepted reconciliation answer", 220))
  end
  queries~append(.LegalInterrogationIntention~new("EXPLAIN_INTERROGATION_STATE", session~id, "Inspect current interrogation closure and unresolved work without changing it", 250))
  return .LegalInterrogationResult~success(.LegalInterrogationIntentionSurface~new(self~id, self~authority, self~generation, session, mandatory, queries), "DISCOVERED", "Dynamic intention surface")
::method execute
  use strict arg session, intention, payload = .nil, actor = "", subjectRef = ""
  if \session~isA(.LegalInterrogationSession) then return .LegalInterrogationResult~failure("BAD_SESSION", "LegalInterrogationSession required")
  if intention~isA(.LegalInterrogationIntention) then do
    name = intention~name; subjectRef = intention~subjectRef
  end
  else name = intention~string~upper
  before = session~closureState; beforeRevision = session~revision; opResult = .nil
  select
    when name == "INGEST_CLAUSE" then do
      if payload == .nil then opResult = .LegalInterrogationResult~failure("MISSING_CLAUSE", subjectRef)
      else if \payload~isA(.LegalInterrogationClause) then opResult = .LegalInterrogationResult~failure("BAD_CLAUSE", subjectRef)
      else do
        opResult = session~addClause(payload)
        if opResult~ok then opResult = self~director~seedClauseQuestions(payload)
      end
    end
    when name~left(7) == "ANSWER_" then do
      q = self~questionById(session, subjectRef)
      if q == .nil then opResult = .LegalInterrogationResult~failure("QUESTION_NOT_FOUND", subjectRef)
      else do
        if payload \== .nil, payload~isA(.LegalInterrogationAnswer) then answer = payload
        else answer = .LegalInterrogationAnswer~new(payload, "", "ANSWERED", .array~new, actor)
        opResult = q~answerQuestion(answer)
      end
    end
    when name~left(7) == "REVIEW_" then do
      q = self~questionById(session, subjectRef)
      if q == .nil then opResult = .LegalInterrogationResult~failure("QUESTION_NOT_FOUND", subjectRef)
      else do
        if payload \== .nil, payload~isA(.LegalInterrogationAnswerReview) then review = payload
        else review = .LegalInterrogationAnswerReview~new(payload, "", actor, .array~new)
        opResult = q~reviewAnswer(review)
      end
    end
    when name == "REOPEN_QUESTION" then do
      q = self~questionById(session, subjectRef)
      if q == .nil then opResult = .LegalInterrogationResult~failure("QUESTION_NOT_FOUND", subjectRef)
      else do
        reason = ""
        if payload \== .nil then reason = payload~string
        opResult = q~reopen(reason)
        if opResult~ok then do
          clause = self~clauseForQuestion(session, subjectRef)
          if clause \== .nil then clause~invalidateDerivedSemantics("Accepted question " || subjectRef || " was reopened: " || reason)
        end
      end
    end
    when name == "PROPOSE_LEGAL_PROPOSITION" then do
      clause = session~clauseById(subjectRef)
      if clause == .nil then opResult = .LegalInterrogationResult~failure("CLAUSE_NOT_FOUND", subjectRef)
      else if payload == .nil then opResult = .LegalInterrogationResult~failure("MISSING_PROPOSITION_DRAFT", subjectRef)
      else if \payload~isA(.LegalInterrogationPropositionDraft) then opResult = .LegalInterrogationResult~failure("BAD_PROPOSITION_DRAFT", subjectRef)
      else do
        opResult = self~director~newProposition(clause, payload~text, payload~propositionKind, payload~subject, payload~predicate, payload~object, payload~modality)
        if opResult~ok then do
          proposition = opResult~value
          do item over payload~conditions; proposition~addCondition(item); end
          do item over payload~exceptions; proposition~addException(item); end
          do item over payload~evidence; proposition~addEvidence(item); end
        end
      end
    end
    when name == "CHALLENGE_PROPOSITION" then do
      proposition = self~propositionById(session, subjectRef)
      if proposition == .nil then opResult = .LegalInterrogationResult~failure("PROPOSITION_NOT_FOUND", subjectRef)
      else opResult = self~director~challengeProposition(session~clauseById(proposition~clauseId), proposition)
    end
    when name == "RESOLVE_PROPOSITION" then do
      proposition = self~propositionById(session, subjectRef)
      if proposition == .nil then opResult = .LegalInterrogationResult~failure("PROPOSITION_NOT_FOUND", subjectRef)
      else if payload == .nil then opResult = .LegalInterrogationResult~failure("MISSING_PROPOSITION_RESOLUTION", subjectRef)
      else if \payload~isA(.LegalInterrogationPropositionResolution) then opResult = .LegalInterrogationResult~failure("BAD_PROPOSITION_RESOLUTION", subjectRef)
      else opResult = proposition~resolve(payload~state, payload~rationale)
    end
    when name == "SUPERSEDE_LEGAL_PROPOSITION" then do
      proposition = self~propositionById(session, subjectRef)
      if proposition == .nil then opResult = .LegalInterrogationResult~failure("PROPOSITION_NOT_FOUND", subjectRef)
      else if payload == .nil then opResult = .LegalInterrogationResult~failure("MISSING_SUPERSESSION_REQUEST", subjectRef)
      else if \payload~isA(.LegalInterrogationSupersessionRequest) then opResult = .LegalInterrogationResult~failure("BAD_SUPERSESSION_REQUEST", subjectRef)
      else opResult = session~clauseById(proposition~clauseId)~supersedeProposition(proposition~id, payload~replacementPropositionId, payload~rationale)
    end
    when name == "TEST_LEGAL_PROPOSITION" then do
      if payload == .nil then opResult = .LegalInterrogationResult~failure("MISSING_TEST_DRAFT", subjectRef)
      else if \payload~isA(.LegalInterrogationTestDraft) then opResult = .LegalInterrogationResult~failure("BAD_TEST_DRAFT", subjectRef)
      else do
        proposition = self~propositionById(session, payload~propositionId)
        if proposition == .nil then opResult = .LegalInterrogationResult~failure("PROPOSITION_NOT_FOUND", payload~propositionId)
        else opResult = self~director~newPropositionTest(session~clauseById(proposition~clauseId), proposition, payload~testKind, payload~assertion)
      end
    end
    when name == "RESOLVE_PROPOSITION_TEST" then do
      test = self~testById(session, subjectRef)
      if test == .nil then opResult = .LegalInterrogationResult~failure("TEST_NOT_FOUND", subjectRef)
      else if payload == .nil then opResult = .LegalInterrogationResult~failure("MISSING_TEST_RESOLUTION", subjectRef)
      else if \payload~isA(.LegalInterrogationTestResolution) then opResult = .LegalInterrogationResult~failure("BAD_TEST_RESOLUTION", subjectRef)
      else opResult = test~resolve(payload~result, payload~reason, payload~evidence)
    end
    when name == "START_DOCUMENT_RECONCILIATION" then opResult = self~director~seedDocumentReconciliation(session)
    when name == "HANDOFF_LEGAL_COMPILATION" then opResult = self~director~makeHandoff(session)
    when name == "REFER_LEGAL_REVIEW" then opResult = .LegalInterrogationResult~success(subjectRef, "LEGAL_REVIEW_PENDING", "Interrogation remains fail-closed pending legal review")
    when name == "EXPLAIN_INTERROGATION_STATE" then opResult = self~discover(session)
    otherwise opResult = .LegalInterrogationResult~failure("UNKNOWN_INTENTION", name)
  end
  return self~finish(session, name, subjectRef, actor, payload, opResult, before, beforeRevision)
::method finish
  use strict arg session, name, subjectRef, actor, payload, opResult, before, beforeRevision
  if opResult~ok, self~mutatesSession(name) then session~touch(name)
  self~executionSerial = self~executionSerial + 1
  session~addNegotiationRecord(.LegalInterrogationNegotiationRecord~new(self~executionSerial, name, subjectRef, actor, payload, opResult~code, opResult~detail, before, session~closureState, beforeRevision, session~revision))
  return opResult
::method mutatesSession
  use strict arg name
  if name == "EXPLAIN_INTERROGATION_STATE" | name == "REFER_LEGAL_REVIEW" | name == "HANDOFF_LEGAL_COMPILATION" then return .false
  return .true
::method questionById
  use strict arg session, id
  do clause over session~clauses
    q = clause~questionById(id); if q \== .nil then return q
  end
  do q over session~crossClauseQuestions; if q~id == id then return q; end
  return .nil
::method clauseForQuestion
  use strict arg session, id
  do clause over session~clauses
    if clause~questionById(id) \== .nil then return clause
  end
  return .nil

::method propositionById
  use strict arg session, id
  do clause over session~clauses
    p = clause~propositionById(id); if p \== .nil then return p
  end
  return .nil
::method testById
  use strict arg session, id
  do clause over session~clauses
    t = clause~propositionTestById(id); if t \== .nil then return t
  end
  return .nil

::class LegalInterrogationIntentionBinding public
::method bind
  use strict arg intentionService, port, adapter
  if port == .nil | \port~isA(.LegalInterrogationIntentionPort) then return .LegalInterrogationResult~failure("BAD_PORT", "LegalInterrogationIntentionPort required")
  if \adapter~hasMethod("REGISTERLEGALINTERROGATIONPROVIDER") then return .LegalInterrogationResult~failure("BAD_INTENTION_ADAPTER", "Adapter must implement registerLegalInterrogationProvider(service, port)")
  return .LegalInterrogationResult~success(adapter~registerLegalInterrogationProvider(intentionService, port), "INTENTION_PROVIDER_BOUND", "Host adapter performed generation-specific registration")

::class LegalEffectTestRequest public
::attribute testKind
::attribute legalArtifact
::attribute actionObject
::attribute contextObject
::attribute assertionObject
::attribute evidence
::method init
  use strict arg testKind, legalArtifact, actionObject = .nil, contextObject = .nil, assertionObject = .nil, evidence = .nil
  if evidence == .nil then evidence = .array~new
  self~testKind = testKind~upper; self~legalArtifact = legalArtifact; self~actionObject = actionObject
  self~contextObject = contextObject; self~assertionObject = assertionObject; self~evidence = evidence

::class LegalEffectTestPort public
::method supportedTests
  a = .array~new
  names = "APPLIES PARTY_IS_BOUND EFFECTIVE_AT CONDITION_SATISFIED EXCEPTION_APPLIES OBLIGATION_SATISFIED BREACH_EXISTS AUTHORITY_EXISTS CONFLICTS_WITH_HIGHER_AUTHORITY REMEDY_AVAILABLE ENFORCEABLE REQUIRED_EVIDENCE EFFECTIVE_DECISION COUNTERFACTUAL"
  do i = 1 to words(names); a~append(word(names, i)); end
  return a
::method supportsTest
  use strict arg testKind
  do item over self~supportedTests
    if item == testKind~upper then return .true
  end
  return .false
::method evaluate
  use strict arg request, adapter
  if request == .nil | \request~isA(.LegalEffectTestRequest) then return .LegalInterrogationResult~failure("BAD_LEGAL_EFFECT_TEST_REQUEST", "LegalEffectTestRequest required")
  if request~legalArtifact == .nil then return .LegalInterrogationResult~failure("MISSING_LEGAL_ARTIFACT", request~testKind)
  if \self~supportsTest(request~testKind) then return .LegalInterrogationResult~failure("UNSUPPORTED_LEGAL_EFFECT_TEST", request~testKind)
  if \adapter~hasMethod("EVALUATELEGALEFFECTTEST") then return .LegalInterrogationResult~failure("BAD_LEGAL_EFFECT_TEST_ADAPTER", "Adapter must implement evaluateLegalEffectTest(request)")
  return .LegalInterrogationResult~success(adapter~evaluateLegalEffectTest(request), "LEGAL_EFFECT_TEST_EVALUATED", "Evaluation authority belongs to the bound Legal Effect adapter")

::requires "LegalInterrogation.cls"
