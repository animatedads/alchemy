/* Example: populate decisions and write the projection as JSON.
 * Invoke from package root with REXX_PATH including src/ and ooRexx json.cls.
 */
parse arg destination
if destination == '' then destination = 'example-plan.json'
if stream(destination, 'C', 'QUERY EXISTS') \== '' then do
  say 'Refusing overwrite of existing plan:' destination
  exit 2
end
cat = .ArchitectureCatalog~fromFile('catalog/architecture_catalog.json')
engine = .ArchitecturePlanner~new(cat)
project = engine~project('demo-rexxos-notes','RexxOS NotNotes architectural proof')
project~answer('workload','service','Interactive documents','design owner','requirements conversation')
project~answer('deployment_model','rexxos_mu_mi','Use managed MU/MI estates','design owner','RexxOS architecture')
project~answer('frontend','web','Browser-facing client','design owner','website requested')
project~answer('browser_edge','both','Website and events','design owner','architecture scenario')
project~answer('scale_profile','horizontal','Replicated services','design owner','capacity goal')
project~answer('placement_policy','cost_guarded','Cost-governed placement','design owner','architecture scenario')
project~answer('xtp_carrier','l2','Private L2 MU/MI local network','design owner','topology assumption')
project~answer('network_scope','same_l2','Local fabric','design owner','network design')
project~answer('xtp_security','authenticated','Auth and admission','design owner','architecture scenario')
project~answer('multicast','xtp','Semantic group operations','design owner','network design')
project~answer('memory','fabric','Managed and fenced memory','design owner','capacity target')
project~answer('memory_bulk','bag','Bulk native, control XTP','design owner','memory.fabric.block/0.1')
project~answer('storage','fabric','Provider-neutral namespace','design owner','durability')
project~answer('storage_access','large_random','Workspace pools','design owner','architecture scenario')
project~answer('storage_replication','local','Failure domain copies','design owner','architecture scenario')
project~answer('durability','journaled','Deterministic continuation','design owner','recovery')
project~answer('restore_objective','checkpoint','Recovery proof','design owner','architecture scenario')
project~answer('data_model','graph','Relationship documents','design owner','NotNotes')
project~answer('security','internal','Controlled internal services','design owner','security policy')
project~answer('identity_boundary','host','Host instance identity','design owner','architecture scenario')
project~answer('observability','mesh','Single instrumentation authority','design owner','ops')
project~answer('deployment_target','rexxos','MI execution in managed grid','design owner','RexxOS')
project~answer('cost_priority','performance','Performance/price governance','design owner','cost planning')
project~answer('cost_budget','approval','Commissioning approval','design owner','architecture scenario')
/* The next step is SSC+Deployment resolution, not execution. */
plan = engine~plan(project)
call lineout destination, .JSON~toJSON(plan)
call lineout destination
call stream destination, 'C', 'CLOSE'
say 'State:' plan['state']
say 'Open:' plan['openQuestions']~items 'Issues:' plan['issues']~items
say 'Components:' plan['buildRequest']['requirements']~items
say 'Wrote:' destination
::requires 'ArchitecturePlanner.cls'
