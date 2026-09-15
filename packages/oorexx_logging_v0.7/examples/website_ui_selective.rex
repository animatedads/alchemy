service = .LogService~new("web-runtime")
memory = .LogMemoryTarget~new("memory", .Log~INTERNAL)
service~addTarget(memory)

ui = .WebsiteUI~new
service~registerMethod(ui, "generateCustomerPanel", .Log~INTERNAL)

condition = .LogConditionAny~new(.array~of( -
  .LogConditionArgNil~new(1), -
  .LogConditionArgPathContains~new(1, -
    .array~of("CUSTOMER", "CUSTOMERNAME"), "%';DROP", .false)))

rule = .LogRule~new("suspicious-panel", "website", -
  "WebsiteUI", "generateCustomerPanel", -
  .Log~INTERNAL, .Log~INTERNAL, .Log~DEBUG, condition, -
  .array~of("memory"), .array~of(.Log~ENTRY, .Log~EXIT, .Log~ERROR_POINT))
service~addRule(rule)

normal = .Session~new(.Customer~new("ordinary customer"))
say ui~generateCustomerPanel(normal)
say "events after normal call:" memory~count

suspicious = .Session~new(.Customer~new("Acme %';DROP TABLE customer;--"))
say ui~generateCustomerPanel(suspicious)
say "events after suspicious call:" memory~count

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

::requires "../src/LoggingCore.cls"
