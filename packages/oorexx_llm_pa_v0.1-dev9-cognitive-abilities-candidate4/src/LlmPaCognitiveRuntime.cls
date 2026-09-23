/* LLMPA binding for the estate Cognitive Continuity / Memory Fabric.
 *
 * LLMPA is a client of cognitive authority.  This class only constructs the
 * local reference service with explicit actors/capabilities and exposes the
 * upstream adapter.  It does not reinterpret cognitive records, self-promote
 * model output, or compact durable cognitive state.
 */
::class LlmPaCognitiveRuntime public
::attribute service get
::attribute adapter get
::attribute scopeRef get
::attribute workerActor get
::attribute operatorActor get
::attribute journalPath get

::method init
  expose service adapter scopeRef workerActor operatorActor journalPath
  use strict arg journalPathArg, scopeRefArg='project:llmpa', workerActorArg='llmpa:worker', operatorActorArg='llmpa:operator'
  journalPath = journalPathArg~string~strip
  scopeRef = scopeRefArg~string~strip
  workerActor = workerActorArg~string~strip
  operatorActor = operatorActorArg~string~strip
  if journalPath = '' then raise syntax 88.900 array('cognitive journal path is required')
  if scopeRef = '' then raise syntax 88.900 array('cognitive scope is required')
  if workerActor = '' | operatorActor = '' then raise syntax 88.900 array('cognitive actors are required')

  policy = .CognitiveAccessPolicy~new
  /* Model/Codex-facing actor: proposals plus explainable reads only. */
  do capability over .array~of('cognitive.effects.propose.model', 'cognitive.records.query', 'cognitive.context.project', 'cognitive.context.explain', 'cognitive.learning.delta')
    ignore = policy~grant(workerActor, capability, scopeRef)
  end
  /* Compatibility operator actor is explicit and remains distinguishable from model output. */
  do capability over .array~of('cognitive.effects.propose.operator', 'cognitive.records.query', 'cognitive.context.project', 'cognitive.context.explain', 'cognitive.learning.delta', 'cognitive.authority.project_owner')
    ignore = policy~grant(operatorActor, capability, scopeRef)
  end

  journal = .CognitiveJsonlJournal~new(journalPath)
  service = .CognitiveContinuityService~new(journal, policy)
  adapter = .LlmPaCognitiveAdapter~new(service, workerActor, operatorActor)

::method dispatchModel
  expose service workerActor scopeRef
  use strict arg operation, args=.nil
  if args == .nil then args = .directory~new
  if \args~hasIndex('scopeRef') then args['scopeRef'] = scopeRef
  return service~dispatch(operation, args, workerActor)

::method dispatchOperator
  expose service operatorActor scopeRef
  use strict arg operation, args=.nil
  if args == .nil then args = .directory~new
  if \args~hasIndex('scopeRef') then args['scopeRef'] = scopeRef
  return service~dispatch(operation, args, operatorActor)

::method asLlmResult
  use strict arg cognitiveResult
  if cognitiveResult == .nil then return .LlmPaResult~failure('COGNITIVE_RESULT_INVALID', 'nil result')
  if \cognitiveResult~hasMethod('OK') | \cognitiveResult~hasMethod('CODE') | \cognitiveResult~hasMethod('VALUE') then -
    return .LlmPaResult~failure('COGNITIVE_RESULT_INVALID', cognitiveResult~class~id)
  if cognitiveResult~ok then return .LlmPaResult~success(cognitiveResult~value)
  return .LlmPaResult~failure(cognitiveResult~code, cognitiveResult~detail)

::requires 'LlmPaCore.cls'
::requires 'CognitiveContinuity.cls'
::requires 'LlmPaCognitiveAdapter.cls'
