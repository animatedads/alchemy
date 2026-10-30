parse source . . here
root = "/mnt/data/mini_notes_batch_persistence_test"
address system "rm -rf " root
app = .MiniNotesApp~new(root)
app~beginBatch
spec=.Directory~new; spec["NAME"]="Value"; spec["LABEL"]="Value"; spec["TYPE"]="TEXT"
app~installUserFormat("Batch Probe", .array~of(spec))
cols=.Array~new; c=.Directory~new; c["LABEL"]="Value"; c["BINDING"]="Value"; cols~append(c)
app~installReportDefinition("Batch Probe Report", "Batch Probe", cols, .Array~new)
if app~batchDepth <> 1 then call fail "batch depth not active"
probe=.MiniNotesApp~new(root)
if probe~node~documentDefinition("Batch Probe/1") \== .nil then call fail "batch leaked to persistence before endBatch"
if probe~reportDefinition("Batch Probe Report") \== .nil then call fail "report leaked to persistence before endBatch"
if \app~endBatch then call fail "endBatch persistence failed"
if app~batchDepth <> 0 then call fail "batch depth did not close"
probe=.MiniNotesApp~new(root)
if probe~node~documentDefinition("Batch Probe/1") == .nil then call fail "format missing after batch commit"
if probe~reportDefinition("Batch Probe Report") == .nil then call fail "report missing after batch commit"
app~beginBatch
app~beginBatch
app~installReportDefinition("Nested Batch Report", "Batch Probe", cols, .Array~new)
if \app~endBatch then call fail "inner endBatch failed"
probe=.MiniNotesApp~new(root)
if probe~reportDefinition("Nested Batch Report") \== .nil then call fail "nested batch committed too early"
if \app~endBatch then call fail "outer endBatch failed"
probe=.MiniNotesApp~new(root)
if probe~reportDefinition("Nested Batch Report") == .nil then call fail "nested batch did not commit"
say "PASS Mini NotNotes batch persistence / nested commit"
exit 0
fail: procedure
  parse arg m
  say "FAIL" m
  exit 1
::requires "MiniNotesApp.cls"
