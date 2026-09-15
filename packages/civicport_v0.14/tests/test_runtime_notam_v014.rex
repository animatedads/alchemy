parse source . . here
call directory here

contract = .CivicNotamApiContract~new
call assertEqual "civic.notam.runway-closure.evidence/0.1", contract~contractGeneration, "NOTAM Runtime contract generation pinned"
call assertEqual "faa.swim.aim-fns.notam-runway-closure/0.1", contract~mappingGeneration, "NOTAM Runtime mapping generation pinned"
call assertEqual "civic.notam.runway-closure.evidence", contract~abilityId, "NOTAM Runtime ability id pinned"

descriptor = contract~descriptor("civic")
call assertTrue descriptor~readOnly, "NOTAM Runtime ability read only"
good = .directory~new
good["source_identity"] = .JsonString~new("JMS:source:test")
call assertTrue descriptor~validateInput(good)~ok, "exact source identity input validates"
do forbidden over .array~of("queue_name", "journal_root", "url", "credential_reference", "jms_selector")
  injected = good~copy
  injected[forbidden] = "forbidden"
  checked = descriptor~validateInput(injected)
  call assertTrue \checked~ok, "NOTAM Runtime API rejects caller property " || forbidden
  call assertEqual "ABILITY_SCHEMA_ADDITIONAL_PROPERTY", checked~code, "transport/storage selector rejected by exact schema"
end

journalRoot = civicTestTempDir("civic_notam_runtime_v014")
journal = .CivicQueueJournal~new(journalRoot)
body = readBinary("fixtures/faa_swim_aim_fns_jyr.xml")
queueDoc = civicNotamTestQueueDocument(body, "ID:NOTAM:RUNTIME:1")
appended = journal~append(queueDoc)
call assertTrue appended~ok, "Runtime fixture evidence journalled"
projectedOutcome = .CivicNotamJournalProjector~new~projectSource(journal, queueDoc~sourceIdentity)
call assertTrue projectedOutcome~ok, "Runtime source identity resolves to typed projection"
projection = projectedOutcome~journalProjection~projection
output = contract~projectProjection(projection, appended~record~recordId)
outputCheck = descriptor~validateOutput(output)
call assertTrue outputCheck~ok, "NOTAM evidence satisfies exact Runtime output schema"
call assertEqual "civic.notam.runway-closure.evidence/0.1", output["contract_generation"], "Runtime output contract generation explicit"
call assertEqual "faa.swim.aim-fns.notam-runway-closure/0.1", output["mapping_generation"], "Runtime output mapping generation explicit"
call assertEqual queueDoc~sourceIdentity, output["source_identity"], "Runtime output traces exact source identity"
call assertEqual appended~record~recordId, output["queue_journal_record_id"], "Runtime output traces exact durable journal record"
call assertEqual queueDoc~evidenceIdentity, output["queue_evidence_identity"], "Runtime output traces exact queue evidence"
call assertEqual queueDoc~bodyDigest, output["body_sha512"], "Runtime output carries source-body SHA-512"
call assertEqual "2608261100", output["effective_start_token"], "Runtime keeps start token lexical"
call assertEqual "2608270001", output["effective_end_token"], "Runtime keeps end token lexical"
call assertTrue output["effective_start_token"]~isA(.String), "Runtime start remains ooRexx String"
call assertTrue output["effective_end_token"]~isA(.String), "Runtime end remains ooRexx String"
call assertEqual "NOT_FOR_OPERATIONAL_USE", output["use_classification"], "Runtime output carries use restriction"
call assertEqual "EVIDENCE_ONLY_NOT_FOR_OPERATIONAL_USE", output["operational_disposition"], "Runtime output cannot masquerade as operational fact"
call assertTrue \output~hasIndex("active"), "Runtime contract does not infer active status"
call assertTrue \output~hasIndex("effective_start_datetime"), "Runtime contract does not infer century/time object"

pin = contract~profilePin("civic-test-client", "1", "civic", "tests/RuntimeCivicContractFixture_v1.cls", "notam-evidence-handler-v1")
call assertEqual "civicport-notam-runway-closure", pin~profile~profileId, "NOTAM Runtime profile has distinct family"
call assertTrue pin~profile~canonicalText~pos("NOT FOR OPERATIONAL USE") > 0, "profile canonical evidence retains operational restriction"

say "PASS test_runtime_notam_v014"
call civicTestRemoveTree journalRoot
exit 0

::requires "TestSupport.cls"
::requires "CacheTestSupport.cls"
::requires "NotamTestSupport.cls"
::requires "CivicNotamJournal.cls"
::requires "CivicNotamRuntime.cls"
