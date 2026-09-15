service = .LogService~new("test-nosql")
scope = .Log~customerScope("CUSTOMER-77")
mem = .LogMemoryTarget~new("memory", scope)
service~addTarget(mem)
deployment = .LogDeploymentContext~new("WEB", "GB", "PUBLIC", "CUSTOMER-77", "PILOT", "point-semantic-77", "deployment-semantic-77", "route-semantic-77", "rollout-semantic-77")
rule = .LogRule~new("nosql-event", "demo", "DemoSubject", "work", -
  scope, scope, .Log~INFO, .nil, .array~of("memory"), .array~of(.Log~BODY), "", "", "CLASS", -
  "NOSQL-POLICY", "7.2", "policy-semantic-xyz", deployment)
service~addRule(rule)

subject = .DemoSubject~new
payload = .RichPayload~new("customer-77", .directory~new)
payload~details["reason"] = "structured"
log = service~loggerFor(subject, "work", .array~new, scope)
call assertTrue log~active, "manual binding becomes active for matching method rule"
call assertTrue log~log(.Log~WARN, payload), "structured event accepted"
call assertEq 1, mem~count, "one event stored"

event = mem~events[1]
call assertTrue event~payload == payload, "memory event retains payload identity"
call assertTrue event~payload~details == payload~details, "nested structured object retained"

adapter = .LogNoSQLAdapter~new(mem, "audit_")
engine = .ObjectDatabaseEngine~new
call assertTrue adapter~registerInto(engine), "registered live log object table"

raw = engine~selectAll("audit_events")
call assertEq .Error~SUCCESS, raw~status, "raw object table query succeeds"
call assertEq 1, raw~rows~items, "raw object table has one row"
call assertTrue raw~rows[1]~rawAt("event_object") == event, "NoSQL raw row retains original LogEvent identity"
call assertTrue raw~rows[1]~rawAt("payload") == payload, "NoSQL raw row retains rich payload identity"
call assertTrue raw~rows[1]~rawAt("source_scope_object") == scope, "NoSQL raw row retains source LogScope identity"
call assertTrue raw~rows[1]~rawAt("delivery_scope_object") == scope, "NoSQL raw row retains delivery LogScope identity"
call assertTrue raw~rows[1]~rawAt("deployment_context") == deployment, "NoSQL raw row retains structured deployment context identity"

sql = .NoSQLServerSQL~new(engine)
rs = sql~execute("SELECT event_id,level_name,source_scope,source_scope_id,source_domain_id,method_name,payload_class,policy_id,policy_version,policy_identity,deployment_service_id,deployment_cohort_id,deployment_route_identity,deployment_rollout_identity FROM audit_events WHERE level>=40 AND source_domain_id='CUSTOMER-77' AND deployment_cohort_id='PILOT'")
call assertEq .Error~SUCCESS, rs~status, "SQL metadata projection succeeds"
call assertEq 1, rs~rows~items, "SQL query selects event"
call assertEq "WARN", rs~rows[1]["level_name"], "severity queryable"
call assertEq "CUSTOMER", rs~rows[1]["source_scope"], "disclosure scope queryable"
call assertEq "CUSTOMER:CUSTOMER-77", rs~rows[1]["source_scope_id"], "structured scope id queryable"
call assertEq "CUSTOMER-77", rs~rows[1]["source_domain_id"], "domain id queryable"
call assertEq "WORK", rs~rows[1]["method_name"], "method queryable"
call assertEq "RICHPAYLOAD", rs~rows[1]["payload_class"]~translate, "payload type queryable without flattening payload"
call assertEq "NOSQL-POLICY", rs~rows[1]["policy_id"], "policy id queryable"
call assertEq "7.2", rs~rows[1]["policy_version"], "policy version queryable"
call assertEq "policy-semantic-xyz", rs~rows[1]["policy_identity"], "policy semantic identity queryable"
call assertEq "WEB", rs~rows[1]["deployment_service_id"], "deployment service queryable"
call assertEq "PILOT", rs~rows[1]["deployment_cohort_id"], "deployment cohort queryable"
call assertEq "route-semantic-77", rs~rows[1]["deployment_route_identity"], "stable deployment route identity queryable"
call assertEq "rollout-semantic-77", rs~rows[1]["deployment_rollout_identity"], "progressive rollout authority queryable"

say "NOSQL_SCOPE_OBJECT raw_scope=PASS domain_query=PASS policy_provenance=PASS deployment_context=PASS"
say "PASS test_nosql_object_table"
exit 0

assertTrue: procedure
  use strict arg actual, message
  if actual \= .true then raise syntax 88.900 array("assertTrue failed:" message)
  return
assertEq: procedure
  use strict arg expected, actual, message
  if expected \== actual then raise syntax 88.900 array("assertEq failed:" message "expected="expected "actual="actual)
  return

::class DemoSubject
::method work
  return .true
::class RichPayload
::attribute customerId get
::attribute details get
::method init
  expose customerId details
  use strict arg customerId, details
  customerId = customerId
  details = details

::requires "LoggingNoSQL.cls"
