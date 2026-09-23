parse source . . testFile
root=filespec("LOCATION",testFile)||"/tmp-starter-layout"
address system "/bin/rm -rf -- '"||root||"'"
l=.MigratableJobStartLayout~new(root,"../job/unsafe","part/../unsafe")
if \l~jobRoot~startsWith(root||"/job-") then call fail "job root escaped"
if l~jobRoot~pos("../")>0 then call fail "raw traversal survived"
address system "/usr/bin/test -d '"||l~jobRoot||"'"
if rc<>0 then call fail "job root not created"
address system "/usr/bin/test -d '"||l~handoffRoot||"'"
if rc<>0 then call fail "handoff root not created"
if l~migrationJournal<>l~jobRoot||"/migration.journal" then call fail "journal path"
if l~provenanceLedger<>l~jobRoot||"/provenance.events" then call fail "provenance path"
if l~startReceipts<>l~jobRoot||"/start.receipts" then call fail "receipt path"
say "PASS standard starter durable layout safely encodes job and partition identifiers"
exit 0
fail: procedure
 parse arg m
 say "FAIL" m
 exit 1
::requires "MigratableJobStarter.cls"
