service = .LogService~new("runtime-control")
mem = .LogMemoryTarget~new("memory", .Log~INTERNAL)
service~addTarget(mem)
rule = .LogRule~new("ui-rule", "web", "RuntimeSubject", "work", -
  .Log~INTERNAL, .Log~INTERNAL, .Log~WARN, .nil, .array~of("memory"), .array~of(.Log~BODY))
service~addRule(rule)
subject = .RuntimeSubject~new
reg = service~registerMethod(subject, "work", .Log~INTERNAL)

control = .LogRuntimeControl~new(service)
snap = control~snapshot
call assertEq 1, snap~serviceRows~items, "one service row"
call assertEq 1, snap~ruleRows~items, "one rule row"
call assertEq 1, snap~targetRows~items, "one target row"
call assertEq 1, snap~registrationRows~items, "one registration row"
call assertEq 1, snap~planRows~items, "one plan row"
call assertTrue snap~registrationRows[1]~instrumented, "matching registration physically instrumented"
call assertTrue snap~ruleRows[1]~operational, "rule is operational"
call assertTrue snap~ruleRows[1]~ruleObject == rule, "status retains rule object identity"
call assertTrue snap~targetRows[1]~targetObject == mem, "status retains target object identity"

adapter = .LogRuntimeNoSQLAdapter~new(service, "ctl_")
engine = .ObjectDatabaseEngine~new
call assertTrue adapter~registerInto(engine), "runtime control tables registered"

rs = .NoSQLServerSQL~new(engine)~execute("SELECT rule_id,class_name,method_name,source_scope_id,operational FROM ctl_rules WHERE rule_id='ui-rule'")
call assertEq .Error~SUCCESS, rs~status, "rule status query succeeds"
call assertEq 1, rs~rows~items, "one queried rule"
call assertEq "RUNTIMESUBJECT", rs~rows[1]["class_name"], "class is queryable"
call assertEq "WORK", rs~rows[1]["method_name"], "method is queryable"
call assertEq "INTERNAL", rs~rows[1]["source_scope_id"], "scope is queryable"

raw = engine~selectAll("ctl_rules")
call assertTrue raw~rows[1]~rawAt("rule_object") == rule, "NoSQL raw rule remains the actual LogRule"

call assertTrue control~disableRule("ui-rule", "incident suppression", "operator-17"), "rule disabled through control object"
call assertFalse service~ruleOperational("ui-rule"), "disabled rule not operational"
call assertEq "", reg~providerId, "disabled last rule physically removes method instrumentation"
call assertEq 1, service~controlEvents~items, "control change journalled"
ev = service~controlEvents[1]
call assertEq "DISABLE", ev~operation, "control operation structured"
call assertEq "RULE", ev~subjectKind, "control subject structured"
call assertEq "ui-rule", ev~subjectId, "control subject id retained"
call assertEq "incident suppression", ev~reason, "control reason retained"
call assertEq "operator-17", ev~actorId, "control actor identity retained"

/* The adapter's query() creates a fresh control-plane snapshot, so callers do
 * not pay mutation hooks in the LogService merely to keep SQL views current. */
rs = adapter~query("SELECT rule_id,enabled,operational FROM ctl_rules WHERE rule_id='ui-rule'")
call assertEq .Error~SUCCESS, rs~status, "fresh rule query succeeds"
call assertEq 1, rs~rows~items, "disabled rule remains inspectable"
call assertEq "0", rs~rows[1]["enabled"]~string, "rule disabled state queryable"
call assertEq "0", rs~rows[1]["operational"]~string, "rule operational state queryable"

/* SQL projection is intentionally read-only.  Operational mutation must go
 * through LogRuntimeControl so plan rebuild/unwrapping and control journalling
 * cannot be bypassed by a table setter. */
engine2 = .ObjectDatabaseEngine~new
ignore = adapter~registerInto(engine2)
updateRs = .NoSQLServerSQL~new(engine2)~execute("UPDATE ctl_rules SET enabled='1' WHERE rule_id='ui-rule'")
call assertTrue updateRs~status \= .Error~SUCCESS, "runtime SQL status projection is read-only"
call assertFalse rule~isEnabled, "failed SQL mutation cannot change rule"

rs = adapter~query("SELECT operation,subject_kind,subject_id,reason,actor_id FROM ctl_control_events WHERE subject_id='ui-rule'")
call assertEq .Error~SUCCESS, rs~status, "control journal query succeeds"
call assertEq 1, rs~rows~items, "one control event query result"
call assertEq "incident suppression", rs~rows[1]["reason"], "journal reason queryable"

call assertTrue control~enableRule("ui-rule", "incident cleared", "operator-17"), "rule re-enabled"
call assertTrue reg~providerId \= "", "method instrumentation restored"
call assertEq 2, service~controlEvents~items, "enable also journalled"

call assertTrue control~disableTarget("memory", "queue maintenance"), "target disabled"
call assertEq "", reg~providerId, "no active delivery means method unwrapped"
call assertTrue control~enableTarget("memory", "queue restored"), "target enabled"
call assertTrue reg~providerId \= "", "target restore re-arms method"

call assertTrue control~disableService("release window"), "service disabled"
call assertEq "", reg~providerId, "service off unwrapped method"
call assertTrue control~enableService("release complete"), "service enabled"
call assertTrue reg~providerId \= "", "service enable restores applicable instrumentation"

say "RUNTIME_CONTROL_NOSQL rules=PASS targets=PASS registrations=PASS plans=PASS controls=PASS raw_objects=PASS"
say "PASS test_runtime_control_nosql"
exit 0

assertTrue: procedure
  use strict arg actual, message
  if actual \= .true then raise syntax 88.900 array("assertTrue failed:" message)
  return
assertFalse: procedure
  use strict arg actual, message
  if actual \= .false then raise syntax 88.900 array("assertFalse failed:" message)
  return
assertEq: procedure
  use strict arg expected, actual, message
  if expected \== actual then raise syntax 88.900 array("assertEq failed:" message "expected="expected "actual="actual)
  return

::class RuntimeSubject inherit LogInstrumentationParticipant
::method work
  return "OK"

::requires "LoggingControl.cls"
