/* test_referral_decision_roundtrip.rex
 * A referred document can be decided offline by the node-local target identity,
 * committed as first-class decision evidence, and replicated back to its origin.
 */

fieldNode = .AlchemyNotNotesNode~new("FIELD")
officeNode = .AlchemyNotNotesNode~new("OFFICE")
fieldNode~setSecurityManager(.RTOSecurityManager~new)
officeNode~setSecurityManager(.RTOSecurityManager~new)

manager = .UserIdentity~new("manager.mary", "Mary Manager")
agent = .UserIdentity~new("field.alice", "Alice Engineer", manager)
fieldNode~setCurrentUser(manager)
officeNode~setCurrentUser(agent)

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
order = officeNode~compose("Sales Order/1")
order~OrderNumber = "SO-DECISION-1"
order~TotalSales = 35000
order~linkDocument(customerRefs~at(1), "Customer")
submitEvidence = officeNode~dispatch(order, "OnSubmit")
call assertEqual "EXECUTED", submitEvidence~status, "OnSubmit executed"
call assertEqual "PENDING APPROVAL", order~ApprovalStatus, "order initially pending"
officeNode~save(order)

outbound = officeNode~connect(fieldNode)~replicateDocument(order~documentId)
call assertTrue outbound~accepted, "pending order replicated to manager node"
remoteOrder = fieldNode~document(order~documentId)
call assertEqual 1, fieldNode~referralTray(manager)~items, "manager tray contains pending order"
beforeDecisionRevision = remoteOrder~revisionId

decision = fieldNode~decideReferral(remoteOrder, "APPROVED", "approved as credit exception")
call assertEqual "manager.mary", decision~actorIdentity, "decision bound to node-local manager"
call assertEqual "APPROVED", decision~outcome, "decision outcome"
call assertEqual "approved as credit exception", decision~note, "decision note"
call assertTrue \remoteOrder~Referrals["manager.mary"]~open, "referral closed after decision"
call assertEqual "APPROVED", remoteOrder~ApprovalStatus, "decision resolves business status"
call assertEqual 0, fieldNode~referralTray(manager)~items, "resolved item leaves manager tray"
call assertTrue remoteOrder~revisionId <> beforeDecisionRevision, "decision committed a new revision"

returnReplication = fieldNode~connect(officeNode)~replicateDocument(remoteOrder~documentId)
call assertTrue returnReplication~accepted, "decision revision replicated to origin"
originOrder = officeNode~document(order~documentId)
originReferral = originOrder~Referrals["manager.mary"]
originDecision = originReferral~decision
call assertTrue \originReferral~open, "origin sees referral resolved"
call assertEqual "manager.mary", originDecision~actorIdentity, "origin sees decision actor"
call assertEqual "APPROVED", originDecision~outcome, "origin sees approved outcome"
call assertEqual "approved as credit exception", originDecision~note, "origin sees decision note"
call assertEqual "APPROVED", originOrder~ApprovalStatus, "origin derives approved status"
call assertEqual 0, officeNode~referralTray(manager)~items, "resolved item absent from origin tray"
call assertTrue originDecision \== decision, "decision evidence detached across replicas"
call assertTrue originReferral \== remoteOrder~Referrals["manager.mary"], "referral item detached across replicas"

say "PASS test_referral_decision_roundtrip"
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
