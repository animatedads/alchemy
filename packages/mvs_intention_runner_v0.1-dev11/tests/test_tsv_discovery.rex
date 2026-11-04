parse source . . here
root = filespec("location", here)
dir = root || "/fixtures/live-feed"
backend = .MvsDiscoveryDirectoryBackend~new(dir)
runner = .MvsIntentionRunner~new("ED209Z", backend)
d = runner~input("find the last failed compile for Fred")
if d~status <> "READY" then do; say "FAIL TSV decision" d~status; exit 1; end
if d~proposal~slot("JOB_ID")~value <> "JOB00999" then do; say "FAIL TSV job"; exit 1; end
if runner~snapshot~probeCount <> 6 then do; say "FAIL TSV probes" runner~snapshot~probeCount; exit 1; end
if runner~snapshot~terminalState <> "TSO_READY" then do; say "FAIL TSV terminal"; exit 1; end
if runner~snapshot~capability("HERCULES_CONTROL_STATE") <> "REACHABLE" then do; say "FAIL TSV Hercules"; exit 1; end
say "PASS provider-neutral TSV discovery feed"
exit 0
::requires "MvsIntention.cls"
