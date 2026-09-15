call must .QueueRexxVersion~version == "0.1-dev12", "dev12 version"
registry = .QueueMigrationRegistry~new
cache = .QueueMigrationStatusCache~new
projector = .QueueMigrationStatusProjector~new(registry, cache)

p0 = projector~project("Q-PROJ")
call eq p0~relation, .QueueMigrationProjectionRelation~NONE, "no evidence"

m0 = .FakeMigration~new("Q-PROJ", "M-1", .MigratableJobMigrationState~NEW, 0, 1000, 1000)
call must registry~register(m0), "register durable"
p1 = projector~project("Q-PROJ")
call eq p1~relation, .QueueMigrationProjectionRelation~DURABLE_ONLY, "durable only"

payload = statusPayload("Q-PROJ", "M-1", .MigratableJobMigrationState~NEW, 0, 1000, 1000)
call must cache~acceptPayload(payload)~accepted, "accept in-sync status"
p2 = projector~project("Q-PROJ")
call eq p2~relation, .QueueMigrationProjectionRelation~IN_SYNC, "in sync"

d = p2~asDirectory
call must d["durable"]["authoritative"] == .JSONBoolean~true, "durable authority flag"
call must d["live"]["authoritative"] == .JSONBoolean~false, "live observation flag"
call eq d["schema"], .QueueSchema~MIGRATION_STATUS_PROJECTION, "projection schema"

m2 = .FakeMigration~new("Q-PROJ", "M-1", .MigratableJobMigrationState~PREPARING, 2, 1000, 1200)
call must registry~register(m2), "register newer durable"
p3 = projector~project("Q-PROJ")
call eq p3~relation, .QueueMigrationProjectionRelation~DURABLE_AHEAD, "durable ahead"

payload2 = statusPayload("Q-PROJ", "M-1", .MigratableJobMigrationState~TRANSFERRING, 3, 1000, 1300)
call must cache~acceptPayload(payload2)~accepted, "accept live ahead"
p4 = projector~project("Q-PROJ")
call eq p4~relation, .QueueMigrationProjectionRelation~LIVE_AHEAD, "live ahead"

m3 = .FakeMigration~new("Q-PROJ", "M-1", .MigratableJobMigrationState~READY, 3, 1000, 1300)
call must registry~register(m3), "register equal-sequence conflicting durable"
p5 = projector~project("Q-PROJ")
call eq p5~relation, .QueueMigrationProjectionRelation~STATE_CONFLICT, "state conflict"

payload3 = statusPayload("Q-PROJ", "M-2", .MigratableJobMigrationState~NEW, 1, 2000, 2000)
call must cache~acceptPayload(payload3)~accepted, "accept newer migration id"
p6 = projector~project("Q-PROJ")
call eq p6~relation, .QueueMigrationProjectionRelation~MIGRATION_MISMATCH, "migration mismatch"

json = .QueueSerialization~toJson(p6~asDirectory)
call must json~pos('"schema":"queuerexx.migration_status_projection.v1"') > 0, "json schema rendered via .JSON"
call must json~pos('"authoritative":false') > 0, "live authority rendered false"

say "PASS status projection"
exit 0

statusPayload:
  use arg jobId, migrationId, stateName, sequence, started, updated
  x = .Directory~new
  x["schema"] = .QueueMigrationStatusContract~SCHEMA
  x["jobId"] = jobId
  x["migrationId"] = migrationId
  x["state"] = stateName
  x["sequence"] = sequence
  x["startedEpochMs"] = started
  x["updatedEpochMs"] = updated
  return x

must:
  use arg condition, message
  if \condition then do; say "FAIL" message; exit 1; end
  return

eq:
  use arg actual, expected, message
  if actual \== expected then do; say "FAIL" message "expected=" expected "actual=" actual; exit 1; end
  return

::class FakeDefinition
::attribute jobId get
::method init
  expose jobId
  use strict arg jobIdArg
  jobId = jobIdArg~string

::class FakeLease
::attribute nodeId get
::method init
  expose nodeId
  use strict arg nodeArg
  nodeId = nodeArg~string

::class FakeMigration
::attribute migrationId get
::attribute definition get
::attribute sourceLease get
::attribute destinationLease get
::attribute state get
::attribute resumeState get
::attribute checkpointManifest get
::attribute failureCode get
::attribute failureDetail get
::attribute startedEpochMs get
::attribute updatedEpochMs get
::attribute sourceFenced get
::attribute sourceAdmissionReleased get
::attribute destinationResumed get
::attribute executionRef get
::attribute sequence get
::method init
  expose migrationId definition sourceLease destinationLease state resumeState checkpointManifest failureCode failureDetail startedEpochMs updatedEpochMs sourceFenced sourceAdmissionReleased destinationResumed executionRef sequence
  use strict arg jobIdArg, migrationIdArg, stateArg, sequenceArg, startedArg, updatedArg
  migrationId = migrationIdArg~string
  definition = .FakeDefinition~new(jobIdArg)
  sourceLease = .FakeLease~new("node-source")
  destinationLease = .nil
  state = stateArg~string
  resumeState = ""
  checkpointManifest = .nil
  failureCode = ""
  failureDetail = ""
  startedEpochMs = startedArg + 0
  updatedEpochMs = updatedArg + 0
  sourceFenced = .false
  sourceAdmissionReleased = .false
  destinationResumed = .false
  executionRef = ""
  sequence = sequenceArg + 0

::requires "QueueRexxSerialization.cls"
::requires "QueueRexxStatusProjection.cls"
