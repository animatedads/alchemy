/* Runtime incident logging for a lightweight/disposable object.
 * The rule is registered dormant, so no proxy exists until the operator arms
 * the rule. Runtime status is queryable through NoSQLServer object tables.
 */
service = .LogService~new("website-logging")
memory = .LogMemoryTarget~new("memory", .Log~INTERNAL)
service~addTarget(memory)

condition = .LogConditionAny~new(.array~of( -
  .LogConditionArgNil~new(1), -
  .LogConditionArgPathContains~new(1, -
    .array~of("CUSTOMER", "CUSTOMERNAME"), "%';DROP", .false)))

rule = .LogRule~new("panel-incident", "website", "WebsiteUI", "generateCustomerPanel", -
  .Log~INTERNAL, .Log~INTERNAL, .Log~DEBUG, condition, -
  .array~of("memory"), .array~of(.Log~ENTRY, .Log~EXIT))
service~addDormantRule(rule)

ui = .WebsiteUI~new
say "inactive_proxy_created=" || (service~proxyIfRequired(ui) \== ui)

control = .LogRuntimeControl~new(service)
control~enableRule("panel-incident", "investigating malformed customer session", "ops-console")
wrapped = service~proxyIfRequired(ui)

normal = .Session~new(.Customer~new("Alice"))
attack = .Session~new(.Customer~new("x%';DROP TABLE customers"))
ignore = wrapped~generateCustomerPanel(normal)
ignore = wrapped~generateCustomerPanel(attack)

adapter = .LogRuntimeNoSQLAdapter~new(service, "log_")
result = adapter~query("SELECT rule_id,enabled,operational,class_name,method_name FROM log_rules")
say "runtime_rules=" || result~rows~items

control~disableRule("panel-incident", "diagnosis complete", "ops-console")
say "after_disable_proxy_created=" || (service~proxyIfRequired(ui) \== ui)

::class WebsiteUI
::method generateCustomerPanel
  use strict arg session
  return "panel"

::class Session
::attribute customer get
::method init
  expose customer
  use strict arg value
  customer = value

::class Customer
::attribute customerName get
::method init
  expose customerName
  use strict arg value
  customerName = value

::requires "LoggingControl.cls"
