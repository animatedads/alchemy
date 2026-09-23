parse source . . here
root=filespec('location',here) || '..'; call directory root
path='/tmp/cognitive-replay-' || random(10000,99999) || '.jsonl'; call sysFileDelete path
p=.CognitiveAccessPolicy~new
ignore=p~grant('agent:a','cognitive.effects.propose.model','project:replay')
ignore=p~grant('agent:a','cognitive.records.query','project:replay')
ignore=p~grant('agent:a','cognitive.context.project','project:replay')
svc=.CognitiveContinuityService~new(.CognitiveJsonlJournal~new(path),p)
e=.directory~new; e['kind']='DECISION'; e['subjectRef']='x'; e['statement']='persist me'; e['basisRefs']=.array~new
a=.directory~new; a['scopeRef']='project:replay'; a['effects']=.array~of(e)
r=svc~dispatch('COGNITIVE.EFFECTS.PROPOSE',a,'agent:a'); call must r~ok,'append'
svc2=.CognitiveContinuityService~new(.CognitiveJsonlJournal~new(path),p)
q=.directory~new; q['scopeRef']='project:replay'
r2=svc2~dispatch('COGNITIVE.RECORDS.QUERY',q,'agent:a'); call must r2~ok,'replay query'
call eq 1,r2~value['count'],'replay count'; call eq 'persist me',r2~value['records'][1]['statement'],'replay value'; call eq 1,r2~value['records'][1]['sequence'],'sequence retained'
call sysFileDelete path
say 'PASS test_jsonl_replay'; exit 0
must: procedure; use arg c,l; if c then return; say 'FAIL' l; exit 91
eq: procedure; use arg e,a,l; if e == a then return; say 'FAIL' l 'expected='e 'actual='a; exit 92
::requires 'CognitiveContinuity.cls'
