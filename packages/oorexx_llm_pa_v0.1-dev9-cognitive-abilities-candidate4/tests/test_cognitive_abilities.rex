parse source . . testHere
root = filespec('L', testHere)
packageRoot = root
if packageRoot~right(6) = 'tests/' then packageRoot = packageRoot~left(packageRoot~length - 6)
tmp = '/tmp/llmpa-cognitive-abilities-test-' || random(10000,99999)
address command 'rm -rf' tmp
address command 'mkdir -p' tmp
scope = 'project:test-cognitive-abilities'
journal = tmp || '/cognitive.jsonl'

runtime = .LlmPaCognitiveRuntime~new(journal, scope)
ctx = .LlmPaAbilityContext~new
ignore = ctx~setService('cognitive_runtime', runtime)
ignore = ctx~setService('cognitive_service', runtime~service)
ignore = ctx~setService('cognitive_adapter', runtime~adapter)
ignore = ctx~setConfig('cognitive_scope', scope)
continuity = .LlmPaContinuityBrief~new(tmp || '/continuity.brief')
call must continuity~publish('legacy handoff projection', 'test')~ok, 'legacy projection publish'
ignore = ctx~setService('continuity', continuity)
registry = .LlmPaAbilityRegistry~new(packageRoot || '/abilities.d', ctx)
loaded = registry~load
call must loaded~ok, 'registry load'
call must loaded~value['count'] >= 14, 'cognitive ability count'
ignore = ctx~setService('ability_registry', registry)

/* A model may propose a decision, but the admission service derives authority. */
effect = .directory~new
effect['kind'] = 'DECISION'
effect['subjectRef'] = 'queue-rexx'
effect['statement'] = 'Use directory-loaded named abilities for LLMPA tooling.'
request = .directory~new
request['effects'] = .array~of(effect)
proposed = registry~invoke('cognitive.effects.propose', request)
call must proposed~ok, 'proposal invoke'
proposalExecution = proposed~value
proposalPayload = proposalExecution['result']
proposalRows = proposalPayload['results']
proposalRow = proposalRows[1]
call must proposalRow['disposition'] = 'ADMITTED_DECISION_PROPOSAL', 'model decision remains proposal'
recordId = proposalRow['recordRef']

query = registry~invoke('cognitive.records.query')
call must query~ok, 'records query'
call must query~value['result']['count'] = 1, 'record persisted'
record = query~value['result']['records'][1]
call must record['recordId'] = recordId, 'record identity'
call must record['origin'] = 'MODEL', 'origin server derived'
call must record['assertionClass'] = 'MODEL_ASSERTED', 'assertion server derived'
call must record['decisionAuthority'] = 'NONE', 'model has no decision authority'
call must record['decisionState'] = 'PROPOSED', 'model decision not accepted'
call must record['memoryClass'] = 'CONTINUITY', 'decision classification'

explainReq = .directory~new; explainReq['record_id'] = recordId
classification = registry~invoke('cognitive.classification.explain', explainReq)
call must classification~ok, 'classification explain'
call must classification~value['result']['memoryClass'] = 'CONTINUITY', 'classification memory class'
call must classification~value['result']['selectionReason'] = 'CURRENT_DECISION', 'classification selection reason'

exportReq = .directory~new; exportReq['task'] = 'resume QueueRexx work'; exportReq['limit'] = 8
feed = registry~invoke('cognitive.context.export', exportReq)
call must feed~ok, 'context export'
call must feed~value['result']['modelInput']['schema'] = 'cognitive.model-context/0.1', 'exact model context schema'
call must feed~value['result']['modelInput']['items'][1]['recordId'] = recordId, 'model feed record'
call must feed~value['result']['projectionTrace'][1]['reason'] = 'CURRENT_DECISION', 'projection reason trace'
projectionId = feed~value['result']['projectionId']
traceReq = .directory~new; traceReq['projection_id'] = projectionId
trace = registry~invoke('cognitive.context.explain', traceReq)
call must trace~ok, 'context explain in process'
call must trace~value['result']['selectionTrace'][1]['recordId'] = recordId, 'context explain record'

current = registry~invoke('continuity.current')
call must current~ok, 'continuity current'
call must current~value['result']['authority'] = 'COGNITIVE_CONTINUITY_EVENTS', 'durable continuity authority'
call must current~value['result']['cognitive_state_compactable'] == .JSON~false, 'durable state not compactable'
call must current~value['result']['durable_state']['records'][1]['recordId'] = recordId, 'durable continuity record'
call must current~value['result']['brief_projection']['authority'] = 'PROJECTION_ONLY', 'legacy brief only projection'

/* Caller cannot smuggle actor/authority into the ability request. */
forbiddenReq = .directory~new
forbiddenReq['effects'] = .array~of(effect)
forbiddenReq['authority'] = 'TOOL_VERIFIED'
forbidden = registry~invoke('cognitive.effects.propose', forbiddenReq)
call must \forbidden~ok, 'authority injection blocked'
call must forbidden~code = 'COGNITIVE_ACTOR_OR_AUTHORITY_FIELD_FORBIDDEN', 'authority rejection code'

/* Rebuild from durable JSONL with a fresh service/registry: no chat or brief is needed. */
runtime2 = .LlmPaCognitiveRuntime~new(journal, scope)
ctx2 = .LlmPaAbilityContext~new
ignore = ctx2~setService('cognitive_runtime', runtime2)
ignore = ctx2~setConfig('cognitive_scope', scope)
registry2 = .LlmPaAbilityRegistry~new(packageRoot || '/abilities.d', ctx2)
call must registry2~load~ok, 'restart registry load'
ignore = ctx2~setService('ability_registry', registry2)
query2 = registry2~invoke('cognitive.records.query')
call must query2~ok, 'restart records query'
call must query2~value['result']['count'] = 1, 'durable cognitive state survives restart'
call must query2~value['result']['records'][1]['recordId'] = recordId, 'restart exact record'
feed2 = registry2~invoke('cognitive.context.export', exportReq)
call must feed2~ok, 'restart context export'
call must feed2~value['result']['modelInput']['items'][1]['recordId'] = recordId, 'projection regenerated from durable state'

address command 'rm -rf' tmp
say 'PASS test_cognitive_abilities'
exit 0

::routine must
  use arg ok, label
  if \ok then do; say 'FAIL' label; exit 1; end
return

::requires 'LlmPaAbility.cls'
::requires 'LlmPaCognitiveRuntime.cls'
::requires 'LlmPaContinuity.cls'
::requires 'json.cls'
