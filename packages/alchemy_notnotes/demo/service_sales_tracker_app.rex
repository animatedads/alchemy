/* service_sales_tracker_app.rex
 * Small Notes-style application built from versioned document/view definitions.
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
visitsView~column("Date", "VisitDate")
visitsView~column("Type", "VisitType")
visitsView~column("FollowUp", "FollowUpRequired")
visitsView~sortBy("Customer.CompanyName")
app~addViewDefinition(visitsView)

app~seal

field = .AlchemyNotNotesNode~new("FIELD")
office = .AlchemyNotNotesNode~new("OFFICE")
app~install(field)
app~install(office)

acme = field~compose("Customer/1")
acme~CompanyName = "Acme Engineering"
acme~ContactName = "Alice Smith"
acme~Phone = "0161 555 0100"
acme~Status = "Active"
field~save(acme)

central = field~compose("Customer/1")
central~CompanyName = "Central Hydraulics"
central~ContactName = "Chris Green"
central~Phone = "0161 555 0200"
central~Status = "Active"
field~save(central)

connection = field~connect(office)
connection~replicate

order = office~compose("Sales Order/1")
order~OrderNumber = "SO-3001"
order~TotalSales = 12500
customerReferences = order~fieldObject("Customer")~references(office)
acmeReference = .nil
do customerReference over customerReferences
  if customerReference~resolve(office)~CompanyName = "Acme Engineering" then do
    acmeReference = customerReference
    leave
  end
end
order~setReferenceField("Customer", acmeReference)
office~save(order)

visit = office~compose("Service Visit/1")
visit~VisitDate = "2026-09-30"
visit~VisitType = "Routine Maintenance"
visit~Summary = "Quarterly inspection complete"
visit~FollowUpRequired = "No"
visit~setReferenceField("Customer", acmeReference)
office~save(visit)

connection~reverse~replicate

say "ALL CUSTOMERS"
do row over field~view("All Customers/1")
  say " " row~value("Company") "|" row~value("Contact") "|" row~value("Phone")
end

say
say "SALES ORDERS BY CUSTOMER"
do row over field~view("Sales Orders by Customer/1")
  say " " row~value("Customer") "|" row~value("Order") "|" row~value("Total")
end

say
say "SERVICE VISITS BY CUSTOMER"
do row over field~view("Service Visits by Customer/1")
  say " " row~value("Customer") "|" row~value("Date") "|" row~value("Type")
end

say
say "ACME LINKED SALES ORDERS:" acme~linkedDocuments(.Document~type("Sales Order"))~items
say "ACME LINKED SERVICE VISITS:" acme~linkedDocuments(.Document~type("Service Visit"))~items

::requires 'src/AlchemyNotNotes.cls'
