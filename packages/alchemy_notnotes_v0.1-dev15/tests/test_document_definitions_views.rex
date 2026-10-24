/* test_document_definitions_views.rex
 * Contract probe for exact versioned document definitions and local views.
 */

app = .ApplicationDefinition~new("Service Sales Tracker", "1")

customerDefinition = .DocumentDefinition~new("Customer", "1")
customerDefinition~field("CompanyName")
customerDefinition~field("ContactName")
customerDefinition~field("Phone")
customerDefinition~field("Status")
app~addDocumentDefinition(customerDefinition)

salesDefinition = .DocumentDefinition~new("Sales Order", "1")
salesDefinition~field("OrderNumber")
salesDefinition~field("Customer", .FromReference~new(.Document~type("Customer")))
salesDefinition~field("TotalSales")
app~addDocumentDefinition(salesDefinition)

visitDefinition = .DocumentDefinition~new("Service Visit", "1")
visitDefinition~field("VisitDate")
visitDefinition~field("Customer", .FromReference~new(.Document~type("Customer")))
visitDefinition~field("VisitType")
visitDefinition~field("Summary")
visitDefinition~field("FollowUpRequired")
app~addDocumentDefinition(visitDefinition)

customersView = .ViewDefinition~new("All Customers", "1", .Document~type("Customer"))
customersView~column("Company", "CompanyName")
customersView~column("Contact", "ContactName")
customersView~column("Status")
customersView~column("Phone")
customersView~sortBy("CompanyName")
app~addViewDefinition(customersView)

ordersView = .ViewDefinition~new("Sales Orders by Customer", "1", .Document~type("Sales Order"))
ordersView~column("Customer", "Customer.CompanyName")
ordersView~column("Order", "OrderNumber")
ordersView~column("Total", "TotalSales")
ordersView~sortBy("Customer.CompanyName")
app~addViewDefinition(ordersView)

visitsView = .ViewDefinition~new("Service Visits by Customer", "1", .Document~type("Service Visit"))
visitsView~column("Customer", "Customer.CompanyName")
visitsView~column("VisitDate")
visitsView~column("VisitType")
visitsView~column("FollowUp", "FollowUpRequired")
visitsView~sortBy("Customer.CompanyName")
app~addViewDefinition(visitsView)

app~seal

fieldNode = .AlchemyNotNotesNode~new("FIELD")
officeNode = .AlchemyNotNotesNode~new("OFFICE")
app~install(fieldNode)
app~install(officeNode)

call assertTrue fieldNode~documentDefinition("Customer/1") \== officeNode~documentDefinition("Customer/1"), "definition copies are node-local"
call assertTrue fieldNode~documentDefinition("Customer") == .nil, "no implicit latest definition lookup"

customerDefinitionV2 = .DocumentDefinition~new("Customer", "2")
customerDefinitionV2~field("CompanyName")
customerDefinitionV2~field("Phone")
customerDefinitionV2~field("AccountManager")
fieldNode~registerDocumentDefinition(customerDefinitionV2)
customerV2 = fieldNode~compose("Customer/2")
call assertEqual "Customer/2", customerV2~definitionIdentity, "parallel definition version composes exactly"

customer1 = fieldNode~compose("Customer/1")
customer1~CompanyName = "Central Hydraulics"
customer1~ContactName = "Chris Green"
customer1~Phone = "0161 555 0200"
customer1~Status = "Active"
fieldNode~save(customer1)

customer2 = fieldNode~compose("Customer/1")
customer2~CompanyName = "Acme Engineering"
customer2~ContactName = "Alice Smith"
customer2~Phone = "0161 555 0100"
customer2~Status = "Active"
fieldNode~save(customer2)

call assertEqual "Customer/1", customer1~definitionIdentity, "customer exact definition binding"

fieldToOffice = fieldNode~connect(officeNode)
batch = fieldToOffice~replicate
call assertEqual 2, batch~count("CREATED"), "customer population replicated"

order = officeNode~compose("Sales Order/1")
order~OrderNumber = "SO-3001"
order~TotalSales = 12500
customerField = order~fieldObject("Customer")
customerRefs = customerField~references(officeNode)
selectedCustomer = .nil
do reference over customerRefs
  candidate = reference~resolve(officeNode)
  if candidate~CompanyName = "Acme Engineering" then do
    selectedCustomer = reference
    leave
  end
end
call assertTrue selectedCustomer \== .nil, "customer selected for sales order"
order~setReferenceField("Customer", selectedCustomer)
officeNode~save(order)

visit = officeNode~compose("Service Visit/1")
visit~VisitDate = "2026-09-30"
visit~VisitType = "Routine Maintenance"
visit~Summary = "Quarterly inspection complete"
visit~FollowUpRequired = "No"
visit~setReferenceField("Customer", selectedCustomer)
officeNode~save(visit)

call assertEqual "Sales Order/1", order~definitionIdentity, "sales order exact definition binding"
call assertEqual "Service Visit/1", visit~definitionIdentity, "service visit exact definition binding"

officeToField = fieldToOffice~reverse
batch = officeToField~replicate
call assertEqual 2, batch~count("CREATED"), "order and visit replicated back"

customerRows = fieldNode~view("All Customers/1")
call assertEqual 2, customerRows~items, "customer view row count"
call assertEqual "Acme Engineering", customerRows~at(1)~value("Company"), "customer view sorted locally"
call assertEqual "Central Hydraulics", customerRows~at(2)~value("Company"), "customer view second row"
call assertEqual customer2~documentId, customerRows~at(1)~document(fieldNode)~documentId, "view row resolves authoritative object"

orderRows = fieldNode~view("Sales Orders by Customer/1")
call assertEqual 1, orderRows~items, "sales order view row count"
call assertEqual "Acme Engineering", orderRows~at(1)~value("Customer"), "relationship path projected"
call assertEqual "SO-3001", orderRows~at(1)~value("Order"), "order number projected"
call assertEqual 12500, orderRows~at(1)~value("Total"), "order total projected"

visitRows = fieldNode~view("Service Visits by Customer/1")
call assertEqual 1, visitRows~items, "service visit view row count"
call assertEqual "Acme Engineering", visitRows~at(1)~value("Customer"), "visit customer projected"
call assertEqual "Routine Maintenance", visitRows~at(1)~value("VisitType"), "visit type projected"

returnedCustomer = fieldNode~document(customer2~documentId)
orders = returnedCustomer~linkedDocuments(.Document~type("Sales Order"))
visits = returnedCustomer~linkedDocuments(.Document~type("Service Visit"))
call assertEqual 1, orders~items, "customer linked order count"
call assertEqual 1, visits~items, "customer linked visit count"

say "PASS test_document_definitions_views"
exit 0

assertEqual: procedure
  use arg expected, actual, label
  if expected == actual then return
  say "FAIL" label "expected="expected "actual="actual
  exit 1

assertTrue: procedure
  use arg actual, label
  if actual then return
  say "FAIL" label
  exit 1

::requires 'src/AlchemyNotNotes.cls'
