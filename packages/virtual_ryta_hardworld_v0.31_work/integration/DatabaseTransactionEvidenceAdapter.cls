/*
 * DatabaseTransactionEvidenceAdapter.cls
 *
 * Detached RYTA evidence projection for Database Core v0.43 logical
 * transactions and their physical retry attempts.
 *
 * Database retry history is provenance, not a business action and not RYTA
 * authority. Native Database objects remain reachable, while deterministic
 * evidence identity is built only from explicit scalar transaction/attempt
 * fields and an explicit canonical identity supplied by attached rich evidence.
 */

::class DatabaseExecutionAttemptEvidence public
::attribute attemptNumber get
::attribute attemptId get
::attribute transactionId get
::attribute status get
::attribute error get
::attribute retryable get
::attribute nativeAttempt get

::method init
  expose attemptNumber attemptId transactionId status error retryable nativeAttempt canonical
  use strict arg attemptNumberArg, attemptIdArg, transactionIdArg, statusArg, errorArg, retryableArg, nativeAttemptArg
  attemptNumber = attemptNumberArg
  attemptId = attemptIdArg~string
  transactionId = transactionIdArg~string
  status = statusArg~string~upper
  error = errorArg~string~upper
  retryable = retryableArg
  nativeAttempt = nativeAttemptArg
  canonical = 'RYTA_DB_ATTEMPT_EVIDENCE_V1' || '0a'x
  canonical = canonical || self~field('TRANSACTION_ID', transactionId)
  canonical = canonical || self~field('ATTEMPT_NUMBER', attemptNumber)
  canonical = canonical || self~field('ATTEMPT_ID', attemptId)
  canonical = canonical || self~field('STATUS', status)
  canonical = canonical || self~field('ERROR', error)
  canonical = canonical || self~field('RETRYABLE', self~booleanText(retryable))

::method algorithmCanonicalText
  expose canonical
  return canonical

::method field private
  use strict arg name, value
  rendered = value~string
  return name || '=' || rendered~length || ':' || rendered || '0a'x

::method booleanText private
  use strict arg value
  if value == .true then return 'TRUE'
  if value == .false then return 'FALSE'
  raise syntax 93.900 additional('DATABASE_ATTEMPT_RETRYABLE_BOOLEAN_INVALID')

::class DatabaseTransactionEvidence public
::attribute evidenceIdentity get
::attribute transactionId get
::attribute outcome get
::attribute status get
::attribute error get
::attribute operationCount get
::attribute attemptCount get
::attribute contextLocator get
::attribute contextEvidenceIdentity get
::attribute nativeTransactionResult get
::attribute nativeExecutionContext get

::method init
  expose evidenceIdentity transactionId outcome status error operationCount attemptCount contextLocator contextEvidenceIdentity nativeTransactionResult nativeExecutionContext attemptsSnapshot canonical
  use strict arg transactionIdArg, outcomeArg, statusArg, errorArg, operationCountArg, attemptsArg, contextLocatorArg, contextEvidenceIdentityArg, nativeTransactionResultArg, nativeExecutionContextArg
  transactionId = transactionIdArg~string
  outcome = outcomeArg~string~upper
  status = statusArg~string~upper
  error = errorArg~string~upper
  operationCount = operationCountArg
  contextLocator = contextLocatorArg~string
  contextEvidenceIdentity = contextEvidenceIdentityArg~string
  nativeTransactionResult = nativeTransactionResultArg
  nativeExecutionContext = nativeExecutionContextArg
  attemptsSnapshot = attemptsArg~copy
  attemptCount = attemptsSnapshot~items
  canonical = 'RYTA_DB_TRANSACTION_EVIDENCE_V1' || '0a'x
  canonical = canonical || self~field('TRANSACTION_ID', transactionId)
  canonical = canonical || self~field('OUTCOME', outcome)
  canonical = canonical || self~field('STATUS', status)
  canonical = canonical || self~field('ERROR', error)
  canonical = canonical || self~field('OPERATION_COUNT', operationCount)
  canonical = canonical || self~field('ATTEMPT_COUNT', attemptCount)
  canonical = canonical || self~field('CONTEXT_LOCATOR', contextLocator)
  canonical = canonical || self~field('CONTEXT_EVIDENCE_IDENTITY', contextEvidenceIdentity)
  do attempt over attemptsSnapshot
    text = attempt~algorithmCanonicalText
    canonical = canonical || self~field('ATTEMPT', text)
  end
  evidenceIdentity = .AlgorithmDigest~sha256Text(canonical)

::method attempts
  expose attemptsSnapshot
  return attemptsSnapshot~copy

::method retried
  expose attemptCount
  return attemptCount > 1

::method algorithmCanonicalText
  expose canonical
  return canonical

::method promotionEligible
  return .false

::method field private
  use strict arg name, value
  rendered = value~string
  return name || '=' || rendered~length || ':' || rendered || '0a'x

::class DatabaseTransactionEvidenceAdapter subclass RYTAObject public
::method init
  self~init:super('DatabaseTransactionEvidenceAdapter', 'DATABASE_PROVENANCE_ONLY')
  self~registerExternalRequirement('library', 'oorexx_db_skeleton', 'v0.43', .false)
  self~registerMethodContract('PROJECT', 'Snapshot Database Core logical transaction and retry-attempt provenance into deterministic non-authority evidence', .array~new, 'DatabaseTransactionEvidence', .false, 'AUTO', 'CUSTOMER', 'SENSITIVE', 'NONE', 'NONE')
  self~registerMethodContract('PROMOTIONSFROM', 'Explicitly refuse promotion of database transaction/retry provenance', .array~new, 'NONE', .false, 'AUTO', 'CUSTOMER', 'SENSITIVE', 'NONE', 'NONE')
  return self

::method project
  use strict arg transactionResult
  if transactionResult == .nil then raise syntax 93.900 additional('DATABASE_TRANSACTION_RESULT_REQUIRED')
  required = .array~of('TRANSACTIONID', 'ATTEMPTS', 'ATTEMPTCOUNT', 'OUTCOME', 'STATUS', 'ERROR', 'OPERATIONCOUNT', 'EXECUTIONCONTEXT')
  do methodName over required
    if \transactionResult~hasMethod(methodName) then raise syntax 93.900 additional('DATABASE_TRANSACTION_RESULT_SURFACE_INVALID:' || methodName)
  end
  transactionId = transactionResult~transactionId~string
  if transactionId = '' then raise syntax 93.900 additional('DATABASE_TRANSACTION_ID_REQUIRED')
  sourceAttempts = transactionResult~attempts
  if \sourceAttempts~isA(.Array) then raise syntax 93.900 additional('DATABASE_ATTEMPTS_ARRAY_REQUIRED')
  if transactionResult~attemptCount \= sourceAttempts~items then raise syntax 93.900 additional('DATABASE_ATTEMPT_COUNT_MISMATCH')
  attempts = .array~new
  expectedNumber = 1
  do sourceAttempt over sourceAttempts
    attemptRequired = .array~of('ATTEMPTNUMBER', 'ATTEMPTID', 'TRANSACTIONID', 'STATUS', 'ERROR', 'RETRYABLE', 'EXECUTIONCONTEXT')
    do methodName over attemptRequired
      if \sourceAttempt~hasMethod(methodName) then raise syntax 93.900 additional('DATABASE_ATTEMPT_SURFACE_INVALID:' || methodName)
    end
    if sourceAttempt~attemptNumber \= expectedNumber then raise syntax 93.900 additional('DATABASE_ATTEMPT_SEQUENCE_INVALID')
    if sourceAttempt~transactionId~string \== transactionId then raise syntax 93.900 additional('DATABASE_ATTEMPT_TRANSACTION_ID_MISMATCH')
    expectedAttemptId = transactionId || ':attempt:' || expectedNumber
    if sourceAttempt~attemptId~string \== expectedAttemptId then raise syntax 93.900 additional('DATABASE_ATTEMPT_ID_INVALID')
    attempts~append(.DatabaseExecutionAttemptEvidence~new(sourceAttempt~attemptNumber, sourceAttempt~attemptId, sourceAttempt~transactionId, sourceAttempt~status, sourceAttempt~error, sourceAttempt~retryable, sourceAttempt))
    expectedNumber = expectedNumber + 1
  end
  executionContext = transactionResult~executionContext
  contextLocator = ''
  contextEvidenceIdentity = 'NONE'
  if executionContext \== .nil then do
    if \executionContext~hasMethod('LOCATOR') | \executionContext~hasMethod('EVIDENCE') then raise syntax 93.900 additional('DATABASE_EXECUTION_CONTEXT_SURFACE_INVALID')
    contextLocator = executionContext~locator~string
    evidence = executionContext~evidence
    if evidence \== .nil then contextEvidenceIdentity = self~explicitEvidenceIdentity(evidence)
    do sourceAttempt over sourceAttempts
      if sourceAttempt~executionContext \== executionContext then raise syntax 93.900 additional('DATABASE_ATTEMPT_CONTEXT_MISMATCH')
    end
  end
  return .DatabaseTransactionEvidence~new(transactionId, transactionResult~outcome, transactionResult~status, transactionResult~error, transactionResult~operationCount, attempts, contextLocator, contextEvidenceIdentity, transactionResult, executionContext)

::method promotionsFrom
  use arg ignored
  raise syntax 93.900 additional('DATABASE_TRANSACTION_EVIDENCE_NOT_AUTHORITY')

::method explicitEvidenceIdentity private
  use strict arg evidence
  if evidence~hasMethod('SEMANTICIDENTITY') then return 'SEMANTIC:' || evidence~semanticIdentity~string
  if evidence~hasMethod('EXECUTIONIDENTITY') then return 'EXECUTION:' || evidence~executionIdentity~string
  if evidence~hasMethod('CANONICALTEXT') then return 'CANONICAL-SHA256:' || .AlgorithmDigest~sha256Text(evidence~canonicalText)
  raise syntax 93.900 additional('DATABASE_CONTEXT_EVIDENCE_IDENTITY_REQUIRED')

::requires '../RYTAObject.cls'
::requires '../algorithm/AlgorithmIntegrity.cls'
