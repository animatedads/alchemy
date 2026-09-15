/*
 * TableFeedDecisionProvider.cls
 *
 * Deliberately simple deterministic consumer of a frozen input relation.
 * It demonstrates table-fed algorithm execution without inventing ontology.
 * Preference scoring elects an action only inside the authority disposition
 * inherited from the upstream relation.
 */

::class TableFeedDecisionProvider public
::attribute invocationCount
::attribute sourceManifest get
::attribute minimumConsistency get

::method init
  expose sourceManifest minimumConsistency
  use arg packageRoot = '', minimumConsistencyArg = .nil
  if minimumConsistencyArg == .nil then minimumConsistencyArg = .AlgorithmInputConsistencyConstant~FROZEN_OBSERVATION
  minimumConsistency = minimumConsistencyArg~string~upper
  probeConsistency = .AlgorithmInputConsistencyDescriptor~new(.AlgorithmInputConsistencyConstant~FROZEN_OBSERVATION, 0)
  ignore = probeConsistency~satisfies(minimumConsistency)
  self~invocationCount = 0
  sourceManifest = .AlgorithmSourceManifest~new
  if packageRoot == '' then do
    sourceManifest~mode = 'LOGICAL_UNBOUND'
    sourceManifest~add('PROVIDER', 'TableFeedDecisionProvider.cls')
    sourceManifest~add('INPUT_RELATION', 'AlgorithmInputRelation.cls')
  end
  else do
    ok = self~addSourceFile(sourceManifest, packageRoot, 'PROVIDER', 'algorithm/TableFeedDecisionProvider.cls')
    ok = self~addSourceFile(sourceManifest, packageRoot, 'INPUT_RELATION', 'algorithm/AlgorithmInputRelation.cls')
    ok = self~addSourceFile(sourceManifest, packageRoot, 'INPUT_CONSISTENCY', 'algorithm/AlgorithmInputConsistency.cls')
    ok = self~addSourceFile(sourceManifest, packageRoot, 'ALGORITHM_RELATION', 'algorithm/AlgorithmRelation.cls')
  end
  sourceManifest~add('MINIMUM_INPUT_CONSISTENCY', minimumConsistency)

::method addSourceFile private
  use arg manifest, packageRoot, label, relativePath
  if packageRoot~right(1) == '/' then filePath = packageRoot || relativePath
  else filePath = packageRoot || '/' || relativePath
  return manifest~addFile(label, filePath)

::method algorithmId
  return 'TABLE_FEED_DECIDER'

::method algorithmVersion
  return 'TABLE-FEED-ALGREL-0.14'

::method sourceComponent
  return 'TABLE_FEED_TESTBED'

::method sourceVersion
  return '0.14'

::method sourceFingerprint
  return 'TABLE-FEED-AUTHORITY-PROPAGATION-V2-CONSISTENCY-GATED'

::method sourceManifestHash
  expose sourceManifest
  return sourceManifest~hash

::method sourceManifestMode
  expose sourceManifest
  return sourceManifest~mode

::method determinism
  if self~sourceManifestMode == 'FILE_HASHED' then return .AlgorithmRelationConstant~DETERMINISTIC_GIVEN_MATERIALIZED_INPUT
  return .AlgorithmRelationConstant~UNVERIFIED_SOURCE_IDENTITY

::method sideEffectClass
  return 'NONE'

::method defaultMaterializePolicy
  return .AlgorithmRelationConstant~MATERIALIZE_ONCE

::method inputContract
  return 'AlgorithmInputRelationSnapshot:TABLE_FEED_SOURCE_V2;MIN_CONSISTENCY=' || self~minimumConsistency

::method canonicalInput
  use arg inputSnapshot, context
  canonical = inputSnapshot~algorithmCanonicalText
  canonical = canonical || 'CONSUMER_CONTRACT=TABLE_FEED_SOURCE_V2' || '0a'x
  canonical = canonical || 'MINIMUM_CONSISTENCY=' || self~minimumConsistency || '0a'x
  return canonical

::method declaredSchemas
  schemas = .array~new
  schemas~append(self~decisionSchema)
  schemas~append(self~traceSchema)
  return schemas

::method decisionSchema
  schema = .AlgorithmSchema~new('TABLE_FEED_DECISIONS')
  schema~add('INVOCATION_ID', 'TEXT', .false)
  schema~add('INPUT_SNAPSHOT_OID', 'OID', .false)
  schema~add('INPUT_CONTENT_HASH', 'TEXT', .false)
  schema~add('INPUT_SOURCE_QUERY_HASH', 'TEXT', .false)
  schema~add('INPUT_SOURCE_IDENTITY', 'TEXT', .false)
  schema~addEnum('INPUT_CONSISTENCY_GRADE', 'TEXT', .false, .array~of('FROZEN_OBSERVATION','SOURCE_SNAPSHOT','COORDINATED_SNAPSHOT'))
  schema~addEnum('REQUIRED_CONSISTENCY_GRADE', 'TEXT', .false, .array~of('FROZEN_OBSERVATION','SOURCE_SNAPSHOT','COORDINATED_SNAPSHOT'))
  schema~add('INPUT_CONSISTENCY_HASH', 'TEXT', .false)
  schema~add('ROW_ID', 'TEXT', .false)
  schema~add('LABEL', 'TEXT', .false)
  schema~add('PREFERENCE_SCORE', 'NUMBER', .false)
  schema~addEnum('UPSTREAM_DISPOSITION', 'TEXT', .false, .array~of('UNRESOLVED','PERMITTED','REQUIRED','SUPPRESSED','PROHIBITED','REQUIRES_APPROVAL'))
  schema~addEnum('STATE', 'TEXT', .false, .array~of('UNRESOLVED','PERMITTED','HARD_REQUIRED','CONTEXT_SUPPRESSED','HARD_PROHIBITED','APPROVAL_BLOCKED'))
  schema~addEnum('DISPOSITION', 'TEXT', .false, .array~of('UNRESOLVED','PERMITTED','REQUIRED','SUPPRESSED','PROHIBITED','REQUIRES_APPROVAL'))
  schema~add('PROVISIONAL_SELECTED', 'BOOLEAN', .false)
  schema~add('FINAL_SELECTED', 'BOOLEAN', .false)
  schema~add('REASON', 'TEXT', .false)
  return schema

::method traceSchema
  schema = .AlgorithmSchema~new('TABLE_FEED_TRACE')
  schema~add('INVOCATION_ID', 'TEXT', .false)
  schema~add('SEQUENCE', 'INTEGER', .false)
  schema~add('EVENT_TEXT', 'TEXT', .false)
  return schema

::method evaluate
  use arg inputSnapshot, context
  self~invocationCount = self~invocationCount + 1

  algorithmResult = .AlgorithmRelationResult~new(self~algorithmId, self~algorithmVersion, self~sourceComponent, self~sourceVersion, self~sourceFingerprint, self~sourceManifestHash, context)
  algorithmResult~addTrace('PROVIDER TABLE_FEED_DECIDER invocation=' || self~invocationCount)
  algorithmResult~addTrace('INPUT relation=' || inputSnapshot~relationName || ' rows=' || inputSnapshot~rowCount || ' content_hash=' || inputSnapshot~contentHash || ' consistency=' || inputSnapshot~consistencyGrade || ' required=' || self~minimumConsistency)
  consistencySatisfied = inputSnapshot~meetsConsistency(self~minimumConsistency)

  decisions = .AlgorithmRelation~new(self~decisionSchema)
  traceRelation = .AlgorithmRelation~new(self~traceSchema)
  sequence = 0

  do inputRow over inputSnapshot~rows
    rowId = inputRow~value('ROW_ID')
    label = inputRow~value('LABEL')
    score = inputRow~value('PREFERENCE_SCORE')
    upstream = inputRow~value('UPSTREAM_DISPOSITION')~upper
    provisional = score > 0

    state = 'UNRESOLVED'
    disposition = 'UNRESOLVED'
    finalSelected = .false
    reasonText = 'UPSTREAM_UNRESOLVED'

    if \consistencySatisfied then do
      state = 'UNRESOLVED'
      disposition = 'UNRESOLVED'
      finalSelected = .false
      reasonText = 'INPUT_CONSISTENCY_INSUFFICIENT'
    end
    else select
      when upstream == 'PROHIBITED' then do
        state = 'HARD_PROHIBITED'
        disposition = 'PROHIBITED'
        finalSelected = .false
        reasonText = 'UPSTREAM_PROHIBITION_OVERRIDES_SCORE'
      end
      when upstream == 'REQUIRED' then do
        state = 'HARD_REQUIRED'
        disposition = 'REQUIRED'
        finalSelected = .true
        reasonText = 'UPSTREAM_REQUIREMENT_OVERRIDES_SCORE'
      end
      when upstream == 'SUPPRESSED' then do
        state = 'CONTEXT_SUPPRESSED'
        disposition = 'SUPPRESSED'
        finalSelected = .false
        reasonText = 'UPSTREAM_CONTEXT_SUPPRESSES_ELECTION'
      end
      when upstream == 'REQUIRES_APPROVAL' then do
        state = 'APPROVAL_BLOCKED'
        disposition = 'REQUIRES_APPROVAL'
        finalSelected = .false
        reasonText = 'NO_APPROVAL_IN_TABLE_FEED_TESTBED'
      end
      when upstream == 'PERMITTED' then do
        state = 'PERMITTED'
        disposition = 'PERMITTED'
        finalSelected = provisional
        reasonText = 'PREFERENCE_ELECTS_WITHIN_PERMISSION'
      end
      otherwise do
        state = 'UNRESOLVED'
        disposition = 'UNRESOLVED'
        finalSelected = .false
        reasonText = 'UNRESOLVED_UPSTREAM_AUTHORITY'
      end
    end

    decisionRow = decisions~newRow
    ok = decisionRow~put('INVOCATION_ID', context~invocationId)
    ok = decisionRow~put('INPUT_SNAPSHOT_OID', inputSnapshot~sourceOid)
    ok = decisionRow~put('INPUT_CONTENT_HASH', inputSnapshot~contentHash)
    ok = decisionRow~put('INPUT_SOURCE_QUERY_HASH', inputSnapshot~sourceQueryHash)
    ok = decisionRow~put('INPUT_SOURCE_IDENTITY', inputSnapshot~sourceIdentity)
    ok = decisionRow~put('INPUT_CONSISTENCY_GRADE', inputSnapshot~consistencyGrade)
    ok = decisionRow~put('REQUIRED_CONSISTENCY_GRADE', self~minimumConsistency)
    ok = decisionRow~put('INPUT_CONSISTENCY_HASH', inputSnapshot~consistencyHash)
    ok = decisionRow~put('ROW_ID', rowId)
    ok = decisionRow~put('LABEL', label)
    ok = decisionRow~put('PREFERENCE_SCORE', score)
    ok = decisionRow~put('UPSTREAM_DISPOSITION', upstream)
    ok = decisionRow~put('STATE', state)
    ok = decisionRow~put('DISPOSITION', disposition)
    ok = decisionRow~put('PROVISIONAL_SELECTED', provisional)
    ok = decisionRow~put('FINAL_SELECTED', finalSelected)
    ok = decisionRow~put('REASON', reasonText)
    added = decisions~addRow(decisionRow)

    sequence = sequence + 1
    traceRow = traceRelation~newRow
    ok = traceRow~put('INVOCATION_ID', context~invocationId)
    ok = traceRow~put('SEQUENCE', sequence)
    eventText = 'ROW ' || rowId || ' score=' || score || ' provisional=' || provisional || ' upstream=' || upstream || ' disposition=' || disposition || ' final=' || finalSelected
    ok = traceRow~put('EVENT_TEXT', eventText)
    added = traceRelation~addRow(traceRow)
  end

  added = algorithmResult~addRelation(decisions)
  added = algorithmResult~addRelation(traceRelation)
  return algorithmResult

::requires 'AlgorithmInputRelation.cls'
::requires 'AlgorithmRelation.cls'
::requires 'AlgorithmIntegrity.cls'
