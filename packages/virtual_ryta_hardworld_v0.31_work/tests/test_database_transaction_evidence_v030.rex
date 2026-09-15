say 'RYTA DATABASE TRANSACTION / RETRY EVIDENCE V0.30 START'

adapter = .DatabaseTransactionEvidenceAdapter~new
context = .DatabaseExecutionContext~new(.PoisonCanonicalEvidence~new('GEN-A'), 'db://orders/update')
identity = .DatabaseTransactionIdentity~new('RYTA-DB-LOGICAL-001')
db = .RetryDatabase~new
tx = db~transaction(context, identity)
call AssertEqual .Error~SUCCESS, tx~setRetryAttempts(2), 'retry policy accepted'
tx~execute('UPDATE account SET balance = balance + 1 WHERE id = 1')
rs = tx~commit
call AssertEqual .Error~SUCCESS, rs~status, 'source transaction succeeds'
call AssertEqual 2, rs~attemptCount, 'source has two physical attempts'

evidence = adapter~project(rs)
call AssertEqual 'RYTA-DB-LOGICAL-001', evidence~transactionId, 'logical transaction identity retained'
call AssertEqual 2, evidence~attemptCount, 'detached attempt count'
call AssertTrue evidence~retried, 'retry state retained'
call AssertTrue evidence~nativeTransactionResult == rs, 'native result remains reachable as provenance'
call AssertTrue evidence~nativeExecutionContext == context, 'native execution context remains reachable'
call AssertEqual 'db://orders/update', evidence~contextLocator, 'context locator retained'
call AssertTrue evidence~contextEvidenceIdentity~pos('CANONICAL-SHA256:') = 1, 'rich context uses explicit canonical identity'
call AssertTrue \evidence~promotionEligible, 'database provenance explicitly non-promotable'

attempts = evidence~attempts
call AssertEqual 2, attempts~items, 'attempt snapshot count'
call AssertEqual 1, attempts[1]~attemptNumber, 'first physical attempt number'
call AssertEqual 'RYTA-DB-LOGICAL-001:attempt:1', attempts[1]~attemptId, 'first physical attempt id'
call AssertTrue attempts[1]~retryable, 'deadlock attempt marked retryable'
call AssertEqual 2, attempts[2]~attemptNumber, 'second physical attempt number'
call AssertEqual 'RYTA-DB-LOGICAL-001:attempt:2', attempts[2]~attemptId, 'second physical attempt id'
call AssertTrue \attempts[2]~retryable, 'successful attempt not retryable'
call AssertTrue attempts[1]~nativeAttempt == rs~attempts[1], 'native first attempt retained separately'
call AssertTrue attempts[2]~nativeAttempt == rs~attempts[2], 'native second attempt retained separately'

context2 = .DatabaseExecutionContext~new(.PoisonCanonicalEvidence~new('GEN-A'), 'db://orders/update')
rs2 = RunRetry(.RetryDatabase~new, context2, .DatabaseTransactionIdentity~new('RYTA-DB-LOGICAL-001'))
evidence2 = .DatabaseTransactionEvidenceAdapter~new~project(rs2)
call AssertEqual evidence~evidenceIdentity, evidence2~evidenceIdentity, 'equivalent retry evidence identity deterministic'

rs3 = RunRetry(.RetryDatabase~new, context2, .DatabaseTransactionIdentity~new('RYTA-DB-LOGICAL-002'))
evidence3 = adapter~project(rs3)
call AssertTrue evidence3~evidenceIdentity \== evidence~evidenceIdentity, 'different logical transaction changes evidence identity'

frozenId = evidence~evidenceIdentity
rs~attempts~append(.nil)
call AssertEqual 2, evidence~attempts~items, 'captured attempts detached from source array'
call AssertEqual frozenId, evidence~evidenceIdentity, 'captured evidence identity unchanged after source mutation'
call AssertTrue ExpectProjectRefused(adapter, rs, 'DATABASE_ATTEMPT_COUNT_MISMATCH'), 'mutated source cannot be re-certified silently'

opaqueContext = .DatabaseExecutionContext~new(.OpaqueEvidence~new, 'db://opaque')
opaqueResult = RunOne(.SingleDatabase~new, opaqueContext, .DatabaseTransactionIdentity~new('RYTA-DB-OPAQUE'))
call AssertTrue ExpectProjectRefused(adapter, opaqueResult, 'DATABASE_CONTEXT_EVIDENCE_IDENTITY_REQUIRED'), 'opaque evidence rejected rather than stringified'
call AssertTrue ExpectPromotionRefused(adapter, evidence), 'database retry provenance has explicit no-authority route'

say '  transaction=' || evidence~transactionId || ' attempts=' || evidence~attemptCount
say '  evidence=' || evidence~evidenceIdentity
say '  retry_semantics=PROVENANCE_ONLY promotion=REFUSED'
say 'RYTA DATABASE TRANSACTION / RETRY EVIDENCE V0.30: OK'
exit 0

::routine RunRetry
  use strict arg db, context, identity
  tx = db~transaction(context, identity)
  ignore = tx~setRetryAttempts(2)
  tx~execute('UPDATE account SET balance = balance + 1 WHERE id = 1')
  return tx~commit

::routine RunOne
  use strict arg db, context, identity
  tx = db~transaction(context, identity)
  tx~execute('UPDATE account SET balance = balance + 1 WHERE id = 1')
  return tx~commit

::routine ExpectProjectRefused
  use strict arg adapter, txResult, expected
  signal on syntax name refused
  ignore = adapter~project(txResult)
  signal off syntax
  return .false
refused:
  signal off syntax
  c = condition('O')
  return c~additional~items > 0 & c~additional[1]~pos(expected) > 0

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

::class PoisonCanonicalEvidence public
::method init
  expose value
  use strict arg value
::method canonicalText
  expose value
  return 'POISON_CANONICAL_EVIDENCE_V1|VALUE=' || value
::method string
  raise syntax 93.900 additional('POISON_STRING_MUST_NOT_BE_USED')

::class OpaqueEvidence public
::method string
  raise syntax 93.900 additional('OPAQUE_STRING_MUST_NOT_BE_USED')

::class RetryDatabase public subclass Database
::method init
  conn = .DatabaseConnection~new('fake', 5432, 'fakedb', '', .nil, 'postgresql')
  self~init:super(conn, .RetryEngine~new, .RetryExecutor~new)

::class SingleDatabase public subclass Database
::method init
  conn = .DatabaseConnection~new('fake', 5432, 'fakedb', '', .nil, 'postgresql')
  self~init:super(conn, .RetryEngine~new, .SingleExecutor~new)

::class RetryEngine public subclass PostgreSQLEngine
::method parser
  return .RetryParser~new

::class RetryExecutor public subclass DatabaseCommandExecutor
::method init
  expose count
  count = 0
::method execute
  expose count
  use arg command
  count += 1
  if count = 1 then return .DatabaseCommandResult~new(1, '', 'deadlock detected', command, 'PROCESS')
  return .DatabaseCommandResult~new(0, 'UPDATE 1' || .endOfLine, '', command, 'PROCESS')

::class SingleExecutor public subclass DatabaseCommandExecutor
::method execute
  use arg command
  return .DatabaseCommandResult~new(0, 'UPDATE 1' || .endOfLine, '', command, 'PROCESS')

::class RetryParser public subclass PostgreSQLResultParser
::method parse
  use arg commandResult
  if commandResult~rc = 1 then return .DatabaseResult~new(.Error~FAILED, .Error~DEADLOCK)
  return .DatabaseResult~new(.Error~SUCCESS, .Error~SUCCESS)

::requires '../integration/DatabaseTransactionEvidenceAdapter.cls'
::requires 'database_core.cls'
