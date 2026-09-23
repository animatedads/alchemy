parse source . . here
root=filespec('location',here) || '..'; call directory root
p=.CognitiveAccessPolicy~new
ignore=p~grant('llmpa:worker','cognitive.effects.propose.model','project:feed')
ignore=p~grant('llmpa:worker','cognitive.records.query','project:feed')
ignore=p~grant('llmpa:worker','cognitive.context.project','project:feed')
ignore=p~grant('llmpa:worker','cognitive.context.explain','project:feed')
svc=.CognitiveContinuityService~new(.CognitiveMemoryJournal~new,p)
call add svc,'DECISION','memory','Durable cognitive state is not model context'
call add svc,'OPEN_QUESTION','memory','Which classifier should handle novel episodes?'
call add svc,'LESSON','coding','Repeated deterministic sequences should become tool candidates'
call add svc,'CLAIM','runtime','HF allowance is external compute, not authority'
call add svc,'TOOL_CANDIDATE','coding','Build runtime dependency resolver'

args=.directory~new; args['scopeRef']='project:feed'; args['task']='continue cognitive memory implementation'; args['limit']=3
r=svc~dispatch('COGNITIVE.CONTEXT.EXPORT',args,'llmpa:worker')
call must r~ok,'export'
call eq 'EXACT_MODEL_INPUT_EXPORT',r~value['disposition'],'export disposition'
model=r~value['modelInput']
call eq 3,model['items']~items,'bounded model items'
call eq 'DECISION',model['items'][1]['kind'],'decision priority first'
call eq 'OPEN_QUESTION',model['items'][2]['kind'],'question priority second'
parsed=.json~fromJSON(r~value['modelInputJson']); call eq 'cognitive.model-context/0.1',parsed['schema'],'json carries schema'
call must r~value['projectionTrace']~items>=5,'trace includes omitted records'

x=.directory~new; x['scopeRef']='project:feed'; x['projectionId']=r~value['projectionId']
e=svc~dispatch('COGNITIVE.CONTEXT.EXPLAIN',x,'llmpa:worker')
call must e~ok,'explain'
call eq r~value['projectionId'],e~value['projectionId'],'same projection'
call eq 'BUDGET_LIMIT',e~value['selectionTrace'][e~value['selectionTrace']~items]['reason'],'omitted due budget'

say 'PASS test_projection_and_feed'
exit 0
add: procedure expose svc
  use arg svc,kind,subject,statement
  e=.directory~new; e['kind']=kind; e['subjectRef']=subject; e['statement']=statement; e['basisRefs']=.array~new
  a=.directory~new; a['scopeRef']='project:feed'; a['effects']=.array~of(e)
  r=svc~dispatch('COGNITIVE.EFFECTS.PROPOSE',a,'llmpa:worker')
  if \r~ok then do; say 'FAIL seed' kind r~code; exit 93; end
  return
must: procedure; use arg c,l; if c then return; say 'FAIL' l; exit 91
eq: procedure; use arg e,a,l; if e == a then return; say 'FAIL' l 'expected='e 'actual='a; exit 92
::requires 'CognitiveContinuity.cls'
::requires 'json.cls'
