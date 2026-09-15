call eq .QueueState~RUNNING, 3, "running state constant"
call eq .QueueState~name(.QueueState~RUNNING), "running", "running boundary name"
call eq .QueueJobObservation~LIVE, 1, "live observation constant"

now = .DateTime~fromIsoDate("2026-09-13T13:00:10.000000", 0)
clock = .FakeClock~new(now)
call eq .QueueTime~ageSeconds("2026-09-13T14:00:00+01:00", now), 10, "ooRexx DateTime timezone age"

root = "health-fixture-" || random(100000, 999999)
address system "rm -rf " || root
address system "mkdir -p " || root || "/pending/p0999999990 " || root || "/running " || root || "/paused " || root || "/done " || root || "/failed " || root || "/pol_blocked " || root || "/interrupted " || root || "/cancelled " || root || "/deleted " || root || "/logs " || root || "/workers " || root || "/outputs " || root || "/streams"

call writeJob root || "/running/direct-live.job", "direct-live", "direct-live", "RUNNER_USED=direct", "RUN_PID=123", "RUN_STARTED_AT=2026-09-13T13:00:00+00:00"
call writeJob root || "/running/direct-dead.job", "direct-dead", "direct-dead", "RUNNER_USED=direct", "RUN_PID=999", "RUN_STARTED_AT=2026-09-13T13:00:00+00:00"
call writeJob root || "/running/launch-pending.job", "launch-pending", "launch-pending", "RUNNER_USED=direct", "SUBMITTED_AT=2026-09-13T13:00:00+00:00", ""
call writeJob root || "/running/launch-unknown.job", "launch-unknown", "launch-unknown", "RUNNER_USED=direct", "SUBMITTED_AT=2026-09-13T12:50:00+00:00", ""
call writeJob root || "/running/systemd-live.job", "systemd-live", "systemd-live", "RUNNER_USED=systemd", "SYSTEMD_UNIT=queue-live.service", "RUN_PID=999"
call writeJob root || "/running/systemd-dead.job", "systemd-dead", "systemd-dead", "RUNNER_USED=systemd", "SYSTEMD_UNIT=queue-dead.service", "RUN_PID=123"
call writeJob root || "/running/systemd-unknown.job", "systemd-unknown", "systemd-unknown", "RUNNER_USED=systemd", "SYSTEMD_UNIT=queue-unknown.service", "RUN_PID=123"
/* duplicate QID is diagnosis only in dev2 */
call writeJob root || "/interrupted/direct-live.job", "direct-live", "direct-live", "INTERRUPTED_REASON=stale-running-detected-by-health", "", ""

livePids = .Directory~new; livePids["123"] = .true
livePgids = .Directory~new
processProbe = .FakeProcessProbe~new(livePids, livePgids)
systemdProbe = .FakeSystemdProbe~new
systemdProbe~set("queue-live.service", .true, "active", "running", "456")
systemdProbe~set("queue-dead.service", .true, "inactive", "dead", "0")
systemdProbe~set("queue-unknown.service", .false, "", "", "")

reg = .QueueProviderRegistry~new
reg~register(.QueueProviderCategory~RUNNER, .DirectRunnerProvider~new(processProbe, clock, 300))
reg~register(.QueueProviderCategory~RUNNER, .SystemdRunnerProvider~new(systemdProbe, processProbe, clock, 300))
observer = .QueueJobObserver~new(reg)
store = .QueueStateStore~new(root)

call obsEq observer, store~findOne("direct-live"), .QueueJobObservation~LIVE, "direct pid live"
call obsEq observer, store~findOne("direct-dead"), .QueueJobObservation~DEAD, "direct dead"
call obsEq observer, store~findOne("launch-pending"), .QueueJobObservation~LAUNCH_PENDING, "launch pending"
call obsEq observer, store~findOne("launch-unknown"), .QueueJobObservation~UNKNOWN, "launch metadata unknown"
call obsEq observer, store~findOne("systemd-live"), .QueueJobObservation~LIVE, "systemd mainpid authority"
call obsEq observer, store~findOne("systemd-dead"), .QueueJobObservation~DEAD, "systemd dead authority"
call obsEq observer, store~findOne("systemd-unknown"), .QueueJobObservation~UNKNOWN, "systemd unknown defers"

report = .QueueHealthScanner~new(store, observer, 1000)~scan
call no report~ok, "health sees errors"
call yes report~errors >= 3, "health counts stale direct/systemd plus duplicate"
json = .QueueSerialization~toJson(report~asDirectory)
parsed = .QueueSerialization~fromJson(json)
call eq parsed["schema"], .QueueSchema~HEALTH, "health schema"
call eq parsed["fix"], .JSONBoolean~false, "health is read-only"

address system "rm -rf " || root
say "PASS test_health"
exit 0

writeJob:
  use arg path, qid, name, extra1, extra2, extra3
  call lineout path, "JOB_ID=" || qid
  call lineout path, "JOB_NAME=" || name
  call lineout path, "PRIORITY=10"
  call lineout path, "COMMAND=(/bin/true)"
  if extra1 \= "" then call lineout path, extra1
  if extra2 \= "" then call lineout path, extra2
  if extra3 \= "" then call lineout path, extra3
  call lineout path
  return

obsEq:
  use arg observer, record, expected, label
  if record == .nil then do; say "FAIL" label "record missing"; exit 1; end
  actual = observer~observe(record)
  if actual~status \== expected then do
    say "FAIL" label "expected=" expected "actual=" actual~status actual~statusName actual~code
    exit 1
  end
  return

eq:
  use arg actual, expected, label
  if actual \== expected then do; say "FAIL" label "expected=" expected "actual=" actual; exit 1; end
  return
yes:
  use arg value, label
  if \value then do; say "FAIL" label; exit 1; end
  return
no:
  use arg value, label
  if value then do; say "FAIL" label; exit 1; end
  return

::class FakeClock public subclass QueueClock
::attribute fixed get
::method init
  expose fixed
  use arg fixedArg
  fixed = fixedArg
::method now
  expose fixed
  return fixed

::class FakeProcessProbe public subclass QueueProcessProbe
::attribute livePids get
::attribute livePgids get
::method init
  expose livePids livePgids
  use arg pidsArg, pgidsArg
  livePids = pidsArg; livePgids = pgidsArg
::method pidAlive
  expose livePids
  use arg pid
  return livePids~hasIndex(pid~string)
::method pgidAlive
  expose livePgids
  use arg pgid
  return livePgids~hasIndex(pgid~string)

::class FakeSystemdProbe public subclass QueueSystemdProbe
::method init
  expose statuses
  statuses = .Directory~new
::method set
  expose statuses
  use arg unit, known, active, sub, mainPid
  statuses[unit] = .QueueSystemdStatus~new(known, active, sub, mainPid)
  return self
::method status
  expose statuses
  use arg unit
  if statuses~hasIndex(unit) then return statuses[unit]
  return .QueueSystemdStatus~new

::requires "../src/QueueRexxHealth.cls"
::requires "../src/QueueRexxSerialization.cls"
