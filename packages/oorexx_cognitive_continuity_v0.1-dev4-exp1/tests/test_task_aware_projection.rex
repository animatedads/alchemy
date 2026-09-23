parse source . . here
root=filespec('location',here) || '..'; call directory root
p=.CognitiveAccessPolicy~new
scope='project:shared'
actor='llmpa:worker'
ignore=p~grant(actor,'cognitive.effects.propose.model',scope)
ignore=p~grant(actor,'cognitive.records.query',scope)
ignore=p~grant(actor,'cognitive.context.project',scope)
ignore=p~grant(actor,'cognitive.context.explain',scope)
svc=.CognitiveContinuityService~new(.CognitiveMemoryJournal~new,p)

call add svc,scope,actor,'DECISION','queuerexx','Verify QueueRexx launcher ABI compatibility and remote authority listeners'
call add svc,scope,actor,'OPEN_QUESTION','safety29','Which Jay Maynard turnkey archive member is the pinned MVTRES.350 image?'
call add svc,scope,actor,'LESSON','artifact-identity','Safety29 media identity is established by the pinned MVTRES.350 SHA-256, not a munged filename'

a=.directory~new
a['scopeRef']=scope
a['task']='Safety29 long MVT run using TURNKEYMVTJAY1 and pinned MVTRES.350 evidence'
a['limit']=8
r=svc~dispatch('COGNITIVE.CONTEXT.EXPORT',a,actor)
call must r~ok,'export'
items=r~value['modelInput']['items']
call eq 2,items~items,'only task-relevant records projected'
call must hasSubject(items,'safety29'),'Safety29 question included'
call must hasSubject(items,'artifact-identity'),'artifact lesson included'
call must \hasSubject(items,'queuerexx'),'QueueRexx record excluded'
call eq 3,r~value['projectionTrace']~items,'trace covers all visible records'
call must traceHas(r~value['projectionTrace'],'queuerexx','TASK_FILTER_MISMATCH'),'QueueRexx mismatch explained'
call must r~value['modelInput']['task']='Safety29 long MVT run using TURNKEYMVTJAY1 and pinned MVTRES.350 evidence','task preserved'

/* Broad/no-task projection remains available for explicit continuity rendering. */
b=.directory~new; b['scopeRef']=scope; b['limit']=8
all=svc~dispatch('COGNITIVE.CONTEXT.PROJECT',b,actor)
call must all~ok,'broad project'
call eq 3,all~value['count'],'broad projection keeps scope records'

say 'PASS test_task_aware_projection'
exit 0

add: procedure
  use arg svc,scope,actor,kind,subject,statement
  e=.directory~new; e['kind']=kind; e['subjectRef']=subject; e['statement']=statement; e['basisRefs']=.array~new
  a=.directory~new; a['scopeRef']=scope; a['effects']=.array~of(e)
  r=svc~dispatch('COGNITIVE.EFFECTS.PROPOSE',a,actor)
  if \r~ok then do; say 'FAIL seed' kind r~code r~detail; exit 93; end
  return

hasSubject: procedure
  use arg items,wanted
  do item over items
    if item['subjectRef']~caselessEquals(wanted) then return .true
  end
  return .false

traceHas: procedure
  use arg trace,subjectWanted,reasonWanted
  /* trace intentionally carries record ids rather than subjects; map known
   * first record id because insertion order in this fixture is stable. */
  do row over trace
    if row['reason']=reasonWanted & row['recordId']='cog-000000001' then return .true
  end
  return .false

must: procedure; use arg c,l; if c then return; say 'FAIL' l; exit 91
eq: procedure; use arg e,a,l; if e == a then return; say 'FAIL' l 'expected='e 'actual='a; exit 92
::requires 'CognitiveContinuity.cls'
::requires 'json.cls'
