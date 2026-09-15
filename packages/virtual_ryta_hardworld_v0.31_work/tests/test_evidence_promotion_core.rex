say 'EVIDENCE PROMOTION CORE START'

a = .PromotionCoreAcceptance~new
exit a~run

::class PromotionCoreAcceptance
::method run
  basis = .EvidencePromotionBasis~new('RULE', 'RULE-1', 'synthetic policy')
  p1 = .EvidencePromotion~new('P1', 'TEST', 'SRC-1', 'THING_ALLOWED', 'KNOWN', .true, 'AUTH-A', 'POLICY-A', 'RULE-1', 'PERMITTED', 'AUTHORIZED', '', .nil, .nil, 'FROZEN_OBSERVATION', 'FROZEN_OBSERVATION', .array~of(basis))
  p2 = .EvidencePromotion~new('P2', 'TEST', 'SRC-2', 'THING_ALLOWED', 'KNOWN', .true, 'AUTH-A', 'POLICY-A', 'RULE-2', 'PERMITTED', 'AUTHORIZED')
  p3 = .EvidencePromotion~new('P3', 'TEST', 'SRC-3', 'NOT_APPLIED', 'KNOWN', .true, 'AUTH-A', 'POLICY-A', 'RULE-3', 'PERMITTED', 'REFUSED')

  promotionSet = .EvidencePromotionSet~new
  call AssertTrue promotionSet~add(p1), 'add p1'
  call AssertTrue promotionSet~add(p2), 'add p2'
  call AssertTrue promotionSet~add(p3), 'add p3'
  ignored = promotionSet~seal

  world = .RYTAWorldState~new('PROMOTION-WORLD')
  applyStatus = .EvidencePromotionApplier~apply(promotionSet, world)
  call AssertEqual 1, applyStatus~applied, 'one target applied'
  call AssertEqual 0, applyStatus~conflicts, 'no conflicts'
  call AssertEqual 1, applyStatus~skipped, 'refused skipped'
  call AssertTrue world~isKnownTrue('THING_ALLOWED'), 'promoted true fact'
  call AssertEqual 'UNKNOWN', world~knowledgeOf('NOT_APPLIED'), 'refused promotion not applied'
  factObject = world~fact('THING_ALLOWED')
  call AssertTrue factObject~evidence~isA(.EvidencePromotionBundle), 'bundle retained as fact evidence'
  call AssertEqual 2, factObject~evidence~promotions~items, 'both agreeing promotions retained'

  c1 = .EvidencePromotion~new('C1', 'TEST', 'SRC-C1', 'THING_CONFLICT', 'KNOWN', .true, 'AUTH-A')
  c2 = .EvidencePromotion~new('C2', 'TEST', 'SRC-C2', 'THING_CONFLICT', 'KNOWN', .false, 'AUTH-B')
  conflictSet = .EvidencePromotionSet~new
  call AssertTrue conflictSet~add(c1), 'add c1'
  call AssertTrue conflictSet~add(c2), 'add c2'
  ignored = conflictSet~seal
  conflictStatus = .EvidencePromotionApplier~apply(conflictSet, world)
  call AssertEqual 1, conflictStatus~conflicts, 'conflict counted'
  call AssertEqual 'CONFLICT', world~knowledgeOf('THING_CONFLICT'), 'conflicting promotions become HardWorld conflict'
  call AssertTrue world~fact('THING_CONFLICT')~evidence~isA(.EvidencePromotionBundle), 'conflict retains all promotions'

  strong = .EvidencePromotion~new('S1', 'TEST', 'SRC-S1', 'NEEDS_SNAPSHOT', 'KNOWN', .true, 'AUTH-A', 'POLICY-A', 'RULE-S', 'REQUIRED', 'AUTHORIZED', '', .nil, .nil, 'SOURCE_SNAPSHOT', 'FROZEN_OBSERVATION')
  strongSet = .EvidencePromotionSet~new
  call AssertTrue strongSet~add(strong), 'add consistency-gated promotion'
  ignored = strongSet~seal
  strongStatus = .EvidencePromotionApplier~apply(strongSet, world)
  call AssertEqual 1, strongStatus~skipped, 'insufficient consistency promotion skipped'
  call AssertEqual 'UNKNOWN', world~knowledgeOf('NEEDS_SNAPSHOT'), 'weak temporal evidence cannot promote fact'

  duplicateSet = .EvidencePromotionSet~new
  call AssertTrue duplicateSet~add(p1), 'duplicate-id seed accepted'
  duplicateId = .EvidencePromotion~new('P1', 'TEST', 'OTHER-SOURCE', 'OTHER_TARGET', 'KNOWN', .false, 'AUTH-B')
  call AssertTrue \duplicateSet~add(duplicateId), 'duplicate promotion id rejected explicitly'

  text1 = promotionSet~algorithmCanonicalText
  secondSet = .EvidencePromotionSet~new
  call AssertTrue secondSet~add(p3), 'second add p3'
  call AssertTrue secondSet~add(p2), 'second add p2'
  call AssertTrue secondSet~add(p1), 'second add p1'
  ignored = secondSet~seal
  call AssertEqual text1, secondSet~algorithmCanonicalText, 'promotion set identity is order independent'

  say 'EVIDENCE PROMOTION CORE: OK'
  return 0

::routine AssertTrue
  use arg condition, label
  if \condition then raise syntax 88.900 array('ASSERT TRUE FAILED: ' || label)
  return 0

::routine AssertEqual
  use arg expected, actual, label
  if expected \== actual then raise syntax 88.900 array('ASSERT EQUAL FAILED: ' || label || ' expected=' || expected || ' actual=' || actual)
  return 0

::requires '../algorithm/EvidencePromotion.cls'
::requires '../HardWorld.cls'
