parse source . . here
call directory here
call test_relation_notam_v014
say "PASS test_relation_notam_v014"
exit 0

test_relation_notam_v014:
  journalRoot = civicTestTempDir("civic_notam_relation_journal")
  dbRoot = civicNoSQLCreateBlankDatabase("civic-notam-v014")
  journal = .CivicQueueJournal~new(journalRoot)
  body = readBinary("fixtures/faa_swim_aim_fns_jyr.xml")
  valid = civicNotamTestQueueDocument(body, "ID:NOTAM:SQL:1")
  validAppend = journal~append(valid)
  call assertTrue validAppend~ok, "valid NOTAM evidence journalled"
  unsupported = civicNotamTestQueueDocument(body~changestr("RWY 17/35 CLSD", "TWY A CLSD"), "ID:NOTAM:SQL:2")
  unsupportedAppend = journal~append(unsupported)
  call assertTrue unsupportedAppend~ok, "unsupported evidence journalled"

  provider = .CivicNotamRelationProvider~new(journal, .DatabaseResult, .TableDefinition)
  definition = provider~defineRunwayClosureRelation("civic_notam_runway_closure")
  fed = .FederatedDatabaseEngine~new(dbRoot)
  ignore = fed~addEngine(provider)

  catalog = fed~readCatalog
  call assertTrue contains(catalog["tables"], "civic_notam_runway_closure"), "NOTAM evidence table discoverable"
  meta = fed~tableMetadata("civic_notam_runway_closure")
  call assertEqual 27, meta~columns~items, "NOTAM relation exposes explicit evidence columns"
  call assertTrue fed~tableRowCount("civic_notam_runway_closure") == .nil, "unmaterialized journal snapshot row count unknown"

  bad = fed~execute("UPDATE civic_notam_runway_closure SET condition='OPEN' WHERE affected_location='JYR'")
  call assertEqual .Error~SQLUNSUPPORTED, bad~error, "NOTAM evidence relation mutation unsupported"
  call assertTrue fed~tableRowCount("civic_notam_runway_closure") == .nil, "rejected mutation does not snapshot journal"

  query = fed~execute("SELECT affected_location, runway_designator, condition, effective_start_token, effective_end_token, end_qualifier, mapping_generation, operational_disposition, queue_journal_record_id, source_identity FROM civic_notam_runway_closure")
  call assertEqual .Error~SUCCESS, query~status, "NOTAM evidence SELECT succeeds"
  call assertEqual 1, query~rows~items, "typed runway-closure relation returns only supported projection"
  row = query~rows[1]
  call assertEqual "JYR", row["affected_location"], "affected location projected"
  call assertEqual "17/35", row["runway_designator"], "runway projected"
  call assertEqual "CLSD", row["condition"], "closure token retained"
  call assertEqual "2608261100", row["effective_start_token"], "start remains lexical"
  call assertEqual "2608270001", row["effective_end_token"], "end remains lexical"
  call assertEqual "EXACT", row["end_qualifier"], "end qualifier retained"
  call assertEqual "faa.swim.aim-fns.notam-runway-closure/0.1", row["mapping_generation"], "mapping generation visible"
  call assertEqual "EVIDENCE_ONLY_NOT_FOR_OPERATIONAL_USE", row["operational_disposition"], "SQL cannot hide non-operational disposition"
  call assertEqual validAppend~record~recordId, row["queue_journal_record_id"], "SQL traces exact Civic queue journal record"
  call assertEqual valid~sourceIdentity, row["source_identity"], "SQL traces exact JMS source identity"
  call assertEqual "CIVIC_QUEUE_EVIDENCE_SNAPSHOT_SCAN", query~accessPath, "queue-evidence snapshot access path explicit"

  diagnostics = provider~diagnostics("civic_notam_runway_closure")
  call assertEqual 1, diagnostics~items, "unsupported source remains inspectable beside typed relation"
  call assertEqual "NOTAM_KEYWORD_UNSUPPORTED", diagnostics[1]~errorCode, "typed relation diagnostic identifies unsupported form"

  /* The first SELECT freezes the relation snapshot. */
  later = civicNotamTestQueueDocument(body, "ID:NOTAM:SQL:LATER", "2026-08-28T12:05:01Z")
  laterAppend = journal~append(later)
  call assertTrue laterAppend~ok, "later evidence appended after SQL snapshot"
  again = fed~execute("SELECT affected_location FROM civic_notam_runway_closure")
  call assertEqual 1, again~rows~items, "existing relation does not absorb later journal records"
  call assertEqual 1, fed~tableRowCount("civic_notam_runway_closure"), "materialized snapshot row count stable"

  richRows = provider~table("civic_notam_runway_closure")~readRows
  call assertEqual 1, richRows~items, "rich NOTAM row retained"
  rich = richRows[1]
  call assertTrue rich~journalProjection~projection~isA(.CivicNotamRunwayClosureProjection), "rich row retains native NOTAM projection"
  call assertTrue rich~sourceFor("runway_designator") == rich~journalProjection~projection, "cell source is native NOTAM evidence"
  call assertEqual validAppend~record~recordId, rich~provenance["queueJournalRecordId"], "rich provenance reaches durable journal record"

  /* A fresh relation instance sees the later record, proving snapshot rather than journal mutation. */
  provider2 = .CivicNotamRelationProvider~new(journal, .DatabaseResult, .TableDefinition)
  ignore = provider2~defineRunwayClosureRelation("civic_notam_runway_closure_2")
  call assertEqual 2, provider2~table("civic_notam_runway_closure_2")~readRows~items, "fresh relation sees current durable journal"

  ignore = civicNoSQLRemoveDatabase(dbRoot)
  return civicTestRemoveTree(journalRoot)

contains: procedure
  use arg items, wanted
  do item over items
    if item~caselessEquals(wanted) then return .true
  end
  return .false

civicNoSQLCreateBlankDatabase: procedure
  use arg label
  target = SysTempFileName("/tmp/nosqlserver-" || label || "-??????")
  if SysMkDir(target) \= 0 then raise syntax 93.900 additional("Unable to create test root:" target)
  if SysMkDir(target || "/tables") \= 0 then raise syntax 93.900 additional("Unable to create test tables directory:" target)
  catalogPath = target || "/database.yaml"
  call lineout catalogPath, "name: " || label
  call lineout catalogPath, "formatVersion: 1"
  call lineout catalogPath, "tables: []"
  call lineout catalogPath
  return target

civicNoSQLRemoveDatabase: procedure
  use arg target
  if target = "" then return 0
  call SysFileTree target || "/*", "files.", "FOS"
  do i = 1 to files.0
    call SysFileDelete files.i
  end
  call SysFileTree target || "/*", "dirs.", "DOS"
  do i = dirs.0 to 1 by -1
    call SysRmDir dirs.i
  end
  call SysRmDir target
  return 0

::requires "NoSQLServer.cls"
::requires "TestSupport.cls"
::requires "CacheTestSupport.cls"
::requires "NotamTestSupport.cls"
::requires "CivicNotamRelation.cls"
