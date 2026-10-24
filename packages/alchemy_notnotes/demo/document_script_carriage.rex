/* document_script_carriage.rex
 * Dev7 demo: an exact document script section travels with its revision.
 */

field = .AlchemyNotNotesNode~new("FIELD")
office = .AlchemyNotNotesNode~new("OFFICE")

sales = .DocumentDefinition~new("Sales Order", "1")
sales~field("OrderNumber")
sales~field("TotalSales")
onSubmit = "This~document~approvals['credit score'](This~document~TotalSales < 10000, sign)"
sales~handler("OnSubmit", onSubmit)

field~registerDocumentDefinition(sales)
office~registerDocumentDefinition(sales~snapshotCopy)

order = field~compose("Sales Order/1")
order~OrderNumber = "SO-DEMO-1"
order~TotalSales = 12500
field~save(order)

say "FIELD definition:" order~definitionIdentity
say "FIELD OnSubmit :" order~scriptHandler("OnSubmit")~source

connection = field~connect(office)
connection~replicateDocument(order~documentId)

remote = office~document(order~documentId)
say "OFFICE definition:" remote~definitionIdentity
say "OFFICE OnSubmit :" remote~scriptHandler("OnSubmit")~source
say "independent handler objects:" remote~scriptHandler("OnSubmit") \== order~scriptHandler("OnSubmit")

say "NOTE: dev7 carries the script source; it does not execute it yet."
exit 0

::requires 'src/AlchemyNotNotes.cls'
