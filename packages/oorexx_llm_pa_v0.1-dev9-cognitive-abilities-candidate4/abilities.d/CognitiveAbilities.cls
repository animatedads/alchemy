/* Cognitive Continuity abilities.
 *
 * These are semantic adapters onto the estate Cognitive Continuity service.
 * They intentionally do not expose journal mutation, authority assignment,
 * generic memory writes, or arbitrary actor selection.
 */

::class LlmPaCognitiveAbility subclass LlmPaAbility
::method runtime protected
  use arg context
  runtime = context~service('cognitive_runtime')
  if runtime == .nil then return .LlmPaResult~failure('COGNITIVE_RUNTIME_NOT_CONFIGURED')
  return .LlmPaResult~success(runtime)
::method scope protected
  use arg context, request
  if request~hasIndex('scope_ref') then do
    value = request['scope_ref']~string~strip
    if value <> '' then return value
  end
  return context~config('cognitive_scope', 'project:llmpa')~string
::method convert protected
  use arg runtime, result
  return runtime~asLlmResult(result)
::method rejectAuthorityFields protected
  use arg request
  do name over .array~of('actor', 'actor_id', 'actorId', 'principalId', 'authority', 'origin', 'epistemicState', 'decisionAuthority', 'verificationState')
    if request~hasIndex(name) then return .LlmPaResult~failure('COGNITIVE_ACTOR_OR_AUTHORITY_FIELD_FORBIDDEN', name)
  end
  return .LlmPaResult~success(.true)

::class LlmPaCognitiveRecordsQueryAbility subclass LlmPaCognitiveAbility public
::method abilityId
  return 'cognitive.records.query'
::method version
  return '0.1.0'
::method description
  return 'Query admitted durable cognitive records in the active scope without searching or flattening the chat transcript.'
::method aliases
  return .array~of('cognitive.records', 'memory.records')
::method authorityClass
  return 'READ_ONLY'
::method requestSchema
  return 'llm.pa.cognitive.records.query.request/0.1'
::method responseSchema
  return 'oorexx.cognitive.records/2'
::method primitiveRequirements
  return .array~of('cognitive.continuity/0.1')
::method execute
  use arg context, request
  got = self~runtime(context); if \got~ok then return got
  runtime = got~value
  args = .directory~new; args['scopeRef'] = self~scope(context, request)
  if request~hasIndex('kind') then args['kind'] = request['kind']
  if request~hasIndex('memory_class') then args['memoryClass'] = request['memory_class']
  return self~convert(runtime, runtime~service~dispatch('COGNITIVE.RECORDS.QUERY', args, runtime~workerActor))

::class LlmPaCognitiveContinuityQueryAbility subclass LlmPaCognitiveAbility public
::method abilityId
  return 'cognitive.continuity.query'
::method version
  return '0.1.0'
::method description
  return 'Return durable continuity and argument records for the active cognitive scope; model context compaction does not alter these records.'
::method aliases
  return .array~of('cognitive.continuity', 'memory.continuity')
::method authorityClass
  return 'READ_ONLY'
::method requestSchema
  return 'llm.pa.cognitive.continuity.query.request/0.1'
::method responseSchema
  return 'oorexx.cognitive.continuity/2'
::method primitiveRequirements
  return .array~of('cognitive.continuity/0.1')
::method execute
  use arg context, request
  got = self~runtime(context); if \got~ok then return got
  runtime = got~value
  args = .directory~new; args['scopeRef'] = self~scope(context, request)
  return self~convert(runtime, runtime~service~dispatch('COGNITIVE.CONTINUITY.QUERY', args, runtime~workerActor))

::class LlmPaCognitiveContextProjectAbility subclass LlmPaCognitiveAbility public
::method abilityId
  return 'cognitive.context.project'
::method version
  return '0.1.0'
::method description
  return 'Build a bounded disposable, reason-traced working-context projection from durable cognitive state.'
::method aliases
  return .array~of('context.project')
::method authorityClass
  return 'EVIDENCE_ONLY'
::method requestSchema
  return 'llm.pa.cognitive.context.project.request/0.1'
::method responseSchema
  return 'oorexx.cognitive.context-projection/2'
::method primitiveRequirements
  return .array~of('cognitive.continuity/0.1')
::method execute
  use arg context, request
  got = self~runtime(context); if \got~ok then return got
  runtime = got~value
  args = .directory~new; args['scopeRef'] = self~scope(context, request)
  if request~hasIndex('task') then args['task'] = request['task']
  if request~hasIndex('limit') then args['limit'] = request['limit']
  return self~convert(runtime, runtime~service~dispatch('COGNITIVE.CONTEXT.PROJECT', args, runtime~workerActor))

::class LlmPaCognitiveContextExportAbility subclass LlmPaCognitiveAbility public
::method abilityId
  return 'cognitive.context.export'
::method version
  return '0.1.0'
::method description
  return 'Export the exact provider-neutral cognitive.model-context/0.1 model input plus the complete selection trace.'
::method aliases
  return .array~of('context.export', 'memory.context')
::method authorityClass
  return 'EVIDENCE_ONLY'
::method requestSchema
  return 'llm.pa.cognitive.context.export.request/0.1'
::method responseSchema
  return 'oorexx.cognitive.model-feed/1'
::method primitiveRequirements
  return .array~of('cognitive.continuity/0.1')
::method execute
  use arg context, request
  got = self~runtime(context); if \got~ok then return got
  runtime = got~value
  args = .directory~new; args['scopeRef'] = self~scope(context, request)
  if request~hasIndex('task') then args['task'] = request['task']
  if request~hasIndex('limit') then args['limit'] = request['limit']
  return self~convert(runtime, runtime~service~dispatch('COGNITIVE.CONTEXT.EXPORT', args, runtime~workerActor))

::class LlmPaCognitiveContextExplainAbility subclass LlmPaCognitiveAbility public
::method abilityId
  return 'cognitive.context.explain'
::method version
  return '0.1.0'
::method description
  return 'Explain why records were included or omitted from an in-process cognitive context projection.'
::method aliases
  return .array~of('context.explain')
::method authorityClass
  return 'EVIDENCE_ONLY'
::method requestSchema
  return 'llm.pa.cognitive.context.explain.request/0.1'
::method responseSchema
  return 'oorexx.cognitive.projection-explanation/1'
::method primitiveRequirements
  return .array~of('cognitive.continuity/0.1')
::method execute
  use arg context, request
  if \request~hasIndex('projection_id') then return .LlmPaResult~failure('PROJECTION_ID_REQUIRED')
  got = self~runtime(context); if \got~ok then return got
  runtime = got~value
  args = .directory~new; args['scopeRef'] = self~scope(context, request); args['projectionId'] = request['projection_id']
  return self~convert(runtime, runtime~service~dispatch('COGNITIVE.CONTEXT.EXPLAIN', args, runtime~workerActor))

::class LlmPaCognitiveClassificationExplainAbility subclass LlmPaCognitiveAbility public
::method abilityId
  return 'cognitive.classification.explain'
::method version
  return '0.1.0'
::method description
  return 'Explain the current cognitive memory-class classification and projection reason for a durable record.'
::method aliases
  return .array~of('classification.explain')
::method authorityClass
  return 'EVIDENCE_ONLY'
::method requestSchema
  return 'llm.pa.cognitive.classification.explain.request/0.1'
::method responseSchema
  return 'oorexx.cognitive.classification-explanation/1'
::method primitiveRequirements
  return .array~of('cognitive.continuity/0.1')
::method execute
  use arg context, request
  if \request~hasIndex('record_id') then return .LlmPaResult~failure('COGNITIVE_RECORD_ID_REQUIRED')
  got = self~runtime(context); if \got~ok then return got
  runtime = got~value
  args = .directory~new; args['scopeRef'] = self~scope(context, request); args['recordId'] = request['record_id']
  return self~convert(runtime, runtime~service~dispatch('COGNITIVE.CLASSIFICATION.EXPLAIN', args, runtime~workerActor))

::class LlmPaCognitiveLearningDeltaAbility subclass LlmPaCognitiveAbility public
::method abilityId
  return 'cognitive.learning.delta'
::method version
  return '0.1.0'
::method description
  return 'Read a bounded durable cognitive delta for the nearline classifier/ML path; it does not promote or admit learned authority.'
::method aliases
  return .array~of('learning.delta')
::method authorityClass
  return 'EVIDENCE_ONLY'
::method requestSchema
  return 'llm.pa.cognitive.learning.delta.request/0.1'
::method responseSchema
  return 'oorexx.cognitive.learning-delta/1'
::method primitiveRequirements
  return .array~of('cognitive.continuity/0.1')
::method execute
  use arg context, request
  got = self~runtime(context); if \got~ok then return got
  runtime = got~value
  args = .directory~new; args['scopeRef'] = self~scope(context, request)
  if request~hasIndex('since_sequence') then args['sinceSequence'] = request['since_sequence']
  return self~convert(runtime, runtime~service~dispatch('COGNITIVE.LEARNING.DELTA', args, runtime~workerActor))

::class LlmPaCognitiveEffectsProposeAbility subclass LlmPaCognitiveAbility public
::method abilityId
  return 'cognitive.effects.propose'
::method version
  return '0.1.0'
::method description
  return 'Submit typed model cognitive-effect proposals through Cognitive Admission; actor, origin, epistemic state and decision authority remain server-derived.'
::method aliases
  return .array~of('cognitive.propose', 'memory.propose')
::method authorityClass
  return 'GOVERNED_MUTATION'
::method mutating
  return .true
::method requestSchema
  return 'cognitive.effect.proposal/0.2'
::method responseSchema
  return 'oorexx.cognitive.effect.proposal-result/2'
::method primitiveRequirements
  return .array~of('cognitive.continuity/0.1', 'cognitive.admission')
::method execute
  use arg context, request
  forbidden = self~rejectAuthorityFields(request); if \forbidden~ok then return forbidden
  if \request~hasIndex('effects') then return .LlmPaResult~failure('EFFECTS_REQUIRED')
  if \request['effects']~isa(.Array) then return .LlmPaResult~failure('EFFECTS_MUST_BE_ARRAY')
  got = self~runtime(context); if \got~ok then return got
  runtime = got~value
  evidence = .nil
  if request~hasIndex('evidence_manifest') then evidence = request['evidence_manifest']
  result = runtime~adapter~modelEffects(self~scope(context, request), request['effects'], evidence)
  return self~convert(runtime, result)

::requires 'LlmPaAbility.cls'
::requires 'LlmPaCognitiveRuntime.cls'
::requires 'json.cls'
