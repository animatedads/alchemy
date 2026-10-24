/* test_customer_sales_order_replication.rex
 * Contract probe for population replication, links, remote mutation and
 * linked-document type selection.
 */

fieldNode = .AlchemyNotNotesNode~new("FIELD")
officeNode = .AlchemyNotNotesNode~new("OFFICE")
fieldToOffice = fieldNode~connect(officeNode)

customer1 = fieldNode~createDocument("Customer")
customer1~CompanyName = "Acme Engineering"
customer1~ContactName = "Alice Smith"
customer1~Phone = "0161 555 0100"
fieldNode~save(customer1)

customer2 = fieldNode~createDocument("Customer")
customer2~CompanyName = "Central Hydraulics"
customer2~ContactName = "Bob Jones"
customer2~Phone = "0161 555 0200"
fieldNode~save(customer2)

customer3 = fieldNode~createDocument("Customer")
customer3~CompanyName = "North Works"
customer3~ContactName = "Carol Green"
customer3~Phone = "0161 555 0300"
fieldNode~save(customer3)

batch = fieldToOffice~replicate
call assertEqual 3, batch~items, "initial population size"
call assertEqual 3, batch~count("CREATED"), "initial population created"

officeCustomer = officeNode~document(customer1~documentId)
call assertEqual "Acme Engineering", officeCustomer~CompanyName, "customer replicated"
call assertEqual "0161 555 0100", officeCustomer~Phone, "original phone"

salesOrder = officeNode~createDocument("Sales Order")
salesOrder~OrderNumber = "SO-1001"
salesOrder~TotalSales = 12500
salesOrder~linkDocument(officeCustomer, "Customer")
officeNode~save(salesOrder)

officeCustomer~Phone = "0161 555 0199"
officeNode~save(officeCustomer)

/* A named link should resolve naturally through UNKNOWN. */
call assertEqual officeCustomer~documentId, salesOrder~Customer~documentId, "named customer relation"

officeToField = fieldToOffice~reverse
batch = officeToField~replicate
call assertEqual 4, batch~items, "return population size"
call assertEqual 1, batch~count("CREATED"), "sales order created remotely"
call assertEqual 1, batch~count("UPDATED"), "customer updated remotely"

returnedCustomer = fieldNode~document(customer1~documentId)
call assertEqual "0161 555 0199", returnedCustomer~Phone, "phone replicated back"

orders = returnedCustomer~linkedDocuments(.Document~type("Sales Order"))
call assertEqual 1, orders~items, "linked sales order count"
returnedOrder = orders~at(1)
call assertEqual "SO-1001", returnedOrder~OrderNumber, "linked sales order identity"
call assertEqual returnedCustomer~documentId, returnedOrder~Customer~documentId, "replicated customer relation"

say "PASS test_customer_sales_order_replication"
exit 0

assertEqual: procedure
  use arg expected, actual, label
  if expected == actual then return
  say "FAIL" label "expected="expected "actual="actual
  exit 1

::requires 'src/AlchemyNotNotes.cls'
