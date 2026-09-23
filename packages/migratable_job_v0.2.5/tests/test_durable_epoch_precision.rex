/* Durable timestamps must survive append/reload without ooRexx DIGITS 9 rounding. */
call mj_test_install_native_crypto
numeric digits 30
parse source . . testFile
root=filespec("LOCATION",testFile)||"/tmp-epoch-precision"
call SysFileDelete root||".journal"
call SysFileDelete root||".events"

startMs=1789000000123
updateMs=1789000000456
provenanceMs=1789000000789

req=.JobNodeRequirement~new(.array~of("GB"))
placement=.JobPlacementRequest~new("JOB-EPOCH-DURABLE",req,"OWNER",1,1)
lease=.JobNodePlacementLease~new("PLACE-EPOCH","JOB-EPOCH-DURABLE","NODE-A","OWNER",1,1,1000,9999999999999,"req","cap","capacity","1","","","",1,0,"")
def=.MigratableJobDefinition~new("JOB-EPOCH-DURABLE",placement,"definition:epoch-durable","PART-E","OWNER")
m=.MigratableJobMigration~new("MIG-EPOCH-DURABLE",def,lease,startMs)
if m~startedEpochMs<>startMs then call fail "initial started epoch rounded"
if \m~transition(.MigratableJobMigrationState~NEW,.MigratableJobMigrationState~PREPARING,updateMs) then call fail "transition failed"
if m~updatedEpochMs<>updateMs then call fail "transition epoch rounded"

j=.MigratableJobDurableJournal~new(root||".journal")
if \j~append(m) then call fail "journal append failed"
snap=.MigratableJobDurableJournal~new(root||".journal")~loadLatest(def)
if \snap~valid then call fail "journal reload failed: "||snap~code
m2=snap~migration
if m2~startedEpochMs<>startMs then call fail "durable started epoch changed: "||m2~startedEpochMs
if m2~updatedEpochMs<>updateMs then call fail "durable updated epoch changed: "||m2~updatedEpochMs

ledger=.MigratableJobProvenanceLedger~new(root||".events")
if \ledger~append("MIG-EPOCH-DURABLE","JOB-EPOCH-DURABLE","PRECISION","PREPARING","NODE-A","PLACE-EPOCH","",provenanceMs,"exact epoch") then call fail "provenance append failed"
ledger2=.MigratableJobProvenanceLedger~new(root||".events")
if ledger2~events~items<>1 then call fail "provenance reload count"
e=ledger2~events[1]
if e~epochMs<>provenanceMs then call fail "provenance epoch changed: "||e~epochMs

say "PASS durable journal and provenance preserve exact epoch milliseconds"
exit 0

fail: procedure
  parse arg m
  say "FAIL" m
  exit 1

::requires "MigratableJobDurable.cls"
::requires "TestForeignCryptoBootstrap.cls"
