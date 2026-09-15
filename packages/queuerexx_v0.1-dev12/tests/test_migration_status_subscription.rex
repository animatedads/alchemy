/* Exact Migratable Job v0.2.4 retained topic -> QueueRexx subscriber test. */
manager = .ObjectQueueManager~new("", .QueueGraphPayloadCodec~new, "admin")
topics = .QueueTopicFabric~new(manager)
call ok topics~defineTopic(.QueueMigrationStatusContract~DEFAULT_TOPIC, "migratable/job/status", .QueueLifecycle~TEMPORARY, "DEFAULT", "admin"), "define migration status topic"
call ok topics~grantTopicAccess(.QueueMigrationStatusContract~DEFAULT_TOPIC, "mj-publisher", .QueueTopicAccess~PUBLISH, "admin"), "grant publisher"
call ok topics~grantTopicAccess(.QueueMigrationStatusContract~DEFAULT_TOPIC, "queuerexx-status", .QueueTopicAccess~SUBSCRIBE, "admin"), "grant subscriber"

uk = .Array~of("GB")
requirement = .JobNodeRequirement~new(uk)
placement = .JobPlacementRequest~new("JOB-SUB-1", requirement, "OWNER", 1000, 1000)
definition = .MigratableJobDefinition~new("JOB-SUB-1", placement, "definition:sub", "PART", "OWNER", "OOREXX", "5.3-r13196", "rev-sub")
source = .JobNodePlacementLease~new("PLACE-S", "JOB-SUB-1", "NODE-A", "OWNER", 1, 1, 1000, 10000, "req", "cap", "obs", "1", "", "", "", 1, 0, "")
migration = .MigratableJobMigration~new("MIG-SUB-1", definition, source, 1100)
publisher = .MigratableJobTopicStatusPublisher~new(topics, .QueueMigrationStatusContract~DEFAULT_TOPIC, "mj-publisher", .false, .true)

/* Publish before QueueRexx subscribes: retained replay must initialise cache. */
call pubok publisher~publish(migration), "publish retained NEW"
subscriber = .QueueMigrationStatusSubscriber~new(manager, topics, "QRX.MIG.STATUS", "QRX.MIG.STATUS.SUB", "queuerexx-status")
call ok subscriber~wireJob("JOB-SUB-1"), "wire QueueRexx job subscription"
drain = subscriber~drain
if \drain~ok then call fail "late retained drain failed"
call eq 1, drain~accepted, "retained status accepted"
snapshot = subscriber~cache~latest("JOB-SUB-1")
if snapshot == .nil then call fail "retained snapshot missing"
call eq .MigratableJobMigrationState~NEW, snapshot~stateName, "retained NEW state"
call eq 0, snapshot~sequence, "retained initial sequence"

/* New revision arrives through the ordinary subscriber queue. */
if \migration~transition(.MigratableJobMigrationState~NEW, .MigratableJobMigrationState~PREPARING, 1200) then call fail "migration transition failed"
call pubok publisher~publish(migration), "publish PREPARING"
drain = subscriber~drain
call eq 1, drain~accepted, "new status accepted"
snapshot = subscriber~cache~latest("JOB-SUB-1")
call eq .MigratableJobMigrationState~PREPARING, snapshot~stateName, "updated PREPARING state"
call eq 1, snapshot~sequence, "updated sequence"

/* Redelivery with the same migration-local sequence is observation noise. */
call pubok publisher~publish(migration), "republish duplicate PREPARING"
drain = subscriber~drain
call eq 1, drain~stale, "duplicate sequence rejected as stale"
call eq 1, subscriber~cache~latest("JOB-SUB-1")~sequence, "cache sequence unchanged"

/* Different job must not enter the job-scoped queue. */
placement2 = .JobPlacementRequest~new("JOB-OTHER", requirement, "OWNER", 1000, 1000)
definition2 = .MigratableJobDefinition~new("JOB-OTHER", placement2, "definition:other", "PART", "OWNER", "OOREXX", "5.3-r13196", "rev-other")
source2 = .JobNodePlacementLease~new("PLACE-O", "JOB-OTHER", "NODE-B", "OWNER", 1, 1, 1000, 10000, "req", "cap", "obs", "1", "", "", "", 1, 0, "")
migration2 = .MigratableJobMigration~new("MIG-OTHER", definition2, source2, 1300)
call pubok publisher~publish(migration2), "publish nonmatching job"
depth = manager~depth("QRX.MIG.STATUS", "queuerexx-status")
call ok depth, "status queue depth"
call eq 0, depth~value["ready"], "job pattern excludes other job"

/* Health path consumes subscribed status, not local source PID inference. */
tmp = "/tmp/queuerexx_status_" || .DateTime~new~microseconds || ".job"
stream = .Stream~new(tmp)
ignore = stream~open("WRITE REPLACE")
stream~lineOut("JOB_ID='JOB-SUB-1'")
stream~lineOut("RUNNER_USED='direct'")
stream~lineOut("RUN_PID='999999'")
stream~lineOut("RUN_PGID='999999'")
stream~close
record = .QueueRecord~new(tmp, .QueueState~RUNNING, "/tmp")
observer = .QueueMigrationTopicAwareJobObserver~new(subscriber)
observation = observer~observe(record)
call eq .QueueJobObservation~UNKNOWN, observation~status, "subscribed migration defers local stale inference"
call eq .QueueMigrationTopicObservationProvider~PROVIDER_ID, observation~providerId, "topic provider owns status observation"
call sysrm tmp

say "PASS QueueRexx consumes Migratable Job v0.2.4 retained status through its own Queue Fabric subscriber queue"
exit 0

ok: procedure
  use arg op, label
  if op == .nil | \op~ok then do
    say "FAIL" label
    if op \== .nil then say op~code op~detail
    exit 1
  end
  return

pubok: procedure
  use arg op, label
  if op == .nil | \op~ok then do
    say "FAIL" label
    if op \== .nil then say op~code op~detail
    exit 1
  end
  return

eq: procedure
  use arg expected, actual, label
  if expected \== actual then do
    say "FAIL" label "expected=" expected "actual=" actual
    exit 1
  end
  return

fail: procedure
  use arg msg
  say "FAIL" msg
  exit 1

sysrm: procedure
  use arg path
  address system 'rm -f -- "' || path || '"'
  return

::requires "QueueRexxMigrationStatus.cls"
