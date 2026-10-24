/* Export a resolved design *request* into an existing project folder.
 * No semantic source resolution, binary vendoring or installation occurs.
 */
parse arg folder
if folder == '' then do
  say 'Usage: rexx examples/export_project.rex EXISTING_EMPTY_DIRECTORY'
  exit 2
end
catalog = .ArchitectureCatalog~fromFile('catalog/architecture_catalog.json')
planner = .ArchitecturePlanner~new(catalog)
project = planner~project('web-store-demo','Provider-neutral website project')
project~feature('search','Search and filter records','must', -
  'Queries are stable across restarts', 'architecture owner', .Array~of('notnotes'))
project~answer('workload','service','Interactive app','architecture owner')
project~answer('deployment_model','cloud','Cloud hosting','architecture owner')
project~answer('frontend','web','Web user interface','architecture owner')
project~answer('browser_edge','https','HTTPS front','architecture owner')
project~answer('scale_profile','elastic','Autoscaling requirement','architecture owner')
project~answer('placement_policy','cost_guarded','Budget gating','architecture owner')
project~answer('interconnect','api','External HTTP APIs','architecture owner')
project~answer('multicast','none','No group needs','architecture owner')
project~answer('memory','process','Local process heap','architecture owner')
project~answer('storage','object','Object files','architecture owner')
project~answer('storage_access','transactional','Small records','architecture owner')
project~answer('storage_replication','provider','Provider managed redundancy','architecture owner')
project~answer('durability','backup','Backup/recovery','architecture owner')
project~answer('restore_objective','tested','Periodic restore qualification','architecture owner')
project~answer('data_model','graph','Document relationships','architecture owner')
project~answer('security','public','Public web ingress','architecture owner')
project~answer('identity_boundary','federated','Federated identities','architecture owner')
project~answer('observability','mesh','Central publication','architecture owner')
project~answer('deployment_target','linux','Linux hosts','architecture owner')
project~answer('hosting','oci','Oracle cloud candidate','architecture owner')
project~answer('cloud_purchase','on_demand','Scale first then optimise','architecture owner')
project~answer('cost_priority','monthly','Keep monthly spending low','architecture owner')
project~answer('cost_budget','approval','Approval required','architecture owner')
project~answer('data_residency','uk','UK data stays UK','architecture owner')
plan = planner~plan(project)
writer = .ArchitecturePackageWriter~new
files = writer~write(plan, folder)
say 'Plan state:' plan['state']
say 'Published' files~items 'JSON artifacts to' folder
::requires 'ArchitecturePackageWriter.cls'
