t = .AccountingTest~new
numeric digits 50

entity = "ANGLO_AUSTRALIAN_LAW_LLP"
book = .AccountingBook~new(entity, "FIRM-STAT", "ENTITY_GAAP")
book~addAccount(.AccountingAccount~new("1100", "Client bank", "ASSET", "AUTO", "SINGLE", .true, "GBP"))
book~addAccount(.AccountingAccount~new("2100", "Client money liability", "LIABILITY", "AUTO", "SINGLE", .true, "GBP"))
book~addAccount(.AccountingAccount~new("1000", "Operating cash", "ASSET", "AUTO", "SINGLE", .true, "GBP"))
book~addAccount(.AccountingAccount~new("4000", "Fees", "REVENUE", "AUTO", "SINGLE", .true, "GBP"))
book~sealChart
book~addPeriod(.AccountingPeriod~new("2026", "2026-01-01", "2026-12-31"))
book~addPeriod(.AccountingPeriod~new("2027", "2027-01-01", "2027-12-31"))

call postClient book, "CLIENT:1", "2026-06-01", "2026", "CLIENT-GB-01", "000123", "100000"
call postOperating book, "OPERATING:1", "2026-06-02", "2026", "50000"

t~assertEq("2", book~entryCount, "fixture has two source entries")

selectors = .directory~new
selectors[.AccountingDimensionKeys~CLIENT_MONEY_ARRANGEMENT_REF] = .array~of("CLIENT-GB-01")
boundary = .AccountingReportingBoundary~new("BOUNDARY-CLIENT-2026", "PROFESSIONAL-REGULATOR", "CLIENT_ACCOUNT_POSITION", "2026-01-01", "2026-12-31", .array~of(entity), .array~of("FIRM-STAT"), selectors, "client.report/0.2", "sha256:client-report-policy-v2")
books = .array~of(book)
meta = .directory~new
meta["reporting.purpose"] = "annual-client-account-assessment"
snapshot = .AccountingReportingService~sealSnapshot("SNAP-CLIENT-2026", boundary, books, "2026-01-01", "2026-12-31", "REPORT-SEAL-001", .array~of("EVIDENCE:REGULATOR:REQUEST:001"), meta)

t~assertEq("accounting.reporting.snapshot/0.1", .AccountingBuild~REPORTING_SNAPSHOT_API, "snapshot API is explicit and additive")
t~assertEq("2", snapshot~lineCount, "snapshot contains only client-money lines")
t~assertEq("2", snapshot~sourceBookStates[1]~entryCount, "source state seals complete source journal population")
t~assertTrue(snapshot~fingerprint \= "", "snapshot has deterministic evidential fingerprint")
t~assertEq(snapshot~fingerprint, snapshot~projection["fingerprint"], "projection carries exact snapshot fingerprint")
t~assertEq("accounting.reporting.snapshot/0.1", snapshot~projection["api"], "projection names snapshot contract")
engineFacade = .AccountingEngine~new(entity, "FIRM-STAT", "ENTITY_GAAP", book)
facadeSnapshot = engineFacade~reportingSnapshot("SNAP-FACADE", boundary, "2026-01-01", "2026-12-31", "REPORT-SEAL-FACADE")
t~assertEq("2", facadeSnapshot~lineCount, "AccountingEngine exposes native-book snapshot facade")
t~assertEq(boundary~fingerprint, facadeSnapshot~boundaryFingerprint, "facade snapshot retains exact boundary identity")

groups = snapshot~totalsByDimensions(.array~of(.AccountingDimensionKeys~MATTER_REF))
t~assertEq("1", groups~items, "dimension aggregation groups the retained client matter")
do groupKey over groups
  row = groups[groupKey]
  t~assertEq("000123", row["dimensions"][.AccountingDimensionKeys~MATTER_REF], "leading-zero matter identity retained in reporting aggregation")
  t~assertEq("100000", row["debit_minor"], "matter debit total retained")
  t~assertEq("100000", row["credit_minor"], "matter credit total retained")
end

verify = .AccountingReportingService~verifySnapshot(snapshot, boundary, books)
t~assertTrue(verify~ok, "fresh snapshot verifies")
t~assertEq("VALID", verify~status, "unchanged source population is exact-valid")

/* Later journal outside the report period does not invalidate the historical
 * population, but verification records that the source book has advanced. */
call postClient book, "CLIENT:2027", "2027-01-05", "2027", "CLIENT-GB-01", "000123", "25000"
verify = .AccountingReportingService~verifySnapshot(snapshot, boundary, books)
t~assertTrue(verify~ok, "out-of-period source advance does not stale snapshot")
t~assertEq("VALID_SOURCE_ADVANCED", verify~status, "source advance is visible")
t~assertEq("2", snapshot~sourceBookStates[1]~entryCount, "sealed source cutoff does not move with live book")

/* A later in-period journal outside the selected dimensions also does not
 * alter the sealed report population. */
call postOperating book, "OPERATING:LATE", "2026-08-01", "2026", "1200"
verify = .AccountingReportingService~verifySnapshot(snapshot, boundary, books)
t~assertTrue(verify~ok, "backdated out-of-scope journal does not stale client report")
t~assertEq("VALID_SOURCE_ADVANCED", verify~status, "out-of-scope backdating remains visible as source advance")

/* A backdated in-scope journal changes the population the regulator would
 * have seen, and therefore makes the prior snapshot stale. */
call postClient book, "CLIENT:LATE", "2026-08-02", "2026", "CLIENT-GB-01", "000999", "7000"
verify = .AccountingReportingService~verifySnapshot(snapshot, boundary, books)
t~assertTrue(\verify~ok, "backdated in-scope journal stales sealed report")
t~assertEq("REPORT_POPULATION_STALE", verify~errorCode, "stale population has explicit code")

changedBoundary = .AccountingReportingBoundary~new("BOUNDARY-CLIENT-2026", "PROFESSIONAL-REGULATOR", "CLIENT_ACCOUNT_POSITION", "2026-01-01", "2026-12-31", .array~of(entity), .array~of("FIRM-STAT"), selectors, "client.report/0.2", "sha256:DIFFERENT-POLICY")
verify = .AccountingReportingService~verifySnapshot(snapshot, changedBoundary, books)
t~assertEq("BOUNDARY_MISMATCH", verify~errorCode, "boundary/policy identity cannot be substituted after seal")

verify = .AccountingReportingService~verifySnapshot(snapshot, boundary, .array~new)
t~assertEq("SOURCE_BOOK_MISSING", verify~errorCode, "missing source book is explicit")

/* Reconstructed source with the same book identity but different first journal
 * cannot satisfy the sealed entry fingerprints. */
replacement = .ReportingSnapshotTest~replacementBook(entity)
verify = .AccountingReportingService~verifySnapshot(snapshot, boundary, .array~of(replacement))
t~assertEq("SOURCE_ENTRY_MISMATCH", verify~errorCode, "same book id with changed history is rejected")

/* A newly supplied book which falls inside an unrestricted book boundary is a
 * changed source population rather than silently becoming part of an old seal. */
wideBoundary = .AccountingReportingBoundary~new("BOUNDARY-WIDE", "BOARD", "MANAGEMENT_ACCOUNTS", "2026-01-01", "2026-12-31", .array~of(entity), .array~new)
wideSnapshot = .AccountingReportingService~sealSnapshot("SNAP-WIDE", wideBoundary, .array~of(replacement), "2026-01-01", "2026-12-31", "REPORT-SEAL-WIDE")
otherBook = .AccountingBook~new(entity, "SECONDARY", "ENTITY_GAAP")
otherBook~addAccount(.AccountingAccount~new("1000", "Cash", "ASSET", "AUTO", "SINGLE", .true, "GBP"))
otherBook~addAccount(.AccountingAccount~new("4000", "Fees", "REVENUE", "AUTO", "SINGLE", .true, "GBP"))
otherBook~sealChart
otherBook~addPeriod(.AccountingPeriod~new("2026", "2026-01-01", "2026-12-31"))
verify = .AccountingReportingService~verifySnapshot(wideSnapshot, wideBoundary, .array~of(replacement, otherBook))
t~assertEq("SOURCE_BOOK_SET_CHANGED", verify~errorCode, "new in-boundary source book cannot silently enter old snapshot")

/* A reporting boundary may span more than one legal entity without merging
 * their identities. This is selection/reporting, not consolidation by fiat. */
affiliate = .AccountingBook~new("PARIS_LAW_SEPARATE_SARL", "FR-STAT", "ENTITY_GAAP")
affiliate~addAccount(.AccountingAccount~new("1000", "Cash", "ASSET", "AUTO", "SINGLE", .true, "EUR"))
affiliate~addAccount(.AccountingAccount~new("4000", "Fees", "REVENUE", "AUTO", "SINGLE", .true, "EUR"))
affiliate~sealChart
affiliate~addPeriod(.AccountingPeriod~new("2026", "2026-01-01", "2026-12-31"))
affDraft = .AccountingJournalDraft~new("FR:1", "2026-06-03", "2026", "fixture/0.1", "French fees")
affDraft~addLine(.AccountingJournalLine~new("1000", "EUR", "20000", 0, "cash"))
affDraft~addLine(.AccountingJournalLine~new("4000", "EUR", 0, "20000", "fees"))
affiliate~post(affDraft)
multiBoundary = .AccountingReportingBoundary~new("BOUNDARY-MULTI-ENTITY", "GROUP-REGULATOR", "HOLISTIC_POSITION", "2026-01-01", "2026-12-31", .array~of(entity, "PARIS_LAW_SEPARATE_SARL"), .array~new)
multiSnapshot = .AccountingReportingService~sealSnapshot("SNAP-MULTI", multiBoundary, .array~of(replacement, affiliate), "2026-01-01", "2026-12-31", "REPORT-SEAL-MULTI")
t~assertEq("2", multiSnapshot~sourceBookStates~items, "multi-entity report retains two independent source books")
t~assertEq("6", multiSnapshot~lineCount, "multi-entity report selects both books without reposting")
seenFirm = .false; seenParis = .false
do line over multiSnapshot~lines
  if line~legalEntityId = entity then seenFirm = .true
  if line~legalEntityId = "PARIS_LAW_SEPARATE_SARL" then seenParis = .true
end
t~assertTrue(seenFirm, "original legal entity identity retained in snapshot lines")
t~assertTrue(seenParis, "second legal entity identity retained rather than collapsed")

say "reporting snapshot assertions=" t~assertions "failures=" t~failures
if t~failures > 0 then exit 1
exit 0

postClient:
  use arg book, sourceRef, postingDate, periodId, arrangementRef, matterRef, amount
  dims = .directory~new
  dims[.AccountingDimensionKeys~CLIENT_MONEY_ARRANGEMENT_REF] = arrangementRef
  dims[.AccountingDimensionKeys~MATTER_REF] = matterRef
  draft = .AccountingJournalDraft~new(sourceRef, postingDate, periodId, "fixture/0.1", "client money")
  draft~addLine(.AccountingJournalLine~new("1100", "GBP", amount, 0, "client bank", dims))
  draft~addLine(.AccountingJournalLine~new("2100", "GBP", 0, amount, "client liability", dims))
  result = book~post(draft)
  if \result~ok then raise syntax 93.900 additional("fixture client posting failed: " || result~errorCode)
return

postOperating:
  use arg book, sourceRef, postingDate, periodId, amount
  draft = .AccountingJournalDraft~new(sourceRef, postingDate, periodId, "fixture/0.1", "operating")
  draft~addLine(.AccountingJournalLine~new("1000", "GBP", amount, 0, "cash"))
  draft~addLine(.AccountingJournalLine~new("4000", "GBP", 0, amount, "fees"))
  result = book~post(draft)
  if \result~ok then raise syntax 93.900 additional("fixture operating posting failed: " || result~errorCode)
return

::class ReportingSnapshotTest
::method replacementBook class
  use arg entity
  book = .AccountingBook~new(entity, "FIRM-STAT", "ENTITY_GAAP")
  book~addAccount(.AccountingAccount~new("1100", "Client bank", "ASSET", "AUTO", "SINGLE", .true, "GBP"))
  book~addAccount(.AccountingAccount~new("2100", "Client money liability", "LIABILITY", "AUTO", "SINGLE", .true, "GBP"))
  book~addAccount(.AccountingAccount~new("1000", "Operating cash", "ASSET", "AUTO", "SINGLE", .true, "GBP"))
  book~addAccount(.AccountingAccount~new("4000", "Fees", "REVENUE", "AUTO", "SINGLE", .true, "GBP"))
  book~sealChart
  book~addPeriod(.AccountingPeriod~new("2026", "2026-01-01", "2026-12-31"))
  dims = .directory~new
  dims[.AccountingDimensionKeys~CLIENT_MONEY_ARRANGEMENT_REF] = "CLIENT-GB-01"
  dims[.AccountingDimensionKeys~MATTER_REF] = "000123"
  draft = .AccountingJournalDraft~new("CLIENT:1", "2026-06-01", "2026", "fixture/0.1", "client money")
  draft~addLine(.AccountingJournalLine~new("1100", "GBP", "99999", 0, "client bank", dims))
  draft~addLine(.AccountingJournalLine~new("2100", "GBP", 0, "99999", "client liability", dims))
  book~post(draft)
  draft = .AccountingJournalDraft~new("OPERATING:1", "2026-06-02", "2026", "fixture/0.1", "operating")
  draft~addLine(.AccountingJournalLine~new("1000", "GBP", "50000", 0, "cash"))
  draft~addLine(.AccountingJournalLine~new("4000", "GBP", 0, "50000", "fees"))
  book~post(draft)
  return book

::options digits 50
::requires "AccountingEngine.cls"
::requires "TestSupport.cls"
