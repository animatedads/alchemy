app = .MiniNotesApp~new
app~seedFive

call assertEqual 5, app~allDocuments~items, "five seed documents"

allTable = app~tableFor(app~allDocuments)
call assertEqual 5, allTable~count, "CLI UI table offers all five"

large = app~byKey("PR-1002")
call assertEqual "PENDING APPROVAL", large~ApprovalStatus, "large purchase needs human approval"
call assertTrue app~dependenciesSatisfied(large), "large purchase dependency approved"

security = app~byKey("SEC-2001")
call assertTrue \app~dependenciesSatisfied(security), "security review initially blocked by purchase"

app~tableFor(app~allDocuments)
call assertTrue app~select("PR-1002") \== .nil, "stable key selection"
model = app~documentModel(app~selected)
call assertTrue model~text~pos("GPU build server") > 0, "CLI UI document exposes readable detail"

status = app~decideSelected("APPROVE", "value reviewed")
call assertEqual "APPROVED", status, "purchase approved"
call assertTrue app~dependenciesSatisfied(security), "security dependency becomes satisfied"

app~select("SEC-2001")
status = app~decideSelected("REJECT", "security evidence insufficient")
call assertEqual "REJECTED", status, "security can be rejected"
release = app~byKey("REL-3001")
call assertTrue \app~dependenciesSatisfied(release), "release blocked by rejected dependency"

pending = app~query("pending")
call assertEqual 1, pending~items, "one pending release after rejection"
purchases = app~query("purchase")
call assertEqual 2, purchases~items, "purchase subset"
largePurchases = app~query("purchase > 1000")
call assertEqual 1, largePurchases~items, "numeric subset query"
nonsense = app~query("nonexistent")
call assertEqual 0, nonsense~items, "unknown term must not degrade to all documents"
mixedNonsense = app~query("purchase nonexistent")
call assertEqual 0, mixedNonsense~items, "unknown term composes with structured filter"
freeText = app~query("gpu")
call assertEqual 2, freeText~items, "free-text title search"
freeTextSubset = app~query("security gpu")
call assertEqual 1, freeTextSubset~items, "free-text plus document type"
lunar = app~query("lunar base not present")
call assertEqual 0, lunar~items, "multiword absent text returns no matches"
releasePending = app~viewDocuments("release pending")
call assertEqual 1, releasePending~items, "registered release view plus status subset"
viewPurchases = app~viewDocuments("purchase")
call assertEqual 2, viewPurchases~items, "registered purchase view subset"
viewPendingPurchases = app~viewDocuments("purchase pending")
call assertEqual 0, viewPendingPurchases~items, "registered view plus status subset after approval"

created = app~createFromCommand("purchase|AI lab storage|2500|SUP-001")
call assertTrue created \== .nil, "create purchase"
call assertEqual "PENDING APPROVAL", created~ApprovalStatus, "created value-driven workflow"
call assertTrue created~DocKey~left(3) = "PR-", "created stable key"

createdAuto = app~createFromCommand("purchase|USB adapters|95|SUP-001")
call assertEqual "APPROVED", createdAuto~ApprovalStatus, "small created purchase auto-approved"

say "PASS test_mini_notes"
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

::requires 'src/MiniNotesApp.cls'
