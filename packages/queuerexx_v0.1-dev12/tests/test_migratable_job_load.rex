say .QueueRexxVersion~version
say .QueueMigrationState~name(.QueueMigrationState~TRANSFERRING)
say .MigratableJobBuild~API
say .MigratableJobPlacementContract~API
say .MigratableJobPlacementContract~RECEIPT_API
exit 0
::requires "QueueRexxMigratableJob.cls"
