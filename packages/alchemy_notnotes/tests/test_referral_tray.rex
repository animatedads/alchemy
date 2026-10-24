/* test_referral_tray.rex
 * Failed automatic approvals create first-class referrals to the node-local user's team leader.
 */

fieldNode = .AlchemyNotNotesNode~new("FIELD")
officeNode = .AlchemyNotNotesNode~new("OFFICE")
fieldSecurity = .RTOSecurityManager~new
officeSecurity = .RTOSecurityManager~new
fieldNode~setSecurityManager(fieldSecurity)
officeNode~setSecurityManager(officeSecurity)

manager = .UserIdentity~new("manager.mary", "Mary Manager")
agent = .UserIdentity~new("field.alice", "Alice Engineer", manager)
officeNode~setCurrentUser(agent)
fieldNode~setCurrentUser(manager)

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
submitSource = 'This~document~approval("credit score", This~document~TotalSales < This~document~Customer~AvailableCredit, sign); This~document~approval("active customer", This~document~Customer~Active = .true, sign); This~document~refer(This~user~teamleader, "automatic approval failed", This~document~Approvals~anyFailed); return This~document~ApprovalStatus'
salesDefinition~handler("OnSubmit", submitSource)
fieldNode~registerDocumentDefinition(salesDefinition)
officeNode~registerDocumentDefinition(salesDefinition~snapshotCopy)

customer = fieldNode~compose("Customer/1")
customer~CompanyName = "Acme Engineering"
customer~Active = .true
customer~AvailableCredit = 30000
fieldNode~save(customer)
customerReplication = fieldNode~connect(officeNode)~replicateDocument(customer~documentId)
call assertTrue customerReplication~accepted, "customer replicated"

customerRefs = officeNode~documents(.Document~type("Customer"))
call assertEqual 1, customerRefs~items, "one customer document"

highOrder = officeNode~compose("Sales Order/1")
highOrder~OrderNumber = "SO-REFERRAL-1"
highOrder~TotalSales = 35000
highOrder~linkDocument(customerRefs~at(1), "Customer")
highEvidence = officeNode~dispatch(highOrder, "OnSubmit")
call assertEqual "EXECUTED", highEvidence~status, "high order OnSubmit executed"
call assertEqual "PENDING APPROVAL", highOrder~ApprovalStatus, "failed automatic approval remains pending"
call assertEqual 1, highOrder~Referrals~items, "one referral created"
call assertEqual "manager.mary", highOrder~Referrals["manager.mary"]~targetIdentity, "team leader referral target"
call assertTrue highOrder~Referrals["manager.mary"]~open, "team leader referral open"
officeNode~save(highOrder)
officeTray = officeNode~referralTray(manager)
call assertEqual 1, officeTray~items, "manager office tray contains order"
call assertEqual highOrder~documentId, officeTray~at(1)~documentId, "office tray order identity"

orderReplication = officeNode~connect(fieldNode)~replicateDocument(highOrder~documentId)
call assertTrue orderReplication~accepted, "referred order replicated"
fieldTray = fieldNode~referralTray("manager.mary")
call assertEqual 1, fieldTray~items, "manager field tray contains replicated order"
remoteOrder = fieldNode~document(highOrder~documentId)
call assertEqual 1, remoteOrder~Referrals~items, "referral replicated"
call assertTrue remoteOrder~Referrals \== highOrder~Referrals, "referral set detached across replicas"
call assertTrue remoteOrder~Referrals["manager.mary"] \== highOrder~Referrals["manager.mary"], "referral item detached across replicas"

safeOrder = officeNode~compose("Sales Order/1")
safeOrder~OrderNumber = "SO-REFERRAL-2"
safeOrder~TotalSales = 12500
safeOrder~linkDocument(customerRefs~at(1), "Customer")
safeEvidence = officeNode~dispatch(safeOrder, "OnSubmit")
call assertEqual "EXECUTED", safeEvidence~status, "safe order OnSubmit executed"
call assertEqual "APPROVED", safeOrder~ApprovalStatus, "safe order auto-approved"
call assertEqual 0, safeOrder~Referrals~items, "safe order not referred"

say "PASS test_referral_tray"
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
