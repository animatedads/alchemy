/* Real dog-food evidence distilled from the Codex Safety29 run.
 * This deliberately records defects as measurement-only observations and the
 * successful artifact-resolution behaviour as a raw procedural episode hint.
 */
parse source . . here
root=filespec('location',here) || '..'; call directory root
outDir=arg(1)
if outDir='' then outDir='/tmp/cognitive-safety29-dogfood'
address command 'mkdir -p' outDir
scope='project:ai-memory-dogfood'; operator='operator:architect'; consumer='agent:codex'; learner='cognitive:scheduler'
p=.CognitiveAccessPolicy~new
ignore=p~grant(operator,'cognitive.effects.propose.operator',scope)
ignore=p~grant(operator,'cognitive.authority.project_owner',scope)
ignore=p~grant(operator,'cognitive.dogfood.observe',scope)
ignore=p~grant(operator,'cognitive.context.project',scope)
ignore=p~grant(operator,'cognitive.context.explain',scope)
ignore=p~grant(operator,'cognitive.projection.outcome',scope)
ignore=p~grant(consumer,'cognitive.context.project',scope)
ignore=p~grant(consumer,'cognitive.context.explain',scope)
ignore=p~grant(consumer,'cognitive.projection.outcome',scope)
ignore=p~grant(learner,'cognitive.learning.delta',scope)
svc=.CognitiveContinuityService~new(.CognitiveJsonlJournal~new(outDir||'/cognitive.jsonl'),p,.CognitiveJsonlMeasurementJournal~new(outDir||'/measurements.jsonl'))
/* Raw successful episode: do not pre-promote it to a lesson. */
e=.directory~new; e['kind']='SKILL_EPISODE_HINT'; e['subjectRef']='s370:safety29'; e['statement']='Codex resolved the authoritative OS/360 MVT media by inspecting the local TURNKEY archive, verifying os360mvt/dasd/mvtres.350 SHA-256 095b44517a85bfdd65764d22af8378e30c1437cd8539ed582e1eb45fea7c5b49, rejecting filename ambiguity, locating the prescribed long-run wrapper, and preserving continuous-run evidence requirements.'; e['basisRefs']=.array~of('handoff:safety29:turnkey-pin','codex:safety29:mvtres-hash'); e['aimScope']='PROJECT'; e['durabilityHint']='PROJECT'; e['verificationNeed']='SOURCE'; e['confidencePct']=100
a=.directory~new; a['scopeRef']=scope; a['evidenceManifest']=.array~of('handoff:safety29:turnkey-pin','codex:safety29:mvtres-hash'); a['effects']=.array~of(e)
seed=svc~dispatch('COGNITIVE.EFFECTS.PROPOSE',a,operator)
/* Observed defects, kept outside cognitive authority. */
o=.directory~new; o['scopeRef']=scope; o['observationClass']='CLIENT_REPLY_CORRELATION_FAILURE'; o['task']='Safety29 OS/360 MVT continuous long run'; o['expectedBehavior']='Return the reply correlated to the Safety29 request id'; o['observedBehavior']='llmpa next returned an older QueueRexx deployment plan from a different request'; o['evidenceManifest']=.array~of('codex:safety29:ask','codex:safety29:wrong-next'); o['evidenceRefs']=.array~of('codex:safety29:ask','codex:safety29:wrong-next'); o['note']='This is a client/reply-correlation defect, not a Cognitive Continuity projection failure.'
ignore=svc~dispatch('COGNITIVE.DOGFOOD.OBSERVE',o,operator)
o2=.directory~new; o2['scopeRef']=scope; o2['observationClass']='COGNITIVE_CONTEXT_BYPASS'; o2['task']='Safety29 OS/360 MVT continuous long run'; o2['expectedBehavior']='Ordinary LLMPA ask consumes task-scoped Cognitive Continuity context'; o2['observedBehavior']='Candidate6 ordinary ask path bypassed Cognitive Continuity; candidate7 corrected the path'; o2['evidenceManifest']=.array~of('candidate6:path-review','candidate7:normal-ask-fix'); o2['evidenceRefs']=.array~of('candidate6:path-review','candidate7:normal-ask-fix')
ignore=svc~dispatch('COGNITIVE.DOGFOOD.OBSERVE',o2,operator)
/* Corrected task-aware projection evidence: create a competing QueueRexx record and a Safety29 record. */
q=.directory~new; q['kind']='DECISION'; q['subjectRef']='QueueRexx'; q['statement']='Verify ED209A and ED209B launcher ABI compatibility'; q['basisRefs']=.array~new
s=.directory~new; s['kind']='OPEN_QUESTION'; s['subjectRef']='Safety29 MVTRES'; s['statement']='Preserve final RING REGS CRS CLOCK OPCODES STOP NEXT and HOST_SYNTAX evidence from the continuous MVT run'; s['basisRefs']=.array~new
pa=.directory~new; pa['scopeRef']=scope; pa['effects']=.array~of(q,s)
seed2=svc~dispatch('COGNITIVE.EFFECTS.PROPOSE',pa,operator)
x=.directory~new; x['scopeRef']=scope; x['task']='Safety29 OS/360 MVT continuous long run'; x['limit']=16
feed=svc~dispatch('COGNITIVE.CONTEXT.EXPORT',x,consumer)
useful=.array~new
if feed~ok then do item over feed~value['modelInput']['items']; if item['subjectRef']='Safety29 MVTRES' then useful~append(item['recordId']); end
y=.directory~new; y['scopeRef']=scope; y['projectionId']=feed~value['projectionId']; y['outcome']='USEFUL'; y['usefulRecordIds']=useful; y['irrelevantRecordIds']=.array~new; y['missingKinds']=.array~new; y['note']='Corrected projector retained Safety29 context and excluded the unrelated QueueRexx record with TASK_FILTER_MISMATCH.'
ignore=svc~dispatch('COGNITIVE.PROJECTION.OUTCOME',y,consumer)
/* Export exact learning bundle/request for Qwen dog-food. */
b=.directory~new; b['scopeRef']=scope; b['sinceSequence']=0; b['sinceMeasurementSequence']=0
bundle=svc~dispatch('COGNITIVE.LEARNING.BUNDLE',b,learner)
req=.CognitiveLearningRequestBuilder~fromBundle(bundle~value,'HOURLY','LOW_COST')
call charout outDir||'/SAFETY29_CODEX_LEARNING_BUNDLE.json',.json~toJSON(bundle~value); call stream outDir||'/SAFETY29_CODEX_LEARNING_BUNDLE.json','c','close'
call charout outDir||'/SAFETY29_CODEX_QWEN_REQUEST.json',.json~toJSON(req); call stream outDir||'/SAFETY29_CODEX_QWEN_REQUEST.json','c','close'
call charout outDir||'/SAFETY29_CORRECTED_MODEL_INPUT.json',feed~value['modelInputJson']; call stream outDir||'/SAFETY29_CORRECTED_MODEL_INPUT.json','c','close'
say 'DOGFOOD_OUT='outDir
say 'CORPUS_POINT='bundle~value['toCorpusPointId']
say 'DOGFOOD_OBSERVATIONS='bundle~value['dogfoodObservationCount']
say 'PROJECTION_RECEIPTS='bundle~value['projectionReceiptCount']
say 'PROJECTION_OUTCOMES='bundle~value['projectionOutcomeCount']
exit 0
::requires 'CognitiveContinuity.cls'
::requires 'CognitiveLearningQueueAdapter.cls'
