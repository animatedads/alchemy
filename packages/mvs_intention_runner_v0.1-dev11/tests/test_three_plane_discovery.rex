/* Proves three independent authorities are safely discovered before proposal,
 * contradictions are retained, and live scope change alters resolution. */
backend = .MvsThreePlaneFixtureBackend~new(1)
runner = .MvsIntentionRunner~new("ED209Z", backend)
d = runner~input("find the last failed compile for Fred")
if d~status <> "READY" then call fail "first decision not READY"
if runner~snapshot~probeCount <> 17 then call fail "expected 17 safe probes, got" runner~snapshot~probeCount
if d~proposal~slot("JOB_ID")~value <> "JOB00140" then call fail "expected JOB00140"
if runner~snapshot~factsBySource("MVS_ALCHEMY")~items = 0 then call fail "missing MVS facts"
if runner~snapshot~factsBySource("TERMINAL_MACHINE")~items = 0 then call fail "missing terminal facts"
if runner~snapshot~factsBySource("HERCULES_SERVICES")~items = 0 then call fail "missing Hercules facts"
if runner~snapshot~terminalState <> "TSO_READY" then call fail "terminal authority not projected"
if runner~snapshot~capability("HERCULES_GUEST_STATE") <> "RUNNING" then call fail "Hercules authority not retained"

/* Contradiction must survive rather than being collapsed into JES/MVS truth. */
backend~hercules~guestState = "STOPPED"
d = runner~input("what system am I on")
if d~status <> "READY" then call fail "identity not READY with contradictory Hercules evidence"
if runner~snapshot~jesState <> "READY" then call fail "MVS JES evidence was collapsed"
if runner~snapshot~capability("HERCULES_GUEST_STATE") <> "STOPPED" then call fail "contradictory Hercules evidence lost"

/* Same English, changed discovered MVS job scope. */
backend~mvs~generation = 2
d = runner~input("find the last failed compile for Fred")
if d~proposal~slot("JOB_ID")~value <> "JOB00144" then call fail "scope refresh did not select JOB00144"
say "PASS three-plane discovery, contradiction retention and scope refresh"
exit 0

fail:
  say "FAIL" arg(1) arg(2)
  exit 1

::requires "MvsIntention.cls"
