/* Create a tiny persistent corpus and export the exact model-facing context. */
parse source . . here
root=filespec('location',here) || '..'; call directory root
journal='dogfood-cognitive.jsonl'; call sysFileDelete journal
scope='project:cognitive-dogfood'; actor='dogfood:model'
p=.CognitiveAccessPolicy~new
ignore=p~grant(actor,'cognitive.effects.propose.model',scope)
ignore=p~grant(actor,'cognitive.records.query',scope)
ignore=p~grant(actor,'cognitive.context.project',scope)
ignore=p~grant(actor,'cognitive.context.explain',scope)
svc=.CognitiveContinuityService~new(.CognitiveJsonlJournal~new(journal),p)
call add svc,scope,actor,'DECISION','architecture','Inference context may compact; durable cognitive state must not'
call add svc,scope,actor,'LESSON','coding','Knowledge should become lessons, procedures and tools rather than inert prose memory'
call add svc,scope,actor,'OPEN_QUESTION','learning','Which HF/Colab classifier gives the best multi-dimensional episode classification?'
a=.CognitiveModelContextAdapter~new(svc,actor); r=a~export(scope,'dog food cognitive context projection',16)
call lineout 'dogfood-model-input.json',r~value['modelInputJson']; call stream 'dogfood-model-input.json','c','close'
call lineout 'dogfood-projection-trace.json',.json~toJSON(r~value['projectionTrace']); call stream 'dogfood-projection-trace.json','c','close'
say 'WROTE dogfood-model-input.json'
say 'WROTE dogfood-projection-trace.json'
exit 0
add: procedure
  use arg svc,scope,actor,kind,subject,statement
  e=.directory~new; e['kind']=kind; e['subjectRef']=subject; e['statement']=statement; e['basisRefs']=.array~new
  a=.directory~new; a['scopeRef']=scope; a['effects']=.array~of(e)
  r=svc~dispatch('COGNITIVE.EFFECTS.PROPOSE',a,actor)
  if \r~ok then do; say 'seed failed' r~code; exit 4; end
  return
::requires 'CognitiveContinuity.cls'
::requires 'CognitiveModelContextAdapter.cls'
::requires 'json.cls'
