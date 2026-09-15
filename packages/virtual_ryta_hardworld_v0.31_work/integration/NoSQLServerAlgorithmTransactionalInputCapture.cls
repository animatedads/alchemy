/*
 * NoSQLServerAlgorithmTransactionalInputCapture.cls
 *
 * SOURCE_SNAPSHOT attestor for a single NoSQLServer file-engine source.
 * The supplied engine must expose NoSQLServer's native transaction contract:
 * transaction -> stable clone, token/baseSignature, deferred query, commit.
 *
 * This deliberately does not work through FederatedDatabaseEngine because
 * federation does not advertise a cross-provider transaction snapshot.
 */

::class NoSQLServerAlgorithmTransactionalInputCapture public
::attribute engine get
::attribute lastError
::attribute lastTransactionToken get
::attribute lastBaseSignature get
::attribute lastCommitResult get

::method init
  expose engine lastTransactionToken lastBaseSignature lastCommitResult
  use arg engineArg
  engine = engineArg
  self~lastError = ''
  lastTransactionToken = ''
  lastBaseSignature = ''
  lastCommitResult = .nil

::method capture
  expose engine lastTransactionToken lastBaseSignature lastCommitResult
  use arg sqlText, inputSchema, snapshotOid = '', orderMode = .nil, sourceIdentity = 'NOSQLSERVER_FILE_TRANSACTION'
  self~lastError = ''
  if orderMode == .nil then orderMode = .AlgorithmInputRelationConstant~BAG_UNORDERED

  if \engine~hasMethod('TRANSACTION') then do
    self~lastError = 'SOURCE_TRANSACTION_UNAVAILABLE'
    return .nil
  end

  transaction = engine~transaction
  if transaction == .nil then do
    self~lastError = 'SOURCE_TRANSACTION_RETURNED_NIL'
    return .nil
  end
  if \transaction~hasMethod('TOKEN') | \transaction~hasMethod('BASESIGNATURE') then do
    self~lastError = 'SOURCE_TRANSACTION_SNAPSHOT_CONTRACT_MISSING'
    return .nil
  end

  lastTransactionToken = transaction~token
  lastBaseSignature = transaction~baseSignature
  deferredResult = transaction~query(sqlText)
  if deferredResult == .nil then do
    self~lastError = 'SOURCE_TRANSACTION_QUERY_RETURNED_NIL'
    ignore = transaction~rollback
    return .nil
  end

  commitResult = transaction~commit
  lastCommitResult = commitResult
  if commitResult == .nil then do
    self~lastError = 'SOURCE_TRANSACTION_COMMIT_RETURNED_NIL'
    return .nil
  end
  if commitResult~status \= 'SUCCESS' & commitResult~status \= 'COMMITTED' then do
    self~lastError = 'SOURCE_TRANSACTION_COMMIT_FAILED status=' || commitResult~status || ' error=' || commitResult~error || ' message=' || commitResult~message
    return .nil
  end
  if deferredResult~status \= 'SUCCESS' then do
    self~lastError = 'SOURCE_TRANSACTION_QUERY_FAILED status=' || deferredResult~status || ' error=' || deferredResult~error || ' message=' || deferredResult~message
    return .nil
  end

  evidence = .array~new
  evidence~append('ATTESTOR=NOSQLSERVER_FILE_TRANSACTION')
  evidence~append('STABLE_CLONE=TRUE')
  evidence~append('TRANSACTION_TOKEN=' || lastTransactionToken)
  evidence~append('BASE_SIGNATURE=' || lastBaseSignature)
  evidence~append('ACCESS_PATH=' || deferredResult~accessPath)
  if deferredResult~snapshotGeneration > 0 then evidence~append('SNAPSHOT_GENERATION=' || deferredResult~snapshotGeneration)

  consistency = .AlgorithmInputConsistencyDescriptor~new(.AlgorithmInputConsistencyConstant~SOURCE_SNAPSHOT, 1, '', 'NOSQL-TX:' || lastTransactionToken, evidence)
  genericCapture = .NoSQLServerAlgorithmInputCapture~new(engine)
  frozen = genericCapture~captureExecutedResult(deferredResult, sqlText, inputSchema, snapshotOid, orderMode, sourceIdentity, consistency)
  if frozen == .nil then do
    self~lastError = genericCapture~lastError
    return .nil
  end
  return frozen

::requires 'NoSQLServerAlgorithmInputCapture.cls'
