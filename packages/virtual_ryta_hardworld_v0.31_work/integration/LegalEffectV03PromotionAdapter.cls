/*
 * LegalEffectV03PromotionAdapter.cls
 *
 * Current Legal Effect v0.3 authority bridge.
 *
 * Legal Effect owns legal applicability, modification, conflict and authority
 * semantics.  This adapter pins a complete authority-bearing evaluation input,
 * preserves v0.3 conflict/suppression lineage, and emits domain-neutral
 * EvidencePromotion objects.  SQL may inspect promotions; only an explicit
 * EvidencePromotionApplier call can introduce them into HardWorld.
 *
 * Two identities are deliberately retained:
 *   - semanticIdentityHash: v0.3's insertion-order-independent legal graph;
 *   - executionIdentity: conservative order fingerprint for any order the
 *     current engine can observe while evaluating/reducing.
 */

::class LegalEffectV03GenerationSnapshot public
::attribute nativeObject get
::attribute semanticIdentityText get
::attribute semanticIdentityHash get
::attribute executionIdentity get
::attribute canonicalIdentity get

::method init
  expose nativeObject semanticIdentityText semanticIdentityHash executionIdentity canonicalTextValue canonicalIdentity
  use arg generation
  if generation == .nil then raise syntax 93.900 additional('Legal generation must not be .nil')
  if \generation~hasMethod('SEALED') then raise syntax 93.900 additional('Legal generation has no SEALED method')
  if \generation~sealed then raise syntax 93.900 additional('Legal generation must be sealed before promotion')
  if \generation~hasMethod('SEMANTICIDENTITY') then raise syntax 93.900 additional('Legal Effect v0.3 SEMANTICIDENTITY contract is required')
  nativeObject = generation

  semanticIdentityText = generation~semanticIdentity
  semanticIdentityHash = .AlgorithmDigest~sha256Text(semanticIdentityText)

  executionText = self~buildExecutionText(generation)
  executionIdentity = .AlgorithmDigest~sha256Text(executionText)

  canonicalTextValue = 'LEGAL_EFFECT_V03_GENERATION_SNAPSHOT_V1' || '0a'x
  canonicalTextValue = canonicalTextValue || self~field('GENERATION_ID', generation~generationId)
  canonicalTextValue = canonicalTextValue || self~field('VERSION', generation~version)
  canonicalTextValue = canonicalTextValue || self~field('SEMANTIC_HASH', semanticIdentityHash)
  canonicalTextValue = canonicalTextValue || self~field('EXECUTION_HASH', executionIdentity)
  canonicalIdentity = .AlgorithmDigest~sha256Text(canonicalTextValue)

::method algorithmCanonicalText
  expose canonicalTextValue
  return canonicalTextValue

::method buildExecutionText private
  use arg generation
  text = 'LEGAL_EFFECT_V03_EXECUTION_ORDER_V1' || '0a'x

  /* Validate every evidence-bearing semantic component against an explicit
     identity contract.  v0.3 itself can represent opaque evidence as OPAQUE;
     authority promotion deliberately requires stronger pinning. */
  sourceTable = generation~sources
  sourceIds = sourceTable~allIndexes
  sourceIds~sort
  do sourceId over sourceIds
    sourceObject = sourceTable[sourceId]
    text = text || self~orderedEvidence('SOURCE:' || sourceId, sourceObject~evidence)
  end

  provisions = generation~provisions
  provisionTexts = .array~new
  do provision over provisions
    ptext = 'PROVISION|' || provision~sourceId || '|' || provision~provisionId || '|' || self~orderedEvidence('PROVISION_EVIDENCE', provision~evidence)
    provisionTexts~append(ptext)
  end
  provisionTexts~sort
  text = text || self~arrayText('PROVISION', provisionTexts)

  /* The resolver imposes its own modification ordering, but retain load order
     too: it is cheap, conservative, and protects future engine changes. */
  modificationTexts = .array~new
  do effect over generation~modifications
    item = 'MODIFICATION|' || effect~effectId || '|'
    item = item || self~orderedRuleInternals(effect)
    modificationTexts~append(item)
  end
  text = text || self~arrayText('MODIFICATION_ORDER', modificationTexts)

  /* Norm order is currently observable by v0.3's final disposition reducer. */
  normTexts = .array~new
  do norm over generation~norms
    item = 'NORM|' || norm~normId || '|'
    item = item || self~orderedRuleInternals(norm)
    normTexts~append(item)
  end
  text = text || self~arrayText('NORM_ORDER', normTexts)

  authorityTexts = .array~new
  do rule over generation~authorityRules
    item = 'AUTHORITY|' || rule~ruleId || '|'
    item = item || self~orderedRuleInternals(rule)
    authorityTexts~append(item)
  end
  text = text || self~arrayText('AUTHORITY_ORDER', authorityTexts)
  return text

::method orderedRuleInternals private
  use arg object
  text = ''
  conditionTexts = .array~new
  do predicate over object~conditions
    conditionTexts~append(predicate~canonicalText)
  end
  text = text || self~arrayText('CONDITION_ORDER', conditionTexts)

  exceptionTexts = .array~new
  do predicate over object~exceptions
    exceptionTexts~append(predicate~canonicalText)
  end
  text = text || self~arrayText('EXCEPTION_ORDER', exceptionTexts)

  claimTexts = .array~new
  do claim over object~jurisdictionClaims
    claimTexts~append(claim~canonicalText)
  end
  text = text || self~arrayText('JURISDICTION_ORDER', claimTexts)
  text = text || self~orderedEvidence('EVIDENCE_ORDER', object~evidence)
  return text

::method orderedEvidence private
  use arg label, anchors
  values = .array~new
  do anchor over anchors
    values~append(self~explicitAnchor(anchor))
  end
  return self~arrayText(label, values)

::method explicitAnchor private
  use arg anchor
  text = 'ANCHOR|' || self~inlineField('SOURCE_ID', anchor~sourceId)
  text = text || self~inlineField('SOURCE_KIND', anchor~sourceKind)
  text = text || self~inlineField('CITATION', anchor~citation)
  text = text || self~inlineField('AUTHORITY', anchor~authority)

  sourceObject = anchor~sourceObject
  if sourceObject == .nil then sourceText = 'NULL'
  else if sourceObject~hasMethod('ALGORITHMCANONICALTEXT') then sourceText = 'ALGORITHM:' || sourceObject~algorithmCanonicalText
  else if sourceObject~hasMethod('EVIDENCEIDENTITY') then sourceText = 'EVIDENCE_ID:' || sourceObject~evidenceIdentity
  else raise syntax 93.900 additional('Legal authority evidence lacks explicit identity contract:' anchor~sourceId)
  text = text || self~inlineField('SOURCE_OBJECT', sourceText)

  metadata = anchor~metadata
  keys = metadata~allIndexes
  keys~sort
  text = text || 'META_COUNT=' || keys~items || '|'
  do key over keys
    text = text || self~inlineField('MK', key~string)
    text = text || self~inlineField('MV', self~canonicalValue(metadata[key]))
  end
  return text

::method canonicalValue private
  use arg value
  if value == .nil then return 'NULL'
  if value == .true then return 'BOOLEAN:TRUE'
  if value == .false then return 'BOOLEAN:FALSE'
  if value~class == .String then return 'TEXT:' || value~length || ':' || value
  if datatype(value, 'N') == 1 then return 'NUMBER:' || value
  if value~hasMethod('ALGORITHMCANONICALTEXT') then do
    valueText = value~algorithmCanonicalText
    return 'ALGORITHM:' || valueText~length || ':' || valueText
  end
  if value~hasMethod('EVIDENCEIDENTITY') then do
    valueText = value~evidenceIdentity
    return 'EVIDENCE_ID:' || valueText~length || ':' || valueText
  end
  raise syntax 93.900 additional('Legal authority metadata lacks explicit canonical contract')

::method arrayText private
  use arg label, values
  text = label || '_COUNT=' || values~items || '0a'x
  ordinal = 0
  do value over values
    ordinal = ordinal + 1
    text = text || label || '[' || ordinal || ']=' || value~length || ':' || value || '0a'x
  end
  return text

::method field private
  use arg name, value
  rendered = value~string
  return name || '=' || rendered~length || ':' || rendered || '0a'x

::method inlineField private
  use arg name, value
  rendered = value~string
  return name || '=' || rendered~length || ':' || rendered || '|'


::class LegalEffectV03AssessmentEvidence public
::attribute nativeObject get
::attribute generationSnapshot get
::attribute inputSnapshot get
::attribute canonicalIdentity get

::method init
  expose nativeObject generationSnapshot inputSnapshot canonicalTextValue canonicalIdentity
  use arg assessment, generationSnapshotArg, inputSnapshotArg
  if assessment == .nil then raise syntax 93.900 additional('Legal assessment must not be .nil')
  if generationSnapshotArg == .nil then raise syntax 93.900 additional('v0.3 generation snapshot is required')
  if inputSnapshotArg == .nil then raise syntax 93.900 additional('Pinned evaluation input snapshot is required')
  nativeObject = assessment
  generationSnapshot = generationSnapshotArg
  inputSnapshot = inputSnapshotArg

  /* Reuse the mature action/context/match canonicalisation from v0.17, then
     append the v0.3-only semantic surfaces. */
  baseEvidence = .LegalEffectAssessmentEvidence~new(assessment, generationSnapshot, inputSnapshot)
  baseText = baseEvidence~algorithmCanonicalText

  canonicalTextValue = 'LEGAL_EFFECT_V03_ASSESSMENT_EVIDENCE_V1' || '0a'x
  canonicalTextValue = canonicalTextValue || self~field('SEMANTIC_HASH', generationSnapshot~semanticIdentityHash)
  canonicalTextValue = canonicalTextValue || self~field('EXECUTION_HASH', generationSnapshot~executionIdentity)
  canonicalTextValue = canonicalTextValue || self~field('BASE_V017', baseText)
  canonicalTextValue = canonicalTextValue || self~canonicalMatches('EFFECTIVE', assessment~effectiveMatches)
  canonicalTextValue = canonicalTextValue || self~canonicalMatches('SUPPRESSED', assessment~suppressedMatches)
  canonicalTextValue = canonicalTextValue || self~canonicalConflicts('RESOLVED_CONFLICT', assessment~resolvedConflicts)
  canonicalTextValue = canonicalTextValue || self~canonicalConflicts('UNRESOLVED_CONFLICT', assessment~unresolvedConflicts)
  canonicalTextValue = canonicalTextValue || self~canonicalFramework('BEFORE_FRAMEWORK', assessment~beforeSnapshot)
  canonicalTextValue = canonicalTextValue || self~canonicalFramework('AFTER_FRAMEWORK', assessment~afterSnapshot)
  canonicalIdentity = .AlgorithmDigest~sha256Text(canonicalTextValue)

::method algorithmCanonicalText
  expose canonicalTextValue
  return canonicalTextValue

::method canonicalMatches private
  use arg label, matches
  values = .array~new
  do matchObject over matches
    item = 'MATCH|' || self~inlineField('NORM', matchObject~norm~normId)
    item = item || self~inlineField('STATUS', matchObject~status)
    reasonNo = 0
    do reason over matchObject~reasons
      reasonNo = reasonNo + 1
      item = item || 'REASON[' || reasonNo || ']=' || reason~length || ':' || reason || '|'
    end
    values~append(item)
  end
  values~sort
  return self~arrayText(label, values)

::method canonicalConflicts private
  use arg label, conflicts
  values = .array~new
  do conflictObject over conflicts
    item = 'CONFLICT|' || self~inlineField('KEY', conflictObject~conflictKey)
    item = item || self~inlineField('STATUS', conflictObject~status)
    item = item || self~inlineField('LEFT', self~normIdFromMatch(conflictObject~leftMatch))
    item = item || self~inlineField('RIGHT', self~normIdFromMatch(conflictObject~rightMatch))
    item = item || self~inlineField('WINNER', self~normIdFromMatch(conflictObject~winnerMatch))
    item = item || self~inlineField('LOSER', self~normIdFromMatch(conflictObject~loserMatch))
    authorityMatch = conflictObject~authorityMatch
    if authorityMatch == .nil then item = item || self~inlineField('AUTHORITY_RULE', '')
    else do
      item = item || self~inlineField('AUTHORITY_RULE', authorityMatch~rule~ruleId)
      item = item || self~inlineField('AUTHORITY_STATUS', authorityMatch~status)
      item = item || self~inlineField('AUTHORITY_RELATION', authorityMatch~rule~relationType)
      authReasonNo = 0
      do reason over authorityMatch~reasons
        authReasonNo = authReasonNo + 1
        item = item || 'AUTH_REASON[' || authReasonNo || ']=' || reason~length || ':' || reason || '|'
      end
    end
    reasonNo = 0
    do reason over conflictObject~reasons
      reasonNo = reasonNo + 1
      item = item || 'REASON[' || reasonNo || ']=' || reason~length || ':' || reason || '|'
    end
    values~append(item)
  end
  values~sort
  return self~arrayText(label, values)

::method canonicalFramework private
  use arg label, snapshot
  if snapshot == .nil then return label || '=NULL' || '0a'x
  text = label || '|'

  applied = .array~new
  do matchObject over snapshot~appliedModifications
    item = 'APPLIED|' || self~inlineField('EFFECT', matchObject~effect~effectId)
    item = item || self~inlineField('STATUS', matchObject~status)
    applied~append(item)
  end
  text = text || self~arrayText(label || '_APPLIED', applied)

  unresolved = .array~new
  do matchObject over snapshot~unresolvedModifications
    item = 'UNRESOLVED|' || self~inlineField('EFFECT', matchObject~effect~effectId)
    item = item || self~inlineField('STATUS', matchObject~status)
    reasonNo = 0
    do reason over matchObject~reasons
      reasonNo = reasonNo + 1
      item = item || 'REASON[' || reasonNo || ']=' || reason~length || ':' || reason || '|'
    end
    unresolved~append(item)
  end
  unresolved~sort
  text = text || self~arrayText(label || '_UNRESOLVED', unresolved)

  provisionStates = .array~new
  do provision over snapshot~generation~provisions
    state = snapshot~provisionState(provision~sourceId, provision~provisionId)
    if state == .nil then iterate
    item = 'PROVISION|' || self~inlineField('SOURCE', provision~sourceId)
    item = item || self~inlineField('PROVISION', provision~provisionId)
    item = item || self~inlineField('STATUS', state~status)
    item = item || self~inlineField('MATERIAL_VERSION', state~materialVersion)
    item = item || self~inlineField('LEXICAL_TEXT', state~lexicalText)
    lineageNo = 0
    do effect over state~lineage
      lineageNo = lineageNo + 1
      item = item || 'LINEAGE[' || lineageNo || ']=' || effect~effectId~length || ':' || effect~effectId || '|'
    end
    provisionStates~append(item)
  end
  provisionStates~sort
  text = text || self~arrayText(label || '_PROVISION', provisionStates)
  return text

::method normIdFromMatch private
  use arg matchObject
  if matchObject == .nil then return ''
  return matchObject~norm~normId

::method arrayText private
  use arg label, values
  text = label || '_COUNT=' || values~items || '0a'x
  do value over values
    text = text || value~length || ':' || value || '0a'x
  end
  return text

::method field private
  use arg name, value
  rendered = value~string
  return name || '=' || rendered~length || ':' || rendered || '0a'x

::method inlineField private
  use arg name, value
  rendered = value~string
  return name || '=' || rendered~length || ':' || rendered || '|'


::class LegalEffectV03EvaluationEnvelope public
::attribute assessment get
::attribute generationSnapshot get
::attribute inputSnapshot get
::attribute assessmentEvidence get
::attribute integrityStatus get
::attribute detail get

::method init
  expose assessment generationSnapshot inputSnapshot assessmentEvidence integrityStatus detail canonicalTextValue
  use arg assessmentArg, generationSnapshotArg, inputSnapshotArg, assessmentEvidenceArg, integrityStatusArg = 'PINNED', detailArg = ''
  assessment = assessmentArg
  generationSnapshot = generationSnapshotArg
  inputSnapshot = inputSnapshotArg
  assessmentEvidence = assessmentEvidenceArg
  integrityStatus = integrityStatusArg~string~upper
  detail = detailArg~string
  canonicalTextValue = 'LEGAL_EFFECT_V03_EVALUATION_ENVELOPE_V1' || '0a'x
  canonicalTextValue = canonicalTextValue || 'STATUS=' || integrityStatus || '0a'x
  canonicalTextValue = canonicalTextValue || 'SEMANTIC=' || generationSnapshot~semanticIdentityHash || '0a'x
  canonicalTextValue = canonicalTextValue || 'EXECUTION=' || generationSnapshot~executionIdentity || '0a'x
  canonicalTextValue = canonicalTextValue || 'GENERATION=' || generationSnapshot~canonicalIdentity || '0a'x
  canonicalTextValue = canonicalTextValue || 'INPUT=' || inputSnapshot~canonicalIdentity || '0a'x
  evidenceText = assessmentEvidence~algorithmCanonicalText
  canonicalTextValue = canonicalTextValue || 'ASSESSMENT=' || evidenceText~length || ':' || evidenceText || '0a'x

::method algorithmCanonicalText
  expose canonicalTextValue
  return canonicalTextValue


::class LegalEffectV03PinnedEvaluator public

::method evaluate class
  use arg legalEngine, action, generation, context
  if legalEngine == .nil then return .LegalEffectPinnedEvaluationResult~new(.false, 'INVALID_ENGINE', 'Legal engine must not be .nil')
  if action == .nil then return .LegalEffectPinnedEvaluationResult~new(.false, 'INVALID_ACTION', 'Legal action must not be .nil')
  if context == .nil then return .LegalEffectPinnedEvaluationResult~new(.false, 'INVALID_CONTEXT', 'Legal context must not be .nil')
  if generation == .nil then return .LegalEffectPinnedEvaluationResult~new(.false, 'INVALID_GENERATION', 'Legal generation must not be .nil')
  if \generation~sealed then return .LegalEffectPinnedEvaluationResult~new(.false, 'GENERATION_NOT_SEALED', 'Legal generation must be sealed')
  if \generation~hasMethod('SEMANTICIDENTITY') then return .LegalEffectPinnedEvaluationResult~new(.false, 'LEGAL_EFFECT_V03_REQUIRED', 'Legal Effect v0.3 semantic identity surface is required')

  signal on syntax name pinInputFailed
  beforeGeneration = .LegalEffectV03GenerationSnapshot~new(generation)
  beforeInput = .LegalEffectEvaluationInputSnapshot~new(beforeGeneration, action, context)
  signal off syntax

  evaluation = legalEngine~evaluate(action, generation, context)
  if \evaluation~ok then return .LegalEffectPinnedEvaluationResult~new(.false, evaluation~code, evaluation~detail)

  signal on syntax name pinInputFailed
  afterGeneration = .LegalEffectV03GenerationSnapshot~new(generation)
  afterInput = .LegalEffectEvaluationInputSnapshot~new(afterGeneration, action, context)
  signal off syntax

  if beforeGeneration~canonicalIdentity \== afterGeneration~canonicalIdentity then do
    return .LegalEffectPinnedEvaluationResult~new(.false, 'LEGAL_GENERATION_CHANGED_DURING_EVALUATION', beforeGeneration~canonicalIdentity || ' -> ' || afterGeneration~canonicalIdentity)
  end
  if beforeInput~actionIdentity \== afterInput~actionIdentity then do
    return .LegalEffectPinnedEvaluationResult~new(.false, 'LEGAL_ACTION_CHANGED_DURING_EVALUATION', beforeInput~actionIdentity || ' -> ' || afterInput~actionIdentity)
  end
  if beforeInput~contextIdentity \== afterInput~contextIdentity then do
    return .LegalEffectPinnedEvaluationResult~new(.false, 'LEGAL_CONTEXT_CHANGED_DURING_EVALUATION', beforeInput~contextIdentity || ' -> ' || afterInput~contextIdentity)
  end

  assessment = evaluation~value
  if assessment == .nil then return .LegalEffectPinnedEvaluationResult~new(.false, 'LEGAL_EFFECT_V03_REQUIRED', 'Legal Effect v0.3 assessment surface is required')
  requiredAssessmentMethods = .array~of('EFFECTIVEMATCHES', 'SUPPRESSEDMATCHES', 'RESOLVEDCONFLICTS', 'UNRESOLVEDCONFLICTS')
  do requiredMethod over requiredAssessmentMethods
    if \assessment~hasMethod(requiredMethod) then return .LegalEffectPinnedEvaluationResult~new(.false, 'LEGAL_EFFECT_V03_REQUIRED', 'Legal Effect v0.3 assessment method missing: ' || requiredMethod)
  end
  reductionCheck = self~validateAssessmentReduction(assessment)
  if reductionCheck \== '' then return .LegalEffectPinnedEvaluationResult~new(.false, 'LEGAL_STATUS_REDUCTION_AMBIGUOUS', reductionCheck)

  evidence = .LegalEffectV03AssessmentEvidence~new(assessment, beforeGeneration, beforeInput)
  envelope = .LegalEffectV03EvaluationEnvelope~new(assessment, beforeGeneration, beforeInput, evidence, 'PINNED', 'v0.3 semantic + execution identity and action/context closure stable across evaluation')
  return .LegalEffectPinnedEvaluationResult~new(.true, 'OK', 'Legal Effect v0.3 evaluation input pinned', envelope)

pinInputFailed:
  signal off syntax
  conditionObject = condition('O')
  detailText = 'Legal Effect v0.3 evaluation input lacks deterministic canonical closure'
  if conditionObject \== .nil then do
    messageText = conditionObject['MESSAGE']
    if messageText \== .nil then detailText = messageText~string
  end
  return .LegalEffectPinnedEvaluationResult~new(.false, 'LEGAL_EVALUATION_INPUT_UNPINNABLE', detailText)

::method validateAssessmentReduction private class
  use arg assessment
  if assessment == .nil then return 'assessment is .nil'
  hasBlocking = .false
  hasReview = .false
  hasConditional = .false
  do disposition over assessment~dispositions
    select
      when disposition == 'PROHIBITED' then hasBlocking = .true
      when disposition == 'CONTRACT_BREACH' then hasBlocking = .true
      when disposition == 'TREATY_BREACH' then hasBlocking = .true
      when disposition == 'STATUS_EFFECT' then hasReview = .true
      when disposition == 'REVIEW' then hasReview = .true
      when disposition == 'REQUIRES_OBLIGATION' then hasConditional = .true
      otherwise nop
    end
  end

  /* Legal Effect v0.3 resolves declared conflictKey groups explicitly, but
     ungrouped REVIEW + REQUIRES_OBLIGATION dispositions still reduce in
     insertion-sensitive order.  Do not invent precedence here. */
  if \hasBlocking then do
    if assessment~unresolved~items = 0 then do
      if assessment~unresolvedConflicts~items = 0 then do
        if hasReview then do
          if hasConditional then return 'Legal Effect v0.3 has REVIEW/STATUS_EFFECT and REQUIRES_OBLIGATION effective dispositions without explicit status precedence'
        end
      end
    end
  end
  return ''


::class LegalEffectV03PromotionAdapter public

::method promotionsFrom class
  use arg sourceObject, prefix = 'LEGAL_'
  if sourceObject == .nil then raise syntax 93.900 additional('Legal promotion source must not be .nil')

  if sourceObject~hasMethod('INTEGRITYSTATUS') then do
    if \sourceObject~hasMethod('ASSESSMENT') then raise syntax 93.900 additional('Pinned legal envelope has no ASSESSMENT method')
    assessment = sourceObject~assessment
    evidence = sourceObject~assessmentEvidence
    generationSnapshot = sourceObject~generationSnapshot
    if sourceObject~integrityStatus == 'PINNED' then do
      promotionStatus = .EvidencePromotionConstant~STATUS_AUTHORIZED
      promotionReason = 'Legal Effect v0.3 assessment pinned to semantic + execution + action/context closure'
    end
    else do
      promotionStatus = .EvidencePromotionConstant~STATUS_UNRESOLVED
      promotionReason = 'legal evaluation envelope is not pinned:' sourceObject~integrityStatus
    end
  end
  else do
    raise syntax 93.900 additional('Legal Effect v0.3 authority promotion requires LegalEffectV03PinnedEvaluator envelope')
  end

  if assessment~generation == .nil then raise syntax 93.900 additional('Legal assessment has no generation')
  if \assessment~generation~sealed then raise syntax 93.900 additional('Only assessments from sealed legal generations may enter promotion')

  sourceIdentity = evidence~canonicalIdentity
  authority = 'LEGAL_EFFECT/0.3/' || assessment~generation~generationId || '@' || generationSnapshot~semanticIdentityHash || '+' || generationSnapshot~executionIdentity
  policyId = 'LEGAL_EFFECT_V03_STATUS_PROJECTION_V2'

  promotionSet = .EvidencePromotionSet~new
  blocked = assessment~status == 'BLOCKED'
  review = assessment~status == 'REVIEW_REQUIRED'
  conditional = assessment~status == 'CONDITIONAL'

  blockedBasis = self~basisFor(assessment, generationSnapshot, 'BLOCKED')
  reviewBasis = self~basisFor(assessment, generationSnapshot, 'REVIEW_REQUIRED')
  conditionalBasis = self~basisFor(assessment, generationSnapshot, 'CONDITIONAL')

  p = .EvidencePromotion~new(sourceIdentity || ':BLOCKED', 'LEGAL_EFFECT_V03', sourceIdentity, prefix || 'ACTION_BLOCKED', 'KNOWN', blocked, authority, policyId, 'ASSESSMENT_STATUS', 'LEGAL_EFFECT', promotionStatus, promotionReason, evidence, assessment, 'FROZEN_OBSERVATION', 'FROZEN_OBSERVATION', blockedBasis)
  ignored = promotionSet~add(p)
  p = .EvidencePromotion~new(sourceIdentity || ':REVIEW', 'LEGAL_EFFECT_V03', sourceIdentity, prefix || 'ACTION_REVIEW_REQUIRED', 'KNOWN', review, authority, policyId, 'ASSESSMENT_STATUS', 'LEGAL_EFFECT', promotionStatus, promotionReason, evidence, assessment, 'FROZEN_OBSERVATION', 'FROZEN_OBSERVATION', reviewBasis)
  ignored = promotionSet~add(p)
  p = .EvidencePromotion~new(sourceIdentity || ':CONDITIONAL', 'LEGAL_EFFECT_V03', sourceIdentity, prefix || 'ACTION_CONDITIONAL', 'KNOWN', conditional, authority, policyId, 'ASSESSMENT_STATUS', 'LEGAL_EFFECT', promotionStatus, promotionReason, evidence, assessment, 'FROZEN_OBSERVATION', 'FROZEN_OBSERVATION', conditionalBasis)
  ignored = promotionSet~add(p)
  ignored = promotionSet~seal
  return promotionSet

::method basisFor private class
  use arg assessment, generationSnapshot, targetStatus
  basis = .array~new

  generationDetail = 'version=' || assessment~generation~version || ';semantic=' || generationSnapshot~semanticIdentityHash || ';execution=' || generationSnapshot~executionIdentity
  basis~append(.EvidencePromotionBasis~new('LEGAL_GENERATION_V03', assessment~generation~generationId, generationDetail, assessment~generation))
  basis~append(.EvidencePromotionBasis~new('LEGAL_ACTION', assessment~action~actionCode, assessment~action~description, assessment~action))
  basis~append(.EvidencePromotionBasis~new('ASSESSMENT_STATUS', targetStatus, 'actual=' || assessment~status, assessment))

  /* v0.3 only: suppressed applicable norms are not promotion basis. */
  do matchObject over assessment~effectiveMatches
    if matchObject~status \== 'APPLIES' then iterate
    include = .false
    select
      when targetStatus == 'BLOCKED' then do
        if matchObject~norm~disposition == 'PROHIBITED' then include = .true
        else if matchObject~norm~disposition == 'CONTRACT_BREACH' then include = .true
        else if matchObject~norm~disposition == 'TREATY_BREACH' then include = .true
      end
      when targetStatus == 'REVIEW_REQUIRED' then do
        if matchObject~norm~disposition == 'STATUS_EFFECT' then include = .true
        else if matchObject~norm~disposition == 'REVIEW' then include = .true
      end
      when targetStatus == 'CONDITIONAL' then do
        if matchObject~norm~disposition == 'REQUIRES_OBLIGATION' then include = .true
      end
      otherwise nop
    end
    if include then do
      detail = matchObject~norm~sourceId || '/' || matchObject~norm~provisionId || '/' || matchObject~norm~disposition
      basis~append(.EvidencePromotionBasis~new('LEGAL_NORM_EFFECTIVE', matchObject~norm~normId, detail, matchObject~norm))
    end
  end

  /* Authority resolution is itself evidence for why one applicable norm was
     retained and another suppressed. */
  do conflictObject over assessment~resolvedConflicts
    authorityMatch = conflictObject~authorityMatch
    if authorityMatch == .nil then iterate
    detail = 'conflict=' || conflictObject~conflictKey
    detail = detail || ';winner=' || conflictObject~winnerMatch~norm~normId
    detail = detail || ';loser=' || conflictObject~loserMatch~norm~normId
    detail = detail || ';relation=' || authorityMatch~rule~relationType
    basis~append(.EvidencePromotionBasis~new('LEGAL_AUTHORITY_RULE', authorityMatch~rule~ruleId, detail, authorityMatch~rule))
  end

  if targetStatus == 'REVIEW_REQUIRED' then do
    do matchObject over assessment~unresolved
      basis~append(.EvidencePromotionBasis~new('LEGAL_NORM_UNRESOLVED', matchObject~norm~normId, matchObject~status, matchObject~norm))
    end
    do conflictObject over assessment~unresolvedConflicts
      detail = 'status=' || conflictObject~status
      if conflictObject~reasons~items > 0 then detail = detail || ';reason=' || conflictObject~reasons[1]
      basis~append(.EvidencePromotionBasis~new('LEGAL_CONFLICT_UNRESOLVED', conflictObject~conflictKey, detail, conflictObject))
    end
  end
  return basis


::requires 'LegalEffectPromotionAdapter.cls'
