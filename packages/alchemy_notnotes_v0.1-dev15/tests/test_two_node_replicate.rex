/* test_two_node_replicate.rex
 * Contract probe for create, replicate, independence, update and conflict detection.
 */

nodeA = .AlchemyNotNotesNode~new("A")
nodeB = .AlchemyNotNotesNode~new("B")
linkAB = nodeA~connect(nodeB)

doc = nodeA~createDocument("Customer")
doc~CompanyName = "Example Ltd"
nodeA~save(doc)

r = linkAB~replicateDocument(doc~documentId)
call assertEqual "CREATED", r~status, "initial replication"
call assertEqual "Example Ltd", nodeB~document(doc~documentId)~CompanyName, "dynamic field getter"

/* Source update must not mutate target until replication runs. */
doc~CompanyName = "Example Limited"
nodeA~save(doc)
call assertEqual "Example Ltd", nodeB~document(doc~documentId)~CompanyName, "replica isolation"
r = linkAB~replicateDocument(doc~documentId)
call assertEqual "UPDATED", r~status, "fast-forward replication"
call assertEqual "Example Limited", nodeB~document(doc~documentId)~CompanyName, "updated replica"

/* Divergent commits from the same revision must surface a conflict. */
doc~CompanyName = "A-side"
nodeA~save(doc)
bDoc = nodeB~document(doc~documentId)
bDoc~CompanyName = "B-side"
nodeB~save(bDoc)
r = linkAB~replicateDocument(doc~documentId)
call assertEqual "CONFLICT", r~status, "divergent revisions"

say "PASS test_two_node_replicate"
exit 0

assertEqual: procedure
  use arg expected, actual, label
  if expected == actual then return
  say "FAIL" label "expected="expected "actual="actual
  exit 1

::requires 'src/AlchemyNotNotes.cls'
