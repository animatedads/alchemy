p=.CognitiveAccessPolicy~new
ignore=p~grant('llmpa:worker','cognitive.effects.propose.model','project:pa')
ignore=p~grant('llmpa:worker','cognitive.records.query','project:pa')
ignore=p~grant('llmpa:worker','cognitive.context.project','project:pa')
ignore=p~grant('llmpa:operator','cognitive.effects.propose.operator','project:pa')
ignore=p~grant('llmpa:operator','cognitive.records.query','project:pa')
ignore=p~grant('llmpa:operator','cognitive.context.project','project:pa')
ignore=p~grant('llmpa:operator','cognitive.authority.project_owner','project:pa')
svc=.CognitiveContinuityService~new(.CognitiveMemoryJournal~new,p)
pa=.LlmPaCognitiveAdapter~new(svc)
r=pa~operatorRemember('project:pa','setting:ssh','Use ./sshnode.sh'); call must r~ok,'operator remember'
e=.directory~new; e['kind']='OPEN_QUESTION'; e['subjectRef']='project:pa'; e['statement']='What next?'; e['basisRefs']=.array~new
r2=pa~modelEffects('project:pa',.array~of(e)); call must r2~ok,'model effects'
c=pa~modelContext('project:pa','continue project',16); call must c~ok,'model context'
call eq 2,c~value['modelInput']['items']~items,'model context count'
call must c~value['modelInputJson']~length>20,'model input json present'
say 'PASS test_llmpa_adapter'; exit 0
must: procedure; use arg c,l; if c then return; say 'FAIL' l; exit 91
eq: procedure; use arg e,a,l; if e == a then return; say 'FAIL' l 'expected='e 'actual='a; exit 92
::requires 'CognitiveContinuity.cls'
::requires 'LlmPaCognitiveAdapter.cls'
