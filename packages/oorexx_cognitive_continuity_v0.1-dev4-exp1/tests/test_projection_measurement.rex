parse source . . here
root=filespec('location',here) || '..'; call directory root
tmp='/tmp/cognitive-measurement-'||random(10000,99999)
address command 'rm -rf' tmp
address command 'mkdir -p' tmp
p=.CognitiveAccessPolicy~new
scope='project:measure'; actor='agent:model'; learner='cognitive:scheduler'
do cap over .array~of('cognitive.effects.propose.model','cognitive.records.query','cognitive.context.project','cognitive.context.explain','cognitive.projection.outcome')
  ignore=p~grant(actor,cap,scope)
end
ignore=p~grant(learner,'cognitive.learning.delta',scope)
ignore=p~grant(learner,'cognitive.context.project',scope)
ignore=p~grant(learner,'cognitive.context.explain',scope)
ignore=p~grant(learner,'cognitive.projection.outcome',scope)
mem=tmp||'/measure.jsonl'; journal=tmp||'/cognitive.jsonl'
svc=.CognitiveContinuityService~new(.CognitiveJsonlJournal~new(journal),p,.CognitiveJsonlMeasurementJournal~new(mem))
e=.directory~new; e['kind']='LESSON'; e['subjectRef']='measurement'; e['statement']='Exact model feeds should be inspectable'; e['basisRefs']=.array~new
a=.directory~new; a['scopeRef']=scope; a['effects']=.array~of(e)
call must svc~dispatch('COGNITIVE.EFFECTS.PROPOSE',a,actor)~ok,'seed'
x=.directory~new; x['scopeRef']=scope; x['limit']=8
feed=svc~dispatch('COGNITIVE.CONTEXT.EXPORT',x,actor); call must feed~ok,'feed export'
call must feed~value~hasIndex('measurementReceiptId'),'receipt id returned'
proj=feed~value['projectionId']
o=.directory~new; o['scopeRef']=scope; o['projectionId']=proj; o['outcome']='USEFUL'; o['usefulRecordIds']=.array~of(feed~value['modelInput']['items'][1]['recordId']); o['irrelevantRecordIds']=.array~new; o['missingKinds']=.array~new
out=svc~dispatch('COGNITIVE.PROJECTION.OUTCOME',o,actor); call must out~ok,'outcome recorded'
q=.directory~new; q['scopeRef']=scope; q['sinceMeasurementSequence']=0
receipts=svc~dispatch('COGNITIVE.PROJECTION.RECEIPTS',q,actor); call must receipts~ok,'receipts query'; call eq 1,receipts~value['count'],'receipt count'
outcomes=svc~dispatch('COGNITIVE.PROJECTION.OUTCOMES',q,actor); call must outcomes~ok,'outcomes query'; call eq 1,outcomes~value['count'],'outcome count'
bargs=.directory~new; bargs['scopeRef']=scope; bargs['sinceSequence']=0; bargs['sinceMeasurementSequence']=0
bundle=svc~dispatch('COGNITIVE.LEARNING.BUNDLE',bargs,learner); call must bundle~ok,'learning bundle'; call eq 1,bundle~value['projectionReceiptCount'],'bundle receipts'; call eq 1,bundle~value['projectionOutcomeCount'],'bundle outcomes'
/* Restart: measurements replay independently of cognitive journal. */
svc2=.CognitiveContinuityService~new(.CognitiveJsonlJournal~new(journal),p,.CognitiveJsonlMeasurementJournal~new(mem))
receipts2=svc2~dispatch('COGNITIVE.PROJECTION.RECEIPTS',q,actor); call eq 1,receipts2~value['count'],'receipt replay'
outcomes2=svc2~dispatch('COGNITIVE.PROJECTION.OUTCOMES',q,actor); call eq 1,outcomes2~value['count'],'outcome replay'
address command 'rm -rf' tmp
say 'PASS test_projection_measurement'
exit 0
must: procedure; use arg c,l; if c then return; say 'FAIL' l; exit 91
eq: procedure; use arg e,a,l; if e == a then return; say 'FAIL' l 'expected='e 'actual='a; exit 92
::requires 'CognitiveContinuity.cls'
