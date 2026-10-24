/* test_document_script_carriage.rex
 * Contract probe for exact versioned document script-section carriage.
 */

fieldNode = .AlchemyNotNotesNode~new("FIELD")
officeNode = .AlchemyNotNotesNode~new("OFFICE")

salesV1 = .DocumentDefinition~new("Sales Order", "1")
salesV1~field("OrderNumber")
salesV1~field("TotalSales")
sourceV1 = "This~document~approvals['credit score'](This~document~TotalSales < 10000, sign)"
salesV1~handler("OnSubmit", sourceV1)
fieldNode~registerDocumentDefinition(salesV1)
officeNode~registerDocumentDefinition(salesV1~snapshotCopy)

salesV2 = .DocumentDefinition~new("Sales Order", "2")
salesV2~field("OrderNumber")
salesV2~field("TotalSales")
sourceV2 = "This~document~approvals['credit score'](This~document~TotalSales < 20000, sign)"
salesV2~handler("OnSubmit", sourceV2)
fieldNode~registerDocumentDefinition(salesV2)

order = fieldNode~compose("Sales Order/1")
order~OrderNumber = "SO-SCRIPT-1"
order~TotalSales = 12500
call assertEqual "Sales Order/1", order~definitionIdentity, "exact script definition binding"
call assertEqual 1, order~scriptEvents~items, "one carried event"
call assertEqual sourceV1, order~scriptHandler("OnSubmit")~source, "v1 source materialised"
call assertTrue order~scriptHandler("OnSubmit") \== salesV1~handlerFor("OnSubmit"), "document owns detached handler"
fieldNode~save(order)

connection = fieldNode~connect(officeNode)
replicationEvidence = connection~replicateDocument(order~documentId)
call assertTrue replicationEvidence \== .nil, "replication returned evidence"

remote = officeNode~document(order~documentId)
call assertTrue remote \== .nil, "replicated scripted document exists"
call assertEqual "Sales Order/1", remote~definitionIdentity, "definition identity travelled"
call assertEqual sourceV1, remote~scriptHandler("OnSubmit")~source, "script source travelled"
call assertTrue remote~scriptHandler("OnSubmit") \== order~scriptHandler("OnSubmit"), "replica owns detached handler"

newOrder = fieldNode~compose("Sales Order/2")
call assertEqual sourceV2, newOrder~scriptHandler("OnSubmit")~source, "v2 script differs"
call assertEqual sourceV1, order~scriptHandler("OnSubmit")~source, "existing v1 document remains v1"

say "PASS test_document_script_carriage"
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
