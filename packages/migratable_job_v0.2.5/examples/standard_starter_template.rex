/* Skeleton showing the standard Migratable Job starter wiring.
 * Supply real Job-to-Node placement/definition and runtime implementations.
 */
parse arg stateRoot, jobId, partitionId, startId
if stateRoot="" | jobId="" | startId="" then do
  say "usage: rexx standard_starter_template.rex STATE_ROOT JOB_ID PARTITION START_ID"
  exit 2
end

/* Application code normally constructs the real definition here. */
say "Template only: implement MyMigratableApplication~definition and ~startNew"
say "state root:" stateRoot
say "job:" jobId "partition:" partitionId "start:" startId
exit 0

::class MyMigratableApplication subclass MigratableJobStarterApplication
::method definition
  raise syntax 88.900 array("template: return stable MigratableJobDefinition")
::method startNew
  raise syntax 88.900 array("template: start runtime idempotently by request~startId")

::requires "MigratableJobStarter.cls"
