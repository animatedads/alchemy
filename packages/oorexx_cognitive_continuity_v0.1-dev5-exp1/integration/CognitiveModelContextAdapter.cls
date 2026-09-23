/* Provider-neutral exact model-context export.
 * ChatGPT, Codex or any other client receives the same detached payload.
 */
::class CognitiveModelContextAdapter public
::method init
  expose service actorId
  use strict arg serviceArg, actorArg='llmpa:worker'
  service=serviceArg; actorId=actorArg
::method export
  expose service actorId
  use strict arg scopeRef, task='', limit=32
  args=.directory~new; args['scopeRef']=scopeRef; args['task']=task; args['limit']=limit
  return service~dispatch('COGNITIVE.CONTEXT.EXPORT',args,actorId)
::method json
  expose service actorId
  use strict arg scopeRef, task='', limit=32
  result=self~export(scopeRef,task,limit)
  if \result~ok then return result
  return .CognitiveResult~success(result~value['modelInputJson'],'COGNITIVE_MODEL_INPUT_JSON')
::requires 'CognitiveContinuity.cls'
