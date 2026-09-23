parse arg directBridge compatBridge
if directBridge="" | compatBridge="" then raise syntax 88.900 array("direct and compatibility bridge paths required")
installed=.CryptoForeignRuntimeInstaller~install(directBridge,.nil,1000,"foreign.openssl.crypto",compatBridge)
payload='00610062ff00010203'x
expected='6b7f2d24560b2fc85dfb3d33882e5b6b4e88608c88e04bcd2c4e6cde6fd75640'
actual=.JobNodeDigestProvider~new~digest(payload)
if actual<>expected then call fail "JobNode digest mismatch"
e=.RuntimeImplementationSwitch~broker~lastEvidence
if e==.nil | e~outcomeCode<>"COMPLETED" | e~providerId<>"foreign.openssl.crypto" then call fail "JobNode digest did not use Foreign Runtime Crypto provider"
ledger=.MigratableJobProvenanceLedger~new
ledger~append("MIG-NATIVE","JOB-NATIVE","NATIVE_SHA","PREPARING","NODE-A","PLACE-A","",1000,"provider-probe")
e=.RuntimeImplementationSwitch~broker~lastEvidence
if e==.nil | e~outcomeCode<>"COMPLETED" | e~providerId<>"foreign.openssl.crypto" then call fail "migration provenance digest did not use Foreign Runtime Crypto provider"
installed["target"]~close
.RuntimeImplementationSwitch~reset
say "PASS JobNode/Migratable Job SHA-256 uses Crypto Foreign Runtime provider"
exit 0
fail: procedure
  parse arg m
  say "FAIL" m
  exit 1
::requires "MigratableJob.cls"
::requires "CryptoForeignRuntimeProvider.cls"
