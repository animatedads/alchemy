call mj_test_install_native_crypto

manager=.ObjectQueueManager~new("",.QueueGraphPayloadCodec~new,"admin")
call ok manager~createQueue("STATUS.UI","TEMPORARY","APP",10,"admin"),"create ui subscriber queue"
call ok manager~createQueue("STATUS.LOG","TEMPORARY","APP",10,"admin"),"create log subscriber queue"
topics=.QueueTopicFabric~new(manager)
call ok topics~defineTopic("MIGRATABLE.JOB.STATUS","migratable/job/status","TEMPORARY","APP","admin"),"define status topic"
call ok topics~grantTopicAccess("MIGRATABLE.JOB.STATUS","status-publisher",.QueueTopicAccess~PUBLISH,"admin"),"grant status publisher"
call ok topics~subscribe("STATUS.UI.SUB","MIGRATABLE.JOB.STATUS","#","STATUS.UI","TEMPORARY","admin"),"subscribe ui"
call ok topics~subscribe("STATUS.LOG.SUB","MIGRATABLE.JOB.STATUS","#","STATUS.LOG","TEMPORARY","admin"),"subscribe log"

uk=.array~of("GB")
req=.JobNodeRequirement~new(uk)
pr=.JobPlacementRequest~new("JOB-STATUS",req,"OWNER",1000,1000)
def=.MigratableJobDefinition~new("JOB-STATUS",pr,"definition:status","PART","OWNER","OOREXX","5.3-r13196","rev-status")
source=.JobNodePlacementLease~new("PLACE-S","JOB-STATUS","NODE-A","OWNER",1,1,1000,10000,"req","cap","obs","1","","","",1,0,"")

statusPublisher=.MigratableJobTopicStatusPublisher~new(topics,"MIGRATABLE.JOB.STATUS","status-publisher",.false,.true)
ledger=.MigratableJobProvenanceLedger~new
coord=.MigratableJobCoordinator~new(.Exec~new,.Transfer~new,.Commit~new,.Handoff~new,ledger,.nil,.nil,.nil,statusPublisher)
m=coord~begin("MIG-STATUS",def,source,1100)

call equal 1,manager~depth("STATUS.UI","admin")~value["ready"],"ui received status"
call equal 1,manager~depth("STATUS.LOG","admin")~value["ready"],"log independently received same status"
ui=manager~browse("STATUS.UI","admin")~value
log=manager~browse("STATUS.LOG","admin")~value
call equal "migratable.job.status/1",ui~payload["schema"],"status schema"
call equal "NEW",ui~payload["state"],"initial state"
call equal 0,ui~payload["sequence"],"initial sequence"
call equal ui~payload["migrationId"],log~payload["migrationId"],"fanout preserves migration"
call equal ui~headers["oqf.topic.publication_id"],log~headers["oqf.topic.publication_id"],"one publication fans out"
ignore=manager~get("STATUS.UI","admin"); ignore=manager~get("STATUS.LOG","admin")

if \m~transition(.MigratableJobMigrationState~NEW,.MigratableJobMigrationState~PREPARING,1200) then call fail "transition failed"
r=statusPublisher~publish(m)
if \r~ok then call fail "second status publish failed"
call equal 1,manager~depth("STATUS.UI","admin")~value["ready"],"ui received replacement status"
call equal 1,manager~depth("STATUS.LOG","admin")~value["ready"],"log received replacement status"
p=manager~browse("STATUS.UI","admin")~value
call equal "PREPARING",p~payload["state"],"updated state"
call equal 1,p~payload["sequence"],"monotonic status sequence"

/* Late subscriber receives the retained current snapshot, not a direct queue handoff. */
call ok manager~createQueue("STATUS.LATE","TEMPORARY","APP",10,"admin"),"create late subscriber queue"
pattern=.MigratableJobStatusTopicAddress~jobPattern("JOB-STATUS")
call ok topics~subscribe("STATUS.LATE.SUB","MIGRATABLE.JOB.STATUS",pattern,"STATUS.LATE","TEMPORARY","admin"),"late job subscriber"
call equal 1,manager~depth("STATUS.LATE","admin")~value["ready"],"late subscriber received retained current status"
late=manager~browse("STATUS.LATE","admin")~value
call equal "PREPARING",late~payload["state"],"retained state is current"
call equal 1,late~payload["sequence"],"retained sequence is current"
call equal 1,late~headers["oqf.topic.retained"],"late delivery marked retained"

/* Observer backpressure must not become migration authority.  Fill one subscriber,
 * then begin a second migration. Topic fanout fails atomically, but begin still
 * succeeds and provenance records the observation failure. */
ignore=manager~get("STATUS.UI","admin")
ignore=manager~get("STATUS.LOG","admin")
do i=1 to 10
  ignore=manager~put("STATUS.UI","fill-"||i,.nil,"admin")
end
pr2=.JobPlacementRequest~new("JOB-STATUS-2",req,"OWNER",1000,1000)
def2=.MigratableJobDefinition~new("JOB-STATUS-2",pr2,"definition:status2","PART","OWNER","OOREXX","5.3-r13196","rev-status")
source2=.JobNodePlacementLease~new("PLACE-S2","JOB-STATUS-2","NODE-A","OWNER",1,1,1000,10000,"req","cap","obs","1","","","",1,0,"")
m2=coord~begin("MIG-STATUS-2",def2,source2,1300)
call equal "NEW",m2~state,"status backpressure does not fail migration creation"
found=.false
do e over ledger~events
  if e~kind="STATUS_PUBLICATION_FAILED" & e~migrationId="MIG-STATUS-2" then found=.true
end
if \found then call fail "status publication failure provenance missing"

say "PASS live job status uses retained topic fanout to independent subscriber queues; observer failure is non-authoritative"
exit 0

ok: procedure
  use arg r,label
  if r==.nil | \r~ok then do
    say "FAIL" label
    if r<>.nil then say r~code r~detail
    exit 1
  end
  return

equal: procedure
  use arg expected,actual,label
  if expected<>actual then do
    say "FAIL" label "expected="expected "actual="actual
    exit 1
  end
  return

fail: procedure
  use arg msg
  say "FAIL" msg
  exit 1

::class Exec subclass MigratableJobExecutionAdapter
::method pauseAndCheckpoint
  return .MigratableJobCheckpointResult~failure("NOT_USED")
::method resumeFromCheckpoint
  return .MigratableJobResumeResult~failure("NOT_USED")
::class Transfer subclass MigratableJobTransferAdapter
::method transfer
  return .MigratableJobTransferResult~new(.MigratableJobTransferStatus~FAILED,"","",0,"NOT_USED")
::class Commit subclass MigratableJobCommitAuthority
::method authorise
  return .MigratableJobCommitDecision~deny("NOT_USED")
::class Handoff
::method fenceSource
  return .JobNodePlacementDecision~new(.false,"NOT_USED",.nil)
::method allocateDestination
  return .JobNodePlacementDecision~new(.false,"NOT_USED",.nil)
::method verifyDestination
  return .false
::method releaseDestination
  return .true

::requires "MigratableJobStatusTopic.cls"
::requires "TestForeignCryptoBootstrap.cls"
