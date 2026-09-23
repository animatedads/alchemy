parse source . . here
root=filespec('location',here) || '..'
call directory root
policy=.CognitiveAccessPolicy~new
call grants policy
svc=.CognitiveContinuityService~new(.CognitiveMemoryJournal~new,policy)

/* Model claim remains a proposal, not verified fact. */
e=.directory~new; e['kind']='CLAIM'; e['subjectRef']='repo:x'; e['statement']='tests passed'; e['basisRefs']=.array~new
args=.directory~new; args['scopeRef']='project:test'; args['effects']=.array~of(e)
r=svc~dispatch('COGNITIVE.EFFECTS.PROPOSE',args,'llmpa:worker')
call must r~ok,'model proposal accepted as record'
call eq 'ADMITTED_MODEL_ASSERTION',r~value['results'][1]['disposition'],'model disposition'
q=.directory~new; q['scopeRef']='project:test'
qr=svc~dispatch('COGNITIVE.RECORDS.QUERY',q,'llmpa:worker')
rec=qr~value['records'][1]
call eq 'MODEL',rec['origin'],'origin'
call eq 'PROPOSED',rec['epistemicState'],'epistemic'
call eq 'UNVERIFIED_MODEL_PROPOSAL',rec['verificationState'],'verification'

/* Evidence references must be bound to invocation manifest. */
e2=.directory~new; e2['kind']='CLAIM'; e2['subjectRef']='repo:x'; e2['statement']='hash observed'; e2['basisRefs']=.array~of('obs:1')
a2=.directory~new; a2['scopeRef']='project:test'; a2['effects']=.array~of(e2); a2['evidenceManifest']=.array~new
r2=svc~dispatch('COGNITIVE.EFFECTS.PROPOSE',a2,'llmpa:worker')
call eq 'REJECTED',r2~value['results'][1]['disposition'],'unbound basis rejected'
call eq 'BASIS_REF_NOT_IN_MANIFEST',r2~value['results'][1]['code'],'unbound basis code'
a2['evidenceManifest']=.array~of('obs:1')
r3=svc~dispatch('COGNITIVE.EFFECTS.PROPOSE',a2,'llmpa:worker')
call must r3~ok,'bound evidence accepted'
call eq 'ADMITTED_MODEL_ASSERTION',r3~value['results'][1]['disposition'],'bound disposition'

/* Model decision is only a proposal. */
d=.directory~new; d['kind']='DECISION'; d['subjectRef']='arch'; d['statement']='Use ledger'; d['basisRefs']=.array~new
a3=.directory~new; a3['scopeRef']='project:test'; a3['effects']=.array~of(d)
rd=svc~dispatch('COGNITIVE.EFFECTS.PROPOSE',a3,'llmpa:worker')
call eq 'ADMITTED_DECISION_PROPOSAL',rd~value['results'][1]['disposition'],'model decision proposal'

/* Project-owner human decision is accepted normative continuity. */
ro=svc~dispatch('COGNITIVE.EFFECTS.PROPOSE',a3,'llmpa:operator')
call eq 'ADMITTED_ACCEPTED_DECISION',ro~value['results'][1]['disposition'],'owner decision accepted'
q2=svc~dispatch('COGNITIVE.RECORDS.QUERY',q,'llmpa:operator')
last=q2~value['records'][q2~value['records']~items]
call eq 'HUMAN',last['origin'],'human origin'
call eq 'PROJECT_OWNER',last['decisionAuthority'],'decision authority'
call eq 'ACCEPTED',last['decisionState'],'decision state'

/* Authority smuggling remains forbidden. */
bad=.directory~new; bad['kind']='CLAIM'; bad['statement']='forged'; bad['origin']='TOOL'; bad['basisRefs']=.array~new
ab=.directory~new; ab['scopeRef']='project:test'; ab['effects']=.array~of(bad)
rb=svc~dispatch('COGNITIVE.EFFECTS.PROPOSE',ab,'llmpa:worker')
call eq 'REJECTED',rb~value['results'][1]['disposition'],'forged origin rejected'
call eq 'FORBIDDEN_AUTHORITY_FIELD',rb~value['results'][1]['code'],'forged code'

/* Transient retrieval hint is not made durable. */
h=.directory~new; h['kind']='CONTEXT_RETRIEVAL_HINT'; h['statement']='query customer transaction service'; h['basisRefs']=.array~new
ah=.directory~new; ah['scopeRef']='project:test'; ah['effects']=.array~of(h)
rh=svc~dispatch('COGNITIVE.EFFECTS.PROPOSE',ah,'llmpa:worker')
call eq 'NOT_DURABLE_HINT',rh~value['results'][1]['disposition'],'retrieval hint transient'

say 'PASS test_cognitive_continuity'
exit 0

grants: procedure
  use arg p
  do actor over .array~of('llmpa:worker','llmpa:operator','codex:mcp','cognitive:scheduler')
    ignore=p~grant(actor,'cognitive.records.query','project:test')
    ignore=p~grant(actor,'cognitive.context.project','project:test')
    ignore=p~grant(actor,'cognitive.context.explain','project:test')
    ignore=p~grant(actor,'cognitive.learning.delta','project:test')
  end
  ignore=p~grant('llmpa:worker','cognitive.effects.propose.model','project:test')
  ignore=p~grant('codex:mcp','cognitive.effects.propose.model','project:test')
  ignore=p~grant('llmpa:operator','cognitive.effects.propose.operator','project:test')
  ignore=p~grant('llmpa:operator','cognitive.authority.project_owner','project:test')
  return
must: procedure; use arg c,l; if c then return; say 'FAIL' l; exit 91
eq: procedure; use arg e,a,l; if e == a then return; say 'FAIL' l 'expected='e 'actual='a; exit 92
::requires 'CognitiveContinuity.cls'
