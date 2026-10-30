/* LegalInterrogationLegalEffectV014.cls
 * Concrete bridge from a closed Legal Interrogation handoff into the
 * source-verified Legal Effect v0.14 compilation boundary.
 *
 * This bridge is deliberately fail-closed.  It never verifies a source merely
 * because Legal Interrogation accepted an interpretation, never parses free
 * text into LegalPredicate objects, and never seals a LegalRuleGeneration on
 * its own.  The LegalRuleCompiler remains the authority-bearing compiler.
 */

::class LegalInterrogationLegalEffectV014Adapter public
::attribute verifier get
::attribute mapper get
::attribute producerId get
::attribute producerKind get
::attribute compilerId get
::attribute compilerVersion get

::method init
  expose verifier mapper producerId producerKind compilerId compilerVersion
  use strict arg verifierArg, mapperArg = .nil, producerIdArg = "legal-interrogation", producerKindArg = "DETERMINISTIC", compilerIdArg = "legal-interrogation-v014-bridge", compilerVersionArg = "0.1-dev6"
  if verifierArg == .nil then raise syntax 93.900 array("Legal Effect source verifier is required")
  if \verifierArg~isA(.LegalSourceVerifier) then raise syntax 93.900 array("LegalSourceVerifier required")
  verifier = verifierArg
  if mapperArg == .nil then mapper = .LegalInterrogationLegalEffectV014Mapper~new
  else mapper = mapperArg
  if \mapper~hasMethod("MAPNORM") then raise syntax 93.900 array("Mapper must implement mapNorm(proposition, sourceId, provisionId)")
  producerId = producerIdArg~string
  producerKind = producerKindArg~string~upper
  compilerId = compilerIdArg~string
  compilerVersion = compilerVersionArg~string

::method buildLegalCompileProposal
  expose verifier mapper producerId producerKind compilerId compilerVersion
  use strict arg handoff
  if handoff == .nil then return .LegalInterrogationResult~failure("HANDOFF_REQUIRED", "")
  if \handoff~isA(.LegalInterrogationCompileHandoff) then return .LegalInterrogationResult~failure("LEGAL_INTERROGATION_HANDOFF_REQUIRED", handoff~class~id~string)
  if handoff~stale then return .LegalInterrogationResult~failure("STALE_HANDOFF", "Session revision changed after handoff")
  if \handoff~session~eligibleForCompilation then return .LegalInterrogationResult~failure("NOT_READY_FOR_COMPILATION", handoff~session~closureState)

  sourceIdentity = handoff~sourceIdentity
  sourceObject = handoff~sourceObject
  if sourceIdentity == .nil then return .LegalInterrogationResult~failure("LEGAL_SOURCE_IDENTITY_REQUIRED", handoff~sessionId)
  if \sourceIdentity~isA(.LegalSourceIdentity) then return .LegalInterrogationResult~failure("LEGAL_SOURCE_IDENTITY_CLASS_REQUIRED", sourceIdentity~class~id~string)
  if sourceObject == .nil then return .LegalInterrogationResult~failure("NORMATIVE_SOURCE_REQUIRED", handoff~sessionId)
  if \sourceObject~isA(.NormativeSource) then return .LegalInterrogationResult~failure("NORMATIVE_SOURCE_CLASS_REQUIRED", sourceObject~class~id~string)
  if \sourceIdentity~cryptographicallyVerified then return .LegalInterrogationResult~failure("LEGAL_SOURCE_VERIFICATION_REQUIRED", sourceIdentity~sourceId)
  if sourceObject~sourceId <> sourceIdentity~sourceId then return .LegalInterrogationResult~failure("SOURCE_IDENTITY_MISMATCH", sourceObject~sourceId)
  if sourceObject~sourceKind <> sourceIdentity~sourceKind then return .LegalInterrogationResult~failure("SOURCE_KIND_MISMATCH", sourceObject~sourceKind)

  generationId = "LI-" || handoff~sessionId || "-R" || handoff~handoffRevision
  unit = .LegalCompilationUnit~new(generationId, "0.14", compilerId, compilerVersion)
  addSourceOutcome = unit~addSource(sourceIdentity, sourceObject)
  if \addSourceOutcome~ok then return .LegalInterrogationResult~failure(addSourceOutcome~code, addSourceOutcome~detail)

  proposalCount = 0
  provider = verifier~digestProvider
  if provider == .nil then return .LegalInterrogationResult~failure("LEGAL_DIGEST_PROVIDER_REQUIRED", sourceIdentity~sourceId)
  algorithm = provider~algorithm~string~lower

  do clause over handoff~clauses
    clauseState = clause~closureState~string~upper
    if clauseState <> "ESTABLISHED" then do
      if clauseState <> "ESTABLISHED_WITH_QUALIFICATIONS" then return .LegalInterrogationResult~failure("CLAUSE_NOT_COMPILABLE", clause~id || ":" || clauseState)
    end
    lexical = clause~exactText~string
    if lexical~strip == "" then return .LegalInterrogationResult~failure("CLAUSE_TEXT_REQUIRED", clause~id)

    locator = clause~sourceLocator~string
    if locator~strip == "" then locator = handoff~sourceLocator~string
    if locator~strip == "" then locator = "legal-interrogation:" || handoff~sessionId || ":" || clause~id
    expressionId = sourceIdentity~expressionId
    provisionDigest = algorithm || ":" || provider~digest(lexical)~string~lower
    reference = .LegalProvisionReference~new(sourceIdentity~sourceId, clause~id, expressionId, locator, provisionDigest, lexical, "UNVERIFIED")
    provision = .LegalProvision~new(sourceIdentity~sourceId, clause~id, "ACTIVE", "BASE", lexical)
    addProvisionOutcome = unit~addProvision(reference, provision)
    if \addProvisionOutcome~ok then return .LegalInterrogationResult~failure(addProvisionOutcome~code, addProvisionOutcome~detail)

    material = .LegalVerificationMaterial~fromText(clause~sourceObject, lexical, locator, "PROVISION_TEXT")
    verificationOutcome = unit~verifyProvision(sourceIdentity~sourceId, clause~id, material, verifier)
    if \verificationOutcome~ok then return .LegalInterrogationResult~failure(verificationOutcome~code, verificationOutcome~detail)
    provisionEvidence = verificationOutcome~value
    if provisionEvidence == .nil then return .LegalInterrogationResult~failure("PROVISION_VERIFICATION_EVIDENCE_REQUIRED", clause~id)
    if \provisionEvidence~verified then return .LegalInterrogationResult~failure("PROVISION_VERIFICATION_FAILED", clause~id || ":" || provisionEvidence~statusCode)
    verifiedReference = unit~provisionReference(sourceIdentity~sourceId, clause~id)

    do proposition over clause~propositions
      state = proposition~state~string~upper
      if state <> "SUPPORTED" then do
        if state <> "PARTIALLY_SUPPORTED" then return .LegalInterrogationResult~failure("PROPOSITION_NOT_COMPILABLE", proposition~id || ":" || state)
      end
      mapped = mapper~mapNorm(proposition, sourceIdentity~sourceId, clause~id)
      if \mapped~ok then return mapped
      norm = mapped~value
      proposalId = "LI-" || handoff~sessionId || "-" || proposition~id
      proposal = .LegalCompileProposal~new(proposalId, "NORM", norm, producerId, producerKind, "")
      evidenceOutcome = proposal~addEvidenceReference(verifiedReference)
      if \evidenceOutcome~ok then return .LegalInterrogationResult~failure(evidenceOutcome~code, evidenceOutcome~detail)
      addProposalOutcome = unit~addProposal(proposal)
      if \addProposalOutcome~ok then return .LegalInterrogationResult~failure(addProposalOutcome~code, addProposalOutcome~detail)
      proposalCount = proposalCount + 1
    end
  end

  if proposalCount = 0 then return .LegalInterrogationResult~failure("NO_COMPILABLE_PROPOSITIONS", handoff~sessionId)
  compilation = .LegalInterrogationLegalEffectCompilation~new(unit, handoff~sessionId, handoff~handoffRevision, proposalCount)
  return .LegalInterrogationResult~success(compilation, "LEGAL_EFFECT_COMPILATION_UNIT_READY", "LegalRuleCompiler must still compile and certify the generation")


::class LegalInterrogationLegalEffectV014Mapper public
::method mapNorm
  use strict arg proposition, sourceId, provisionId
  if proposition == .nil then return .LegalInterrogationResult~failure("PROPOSITION_REQUIRED", provisionId)
  actionCode = proposition~predicate~string~strip
  if actionCode == "" then return .LegalInterrogationResult~failure("LEGAL_ACTION_CODE_REQUIRED", proposition~id)

  mode = proposition~modality~string~upper~strip
  kind = proposition~propositionKind~string~upper~strip
  normType = ""
  disposition = ""
  select
    when mode = "PROHIBITION" then do
      normType = "PROHIBITION"
      disposition = "PROHIBITED"
    end
    when mode = "PROHIBITED" then do
      normType = "PROHIBITION"
      disposition = "PROHIBITED"
    end
    when mode = "OBLIGATION" then do
      normType = "OBLIGATION"
      disposition = "REQUIRED"
    end
    when mode = "REQUIRED" then do
      normType = "OBLIGATION"
      disposition = "REQUIRED"
    end
    when mode = "PERMISSION" then do
      normType = "PERMISSION"
      disposition = "PERMITTED"
    end
    when mode = "PERMITTED" then do
      normType = "PERMISSION"
      disposition = "PERMITTED"
    end
    when mode = "RIGHT" then do
      normType = "RIGHT"
      disposition = "PERMITTED"
    end
    when mode = "POWER" then do
      normType = "POWER"
      disposition = "PERMITTED"
    end
    when mode = "REVIEW" then do
      if kind == "" then normType = "CONTRACT_TERM"
      else if kind = "NORMATIVE" then normType = "CONTRACT_TERM"
      else normType = kind
      disposition = "REVIEW"
    end
    otherwise do
      return .LegalInterrogationResult~failure("UNMAPPED_LEGAL_MODALITY", proposition~id || ":" || mode)
    end
  end

  subjectMatter = proposition~object~string~strip
  if subjectMatter == "" then subjectMatter = proposition~subject~string~strip
  if subjectMatter == "" then subjectMatter = "*"
  rationale = proposition~text~string
  if proposition~rationale~string~strip <> "" then rationale ||= " | interrogation=" || proposition~rationale~string
  normId = sourceId || "-" || provisionId || "-" || proposition~id
  norm = .LegalNorm~new(normId, sourceId, provisionId, normType, actionCode, disposition, subjectMatter, rationale)

  do condition over proposition~conditions
    if condition == .nil then return .LegalInterrogationResult~failure("LEGAL_PREDICATE_REQUIRED", proposition~id || ":condition")
    if \condition~isA(.LegalPredicate) then return .LegalInterrogationResult~failure("CONDITION_NOT_LEGAL_PREDICATE", proposition~id || ":" || condition~class~id~string)
    addConditionOutcome = norm~addCondition(condition)
    if \addConditionOutcome~ok then return .LegalInterrogationResult~failure(addConditionOutcome~code, addConditionOutcome~detail)
  end
  do exception over proposition~exceptions
    if exception == .nil then return .LegalInterrogationResult~failure("LEGAL_PREDICATE_REQUIRED", proposition~id || ":exception")
    if \exception~isA(.LegalPredicate) then return .LegalInterrogationResult~failure("EXCEPTION_NOT_LEGAL_PREDICATE", proposition~id || ":" || exception~class~id~string)
    addExceptionOutcome = norm~addException(exception)
    if \addExceptionOutcome~ok then return .LegalInterrogationResult~failure(addExceptionOutcome~code, addExceptionOutcome~detail)
  end
  return .LegalInterrogationResult~success(norm, "LEGAL_NORM_MAPPED", proposition~id)


::class LegalInterrogationLegalEffectCompilation public
::attribute unit get
::attribute sessionId get
::attribute handoffRevision get
::attribute proposalCount get
::attribute authoritative get

::method init
  expose unit sessionId handoffRevision proposalCount authoritative compileReport
  use strict arg unitArg, sessionIdArg, handoffRevisionArg, proposalCountArg
  unit = unitArg
  sessionId = sessionIdArg
  handoffRevision = handoffRevisionArg
  proposalCount = proposalCountArg
  authoritative = .false
  compileReport = .nil

::method compile
  expose unit compileReport authoritative
  use strict arg compiler = .nil
  if compiler == .nil then compiler = .LegalRuleCompiler~new
  if \compiler~isA(.LegalRuleCompiler) then return .LegalInterrogationResult~failure("LEGAL_RULE_COMPILER_REQUIRED", compiler~class~id~string)
  compileReport = compiler~compile(unit)
  if compileReport~ok then authoritative = .true
  return compileReport

::method report
  expose compileReport
  return compileReport

::requires "LegalInterrogation.cls"
::requires "LegalEffect.cls"
