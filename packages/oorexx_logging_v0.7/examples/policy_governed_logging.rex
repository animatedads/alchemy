/* Effective-dated logging policy: selective rule, then reviewed OFF policy. */
now = .DateTime~new
cut = now + .TimeSpan~new(0,0,30,0,0)

condition = .LogConditionAny~new(.array~of( -
  .LogConditionArgNil~new(1), -
  .LogConditionArgPathContains~new(1, .array~of("CUSTOMER", "CUSTOMERNAME"), "%';DROP", .false)))

spec = .LogRuleSpec~new("website-panel-suspicious", "website", "WebsiteUI", "generateCustomerPanel", -
  .Log~INTERNAL, .Log~INTERNAL, .Log~DEBUG, condition, .array~of("memory"), -
  .array~of(.Log~ENTRY, .Log~EXIT, .Log~ERROR_POINT))

selective = .LogRuleSetPolicy~new("WEBSITE-LOGGING", "1.0", .array~of(spec), now, cut, "OPS", "SECURITY")~seal
offPolicy = .LogRuleSetPolicy~new("WEBSITE-LOGGING", "2.0", .array~new, cut, .nil, "OPS", "SECURITY", "1.0")~seal

catalog = .LogPolicyCatalog~new
ignore = catalog~publish(selective)
ignore = catalog~publish(offPolicy)

service = .LogService~new("website-log")
memory = .LogMemoryTarget~new("memory", .Log~INTERNAL)
service~addTarget(memory)
ui = .WebsiteUI~new
service~registerMethod(ui, "generateCustomerPanel", .Log~INTERNAL)

binding = .LogPolicyBinding~new(service, catalog, "WEBSITE-LOGGING")
ignore = binding~activate(now)
say "active logging policy:" binding~activeVersion
say "next policy boundary:" binding~nextTransition

ignore = ui~generateCustomerPanel(.Session~new(.Customer~new("ordinary")))
ignore = ui~generateCustomerPanel(.Session~new(.Customer~new("Acme %';DROP")))
say "events after selective policy:" memory~count

/* A host lifecycle/scheduler invokes activation at the effective boundary. */
ignore = binding~activate(cut)
say "active logging policy:" binding~activeVersion
say "instrumented methods after OFF policy:" service~metrics["instrumented_methods"]

::class Customer
::attribute customerName get
::method init
  expose customerName
  use strict arg customerName
  customerName = customerName

::class Session
::attribute customer get
::method init
  expose customer
  use strict arg customer
  customer = customer

::class WebsiteUI inherit LogInstrumentationParticipant
::method generateCustomerPanel unguarded
  use arg session
  if session == .nil then return "anonymous"
  return "panel:" || session~customer~customerName

::requires "LoggingPolicy.cls"
