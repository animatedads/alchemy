/* LLMPA is a client of Cognitive Continuity, not cognitive authority. */
::class LlmPaCognitiveAdapter public
::method init
  expose service workerActor operatorActor
  use strict arg serviceArg, workerActorArg='llmpa:worker', operatorActorArg='llmpa:operator'
  service=serviceArg; workerActor=workerActorArg; operatorActor=operatorActorArg
::method modelEffects
  expose service workerActor
  use strict arg scopeRef, effects, evidenceManifest=.nil
  args=.directory~new; args['scopeRef']=scopeRef; args['effects']=effects
  if evidenceManifest<>.nil then args['evidenceManifest']=evidenceManifest
  return service~dispatch('COGNITIVE.EFFECTS.PROPOSE',args,workerActor)
::method operatorRemember
  expose service operatorActor
  use strict arg scopeRef, subjectRef, statement
  effect=.directory~new; effect['kind']='CLAIM'; effect['subjectRef']=subjectRef; effect['statement']=statement; effect['basisRefs']=.array~new
  args=.directory~new; args['scopeRef']=scopeRef; args['effects']=.array~of(effect)
  return service~dispatch('COGNITIVE.EFFECTS.PROPOSE',args,operatorActor)
::method operatorDecision
  expose service operatorActor
  use strict arg scopeRef, subjectRef, statement
  effect=.directory~new; effect['kind']='DECISION'; effect['subjectRef']=subjectRef; effect['statement']=statement; effect['basisRefs']=.array~new
  args=.directory~new; args['scopeRef']=scopeRef; args['effects']=.array~of(effect)
  return service~dispatch('COGNITIVE.EFFECTS.PROPOSE',args,operatorActor)
::method context
  expose service workerActor
  use strict arg scopeRef, task='', limit=32
  args=.directory~new; args['scopeRef']=scopeRef; args['task']=task; args['limit']=limit
  return service~dispatch('COGNITIVE.CONTEXT.PROJECT',args,workerActor)
::method modelContext
  expose service workerActor
  use strict arg scopeRef, task='', limit=32
  args=.directory~new; args['scopeRef']=scopeRef; args['task']=task; args['limit']=limit
  return service~dispatch('COGNITIVE.CONTEXT.EXPORT',args,workerActor)
::requires 'CognitiveContinuity.cls'
