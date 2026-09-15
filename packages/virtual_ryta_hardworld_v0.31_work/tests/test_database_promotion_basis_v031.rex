say 'RYTA DATABASE PROMOTION BASIS V0.31 START'

attempt = .DatabaseExecutionAttemptEvidence~new(1, 'DB-TX-31:attempt:1', 'DB-TX-31', 'SUCCESS', 'SUCCESS', .false, .nil)
evidence = .DatabaseTransactionEvidence~new('DB-TX-31', 'COMMITTED', 'SUCCESS', 'SUCCESS', 1, .array~of(attempt), 'db://orders/update', 'CANONICAL-SHA256:abc123', .nil, .nil)
adapter1 = .DatabaseTransactionPromotionBasisAdapter~new
adapter2 = .DatabaseTransactionPromotionBasisAdapter~new
basis1 = adapter1~basisFrom(evidence, 'post-commit audit')
basis2 = adapter2~basisFrom(evidence, 'post-commit audit')

call AssertEqual 'DATABASE_TRANSACTION_EVIDENCE', basis1~basisKind, 'basis kind explicit'
call AssertEqual evidence~evidenceIdentity, basis1~basisId, 'basis id is detached evidence identity'
call AssertTrue basis1~nativeObject == evidence, 'native detached evidence retained'
call AssertEqual basis1~algorithmCanonicalText, basis2~algorithmCanonicalText, 'Alchemy adapter identity does not enter basis identity'
call AssertTrue ExpectPromotionRefused(adapter1, evidence), 'database evidence cannot directly mint promotion'

/* Rich successful database evidence does not rescue a refused promotion. */
refused = .EvidencePromotion~new('DB-BASIS-REFUSED', 'TEST', 'SRC-DB-REFUSED', 'DB_BASIS_MUST_NOT_GRANT', 'KNOWN', .true, 'NO_AUTHORITY', 'TEST-POLICY', 'TEST-RULE', 'PERMITTED', 'REFUSED', 'database evidence is basis only', .nil, .nil, 'FROZEN_OBSERVATION', 'FROZEN_OBSERVATION', .array~of(basis1))
refusedSet = .EvidencePromotionSet~new
call AssertTrue refusedSet~add(refused), 'refused promotion accepted into audit set'
ignore = refusedSet~seal
world = .RYTAWorldState~new('DB-BASIS-WORLD')
status = .EvidencePromotionApplier~apply(refusedSet, world)
call AssertEqual 0, status~applied, 'refused promotion not applied'
call AssertEqual 1, status~skipped, 'refused promotion skipped despite DB basis'
call AssertEqual 'UNKNOWN', world~knowledgeOf('DB_BASIS_MUST_NOT_GRANT'), 'database basis grants no fact'

/* The same basis may accompany an independently-authorized promotion; its role
   remains provenance because authorization is explicit on the promotion. */
authorized = .EvidencePromotion~new('DB-BASIS-AUTH', 'INDEPENDENT_AUTHORITY', 'SRC-AUTH', 'DB_BASIS_AUDITED_ACTION', 'KNOWN', .true, 'EXPLICIT_TEST_AUTHORITY', 'TEST-POLICY', 'TEST-RULE', 'REQUIRED', 'AUTHORIZED', 'authority independent of database provenance', .nil, .nil, 'FROZEN_OBSERVATION', 'FROZEN_OBSERVATION', .array~of(basis1))
authorizedSet = .EvidencePromotionSet~new
call AssertTrue authorizedSet~add(authorized), 'independently authorized promotion added'
ignore = authorizedSet~seal
status2 = .EvidencePromotionApplier~apply(authorizedSet, world)
call AssertEqual 1, status2~applied, 'independently authorized promotion applied'
call AssertTrue world~isKnownTrue('DB_BASIS_AUDITED_ACTION'), 'authorized fact applied with DB evidence retained as basis'
call AssertTrue world~fact('DB_BASIS_AUDITED_ACTION')~evidence~promotions[1]~basis[1]~nativeObject == evidence, 'database evidence reachable from applied promotion basis'

say '  evidence=' || evidence~evidenceIdentity
say '  basis=' || basis1~basisId
say '  rule=DATABASE_PROVENANCE_IS_BASIS_NOT_AUTHORITY'
say 'RYTA DATABASE PROMOTION BASIS V0.31: OK'
exit 0

::routine ExpectPromotionRefused
  use strict arg adapter, evidence
  signal on syntax name refused
  ignore = adapter~promotionsFrom(evidence)
  signal off syntax
  return .false
refused:
  signal off syntax
  c = condition('O')
  return c~additional~items > 0 & c~additional[1]~pos('DATABASE_TRANSACTION_EVIDENCE_NOT_AUTHORITY') > 0

::routine AssertTrue
  use strict arg value, label
  if \value then raise syntax 88.900 array('ASSERT TRUE FAILED: ' || label)
  return 0
::routine AssertEqual
  use strict arg expected, actual, label
  if expected \== actual then raise syntax 88.900 array('ASSERT EQUAL FAILED: ' || label || ' expected=' || expected || ' actual=' || actual)
  return 0

::requires '../integration/DatabaseTransactionPromotionBasisAdapter.cls'
::requires '../HardWorld.cls'
