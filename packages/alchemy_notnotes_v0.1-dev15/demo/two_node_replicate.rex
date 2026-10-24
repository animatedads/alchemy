/* two_node_replicate.rex
 * Smallest useful notNotes demo: two autonomous nodes and one replicated document.
 */

nodeA = .AlchemyNotNotesNode~new("FIELD-NODE")
nodeB = .AlchemyNotNotesNode~new("OFFICE-NODE")
connection = nodeA~connect(nodeB)

order = nodeA~createDocument("SalesOrder")
order~CompanyName = "Acme Engineering"
order~TotalSales = 12500
order~AvailableCredit = 30000
nodeA~save(order)

say "source:" nodeA~nodeId order~documentId order~revisionId
say "target before replication:" nodeB~document(order~documentId)

replication = connection~replicateDocument(order~documentId)
say "replication:" replication~status replication~detail

replica = nodeB~document(order~documentId)
say "target customer:" replica~CompanyName
say "target total:" replica~TotalSales
say "target revision:" replica~revisionId

/* Prove the replicas are independent objects. */
order~TotalSales = 14000
nodeA~save(order)
say "source changed total:" order~TotalSales
say "target still old total:" replica~TotalSales

replication = connection~replicateDocument(order~documentId)
say "second replication:" replication~status replication~detail
say "target updated total:" nodeB~document(order~documentId)~TotalSales

::requires 'src/AlchemyNotNotes.cls'
