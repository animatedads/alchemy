reg = .QueueProviderRegistry~builtins
sel = .QueueRunnerSelector~new(reg)

autoReq = .QueueJobRequirement~new("auto")
facts = .QueuePlatformFacts~new("linux", "alice", 1000, .true, .true)
d = sel~select(facts, autoReq)
call yes d~selected, "auto selected"
call eq d~provider~id, "systemd", "auto prefers available systemd"

facts2 = .QueuePlatformFacts~new("linux", "alice", 1000, .false, .true)
d = sel~select(facts2, autoReq)
call eq d~provider~id, "direct", "auto falls back direct"

foreignReq = .QueueJobRequirement~new("auto", "alice")
rootFacts = .QueuePlatformFacts~new("linux", "root", 0, .true, .true)
d = sel~select(rootFacts, foreignReq)
call eq d~provider~id, "direct", "root foreign user prefers direct"

explicitSystemd = .QueueJobRequirement~new("systemd", "alice")
d = sel~select(rootFacts, explicitSystemd)
call no d~selected, "explicit systemd foreign user fails"
call eq d~code, "SYSTEMD_FOREIGN_USER_NOT_USED", "explicit systemd failure code"

unknownReq = .QueueJobRequirement~new("something-new")
d = sel~select(facts, unknownReq)
call eq d~provider~id, "direct", "unknown token QueueBash compatibility fallback"
call yes d~warning \= "", "fallback warning"

say "PASS test_providers"
exit 0

eq:
  use arg actual, expected, label
  if actual \== expected then do; say "FAIL" label "expected=" expected "actual=" actual; exit 1; end
  return
yes:
  use arg v, label
  if \v then do; say "FAIL" label; exit 1; end
  return
no:
  use arg v, label
  if v then do; say "FAIL" label; exit 1; end
  return

::requires "../src/QueueRexxProviders.cls"
