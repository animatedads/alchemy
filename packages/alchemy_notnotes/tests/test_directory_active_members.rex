/* test_directory_active_members.rex
 * Qualifies the ooRexx Directory/setMethod substrate used by Document.
 */

left = .AlchemyNotNotesNode~new("LEFT")
right = .AlchemyNotNotesNode~new("RIGHT")

customer = left~createDocument("Customer")
customer~CompanyName = "Acme Engineering"
customer~Phone = "0161 555 0100"
left~save(customer)

order = left~createDocument("Sales Order")
order~OrderNumber = "SO-2001"
order~TotalSales = 9900
order~linkDocument(customer, "Customer")
left~save(order)

/* Ordinary fields are native Directory dynamic members. */
call assertEqual "Acme Engineering", customer~CompanyName, "Directory UNKNOWN field getter"
call assertEqual "Acme Engineering", customer~at("COMPANYNAME"), "Directory AT field getter"
call assertTrue customer~hasField("CompanyName"), "data field recognised"

/* Named relationships are Directory active members installed with setMethod(). */
call assertEqual customer~documentId, order~Customer~documentId, "active relation message"
call assertEqual customer~documentId, order~at("CUSTOMER")~documentId, "active relation AT lookup"
call assertFalse order~hasField("Customer"), "active relation is not a data field"
call assertFalse arrayContains(order~fieldNames, "CUSTOMER"), "active relation excluded from fieldNames"

/* Active members are rebuilt from durable link descriptors after replication. */
left~connect(right)~replicate
remoteOrder = right~document(order~documentId)
remoteCustomer = right~document(customer~documentId)
call assertEqual remoteCustomer~documentId, remoteOrder~Customer~documentId, "replicated active relation message"
call assertEqual remoteCustomer~documentId, remoteOrder~at("CUSTOMER")~documentId, "replicated active relation AT lookup"
call assertEqual "SO-2001", remoteOrder~OrderNumber, "replicated field still dynamic"

say "PASS test_directory_active_members"
exit 0

arrayContains: procedure
  use arg values, wanted
  do value over values
    if value = wanted then return .true
  end
  return .false

assertTrue: procedure
  use arg actual, label
  if actual = .true then return
  say "FAIL" label "expected=.true actual="actual
  exit 1

assertFalse: procedure
  use arg actual, label
  if actual = .false then return
  say "FAIL" label "expected=.false actual="actual
  exit 1

assertEqual: procedure
  use arg expected, actual, label
  if expected == actual then return
  say "FAIL" label "expected="expected "actual="actual
  exit 1

::requires 'src/AlchemyNotNotes.cls'
