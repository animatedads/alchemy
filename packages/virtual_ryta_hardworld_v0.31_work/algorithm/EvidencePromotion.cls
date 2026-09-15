/*
 * EvidencePromotion.cls
 *
 * Domain-neutral, evidence-bearing promotion boundary between observed or
 * assessed evidence and HardWorld facts.  A promotion is not an authority
 * engine: it records the authority/policy/rule which entitled a caller to
 * propose a fact.  Only AUTHORIZED promotions are eligible for application.
 */

::class EvidencePromotionConstant public
::constant STATUS_AUTHORIZED 'AUTHORIZED'
::constant STATUS_REFUSED    'REFUSED'
::constant STATUS_UNRESOLVED 'UNRESOLVED'

::class EvidencePromotionBasis public
::attribute basisKind get
::attribute basisId get
::attribute detail get
::attribute nativeObject get

::method init
  expose basisKind basisId detail nativeObject
  use arg basisKindArg, basisIdArg, detailArg = '', nativeObjectArg = .nil
  basisKind = basisKindArg~string~upper
  basisId = basisIdArg~string
  detail = detailArg~string
  nativeObject = nativeObjectArg

::method algorithmCanonicalText
  expose basisKind basisId detail
  text = 'EVIDENCE_PROMOTION_BASIS_V1' || '0a'x
  text = text || self~field('KIND', basisKind)
  text = text || self~field('ID', basisId)
  text = text || self~field('DETAIL', detail)
  return text

::method field private
  use arg name, value
  rendered = value~string
  return name || '=' || rendered~length || ':' || rendered || '0a'x


::class EvidencePromotion subclass RYTAObject public
::attribute promotionId get
::attribute sourceKind get
::attribute sourceIdentity get
::attribute sourceObject get
::attribute targetFactName get
::attribute proposedKnowledgeState get
::attribute proposedValue get
::attribute authority get
::attribute policyId get
::attribute ruleId get
::attribute disposition get
::attribute promotionStatus get
::attribute reason get
::attribute evidence get
::attribute minimumConsistency get
::attribute actualConsistency get

::method init
  expose promotionId sourceKind sourceIdentity sourceObject targetFactName proposedKnowledgeState proposedValue authority policyId ruleId disposition promotionStatus reason evidence minimumConsistency actualConsistency storedBasis
  use arg promotionIdArg, sourceKindArg, sourceIdentityArg, targetFactNameArg, proposedKnowledgeStateArg = 'KNOWN', proposedValueArg = .nil, authorityArg = '', policyIdArg = '', ruleIdArg = '', dispositionArg = '', promotionStatusArg = 'AUTHORIZED', reasonArg = '', evidenceArg = .nil, sourceObjectArg = .nil, minimumConsistencyArg = 'FROZEN_OBSERVATION', actualConsistencyArg = 'FROZEN_OBSERVATION', basisArg = .nil
  self~init:super('EvidencePromotion', 'PROMOTION_AUTHORITY_EVIDENCE')
  promotionId = promotionIdArg~string
  sourceKind = sourceKindArg~string~upper
  sourceIdentity = sourceIdentityArg~string
  sourceObject = sourceObjectArg
  targetFactName = targetFactNameArg~string~upper
  proposedKnowledgeState = proposedKnowledgeStateArg~string~upper
  proposedValue = proposedValueArg
  authority = authorityArg~string
  policyId = policyIdArg~string
  ruleId = ruleIdArg~string
  disposition = dispositionArg~string~upper
  promotionStatus = promotionStatusArg~string~upper
  reason = reasonArg~string
  evidence = evidenceArg
  minimumConsistency = minimumConsistencyArg~string~upper
  actualConsistency = actualConsistencyArg~string~upper
  storedBasis = .array~new
  if basisArg \== .nil then do basisItem over basisArg
    storedBasis~append(basisItem)
  end

::method basis
  expose storedBasis
  copied = .array~new
  do basisItem over storedBasis
    copied~append(basisItem)
  end
  return copied

::method canonicalProposedValue
  expose proposedValue
  if proposedValue == .nil then return 'NULL'
  if proposedValue == .true then return 'BOOLEAN:TRUE'
  if proposedValue == .false then return 'BOOLEAN:FALSE'
  if proposedValue~class == .String then return 'TEXT:' || proposedValue~length || ':' || proposedValue
  if datatype(proposedValue, 'N') == 1 then return 'NUMBER:' || proposedValue
  if proposedValue~hasMethod('ALGORITHMCANONICALTEXT') then do
    valueText = proposedValue~algorithmCanonicalText
    return 'OBJECT:' || valueText~length || ':' || valueText
  end
  raise syntax 93.900 additional('Promotion proposed value lacks explicit canonical contract')

::method valueType
  expose proposedValue
  if proposedValue == .nil then return 'NULL'
  if proposedValue == .true then return 'BOOLEAN'
  if proposedValue == .false then return 'BOOLEAN'
  if proposedValue~class == .String then return 'TEXT'
  if datatype(proposedValue, 'N') == 1 then return 'NUMBER'
  return 'OBJECT'

::method algorithmCanonicalText
  expose storedBasis evidence
  text = 'EVIDENCE_PROMOTION_V1' || '0a'x
  text = text || self~field('PROMOTION_ID', self~promotionId)
  text = text || self~field('SOURCE_KIND', self~sourceKind)
  text = text || self~field('SOURCE_IDENTITY', self~sourceIdentity)
  text = text || self~field('TARGET_FACT', self~targetFactName)
  text = text || self~field('KNOWLEDGE_STATE', self~proposedKnowledgeState)
  valueText = self~canonicalProposedValue
  text = text || self~field('VALUE', valueText)
  text = text || self~field('AUTHORITY', self~authority)
  text = text || self~field('POLICY_ID', self~policyId)
  text = text || self~field('RULE_ID', self~ruleId)
  text = text || self~field('DISPOSITION', self~disposition)
  text = text || self~field('STATUS', self~promotionStatus)
  text = text || self~field('REASON', self~reason)
  text = text || self~field('MIN_CONSISTENCY', self~minimumConsistency)
  text = text || self~field('ACTUAL_CONSISTENCY', self~actualConsistency)

  basisTexts = .array~new
  do basisItem over storedBasis
    if \basisItem~hasMethod('ALGORITHMCANONICALTEXT') then raise syntax 93.900 additional('Promotion basis lacks ALGORITHMCANONICALTEXT')
    basisTexts~append(basisItem~algorithmCanonicalText)
  end
  basisTexts~sort
  text = text || 'BASIS_COUNT=' || basisTexts~items || '0a'x
  do basisText over basisTexts
    text = text || basisText~length || ':' || basisText || '0a'x
  end

  if evidence == .nil then text = text || 'EVIDENCE=NULL' || '0a'x
  else do
    if \evidence~hasMethod('ALGORITHMCANONICALTEXT') then raise syntax 93.900 additional('Promotion evidence lacks ALGORITHMCANONICALTEXT')
    evidenceText = evidence~algorithmCanonicalText
    text = text || 'EVIDENCE=' || evidenceText~length || ':' || evidenceText || '0a'x
  end
  return text

::method field private
  use arg name, value
  rendered = value~string
  return name || '=' || rendered~length || ':' || rendered || '0a'x


::class EvidencePromotionSet subclass RYTAObject public
::attribute sealed get

::method init
  expose storedPromotions storedIds sealed
  self~init:super('EvidencePromotionSet', 'PROMOTION_SET')
  storedPromotions = .array~new
  storedIds = .directory~new
  sealed = .false

::method add
  expose storedPromotions storedIds sealed
  use arg promotion
  if sealed then return .false
  if promotion == .nil then return .false
  id = promotion~promotionId
  if id == '' then return .false
  if storedIds~hasIndex(id) then return .false
  storedPromotions~append(promotion)
  storedIds[id] = promotion
  return .true

::method seal
  expose sealed
  sealed = .true
  return self

::method promotions
  expose storedPromotions storedIds
  copied = .array~new
  ids = storedIds~allIndexes
  ids~sort
  do id over ids
    copied~append(storedIds[id])
  end
  return copied

::method count
  expose storedPromotions
  return storedPromotions~items

::method algorithmCanonicalText
  expose storedPromotions sealed
  if \sealed then raise syntax 93.900 additional('EvidencePromotionSet must be sealed before canonicalisation')
  texts = .array~new
  do promotion over storedPromotions
    texts~append(promotion~algorithmCanonicalText)
  end
  texts~sort
  text = 'EVIDENCE_PROMOTION_SET_V1' || '0a'x || 'COUNT=' || texts~items || '0a'x
  do promotionText over texts
    text = text || promotionText~length || ':' || promotionText || '0a'x
  end
  return text


::class EvidencePromotionBundle subclass RYTAObject public
::attribute targetFactName get

::method init
  expose targetFactName storedPromotions
  use arg targetFactNameArg, promotionsArg
  self~init:super('EvidencePromotionBundle', 'PROMOTION_BUNDLE')
  targetFactName = targetFactNameArg~string~upper
  storedPromotions = .array~new
  do promotion over promotionsArg
    storedPromotions~append(promotion)
  end

::method promotions
  expose storedPromotions
  copied = .array~new
  byId = .directory~new
  do promotion over storedPromotions
    byId[promotion~promotionId] = promotion
  end
  ids = byId~allIndexes
  ids~sort
  do id over ids
    copied~append(byId[id])
  end
  return copied

::method algorithmCanonicalText
  expose storedPromotions targetFactName
  texts = .array~new
  do promotion over storedPromotions
    texts~append(promotion~algorithmCanonicalText)
  end
  texts~sort
  text = 'EVIDENCE_PROMOTION_BUNDLE_V1' || '0a'x
  text = text || 'TARGET=' || targetFactName~length || ':' || targetFactName || '0a'x
  text = text || 'COUNT=' || texts~items || '0a'x
  do promotionText over texts
    text = text || promotionText~length || ':' || promotionText || '0a'x
  end
  return text


::class EvidencePromotionApplyResult subclass RYTAObject public
::attribute applied get
::attribute conflicts get
::attribute skipped get

::method init
  expose applied conflicts skipped
  use arg appliedArg = 0, conflictsArg = 0, skippedArg = 0
  self~init:super('EvidencePromotionApplyResult', 'PROMOTION_APPLY_RESULT')
  applied = appliedArg
  conflicts = conflictsArg
  skipped = skippedArg


::class EvidencePromotionApplier public


::method apply class
  use arg promotionSet, world
  if promotionSet == .nil then raise syntax 93.900 additional('Promotion set must not be .nil')
  if \promotionSet~sealed then raise syntax 93.900 additional('Promotion set must be sealed before application')
  if world == .nil then raise syntax 93.900 additional('HardWorld world must not be .nil')

  byTarget = .directory~new
  skipped = 0
  do promotion over promotionSet~promotions
    if promotion~promotionStatus \== .EvidencePromotionConstant~STATUS_AUTHORIZED then do
      skipped = skipped + 1
      iterate
    end
    if \self~consistencySatisfies(promotion~actualConsistency, promotion~minimumConsistency) then do
      skipped = skipped + 1
      iterate
    end
    key = promotion~targetFactName
    if \byTarget~hasIndex(key) then byTarget[key] = .array~new
    byTarget[key]~append(promotion)
  end

  applied = 0
  conflicts = 0
  do targetFact over byTarget
    candidates = byTarget[targetFact]
    firstPromotion = candidates[1]
    same = .true
    firstState = firstPromotion~proposedKnowledgeState
    firstValueText = firstPromotion~canonicalProposedValue
    do candidate over candidates
      if candidate~proposedKnowledgeState \== firstState then same = .false
      if candidate~canonicalProposedValue \== firstValueText then same = .false
    end

    bundle = .EvidencePromotionBundle~new(targetFact, candidates)
    if \same then do
      ignored = world~putConflict(targetFact, 'EVIDENCE_PROMOTION', 'CONFLICTING_PROMOTIONS', bundle)
      conflicts = conflicts + 1
      iterate
    end

    authority = firstPromotion~authority
    do candidate over candidates
      if candidate~authority \== authority then authority = 'MULTIPLE_AUTHORITIES'
    end

    select
      when firstState == 'KNOWN' then ignored = world~putKnown(targetFact, firstPromotion~proposedValue, 'EVIDENCE_PROMOTION', authority, bundle)
      when firstState == 'UNKNOWN' then ignored = world~putUnknown(targetFact, 'EVIDENCE_PROMOTION', authority, bundle)
      when firstState == 'CONFLICT' then ignored = world~putConflict(targetFact, 'EVIDENCE_PROMOTION', authority, bundle)
      otherwise do
        ignored = world~putUnknown(targetFact, 'INVALID_PROMOTION_STATE', authority, bundle)
      end
    end
    applied = applied + 1
  end

  return .EvidencePromotionApplyResult~new(applied, conflicts, skipped)

::method consistencySatisfies private class
  use arg actualGrade, requiredGrade
  actualRank = self~consistencyRank(actualGrade)
  requiredRank = self~consistencyRank(requiredGrade)
  if actualRank = 0 then return .false
  if requiredRank = 0 then return .false
  return actualRank >= requiredRank

::method consistencyRank private class
  use arg grade
  grade = grade~string~upper
  if grade == 'FROZEN_OBSERVATION' then return 10
  if grade == 'SOURCE_SNAPSHOT' then return 20
  if grade == 'COORDINATED_SNAPSHOT' then return 30
  return 0

::requires "RYTAObject.cls"
