/* customer_sales_order_roundtrip.rex
 * Minimal notNotes round trip:
 *   customers FIELD -> OFFICE
 *   sales order + customer phone change OFFICE -> FIELD
 *   customer linkedDocuments(.Document~type("Sales Order"))
 */

field = .AlchemyNotNotesNode~new("FIELD")
office = .AlchemyNotNotesNode~new("OFFICE")
connection = field~connect(office)

customer1 = field~createDocument("Customer")
customer1~CompanyName = "Acme Engineering"
customer1~Phone = "0161 555 0100"
field~save(customer1)

customer2 = field~createDocument("Customer")
customer2~CompanyName = "Central Hydraulics"
customer2~Phone = "0161 555 0200"
field~save(customer2)

customer3 = field~createDocument("Customer")
customer3~CompanyName = "North Works"
customer3~Phone = "0161 555 0300"
field~save(customer3)

outbound = connection~replicate
say "FIELD -> OFFICE documents:" outbound~items
say "  created:" outbound~count("CREATED")

customer = office~document(customer1~documentId)
order = office~createDocument("Sales Order")
order~OrderNumber = "SO-1001"
order~TotalSales = 12500
order~linkDocument(customer, "Customer")
office~save(order)

customer~Phone = "0161 555 0199"
office~save(customer)

inbound = connection~reverse~replicate
say "OFFICE -> FIELD documents:" inbound~items
say "  created:" inbound~count("CREATED")
say "  updated:" inbound~count("UPDATED")

customer = field~document(customer1~documentId)
say ""
say "Customer:" customer~CompanyName
say "Phone:" customer~Phone

orders = customer~linkedDocuments(.Document~type("Sales Order"))
say "Linked Sales Orders:" orders~items
do linkedOrder over orders
  say "  " linkedOrder~OrderNumber "total=" linkedOrder~TotalSales
end

exit 0

::requires 'src/AlchemyNotNotes.cls'
