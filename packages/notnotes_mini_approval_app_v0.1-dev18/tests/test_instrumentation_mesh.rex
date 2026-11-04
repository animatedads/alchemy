root = value("MININOTES_TEST_ROOT",, "ENVIRONMENT")
if root = "" then root = directory() || "/tmp-instrumentation-" || time("S")
address system 'rm -rf "' || root || '"'
app = .MiniNotesApp~new(root)
identity = .InstrumentationCodec~identity("alchemy", "notnotes", "mini-dev15", "test-node", "", "APPLICATION")
source = .MiniNotesInstrumentationSource~new(app, identity)

dbIdentity = .InstrumentationCodec~identity("alchemy", "nosqlserver", "mininotes-db", "test-node", "", "DATABASE")
dbSource = .NoSQLServerInstrumentationSource~new(dbIdentity)
app~persistence~database~instrumentation = dbSource

app~seedFive
sql = .NoSQLServerSQL~new(app~persistence~database)
queryResult = sql~execute("SELECT doc_key FROM documents ORDER BY doc_key")
if queryResult~status \= .Error~SUCCESS then call fail "instrumented NoSQL query failed"
ignore = app~query("purchase")
fields = .Array~new
spec = .Directory~new
spec["NAME"] = "Subject"
spec["LABEL"] = "Subject"
spec["TYPE"] = "TEXT"
fields~append(spec)
ignore = app~installUserFormat("Telemetry Note", fields)
values = .Directory~new
values["Subject"] = "instrumentation acceptance"
note = app~createUserDocument("Telemetry Note", fields, values)
ignore = app~select(note~DocKey)
if app~submitSelected("instrumentation acceptance") <> "PENDING APPROVAL" then call fail "submit did not enter pending approval"
if app~decideSelected("APPROVE", "instrumentation acceptance") <> "APPROVED" then call fail "approval did not complete"

snapshot = source~snapshot("2026-10-08T10:00:00Z")
if snapshot["schema"] <> "instrumentation.snapshot/1" then call fail "wrong snapshot schema"
if snapshot["identity"]["service_id"] <> "notnotes" then call fail "wrong service identity"
if metric(snapshot, "notnotes.documents.total") < 5 then call fail "document gauge missing"
if metric(snapshot, "notnotes.workflow.submitted_total") <> 1 then call fail "submit counter missing"
if metric(snapshot, "notnotes.workflow.approved_total") <> 1 then call fail "approved counter missing"
if metric(snapshot, "notnotes.query.completed_total") <> 1 then call fail "query counter missing"
if metric(snapshot, "notnotes.persistence.completed_total") < 1 then call fail "persistence counter missing"
if metric(snapshot, "notnotes.documents.approved") < 1 then call fail "approved gauge missing"

dbSnapshot = dbSource~snapshot("2026-10-08T10:00:00Z")
if dbSnapshot["identity"]["service_id"] <> "nosqlserver" then call fail "database identity mixed into NotNotes source"
if metric(dbSnapshot, "database.query.completed_total") < 1 then call fail "NoSQL query telemetry missing"
if hasMetric(snapshot, "database.query.completed_total") then call fail "NotNotes duplicated database telemetry"
if hasMetric(dbSnapshot, "notnotes.documents.total") then call fail "database source duplicated NotNotes telemetry"

/* Dev3 continuous publication path: register both independent sources and
 * publish them atomically through the common collector seam. */
registry = .InstrumentationRegistry~new
registry~register("notnotes", source)
registry~register("nosqlserver", dbSource)
service = .InstrumentationService~new(registry)
collector = .InstrumentationCollector~new(8)
collectorService = .InstrumentationCollectorService~new(collector)
transport = .InstrumentationLocalCollectorTransport~new(collectorService, "notnotes-test")
publisher = .InstrumentationPublisher~new("notnotes-dev15", service, transport, "collector")
published = publisher~publish("2026-10-08T10:01:00Z")
if \published~ok then call fail "continuous publication failed"
latest = collector~latest
if latest~items <> 2 then call fail "collector did not retain both service snapshots"
notNotesRef = snapshot["semantic_ref"]
series = collector~series(notNotesRef, "notnotes.documents.total")
if series~items <> 1 then call fail "NotNotes document series missing from collector"
if series[1]["value"] < 5 then call fail "NotNotes document series value incorrect"

do sample over snapshot["samples"]
  dims = sample["dimensions"]
  if dims \== .nil then do key over dims
    if dims[key]~string~pos("GPU build server") > 0 then call fail "business data leaked into metric dimensions"
  end
end

say "PASS Mini NotNotes instrumentation mesh / independent NoSQL telemetry"
address system 'rm -rf "' || root || '"'
exit 0

metric: procedure
  use arg snapshot, wanted
  do sample over snapshot["samples"]
    if sample["name"] = wanted then return sample["value"]
  end
  return 0

hasMetric: procedure
  use arg snapshot, wanted
  do sample over snapshot["samples"]
    if sample["name"] = wanted then return .true
  end
  return .false

fail: procedure
  use arg message
  say "FAIL:" message
  exit 1

::requires "src/MiniNotesApp.cls"
::requires "src/MiniNotesInstrumentation.cls"
::requires "vendor/nosql/NoSQLServerInstrumentation.cls"
