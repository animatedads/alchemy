/*
 * NoSQLServerAlgorithmInputCapture.cls
 *
 * Converts an already-executed NoSQLServer SELECT result into a frozen,
 * content-addressed AlgorithmInputRelationSnapshot.  The algorithm layer does
 * not depend on NoSQLServer; this adapter owns the DatabaseRow translation.
 *
 * v0.14: a generic NoSQL/federated capture makes only the claim it can prove:
 * FROZEN_OBSERVATION.  Stronger SOURCE_SNAPSHOT / COORDINATED_SNAPSHOT grades
 * require an explicit source/coordinator consistency descriptor and therefore
 * use captureWithConsistency().
 */

::class NoSQLServerAlgorithmInputCapture public
::attribute queryEngine get
::attribute lastError
::attribute lastSourceResult get
::attribute lastConsistency get

::method init
  expose queryEngine lastSourceResult lastConsistency
  use arg queryEngineArg
  queryEngine = queryEngineArg
  self~lastError = ''
  lastSourceResult = .nil
  lastConsistency = .nil

::method capture
  use arg sqlText, inputSchema, snapshotOid, orderMode = .nil, sourceIdentity = 'NOSQLSERVER_FEDERATED_SQL'
  evidence = .array~new
  evidence~append('CAPTURE=NOSQLSERVER_QUERY_RESULT')
  evidence~append('ATOMICITY=NOT_CLAIMED')
  consistencyDescriptor = .AlgorithmInputConsistencyDescriptor~new(.AlgorithmInputConsistencyConstant~FROZEN_OBSERVATION, 0, '', '', evidence)
  return self~captureInternal(sqlText, inputSchema, snapshotOid, orderMode, sourceIdentity, consistencyDescriptor)

/*
 * Source/coordinator adapters that already executed a query under their own
 * snapshot mechanism may freeze that exact result with the matching evidence.
 * This avoids a second query between attestation and capture.
 */
::method captureExecutedResult
  use arg sourceQueryResult, sqlText, inputSchema, snapshotOid, orderMode = .nil, sourceIdentity = 'NOSQLSERVER_ATTESTED_RESULT', consistencyDescriptor
  if consistencyDescriptor == .nil then do
    self~lastError = 'CONSISTENCY_DESCRIPTOR_REQUIRED'
    return .nil
  end
  if orderMode == .nil then orderMode = .AlgorithmInputRelationConstant~BAG_UNORDERED
  return self~freezeSourceResult(sourceQueryResult, sqlText, inputSchema, snapshotOid, orderMode, sourceIdentity, consistencyDescriptor)

::method captureWithConsistency
  use arg sqlText, inputSchema, snapshotOid, orderMode = .nil, sourceIdentity = 'NOSQLSERVER_DECLARED_SNAPSHOT', consistencyDescriptor
  if consistencyDescriptor == .nil then do
    self~lastError = 'CONSISTENCY_DESCRIPTOR_REQUIRED'
    return .nil
  end
  return self~captureInternal(sqlText, inputSchema, snapshotOid, orderMode, sourceIdentity, consistencyDescriptor)

::method captureInternal private
  expose queryEngine lastSourceResult lastConsistency
  use arg sqlText, inputSchema, snapshotOid, orderMode, sourceIdentity, consistencyDescriptor
  self~lastError = ''
  if orderMode == .nil then orderMode = .AlgorithmInputRelationConstant~BAG_UNORDERED
  lastConsistency = consistencyDescriptor

  sourceQueryResult = queryEngine~execute(sqlText)
  return self~freezeSourceResult(sourceQueryResult, sqlText, inputSchema, snapshotOid, orderMode, sourceIdentity, consistencyDescriptor)

::method freezeSourceResult private
  expose lastSourceResult lastConsistency
  use arg sourceQueryResult, sqlText, inputSchema, snapshotOid, orderMode, sourceIdentity, consistencyDescriptor
  self~lastError = ''
  lastConsistency = consistencyDescriptor
  lastSourceResult = sourceQueryResult
  if sourceQueryResult == .nil then do
    self~lastError = 'SOURCE_QUERY_RETURNED_NIL'
    return .nil
  end
  if sourceQueryResult~status \= 'SUCCESS' then do
    self~lastError = 'SOURCE_QUERY_FAILED status=' || sourceQueryResult~status || ' error=' || sourceQueryResult~error || ' message=' || sourceQueryResult~message
    return .nil
  end

  builder = .AlgorithmInputRelationBuilder~new(inputSchema, inputSchema~relationName, orderMode)
  do sourceRow over sourceQueryResult~rows
    values = .directory~new
    do column over inputSchema~columns
      found = self~copyColumn(sourceRow, column~name, values)
      if \found then do
        self~lastError = 'SOURCE_RESULT_MISSING_COLUMN ' || column~name
        return .nil
      end
    end
    added = builder~addValues(values)
    if \added then do
      self~lastError = 'INPUT_ROW_REJECTED ' || builder~errors[builder~errors~items]
      return .nil
    end
  end

  frozenSnapshot = builder~freeze(snapshotOid, sqlText, sourceIdentity, consistencyDescriptor)
  if frozenSnapshot == .nil then do
    self~lastError = 'INPUT_FREEZE_FAILED'
    return .nil
  end
  return frozenSnapshot

::method copyColumn private
  use arg sourceRow, wantedName, targetValues
  sourceValues = sourceRow~values
  candidates = .array~of(wantedName, wantedName~lower, wantedName~upper)
  do candidate over candidates
    if sourceValues~hasIndex(candidate) then do
      targetValues[wantedName~upper] = sourceValues[candidate]
      return .true
    end
  end

  /* Qualified projection names are accepted only when unambiguous. */
  matchedKey = ''
  do actualKey over sourceValues~allIndexes
    keyText = actualKey~string
    dot = keyText~lastPos('.')
    if dot > 0 then tail = keyText~substr(dot + 1)
    else tail = keyText
    if tail~caselessEquals(wantedName) then do
      if matchedKey \= '' then return .false
      matchedKey = keyText
    end
  end
  if matchedKey == '' then return .false
  targetValues[wantedName~upper] = sourceValues[matchedKey]
  return .true

::requires '../algorithm/AlgorithmInputRelation.cls'
