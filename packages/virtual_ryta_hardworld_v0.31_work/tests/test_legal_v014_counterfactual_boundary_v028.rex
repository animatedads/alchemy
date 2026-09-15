say 'RYTA LEGAL V0.14 COUNTERFACTUAL NON-AUTHORITY V0.28 START'

/* Build a real Legal Effect v0.14 base assessment and run the public
   counterfactual evaluator.  No RYTA mock stands in for Legal Effect here. */
source = .NormativeSource~new('RYTA-CF-LICENCE-ACT', 'LEGISLATION', 'Synthetic licence rule', 'PARLIAMENT', 'ENGLAND')
gen = .LegalRuleGeneration~new('RYTA-CF-G1', '0.14')
ignored = gen~addSource(source)
norm = .LegalNorm~new('RYTA-CF-LICENCE-NORM', source~sourceId, '20', 'PROHIBITION', 'SHIP_GOODS', 'PROHIBITED', 'LICENSING', 'active licence forbids this synthetic shipment')
ignored = norm~addCondition(.LegalPredicate~new('LICENCE_ACTIVE', 'KNOWN_TRUE'))
ignored = norm~addEvidence(.LegalEvidenceAnchor~new(source~sourceId, 'LEGAL_PROVISION', 's.20', .nil, 'PARLIAMENT'))
ignored = gen~addNorm(norm)
ignored = gen~seal
context = .LegalContext~new('RYTA-CF-EVENT', '2026-08-24')
action = .LegalAction~new('SHIP_GOODS', 'ship regulated goods')
baseResult = .LegalEffectEngine~new~evaluate(action, gen, context)
call AssertTrue baseResult~ok, 'base Legal evaluation succeeds'
call AssertEqual 'REVIEW_REQUIRED', baseResult~value~status, 'base Legal status'

evaluator = .LegalCounterfactualEvaluator~new
trueResult = evaluator~evaluateFact(baseResult~value, 'LICENCE_ACTIVE', .true)
falseResult = evaluator~evaluateFact(baseResult~value, 'LICENCE_ACTIVE', .false)
call AssertTrue trueResult~ok, 'true counterfactual succeeds'
call AssertTrue falseResult~ok, 'false counterfactual succeeds'
trueCf = trueResult~value
falseCf = falseResult~value
call AssertEqual .true, trueCf~hypothetical, 'Legal counterfactual labels hypothetical'
call AssertEqual .false, trueCf~authoritative, 'Legal counterfactual labels non-authoritative'
call AssertEqual 'COUNTERFACTUAL_ASSUMPTION', trueCf~assumption~authority, 'assumption authority explicitly hypothetical'
call AssertEqual 'BLOCKED', trueCf~counterfactualStatus, 'true branch analysis result'
call AssertEqual 'ADMISSIBLE', falseCf~counterfactualStatus, 'false branch analysis result'

adapter1 = .LegalEffectV014CounterfactualEvidenceAdapter~new
adapter2 = .LegalEffectV014CounterfactualEvidenceAdapter~new
trueEvidence = adapter1~project(trueCf)
trueAgain = adapter2~project(evaluator~evaluateFact(baseResult~value, 'LICENCE_ACTIVE', .true)~value)
falseEvidence = adapter1~project(falseCf)

call AssertEqual .true, trueEvidence~hypothetical, 'RYTA projection remains hypothetical'
call AssertEqual .false, trueEvidence~authoritative, 'RYTA projection remains non-authoritative'
call AssertEqual .false, trueEvidence~promotionEligible, 'RYTA projection explicitly not promotion-eligible'
call AssertEqual 'COUNTERFACTUAL_ASSUMPTION', trueEvidence~assumptionAuthority, 'RYTA keeps hypothetical assumption authority'
call AssertEqual 'LICENCE_ACTIVE', trueEvidence~assumptionFactName, 'assumption fact retained'
call AssertEqual 'BLOCKED', trueEvidence~counterfactualStatus, 'counterfactual status retained as evidence'
call AssertTrue trueEvidence~nativeObject == trueCf, 'native Legal comparison remains reachable as provenance'

/* Same Legal analysis has a stable evidence identity even though it travelled
   through different Alchemy adapter objects. Alchemy object ids are not part
   of the counterfactual evidence identity. */
call AssertTrue adapter1~alchemyObjectId \== adapter2~alchemyObjectId, 'Alchemy adapter identities differ'
call AssertEqual trueEvidence~evidenceIdentity, trueAgain~evidenceIdentity, 'same Legal counterfactual has stable RYTA evidence identity'
call AssertEqual trueEvidence~algorithmCanonicalText, trueAgain~algorithmCanonicalText, 'same Legal counterfactual canonical projection stable'
call AssertTrue trueEvidence~evidenceIdentity \== falseEvidence~evidenceIdentity, 'changed assumption value changes evidence identity'

/* The evidence-only adapter has an explicit refusal surface. */
call ExpectCounterfactualPromotionRefusal adapter1, trueCf

/* And the EvidencePromotionApplier cannot consume the projected evidence as a
   promotion set. This is a type/behaviour boundary, not a status flag that a
   caller can flip. */
call ExpectApplierRefusal trueEvidence

say '  true_evidence=' || trueEvidence~evidenceIdentity
say '  false_evidence=' || falseEvidence~evidenceIdentity
say 'RYTA LEGAL V0.14 COUNTERFACTUAL NON-AUTHORITY V0.28: OK'
exit 0

::routine ExpectCounterfactualPromotionRefusal
  use strict arg adapter, comparison
  signal on syntax name Refused
  ignored = adapter~promotionsFrom(comparison)
  signal off syntax
  raise syntax 88.900 array('counterfactual promotion unexpectedly succeeded')
Refused:
  signal off syntax
  return 0

::routine ExpectApplierRefusal
  use strict arg evidence
  signal on syntax name Refused
  ignored = .EvidencePromotionApplier~apply(evidence, .nil)
  signal off syntax
  raise syntax 88.900 array('counterfactual evidence unexpectedly applied as authority')
Refused:
  signal off syntax
  return 0

::routine AssertTrue
  use strict arg value, label
  if \value then raise syntax 88.900 array('ASSERT TRUE FAILED: ' || label)
  return 0

::routine AssertEqual
  use strict arg expected, actual, label
  if expected \== actual then raise syntax 88.900 array('ASSERT EQUAL FAILED: ' || label || ' expected=' || expected || ' actual=' || actual)
  return 0

::requires '../integration/LegalEffectV014CounterfactualEvidenceAdapter.cls'
::requires '../algorithm/EvidencePromotion.cls'
::requires 'LegalEffect.cls'
