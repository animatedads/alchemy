/*
 * LegalEffectV06PromotionAdapter.cls
 *
 * Current Legal Effect v0.6 authority bridge.
 *
 * Legal Effect owns legal applicability, modification, conflict and authority
 * semantics.  This adapter pins a complete authority-bearing evaluation input,
 * preserves v0.6 conflict/suppression lineage, and emits domain-neutral
 * EvidencePromotion objects.  SQL may inspect promotions; only an explicit
 * EvidencePromotionApplier call can introduce them into HardWorld.
 *
 * Two identities are deliberately retained:
 *   - semanticIdentityHash: v0.6's insertion-order-independent legal graph;
 *   - executionIdentity: conservative order fingerprint for any order the
 *     current engine can observe while evaluating/reducing.
 */

::class LegalEffectV06GenerationSnapshot public
::attribute nativeObject get
::attribute semanticIdentityText get
::attribute semanticIdentityHash get
::attribute executionIdentity get
::attribute compilationInputIdentity get
::attribute certificateHash get
::attribute verificationClosureHash get
::attribute canonicalIdentity get

::method init
  expose nativeObject semanticIdentityText semanticIdentityHash executionIdentity compilationInputIdentity certificateHash verificationClosureHash canonicalTextValue canonicalIdentity
  use arg generation
  if generation == .nil then raise syntax 93.900 additional('Legal generation must not be .nil')
  if \generation~hasMethod('SEALED') then raise syntax 93.900 additional('Legal generation has no SEALED method')
  if \generation~sealed then raise syntax 93.900 additional('Legal generation must be sealed before promotion')
  if \generation~hasMethod('SEMANTICIDENTITY') then raise syntax 93.900 additional('Legal Effect v0.6 SEMANTICIDENTITY contract is required')
  if \generation~hasMethod('PUBLICATIONELIGIBLE') then raise syntax 93.900 additional('Legal Effect v0.6 PUBLICATIONELIGIBLE contract is required')
  if \generation~publicationEligible then raise syntax 93.900 additional('LEGAL_GENERATION_NOT_COMPILED')
  if \generation~hasMethod('COMPILATIONCERTIFICATE') then raise syntax 93.900 additional('Legal Effect v0.6 COMPILATIONCERTIFICATE contract is required')
  certificate = generation~compilationCertificate
  if certificate == .nil then raise syntax 93.900 additional('LEGAL_COMPILATION_CERTIFICATE_REQUIRED')
  requiredCertificateMethods = .array~of('CANONICALTEXT', 'INPUTIDENTITY', 'COMPILERID', 'COMPILERVERSION', 'PROPOSALCOUNT', 'SOURCECOUNT', 'PROVISIONCOUNT', 'VERIFICATIONEVIDENCE')
  do requiredMethod over requiredCertificateMethods
    if \certificate~hasMethod(requiredMethod) then raise syntax 93.900 additional('LEGAL_COMPILATION_CERTIFICATE_SURFACE_INVALID:' requiredMethod)
  end
  nativeObject = generation

  semanticIdentityText = generation~semanticIdentity
  semanticIdentityHash = .AlgorithmDigest~sha256Text(semanticIdentityText)

  executionText = self~buildExecutionText(generation)
  executionIdentity = .AlgorithmDigest~sha256Text(executionText)

  compilationInputIdentity = certificate~inputIdentity
  certificateText = certificate~canonicalText
  certificateHash = .AlgorithmDigest~sha256Text(certificateText)
  verificationText = self~buildVerificationText(generation)
  verificationClosureHash = .AlgorithmDigest~sha256Text(verificationText)

  canonicalTextValue = 'LEGAL_EFFECT_V06_GENERATION_SNAPSHOT_V2' || '0a'x
  canonicalTextValue = canonicalTextValue || self~field('GENERATION_ID', generation~generationId)
  canonicalTextValue = canonicalTextValue || self~field('VERSION', generation~version)
  canonicalTextValue = canonicalTextValue || self~field('SEMANTIC_HASH', semanticIdentityHash)
  canonicalTextValue = canonicalTextValue || self~field('EXECUTION_HASH', executionIdentity)
  canonicalTextValue = canonicalTextValue || self~field('COMPILATION_INPUT', compilationInputIdentity)
  canonicalTextValue = canonicalTextValue || self~field('CERTIFICATE_HASH', certificateHash)
  canonicalTextValue = canonicalTextValue || self~field('VERIFICATION_CLOSURE_HASH', verificationClosureHash)
  canonicalIdentity = .AlgorithmDigest~sha256Text(canonicalTextValue)

::method algorithmCanonicalText
  expose canonicalTextValue
  return canonicalTextValue

::method buildVerificationText private
  use arg generation
  text = 'LEGAL_EFFECT_V06_VERIFIED_ADMISSION_V2' || '0a'x

  certificate = generation~compilationCertificate
  if certificate == .nil then raise syntax 93.900 additional('LEGAL_COMPILATION_CERTIFICATE_REQUIRED')
  if \certificate~hasMethod('VERIFICATIONEVIDENCE') then raise syntax 93.900 additional('LEGAL_EFFECT_V06_CERTIFICATE_VERIFICATION_EVIDENCE_REQUIRED')
  certificateText = certificate~canonicalText
  text = text || self~field('CERTIFICATE', certificateText)

  certificateSnapshots = certificate~verificationEvidence
  snapshotById = .table~new
  snapshotTexts = .array~new
  do snapshot over certificateSnapshots
    requiredSnapshotMethods = .array~of('EVIDENCEIDENTITY', 'CANONICALTEXT', 'SUBJECTKIND', 'SOURCEID', 'PROVISIONID', 'EXPRESSIONID', 'EXPECTEDDIGEST', 'ACTUALDIGEST', 'VERIFIED', 'STATUSCODE', 'MATERIALREPRESENTATION', 'LOCATOR', 'VERIFIERID', 'PARENTEVIDENCEIDENTITY')
    do requiredMethod over requiredSnapshotMethods
      if \snapshot~hasMethod(requiredMethod) then raise syntax 93.900 additional('LEGAL_VERIFICATION_SNAPSHOT_SURFACE_INVALID:' requiredMethod)
    end
    if \snapshot~verified then raise syntax 93.900 additional('LEGAL_CERTIFICATE_CONTAINS_UNVERIFIED_EVIDENCE:' snapshot~evidenceIdentity)
    if snapshot~statusCode <> 'VERIFIED' then raise syntax 93.900 additional('LEGAL_CERTIFICATE_VERIFICATION_STATUS_INVALID:' snapshot~evidenceIdentity)
    evidenceId = snapshot~evidenceIdentity
    if snapshotById~hasIndex(evidenceId) then raise syntax 93.900 additional('LEGAL_CERTIFICATE_DUPLICATE_VERIFICATION_EVIDENCE:' evidenceId)
    snapshotById[evidenceId] = snapshot
    snapshotTexts~append(snapshot~canonicalText)
  end
  snapshotTexts~sort
  text = text || self~arrayText('CERTIFICATE_VERIFICATION_SNAPSHOT', snapshotTexts)

  expectedEvidenceCount = 0
  sourceTexts = .array~new
  sourceTable = generation~sources
  sourceIds = sourceTable~allIndexes
  sourceIds~sort
  do sourceId over sourceIds
    sourceObject = sourceTable[sourceId]
    if \sourceObject~hasMethod('SOURCEIDENTITY') then raise syntax 93.900 additional('LEGAL_SOURCE_IDENTITY_REQUIRED:' sourceId)
    identity = sourceObject~sourceIdentity
    if identity == .nil then raise syntax 93.900 additional('LEGAL_SOURCE_IDENTITY_REQUIRED:' sourceId)
    if \identity~hasMethod('VERIFICATIONEVIDENCE') then raise syntax 93.900 additional('LEGAL_SOURCE_VERIFICATION_EVIDENCE_SURFACE_REQUIRED:' sourceId)
    evidence = identity~verificationEvidence
    if evidence == .nil then raise syntax 93.900 additional('LEGAL_SOURCE_VERIFICATION_EVIDENCE_REQUIRED:' sourceId)
    self~validateLiveVerificationEvidence('SOURCE', identity, evidence, sourceId, '')
    certificateSnapshot = snapshotById[evidence~evidenceIdentity]
    if certificateSnapshot == .nil then raise syntax 93.900 additional('LEGAL_SOURCE_VERIFICATION_NOT_IN_CERTIFICATE:' sourceId)
    if \self~verificationEvidenceMatchesSnapshot(evidence, certificateSnapshot) then raise syntax 93.900 additional('LEGAL_SOURCE_VERIFICATION_CERTIFICATE_MISMATCH:' sourceId)
    identityText = identity~canonicalText
    sourceTexts~append(sourceId || '|IDENTITY=' || identityText || '|VERIFICATION=' || self~liveVerificationText(evidence))
    expectedEvidenceCount = expectedEvidenceCount + 1
  end
  sourceTexts~sort
  text = text || self~arrayText('VERIFIED_SOURCE', sourceTexts)

  provisionTexts = .array~new
  do provision over generation~provisions
    if \provision~hasMethod('PROVISIONREFERENCE') then raise syntax 93.900 additional('LEGAL_PROVISION_REFERENCE_REQUIRED:' provision~provisionId)
    reference = provision~provisionReference
    if reference == .nil then raise syntax 93.900 additional('LEGAL_PROVISION_REFERENCE_REQUIRED:' provision~provisionId)
    if \reference~hasMethod('VERIFICATIONEVIDENCE') then raise syntax 93.900 additional('LEGAL_PROVISION_VERIFICATION_EVIDENCE_SURFACE_REQUIRED:' provision~provisionId)
    evidence = reference~verificationEvidence
    if evidence == .nil then raise syntax 93.900 additional('LEGAL_PROVISION_VERIFICATION_EVIDENCE_REQUIRED:' provision~provisionId)
    self~validateLiveVerificationEvidence('PROVISION', reference, evidence, provision~sourceId, provision~provisionId)

    parentEvidence = evidence~parentEvidence
    if parentEvidence == .nil then raise syntax 93.900 additional('LEGAL_PROVISION_PARENT_SOURCE_EVIDENCE_REQUIRED:' provision~provisionId)
    sourceObject = sourceTable[provision~sourceId]
    if sourceObject == .nil then raise syntax 93.900 additional('LEGAL_PROVISION_SOURCE_REQUIRED:' provision~sourceId)
    sourceIdentity = sourceObject~sourceIdentity
    if sourceIdentity == .nil then raise syntax 93.900 additional('LEGAL_PROVISION_SOURCE_IDENTITY_REQUIRED:' provision~sourceId)
    if sourceIdentity~verificationEvidence == .nil then raise syntax 93.900 additional('LEGAL_PROVISION_PARENT_SOURCE_EVIDENCE_REQUIRED:' provision~provisionId)
    if parentEvidence~evidenceIdentity \== sourceIdentity~verificationEvidence~evidenceIdentity then raise syntax 93.900 additional('LEGAL_PROVISION_PARENT_SOURCE_EVIDENCE_MISMATCH:' provision~provisionId)

    certificateSnapshot = snapshotById[evidence~evidenceIdentity]
    if certificateSnapshot == .nil then raise syntax 93.900 additional('LEGAL_PROVISION_VERIFICATION_NOT_IN_CERTIFICATE:' provision~provisionId)
    if \self~verificationEvidenceMatchesSnapshot(evidence, certificateSnapshot) then raise syntax 93.900 additional('LEGAL_PROVISION_VERIFICATION_CERTIFICATE_MISMATCH:' provision~provisionId)
    referenceText = reference~canonicalText
    provisionTexts~append(provision~sourceId || '/' || provision~provisionId || '|REFERENCE=' || referenceText || '|VERIFICATION=' || self~liveVerificationText(evidence))
    expectedEvidenceCount = expectedEvidenceCount + 1
  end
  provisionTexts~sort
  text = text || self~arrayText('VERIFIED_PROVISION', provisionTexts)

  if certificateSnapshots~items <> expectedEvidenceCount then raise syntax 93.900 additional('LEGAL_CERTIFICATE_VERIFICATION_CLOSURE_COUNT_MISMATCH:' certificateSnapshots~items || '/' || expectedEvidenceCount)
  return text

::method validateLiveVerificationEvidence private
  use arg expectedKind, identityObject, evidence, sourceId, provisionId
  requiredMethods = .array~of('EVIDENCEIDENTITY', 'SUBJECTKIND', 'SOURCEID', 'PROVISIONID', 'EXPRESSIONID', 'EXPECTEDDIGEST', 'ACTUALDIGEST', 'VERIFIED', 'STATUSCODE', 'MATERIALREPRESENTATION', 'LOCATOR', 'VERIFIERID', 'PARENTEVIDENCE')
  do requiredMethod over requiredMethods
    if \evidence~hasMethod(requiredMethod) then raise syntax 93.900 additional('LEGAL_VERIFICATION_EVIDENCE_SURFACE_INVALID:' requiredMethod)
  end
  if \evidence~verified then raise syntax 93.900 additional('LEGAL_VERIFICATION_EVIDENCE_NOT_VERIFIED:' evidence~evidenceIdentity)
  if evidence~statusCode <> 'VERIFIED' then raise syntax 93.900 additional('LEGAL_VERIFICATION_EVIDENCE_STATUS_INVALID:' evidence~evidenceIdentity)
  if evidence~subjectKind <> expectedKind then raise syntax 93.900 additional('LEGAL_VERIFICATION_EVIDENCE_KIND_MISMATCH:' evidence~evidenceIdentity)
  if evidence~sourceId <> sourceId then raise syntax 93.900 additional('LEGAL_VERIFICATION_EVIDENCE_SOURCE_MISMATCH:' evidence~evidenceIdentity)
  if expectedKind == 'SOURCE' then do
    if evidence~provisionId <> '' then raise syntax 93.900 additional('LEGAL_SOURCE_VERIFICATION_PROVISION_ID_PRESENT:' evidence~evidenceIdentity)
    if evidence~expressionId <> identityObject~expressionId then raise syntax 93.900 additional('LEGAL_SOURCE_VERIFICATION_EXPRESSION_MISMATCH:' sourceId)
    if evidence~expectedDigest <> identityObject~contentDigest then raise syntax 93.900 additional('LEGAL_SOURCE_VERIFICATION_DIGEST_MISMATCH:' sourceId)
  end
  else do
    if evidence~provisionId <> provisionId then raise syntax 93.900 additional('LEGAL_PROVISION_VERIFICATION_ID_MISMATCH:' provisionId)
    if evidence~expressionId <> identityObject~expressionId then raise syntax 93.900 additional('LEGAL_PROVISION_VERIFICATION_EXPRESSION_MISMATCH:' provisionId)
    if evidence~expectedDigest <> identityObject~contentDigest then raise syntax 93.900 additional('LEGAL_PROVISION_VERIFICATION_DIGEST_MISMATCH:' provisionId)
  end
  if evidence~actualDigest <> evidence~expectedDigest then raise syntax 93.900 additional('LEGAL_VERIFICATION_DIGEST_PAIR_MISMATCH:' evidence~evidenceIdentity)
  return .true

::method verificationEvidenceMatchesSnapshot private
  use arg evidence, snapshot
  if evidence~evidenceIdentity \== snapshot~evidenceIdentity then return .false
  if evidence~subjectKind \== snapshot~subjectKind then return .false
  if evidence~sourceId \== snapshot~sourceId then return .false
  if evidence~provisionId \== snapshot~provisionId then return .false
  if evidence~expressionId \== snapshot~expressionId then return .false
  if evidence~locator \== snapshot~locator then return .false
  if evidence~algorithm \== snapshot~algorithm then return .false
  if evidence~expectedDigest \== snapshot~expectedDigest then return .false
  if evidence~actualDigest \== snapshot~actualDigest then return .false
  if evidence~verified \== snapshot~verified then return .false
  if evidence~statusCode \== snapshot~statusCode then return .false
  if evidence~materialRepresentation \== snapshot~materialRepresentation then return .false
  if evidence~materialLength \== snapshot~materialLength then return .false
  if evidence~verifierId \== snapshot~verifierId then return .false
  if evidence~verifiedAt \== snapshot~verifiedAt then return .false
  parentId = ''
  if evidence~parentEvidence \== .nil then parentId = evidence~parentEvidence~evidenceIdentity
  if parentId \== snapshot~parentEvidenceIdentity then return .false
  return .true

::method liveVerificationText private
  use arg evidence
  text = self~field('EVIDENCE_ID', evidence~evidenceIdentity)
  text = text || self~field('SUBJECT_KIND', evidence~subjectKind)
  text = text || self~field('SOURCE_ID', evidence~sourceId)
  text = text || self~field('PROVISION_ID', evidence~provisionId)
  text = text || self~field('EXPRESSION_ID', evidence~expressionId)
  text = text || self~field('LOCATOR', evidence~locator)
  text = text || self~field('ALGORITHM', evidence~algorithm)
  text = text || self~field('EXPECTED_DIGEST', evidence~expectedDigest)
  text = text || self~field('ACTUAL_DIGEST', evidence~actualDigest)
  text = text || self~field('VERIFIED', evidence~verified)
  text = text || self~field('STATUS', evidence~statusCode)
  text = text || self~field('REPRESENTATION', evidence~materialRepresentation)
  text = text || self~field('MATERIAL_LENGTH', evidence~materialLength)
  text = text || self~field('VERIFIER_ID', evidence~verifierId)
  text = text || self~field('VERIFIED_AT', evidence~verifiedAt)
  parentId = ''
  if evidence~parentEvidence \== .nil then parentId = evidence~parentEvidence~evidenceIdentity
  text = text || self~field('PARENT_EVIDENCE', parentId)
  return text

::method buildExecutionText private
  use arg generation
  text = 'LEGAL_EFFECT_V06_EXECUTION_ORDER_V1' || '0a'x

  /* Validate every evidence-bearing semantic component against an explicit
     identity contract.  v0.6 itself can represent opaque evidence as OPAQUE;
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

  /* Norm order is currently observable by v0.6's final disposition reducer. */
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


::class LegalEffectV06AssessmentEvidence public
::attribute nativeObject get
::attribute generationSnapshot get
::attribute inputSnapshot get
::attribute canonicalIdentity get

::method init
  expose nativeObject generationSnapshot inputSnapshot canonicalTextValue canonicalIdentity
  use arg assessment, generationSnapshotArg, inputSnapshotArg
  if assessment == .nil then raise syntax 93.900 additional('Legal assessment must not be .nil')
  if generationSnapshotArg == .nil then raise syntax 93.900 additional('v0.6 generation snapshot is required')
  if inputSnapshotArg == .nil then raise syntax 93.900 additional('Pinned evaluation input snapshot is required')
  nativeObject = assessment
  generationSnapshot = generationSnapshotArg
  inputSnapshot = inputSnapshotArg

  /* Reuse the mature action/context/match canonicalisation from v0.17, then
     append the v0.6-only semantic surfaces. */
  baseEvidence = .LegalEffectAssessmentEvidence~new(assessment, generationSnapshot, inputSnapshot)
  baseText = baseEvidence~algorithmCanonicalText

  canonicalTextValue = 'LEGAL_EFFECT_V06_ASSESSMENT_EVIDENCE_V1' || '0a'x
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


::class LegalEffectV06EvaluationEnvelope public
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
  canonicalTextValue = 'LEGAL_EFFECT_V06_EVALUATION_ENVELOPE_V1' || '0a'x
  canonicalTextValue = canonicalTextValue || 'STATUS=' || integrityStatus || '0a'x
  canonicalTextValue = canonicalTextValue || 'SEMANTIC=' || generationSnapshot~semanticIdentityHash || '0a'x
  canonicalTextValue = canonicalTextValue || 'EXECUTION=' || generationSnapshot~executionIdentity || '0a'x
  canonicalTextValue = canonicalTextValue || 'COMPILATION_INPUT=' || generationSnapshot~compilationInputIdentity || '0a'x
  canonicalTextValue = canonicalTextValue || 'CERTIFICATE=' || generationSnapshot~certificateHash || '0a'x
  canonicalTextValue = canonicalTextValue || 'VERIFICATION=' || generationSnapshot~verificationClosureHash || '0a'x
  canonicalTextValue = canonicalTextValue || 'GENERATION=' || generationSnapshot~canonicalIdentity || '0a'x
  canonicalTextValue = canonicalTextValue || 'INPUT=' || inputSnapshot~canonicalIdentity || '0a'x
  evidenceText = assessmentEvidence~algorithmCanonicalText
  canonicalTextValue = canonicalTextValue || 'ASSESSMENT=' || evidenceText~length || ':' || evidenceText || '0a'x

::method algorithmCanonicalText
  expose canonicalTextValue
  return canonicalTextValue


::class LegalEffectV06PinnedEvaluator public

::method evaluate class
  use arg legalEngine, action, generation, context
  if legalEngine == .nil then return .LegalEffectPinnedEvaluationResult~new(.false, 'INVALID_ENGINE', 'Legal engine must not be .nil')
  if action == .nil then return .LegalEffectPinnedEvaluationResult~new(.false, 'INVALID_ACTION', 'Legal action must not be .nil')
  if context == .nil then return .LegalEffectPinnedEvaluationResult~new(.false, 'INVALID_CONTEXT', 'Legal context must not be .nil')
  if generation == .nil then return .LegalEffectPinnedEvaluationResult~new(.false, 'INVALID_GENERATION', 'Legal generation must not be .nil')
  if \generation~sealed then return .LegalEffectPinnedEvaluationResult~new(.false, 'GENERATION_NOT_SEALED', 'Legal generation must be sealed')
  if \generation~hasMethod('SEMANTICIDENTITY') then return .LegalEffectPinnedEvaluationResult~new(.false, 'LEGAL_EFFECT_V06_REQUIRED', 'Legal Effect v0.6 semantic identity surface is required')
  if \generation~hasMethod('PUBLICATIONELIGIBLE') then return .LegalEffectPinnedEvaluationResult~new(.false, 'LEGAL_EFFECT_V06_REQUIRED', 'Legal Effect v0.6 publication eligibility surface is required')
  if \generation~publicationEligible then return .LegalEffectPinnedEvaluationResult~new(.false, 'LEGAL_GENERATION_NOT_COMPILED', 'Authority promotion requires compiler-certified Legal Effect v0.6 generation')

  signal on syntax name pinInputFailed
  beforeGeneration = .LegalEffectV06GenerationSnapshot~new(generation)
  beforeInput = .LegalEffectEvaluationInputSnapshot~new(beforeGeneration, action, context)
  signal off syntax

  evaluation = legalEngine~evaluate(action, generation, context)
  if \evaluation~ok then return .LegalEffectPinnedEvaluationResult~new(.false, evaluation~code, evaluation~detail)

  signal on syntax name pinInputFailed
  afterGeneration = .LegalEffectV06GenerationSnapshot~new(generation)
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
  if assessment == .nil then return .LegalEffectPinnedEvaluationResult~new(.false, 'LEGAL_EFFECT_V06_REQUIRED', 'Legal Effect v0.6 assessment surface is required')
  requiredAssessmentMethods = .array~of('EFFECTIVEMATCHES', 'SUPPRESSEDMATCHES', 'RESOLVEDCONFLICTS', 'UNRESOLVEDCONFLICTS')
  do requiredMethod over requiredAssessmentMethods
    if \assessment~hasMethod(requiredMethod) then return .LegalEffectPinnedEvaluationResult~new(.false, 'LEGAL_EFFECT_V06_REQUIRED', 'Legal Effect v0.6 assessment method missing: ' || requiredMethod)
  end
  reductionCheck = self~validateAssessmentReduction(assessment)
  if reductionCheck \== '' then return .LegalEffectPinnedEvaluationResult~new(.false, 'LEGAL_STATUS_REDUCTION_AMBIGUOUS', reductionCheck)

  evidence = .LegalEffectV06AssessmentEvidence~new(assessment, beforeGeneration, beforeInput)
  envelope = .LegalEffectV06EvaluationEnvelope~new(assessment, beforeGeneration, beforeInput, evidence, 'PINNED', 'v0.6 semantic + execution identity and action/context closure stable across evaluation')
  return .LegalEffectPinnedEvaluationResult~new(.true, 'OK', 'Legal Effect v0.6 evaluation input pinned', envelope)

pinInputFailed:
  signal off syntax
  conditionObject = condition('O')
  detailText = 'Legal Effect v0.6 evaluation input lacks deterministic canonical closure'
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

  /* Legal Effect v0.6 resolves declared conflictKey groups explicitly, but
     ungrouped REVIEW + REQUIRES_OBLIGATION dispositions still reduce in
     insertion-sensitive order.  Do not invent precedence here. */
  if \hasBlocking then do
    if assessment~unresolved~items = 0 then do
      if assessment~unresolvedConflicts~items = 0 then do
        if hasReview then do
          if hasConditional then return 'Legal Effect v0.6 has REVIEW/STATUS_EFFECT and REQUIRES_OBLIGATION effective dispositions without explicit status precedence'
        end
      end
    end
  end
  return ''


::class LegalEffectV06PromotionAdapter public

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
      promotionReason = 'Legal Effect v0.6 compiler-certified, verifier-backed assessment pinned to semantic + execution + action/context closure'
    end
    else do
      promotionStatus = .EvidencePromotionConstant~STATUS_UNRESOLVED
      promotionReason = 'legal evaluation envelope is not pinned:' sourceObject~integrityStatus
    end
  end
  else do
    raise syntax 93.900 additional('Legal Effect v0.6 authority promotion requires LegalEffectV06PinnedEvaluator envelope')
  end

  if assessment~generation == .nil then raise syntax 93.900 additional('Legal assessment has no generation')
  if \assessment~generation~sealed then raise syntax 93.900 additional('Only assessments from sealed legal generations may enter promotion')
  if \assessment~generation~publicationEligible then raise syntax 93.900 additional('LEGAL_GENERATION_NOT_COMPILED')

  sourceIdentity = evidence~canonicalIdentity
  authority = 'LEGAL_EFFECT/0.6/' || assessment~generation~generationId || '@' || generationSnapshot~semanticIdentityHash || '+' || generationSnapshot~executionIdentity
  authority = authority || '+cert:' || generationSnapshot~certificateHash || '+verified:' || generationSnapshot~verificationClosureHash
  policyId = 'LEGAL_EFFECT_V06_STATUS_PROJECTION_V1'

  promotionSet = .EvidencePromotionSet~new
  blocked = assessment~status == 'BLOCKED'
  review = assessment~status == 'REVIEW_REQUIRED'
  conditional = assessment~status == 'CONDITIONAL'

  blockedBasis = self~basisFor(assessment, generationSnapshot, 'BLOCKED')
  reviewBasis = self~basisFor(assessment, generationSnapshot, 'REVIEW_REQUIRED')
  conditionalBasis = self~basisFor(assessment, generationSnapshot, 'CONDITIONAL')

  p = .EvidencePromotion~new(sourceIdentity || ':BLOCKED', 'LEGAL_EFFECT_V06', sourceIdentity, prefix || 'ACTION_BLOCKED', 'KNOWN', blocked, authority, policyId, 'ASSESSMENT_STATUS', 'LEGAL_EFFECT', promotionStatus, promotionReason, evidence, assessment, 'FROZEN_OBSERVATION', 'FROZEN_OBSERVATION', blockedBasis)
  ignored = promotionSet~add(p)
  p = .EvidencePromotion~new(sourceIdentity || ':REVIEW', 'LEGAL_EFFECT_V06', sourceIdentity, prefix || 'ACTION_REVIEW_REQUIRED', 'KNOWN', review, authority, policyId, 'ASSESSMENT_STATUS', 'LEGAL_EFFECT', promotionStatus, promotionReason, evidence, assessment, 'FROZEN_OBSERVATION', 'FROZEN_OBSERVATION', reviewBasis)
  ignored = promotionSet~add(p)
  p = .EvidencePromotion~new(sourceIdentity || ':CONDITIONAL', 'LEGAL_EFFECT_V06', sourceIdentity, prefix || 'ACTION_CONDITIONAL', 'KNOWN', conditional, authority, policyId, 'ASSESSMENT_STATUS', 'LEGAL_EFFECT', promotionStatus, promotionReason, evidence, assessment, 'FROZEN_OBSERVATION', 'FROZEN_OBSERVATION', conditionalBasis)
  ignored = promotionSet~add(p)
  ignored = promotionSet~seal
  return promotionSet

::method basisFor private class
  use arg assessment, generationSnapshot, targetStatus
  basis = .array~new

  generationDetail = 'version=' || assessment~generation~version || ';semantic=' || generationSnapshot~semanticIdentityHash || ';execution=' || generationSnapshot~executionIdentity
  basis~append(.EvidencePromotionBasis~new('LEGAL_GENERATION_V06', assessment~generation~generationId, generationDetail, assessment~generation))
  certificate = assessment~generation~compilationCertificate
  certificateDetail = 'compiler=' || certificate~compilerId || ';version=' || certificate~compilerVersion || ';input=' || certificate~inputIdentity
  basis~append(.EvidencePromotionBasis~new('LEGAL_COMPILATION_CERTIFICATE', certificate~inputIdentity, certificateDetail, certificate))
  sourceTable = assessment~generation~sources
  sourceIds = sourceTable~allIndexes
  sourceIds~sort
  do sourceId over sourceIds
    identity = sourceTable[sourceId]~sourceIdentity
    evidence = identity~verificationEvidence
    basis~append(.EvidencePromotionBasis~new('LEGAL_VERIFIED_SOURCE', identity~sourceId, identity~evidenceIdentity, identity))
    if evidence \== .nil then do
      snapshot = self~certificateSnapshotFor(certificate, evidence~evidenceIdentity)
      if snapshot == .nil then raise syntax 93.900 additional('LEGAL_SOURCE_VERIFICATION_NOT_IN_CERTIFICATE:' identity~sourceId)
      detail = self~verificationBasisDetail(snapshot)
      basis~append(.EvidencePromotionBasis~new('LEGAL_SOURCE_VERIFICATION_EVIDENCE', snapshot~evidenceIdentity, detail, snapshot))
    end
  end
  do provision over assessment~generation~provisions
    reference = provision~provisionReference
    evidence = reference~verificationEvidence
    basis~append(.EvidencePromotionBasis~new('LEGAL_VERIFIED_PROVISION', reference~provisionId, reference~evidenceIdentity, reference))
    if evidence \== .nil then do
      snapshot = self~certificateSnapshotFor(certificate, evidence~evidenceIdentity)
      if snapshot == .nil then raise syntax 93.900 additional('LEGAL_PROVISION_VERIFICATION_NOT_IN_CERTIFICATE:' reference~provisionId)
      detail = self~verificationBasisDetail(snapshot)
      basis~append(.EvidencePromotionBasis~new('LEGAL_PROVISION_VERIFICATION_EVIDENCE', snapshot~evidenceIdentity, detail, snapshot))
    end
  end
  basis~append(.EvidencePromotionBasis~new('LEGAL_ACTION', assessment~action~actionCode, assessment~action~description, assessment~action))
  basis~append(.EvidencePromotionBasis~new('ASSESSMENT_STATUS', targetStatus, 'actual=' || assessment~status, assessment))

  /* v0.6 only: suppressed applicable norms are not promotion basis. */
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


::method certificateSnapshotFor private class
  use arg certificate, evidenceIdentity
  do snapshot over certificate~verificationEvidence
    if snapshot~evidenceIdentity == evidenceIdentity then return snapshot
  end
  return .nil

::method verificationBasisDetail private class
  use arg snapshot
  detail = 'subject=' || snapshot~subjectKind
  detail = detail || ';source=' || snapshot~sourceId
  if snapshot~provisionId <> '' then detail = detail || ';provision=' || snapshot~provisionId
  detail = detail || ';representation=' || snapshot~materialRepresentation
  detail = detail || ';locator=' || snapshot~locator
  detail = detail || ';algorithm=' || snapshot~algorithm
  detail = detail || ';expected=' || snapshot~expectedDigest
  detail = detail || ';actual=' || snapshot~actualDigest
  detail = detail || ';verifier=' || snapshot~verifierId
  if snapshot~parentEvidenceIdentity <> '' then detail = detail || ';parent=' || snapshot~parentEvidenceIdentity
  return detail


::requires 'LegalEffectPromotionAdapter.cls'
