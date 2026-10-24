/* Provider-neutral NotNotes + Intention Service qualification. */

app = .ApplicationDefinition~new("Service Sales Tracker", "1")

customerDefinition = .DocumentDefinition~new("Customer", "1")
customerDefinition~field("CompanyName")
customerDefinition~field("ContactName")
customerDefinition~field("Status")
app~addDocumentDefinition(customerDefinition)

salesDefinition = .DocumentDefinition~new("Sales Order", "1")
orderNumberField = salesDefinition~field("OrderNumber")
orderNumberField~semanticType("IDENTIFIER")
orderNumberField~alias("ORDER")
customerField = salesDefinition~field("Customer", .FromReference~new(.Document~type("Customer")))
customerField~semanticType("DOCUMENT_REFERENCE")
totalField = salesDefinition~field("TotalSales")
totalField~semanticType("DECIMAL")
totalField~alias("TOTAL")
app~addDocumentDefinition(salesDefinition)

customersView = .ViewDefinition~new("All Customers", "1", .Document~type("Customer"))
customersView~column("Company", "CompanyName")
customersView~column("Contact", "ContactName")
app~addViewDefinition(customersView)

ordersView = .ViewDefinition~new("Sales Orders by Customer", "1", .Document~type("Sales Order"))
ordersView~column("Customer", "Customer.CompanyName")
ordersView~column("Order", "OrderNumber")
ordersView~column("Total", "TotalSales")
app~addViewDefinition(ordersView)
app~seal

node = .AlchemyNotNotesNode~new("OFFICE")
app~install(node)

acme = node~compose("Customer/1")
acme~CompanyName = "Acme Engineering"
acme~ContactName = "Alice Smith"
acme~Status = "Active"
node~save(acme)

order = node~compose("Sales Order/1")
order~OrderNumber = "SO-3001"
order~TotalSales = 12500
refs = order~fieldObject("Customer")~references(node)
order~setReferenceField("Customer", refs~at(1))
node~save(order)

bob = .UserIdentity~new("bob", "Bob Manager")
carol = .UserIdentity~new("carol", "Carol Manager")
users = .directory~new
users~put(bob, bob~identity)
users~put(carol, carol~identity)

authorities = .directory~new
authorities~put(.true, "NOTNOTES_REFERRAL_CREATE")
authorities~put(.true, "NOTNOTES_FIELD_WRITE")
runtime = .AlchemyNotNotesIntentionRuntime~new(node, users, authorities)
service = runtime~service

/* Semantic catalogue interrogation comes from the installed NotNotes model. */
decision = runtime~input("from notnotes what views are available")
call assertEq "READY", decision~status, "views ready"
call assertEq "SHOW_VIEWS", decision~registration~id, "views intention"
call assertEq "NOTNOTES_INTERROGATOR", decision~proposal~providerName, "views provider"
call assertEq "READ_ONLY", decision~proposedPlan~sideEffectClass, "views read-only plan"
views = runtime~dispatch(decision)
call assertEq 2, views~items, "installed views returned"
call assertContains views, "All Customers/1", "customer view present"
call assertContains views, "Sales Orders by Customer/1", "orders view present"

/* Field meaning is read from the exact installed document definition. */
decision = runtime~input("from notnotes what fields does sales order have")
call assertEq "READY", decision~status, "fields ready"
call assertEq "SHOW_FIELDS", decision~registration~id, "fields intention"
call assertEq "Sales Order/1", decision~slots~at("DEFINITION_ID")~value, "canonical definition binding"
fields = runtime~dispatch(decision)
call assertEq 3, fields~items, "sales order field count"
call assertFieldContains fields, "ORDERNUMBER", "order number field"
call assertFieldContains fields, "CUSTOMER", "customer field"
call assertFieldContains fields, "TOTALSALES", "total field"
call assertEq "DECIMAL", node~documentDefinition("Sales Order/1")~fieldDefinition("TotalSales")~semanticType, "semantic type installed"

/* Natural language selects the existing hard-lifting document query path. */
decision = runtime~input("from notnotes show me sales orders")
call assertEq "READY", decision~status, "orders ready"
call assertEq "SHOW_DOCUMENTS", decision~registration~id, "orders intention"
call assertEq "Sales Order/1", decision~slots~at("DEFINITION_ID")~value, "orders canonical definition"
orders = runtime~dispatch(decision)
call assertEq 1, orders~items, "one sales order"
call assertEq "SO-3001", orders~at(1)~OrderNumber, "real NotNotes order returned"

/* Deterministic sphere recognition reaches a real durable referral operation. */
startRevision = order~revision
decision = runtime~input("from notnotes refer order SO-3001 to Bob Manager")
call assertEq "CONFIRM", decision~status, "deterministic referral requires confirmation"
call assertEq "REFER_DOCUMENT", decision~registration~id, "deterministic referral intention"
call assertEq "WRITE", decision~proposedPlan~sideEffectClass, "referral write plan"
call assertEq order~documentId, decision~slots~at("DOCUMENT_ID")~value, "canonical order identity"
call assertEq "bob", decision~slots~at("TARGET_IDENTITY")~value, "canonical Bob identity"
decision = runtime~input("yes")
call assertEq "READY", decision~status, "deterministic referral confirmed"
referral = runtime~dispatch(decision)
call assertEq "bob", referral~targetIdentity, "Bob referral created"
call assertEq startRevision + 1, order~revision, "referral committed new revision"
call assertEq 1, node~referralTray(bob)~items, "Bob tray uses normal NotNotes hard lifting"

/* A provider standing in for an LLM proposes the SAME canonical intention. */
service~registerProvider(.FixtureLlmReferralProvider~new(order~documentId, "carol"))
startRevision = order~revision
decision = runtime~input("please ask Carol to review the order")
call assertEq "CONFIRM", decision~status, "LLM-shaped referral requires same confirmation"
call assertEq "REFER_DOCUMENT", decision~registration~id, "LLM-shaped canonical intention"
call assertEq "LLM_PROVIDER_FIXTURE", decision~proposal~providerName, "provider provenance retained"
call assertEq order~documentId, decision~slots~at("DOCUMENT_ID")~value, "LLM canonical order identity"
call assertEq "carol", decision~slots~at("TARGET_IDENTITY")~value, "LLM canonical Carol identity"
call assertEq "CREATE_REFERRAL", decision~proposedPlan~steps~at(2)~kind, "same domain plan hard lifting"
decision = runtime~input("yes")
call assertEq "READY", decision~status, "LLM-shaped referral confirmed"
referral = runtime~dispatch(decision)
call assertEq "carol", referral~targetIdentity, "Carol referral created"
call assertEq startRevision + 1, order~revision, "LLM route committed through NotNotes save"
call assertEq 1, node~referralTray(carol)~items, "Carol tray populated by same NotNotes operation"
call assertEq 1, node~referralTray(bob)~items, "Bob referral remains authoritative"

say "PASS test_intention_service_integration"
exit 0

assertEq: procedure
  use arg expected, actual, label
  if expected == actual then return
  say "FAIL" label "expected=" expected "actual=" actual
  exit 1

assertContains: procedure
  use arg values, expected, label
  do value over values
    if value == expected then return
  end
  say "FAIL" label "missing=" expected
  exit 1

assertFieldContains: procedure
  use arg values, expected, label
  do value over values
    if value~name == expected then return
  end
  say "FAIL" label "missing=" expected
  exit 1

::class FixtureLlmReferralProvider public
::method init
  expose documentId targetIdentity
  use arg newDocumentId, newTargetIdentity
  documentId = newDocumentId
  targetIdentity = newTargetIdentity
::method name
  return "LLM_PROVIDER_FIXTURE"
::method propose
  expose documentId targetIdentity
  use arg service, text
  if translate(strip(text)) \== "PLEASE ASK CAROL TO REVIEW THE ORDER" then return .array~new
  proposal = .IntentionProposal~new("REFER_DOCUMENT", 99, "LLM_PROVIDER_FIXTURE", .true, "fixture emulates an LLM recognition provider")
  proposal~putSlot("DOCUMENT_ID", documentId, .true)
  proposal~putSlot("TARGET_IDENTITY", targetIdentity, .true)
  proposal~putSlot("REASON", "LLM-recognised review request", .false)
  return .array~of(proposal)

::requires "AlchemyNotNotesIntentions.cls"
