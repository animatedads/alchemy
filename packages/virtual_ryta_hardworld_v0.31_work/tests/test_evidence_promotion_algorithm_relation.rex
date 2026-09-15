say 'EVIDENCE PROMOTION ALGORITHM RELATION START'

a = .PromotionAlgrelAcceptance~new
exit a~run

::class PromotionAlgrelAcceptance
::method run
  basis = .array~of(.EvidencePromotionBasis~new('RULE','RULE-7','why',.directory~new))
  promotion = .EvidencePromotion~new('P-7','TEST','SRC-7','LEGAL_ACTION_BLOCKED','KNOWN',.true,'AUTH-7','POLICY-7','RULE-7','PROHIBITED','AUTHORIZED','because',.nil,.directory~new,'FROZEN_OBSERVATION','FROZEN_OBSERVATION',basis)
  promotionSet = .EvidencePromotionSet~new
  call AssertTrue promotionSet~add(promotion), 'promotion added'
  ignored = promotionSet~seal

  engine = .AlgorithmRelationEngine~new
  provider = .EvidencePromotionAlgorithmProvider~new('..')
  call AssertTrue engine~addProvider(provider), 'provider added'
  call AssertEqual 0, provider~invocationCount, 'catalog path starts at zero'
  call AssertEqual 3, provider~declaredSchemas~items, 'three schemas declared without execution'
  call AssertEqual 0, provider~invocationCount, 'schema discovery did not execute provider'

  context = .AlgorithmExecutionContext~new('PROMO-INV-1','PROMO-INPUT','PROMO-WORLD')
  algResult = engine~execute(provider~algorithmId,promotionSet,context)
  call AssertEqual 1, provider~invocationCount, 'first materialization executes once'
  relation = algResult~relation('EVIDENCE_PROMOTIONS')
  call AssertEqual 1, relation~rows~items, 'one promotion row'
  row = relation~rows[1]
  call AssertEqual 'LEGAL_ACTION_BLOCKED', row~value('TARGET_FACT'), 'target visible'
  call AssertTrue row~value('VALUE_BOOLEAN'), 'boolean value preserved'
  call AssertEqual 'AUTHORIZED', row~value('PROMOTION_STATUS'), 'status visible'
  call AssertTrue row~value('NATIVE_SOURCE_PRESERVED'), 'source object retained internally'
  basisRelation = algResult~relation('EVIDENCE_PROMOTION_BASIS')
  call AssertEqual 1, basisRelation~rows~items, 'basis projected separately'
  call AssertEqual 'RULE-7', basisRelation~rows[1]~value('BASIS_ID'), 'basis id visible'

  context2 = .AlgorithmExecutionContext~new('PROMO-INV-2','PROMO-INPUT','PROMO-WORLD')
  replay = engine~execute(provider~algorithmId,promotionSet,context2)
  call AssertEqual 1, provider~invocationCount, 'second invocation reuses materialization'
  call AssertEqual 'PROMO-INV-2', replay~relation('EVIDENCE_PROMOTIONS')~rows[1]~value('INVOCATION_ID'), 'audit invocation rebound on replay'

  say 'EVIDENCE PROMOTION ALGORITHM RELATION: OK'
  return 0

::routine AssertTrue
  use arg condition, label
  if \condition then raise syntax 88.900 array('ASSERT TRUE FAILED: ' || label)
  return 0

::routine AssertEqual
  use arg expected, actual, label
  if expected \== actual then raise syntax 88.900 array('ASSERT EQUAL FAILED: ' || label || ' expected=' || expected || ' actual=' || actual)
  return 0

::requires '../integration/EvidencePromotionAlgorithmProvider.cls'
