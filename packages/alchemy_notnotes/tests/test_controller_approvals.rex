/* test_controller_approvals.rex
 * Travelling OnSubmit code executes under node-local RTOSecurityManager
 * and creates first-class replicated approval objects.
 */

fieldNode = .AlchemyNotNotesNode~new("FIELD")
officeNode = .AlchemyNotNotesNode~new("OFFICE")
fieldSecurity = .RTOSecurityManager~new
officeSecurity = .RTOSecurityManager~new
fieldNode~setSecurityManager(fieldSecurity)
officeNode~setSecurityManager(officeSecurity)

customerDefinition = .DocumentDefinition~new("Customer", "1")
customerDefinition~field("CompanyName")
customerDefinition~field("Active")
customerDefinition~field("AvailableCredit")
fieldNode~registerDocumentDefinition(customerDefinition)
officeNode~registerDocumentDefinition(customerDefinition~snapshotCopy)

salesDefinition = .DocumentDefinition~new("Sales Order", "1")
salesDefinition~field("OrderNumber")
salesDefinition~field("Customer", .FromReference~new(.Document~type("Customer")))
salesDefinition~field("TotalSales")
submitSource = 'This~document~approval("credit score", This~document~TotalSales < This~document~Customer~AvailableCredit, sign); This~document~approval("active customer", This~document~Customer~Active = .true, sign); return This~document~ApprovalStatus'
unsafeSource = "address system 'echo SHOULD_NOT_RUN'"
salesDefinition~handler("OnSubmit", submitSource)
salesDefinition~handler("OnUnsafe", unsafeSource)
fieldNode~registerDocumentDefinition(salesDefinition)
officeNode~registerDocumentDefinition(salesDefinition~snapshotCopy)

customer = fieldNode~compose("Customer/1")
customer~CompanyName = "Acme Engineering"
customer~Active = .true
customer~AvailableCredit = 30000
fieldNode~save(customer)
customerReplication = fieldNode~connect(officeNode)~replicateDocument(customer~documentId)
call assertTrue customerReplication~accepted, "customer replicated"

order = officeNode~compose("Sales Order/1")
order~OrderNumber = "SO-APPROVAL-1"
order~TotalSales = 12500
customerRefs = order~fieldObject("Customer")~references(officeNode)
call assertEqual 1, customerRefs~items, "one customer reference"
order~setReferenceField("Customer", customerRefs~at(1))
officeNode~save(order)

dispatchEvidence = officeNode~dispatch(order, "OnSubmit")
call assertEqual "EXECUTED", dispatchEvidence~status, "OnSubmit executed"
call assertEqual "APPROVED", order~ApprovalStatus, "automatic approval"
call assertEqual 2, order~Approvals~items, "two approval objects"
call assertTrue order~Approvals["credit score"]~signed, "credit approval signed"
call assertTrue order~Approvals["active customer"]~passed, "active approval passed"

unsafeEvidence = officeNode~dispatch(order, "OnUnsafe")
call assertEqual "BLOCKED", unsafeEvidence~status, "unsafe handler blocked"
call assertTrue officeSecurity~auditLog~items > 0, "security audit recorded"

officeNode~save(order)
orderReplication = officeNode~connect(fieldNode)~replicateDocument(order~documentId)
call assertTrue orderReplication~accepted, "approved order replicated"
remoteOrder = fieldNode~document(order~documentId)
call assertEqual "APPROVED", remoteOrder~ApprovalStatus, "approval state replicated"
call assertEqual 2, remoteOrder~Approvals~items, "approval objects replicated"
call assertTrue remoteOrder~Approvals \== order~Approvals, "approval set detached across replicas"
call assertTrue remoteOrder~Approvals["credit score"] \== order~Approvals["credit score"], "approval item detached across replicas"

highOrder = officeNode~compose("Sales Order/1")
highOrder~OrderNumber = "SO-APPROVAL-2"
highOrder~TotalSales = 35000
highOrder~setReferenceField("Customer", customerRefs~at(1))
highEvidence = officeNode~dispatch(highOrder, "OnSubmit")
call assertEqual "EXECUTED", highEvidence~status, "high-value OnSubmit executed"
call assertEqual "PENDING APPROVAL", highOrder~ApprovalStatus, "failed check requires approval"
call assertTrue highOrder~Approvals~anyFailed, "failed approval visible"

say "PASS test_controller_approvals"
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
::requires 'RTOSecurityManager.cls'
