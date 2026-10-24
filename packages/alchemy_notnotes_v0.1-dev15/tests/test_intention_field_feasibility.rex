/* Semantic field exposure + dev7 feasibility qualification. */

app = .ApplicationDefinition~new("Intentions Sales", "1")
orderDefinition = .DocumentDefinition~new("Sales Order", "1")

orderNumber = orderDefinition~field("OrderNumber")
orderNumber~semanticType("IDENTIFIER")
orderNumber~alias("ORDER")
orderNumber~intentionWritable(.false)

statusField = orderDefinition~field("Status")
statusField~semanticType("ENUM")
statusField~alias("STATE")
statusField~intentionWritable(.true)

totalField = orderDefinition~field("TotalSales")
totalField~semanticType("DECIMAL")
totalField~alias("TOTAL")
totalField~computed(.true)
totalField~processOwner("ORDER_TOTAL_CALCULATION")

approvalField = orderDefinition~field("ApprovalStatus")
approvalField~semanticType("ENUM")
approvalField~alias("APPROVAL")
approvalField~intentionWritable(.false)
approvalField~processOwner("APPROVE_DOCUMENT")

app~addDocumentDefinition(orderDefinition)
app~seal

node = .AlchemyNotNotesNode~new("OFFICE")
app~install(node)
order = node~compose("Sales Order/1")
order~OrderNumber = "SO-4001"
order~Status = "Open"
order~TotalSales = 500
order~ApprovalStatus = "Pending"
node~save(order)

authorities = .directory~new
authorities~put(.true, "NOTNOTES_FIELD_WRITE")
runtime = .AlchemyNotNotesIntentionRuntime~new(node, .directory~new, authorities)

/* Installed semantic metadata is preserved through application snapshot/install. */
definition = node~documentDefinition("Sales Order/1")
field = definition~fieldDefinition("Status")
call assertEq "ENUM", field~semanticType, "status type"
call assertEq .true, field~intentionWritable, "status writable"
call assertEq 1, field~aliases~items, "status alias count"
call assertEq "STATE", field~aliases~at(1), "status alias"

field = definition~fieldDefinition("TotalSales")
call assertEq .true, field~computed, "total computed"
call assertEq .false, field~intentionWritable, "computed total not writable"
call assertEq "ORDER_TOTAL_CALCULATION", field~processOwner, "total process owner"

/* Ordinary writable field: understood, feasible, confirmed, then normal NotNotes save. */
startRevision = order~revision
decision = runtime~input("from notnotes set state to Closed on order SO-4001")
call assertEq "CONFIRM", decision~status, "ordinary field write confirmation"
call assertEq "SET_FIELD", decision~registration~id, "ordinary field intention"
call assertEq "STATUS", decision~slots~at("FIELD_NAME")~value, "alias canonicalised"
call assertEq "CLOSED", decision~slots~at("VALUE")~value, "field value captured"
call assertEq "FEASIBLE", decision~planAssessment~status, "ordinary field feasible"
call assertEq .true, decision~planExecutable, "ordinary field executable"
decision = runtime~input("yes")
call assertEq "READY", decision~status, "ordinary field confirmed"
updated = runtime~dispatch(decision)
call assertEq "CLOSED", updated~Status, "ordinary field changed through NotNotes"
call assertEq startRevision + 1, updated~revision, "ordinary field committed new revision"

/* Computed field: meaning is understood but NotNotes says the plan cannot run. */
decision = runtime~input("from notnotes set total to 999 on order SO-4001")
call assertEq "CONFIRM", decision~status, "computed field meaning still understood"
call assertEq "SET_FIELD", decision~registration~id, "computed field canonical intention"
call assertEq "INFEASIBLE", decision~planAssessment~status, "computed field infeasible"
call assertEq .false, decision~planExecutable, "computed field non executable"
call assertContains decision~planAssessment~violatedPreconditions, "FIELD_COMPUTED:TOTALSALES", "computed blocker"
call assertContains decision~planAssessment~violatedPreconditions, "FIELD_OWNED_BY:ORDER_TOTAL_CALCULATION", "computed owner blocker"
runtime~input("no")

/* Process-owned field: generic SET_FIELD must not bypass the owning domain operation. */
decision = runtime~input("from notnotes set approval to Approved on order SO-4001")
call assertEq "CONFIRM", decision~status, "process-owned field meaning understood"
call assertEq "INFEASIBLE", decision~planAssessment~status, "process-owned field infeasible"
call assertContains decision~planAssessment~violatedPreconditions, "FIELD_OWNED_BY:APPROVE_DOCUMENT", "approval owner blocker"
runtime~input("no")

/* Same understood operation without authority reports authority separately. */
noAuthorityRuntime = .AlchemyNotNotesIntentionRuntime~new(node, .directory~new, .directory~new)
decision = noAuthorityRuntime~input("from notnotes set state to Reopened on order SO-4001")
call assertEq "CONFIRM", decision~status, "missing-authority meaning understood"
call assertEq "INFEASIBLE", decision~planAssessment~status, "missing authority infeasible"
call assertContains decision~planAssessment~missingAuthority, "NOTNOTES_FIELD_WRITE", "missing authority explicit"
call assertEq "CLOSED", order~Status, "assessment did not mutate document"

say "PASS test_intention_field_feasibility"
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

::requires "AlchemyNotNotesIntentions.cls"
