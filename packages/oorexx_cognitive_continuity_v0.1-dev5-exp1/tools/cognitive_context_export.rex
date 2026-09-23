/* Export the exact JSON payload selected for an LLM plus the reason trace.
 * Usage: rexx tools/cognitive_context_export.rex JOURNAL SCOPE ACTOR TASK OUT_PREFIX [LIMIT]
 */
parse arg journalPath scopeRef actorId task outPrefix limit
if journalPath='' | scopeRef='' | actorId='' | outPrefix='' then do
  say 'usage: cognitive_context_export.rex JOURNAL SCOPE ACTOR TASK OUT_PREFIX [LIMIT]'
  exit 2
end
if limit='' then limit=32
p=.CognitiveAccessPolicy~new
ignore=p~grant(actorId,'cognitive.records.query',scopeRef)
ignore=p~grant(actorId,'cognitive.context.project',scopeRef)
ignore=p~grant(actorId,'cognitive.context.explain',scopeRef)
svc=.CognitiveContinuityService~new(.CognitiveJsonlJournal~new(journalPath),p)
a=.CognitiveModelContextAdapter~new(svc,actorId)
r=a~export(scopeRef,task,limit)
if \r~ok then do; say 'ERROR' r~code r~detail; exit 3; end
call lineout outPrefix||'.model-input.json',r~value['modelInputJson']; call stream outPrefix||'.model-input.json','c','close'
call lineout outPrefix||'.projection-trace.json',.json~toJSON(r~value['projectionTrace']); call stream outPrefix||'.projection-trace.json','c','close'
say 'projectionId='r~value['projectionId']
say 'modelInput='outPrefix||'.model-input.json'
say 'trace='outPrefix||'.projection-trace.json'
exit 0
::requires 'CognitiveContinuity.cls'
::requires 'CognitiveModelContextAdapter.cls'
::requires 'json.cls'
