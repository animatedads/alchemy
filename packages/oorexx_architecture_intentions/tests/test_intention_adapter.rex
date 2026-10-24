cat = .ArchitectureCatalog~fromFile('catalog/architecture_catalog.json')
engine = .ArchitecturePlanner~new(cat)
project = engine~project('intent-test','Intention test')
service = .IntentionService~new
service~registerProvider(.DeterministicIntentionProvider~new)
registrations = .ArchitectureIntentionAdapter~new~registerOpenChoices(service, engine, project, 'verified tester')
if registrations~items < 5 then signal failure
p = engine~plan(project)
if p['effectiveAnswers']~hasIndex('workload') then signal failure
decision = service~input('select batch for workload')
say 'first decision status:' decision~status
if decision~status \== 'CONFIRM' then signal failure
decision = service~input('yes')
say 'confirmed status:' decision~status
if decision~status \== 'READY' then signal failure
service~dispatch(decision)
if project~value('workload') \== 'batch' then signal failure
/* Design-time planner components are no longer forced into an application build. */
if engine~plan(project)['buildRequest']['requirements']~items < 1 then signal failure
say 'PASS intention adapter READY gated dispatch'
exit 0
failure:
say 'FAIL Intention Adapter'
exit 1
::requires 'ArchitectureIntentionAdapter.cls'
