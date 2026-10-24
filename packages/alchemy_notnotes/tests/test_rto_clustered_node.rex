/* Qualify NotNotes as replayable state behind AlchemyClusteredApp. */
liveUser = .UserIdentity~new("alice", "Alice")
spareUser = .UserIdentity~new("bob", "Bob")

live = .AlchemyNotNotesClusteredNode~new("NOTNOTES", "id1", "ACTIVE", "branchA")
spare = .AlchemyNotNotesClusteredNode~new("NOTNOTES", "id2", "REPLAY", "branchA")
live~configureLocalAuthority(liveUser)
spare~configureLocalAuthority(spareUser)
call assertTrue live~negotiateRole("ACTIVE", 1), "live activates"
call assertTrue spare~negotiateRole("REPLAY", 1), "spare enters replay"

customer = live~createDocument("Customer")
customer~CompanyName = "Acme"
live~stageSave(customer)
seq = live~commitStaged("customer-create")
call mirrorCommitted live, spare, seq

order = live~createDocument("SalesOrder")
order~defineField("Customer", .FromReference~new(.Document~type("Customer")))
order~setReferenceField("Customer", .DocumentReference~new(customer~documentId, customer~formName))
order~defineField("EvidenceImage", .FromExternalDocument~new("image/"))
external = live~createExternalDocument("proof.bin", "image/test", x2c("00017FFF80FE"), "PASTE")
order~setExternalField("EvidenceImage", .ExternalDocumentLink~new(external~externalId, external~displayName, external~mediaType))
order~putField("Amount", "282.00")
nested = .directory~new
nested["A"] = .array~of("one", "two")
order~putField("Nested", nested)
order~approval("CreditCheck", .false, "SIGN", "manual review")
order~refer(spareUser, "manager approval")
order~installScriptHandler(.ScriptHandler~new("ONSUBMIT", "return This~document~approvalStatus"))
live~stageSave(order)
seq = live~commitStaged("order-create")
call mirrorCommitted live, spare, seq

spareOrder = spare~document(order~documentId)
call assertEquals "282.00", spareOrder~Amount, "amount replayed"
call assertEquals "Acme", spareOrder~Customer~CompanyName, "active relationship replayed"
call assertEquals "PENDING APPROVAL", spareOrder~approvalStatus, "referral replayed"
call assertEquals 1, spare~referralTray(spareUser)~items, "local referral tray reconstructs"
call assertEquals "bob", spare~currentUser~identity, "local user authority did not travel"
replayedExternal = spare~externalDocument(spareOrder~EvidenceImage~externalId)
call assertEquals x2c("00017FFF80FE"), replayedExternal~content, "external bytes replayed"

/* Direct mutation through the clustered service is fenced while REPLAY. */
fenced = .false
signal on syntax name replayFence
ignore = spare~createDocument("ShouldFail")
signal off syntax
call fail "REPLAY mutation unexpectedly succeeded"
replayFence:
say "EXPECTED REPLAY FENCE rc=" rc "sigl=" sigl "condition=" condition("C") "description=" condition("D")
signal off syntax
fenced = .true
call assertTrue fenced, "REPLAY mutation fenced"

/* Read access on REPLAY must not leak a mutable reference into cluster state. */
replayView = spare~document(order~documentId)
replayView~Amount = "MUTATED-THROUGH-READ"
replayView~Customer~CompanyName = "Mutated Customer"
call assertEquals "282.00", spare~document(order~documentId)~Amount, "REPLAY document accessor is detached"
call assertEquals "Acme", spare~document(order~documentId)~Customer~CompanyName, "REPLAY relationship accessor is detached"

replayDocs = spare~documents
do candidate over replayDocs
  if candidate~documentId = order~documentId then candidate~Amount = "MUTATED-THROUGH-DOCUMENTS"
end
call assertEquals "282.00", spare~document(order~documentId)~Amount, "REPLAY documents collection is detached"

replayTray = spare~referralTray(spareUser)
call assertEquals 1, replayTray~items, "REPLAY detached tray still projects referral"
replayTray[1]~Amount = "MUTATED-THROUGH-TRAY"
call assertEquals "282.00", spare~document(order~documentId)~Amount, "REPLAY referral tray documents are detached"

/* ACTIVE retains live edit semantics for the normal stage/commit workflow. */
liveView = live~document(order~documentId)
liveView~Amount = "283.00"
call assertEquals "283.00", live~document(order~documentId)~Amount, "ACTIVE accessor remains live"
liveView~Amount = "282.00"

/* Speculative replay must be discarded before promotion. */
liveOrder = live~document(order~documentId)
liveOrder~Amount = "999.00"
live~stageSave(liveOrder)
speculative = live~stagedState
call assertTrue spare~applyReplay(speculative, seq + 1, .false), "spare accepts speculative state"
call assertEquals "999.00", spare~document(order~documentId)~Amount, "speculative state visible on replay"
live~rollbackStaged
call assertTrue spare~promote(2), "spare promotes"
call assertEquals "282.00", spare~document(order~documentId)~Amount, "promotion rolls back to committed state"
call assertEquals "bob", spare~currentUser~identity, "promotion preserves spare-local authority"

/* Promoted spare can continue the same logical node without ID collision. */
newDoc = spare~createDocument("AfterFailover")
call assertEquals "branchA/DOC/3", newDoc~documentId, "document counter restored"
newDoc~Marker = "after"
spare~stageSave(newDoc)
newSeq = spare~commitStaged("after-failover")
call assertEquals seq + 2, newSeq, "sequence remains monotonic after speculative rollback"

say "PASS test_rto_clustered_node"
exit 0

mirrorCommitted:
  use arg source, target, sequence
  state = source~rtoExportState
  call assertTrue target~applyReplay(state, sequence, .true), "committed replay accepted"
  return

assertTrue:
  use arg condition, label
  if condition then return
  call fail label
  return

assertEquals:
  use arg expected, actual, label
  if expected == actual then return
  say "EXPECTED=" expected
  say "ACTUAL=" actual
  call fail label
  return

fail:
  use arg message
  say "FAIL" message
  exit 1

::requires "AlchemyNotNotesClustered.cls"
