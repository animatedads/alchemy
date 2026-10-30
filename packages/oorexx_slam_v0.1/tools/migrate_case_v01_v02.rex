/* migrate_case_v01_v02.rex - offence-event case file v0.1 (ChatGPT (GPT-6), commit 48470c08) -> v0.2.
 * Architecture: Tom Dyer.  Migration: Claude (Opus 5.5), 2026-10-30.  Reads and writes JSON with ooRexx's
 * own json.cls.  Every change is listed in the file it writes ("migration"), and in
 * docs/architecture/fixtures/MIGRATION_v0.1_to_v0.2.md, with its reason.  Nothing in v0.1 is deleted: a
 * renamed event type keeps its v0.1 name in "eventTypeV01".
 * Usage: rexx tools/migrate_case_v01_v02.rex v0.1.json v0.2.json
 */
parse arg inFile outFile
inFile = inFile~strip; outFile = outFile~strip
d = .json~fromJsonFile(inFile)
if d['schemaVersion'] \== 'offence-event/0.1-PROPOSAL' then do
  say 'not a v0.1 file:' d['schemaVersion']; exit 1
end
d['schemaVersion'] = 'offence-event/0.2-PROPOSAL'
d['dictionary'] = 'law.kinds 0.2: packages/oorexx_slam_v0.1/tests/law/VOCABULARY.md'
changes = .array~new

/* 1. EV06: T's card was shown to a person.  "Credential" is kept for authenticating to a system. */
do e over d['events']
  if e['eventId'] == 'EV06' & e['eventType'] == 'CREDENTIAL_PRESENTED' then do
    e['eventType'] = 'DOCUMENT_PRESENTED'; e['eventTypeV01'] = 'CREDENTIAL_PRESENTED'
    e['document'] = 'ID_CARD'
    changes~append('EV06 CREDENTIAL_PRESENTED -> DOCUMENT_PRESENTED (an ID card shown to a person is a document; CREDENTIAL_USED is authenticating to a system)')
  end
end

/* 2. Tom Dyer's second message: the withdrawals after death, a source of its own. */
src = .directory~new
src['id'] = 'SOURCE_NARRATIVE_2026_10_30_B'; src['type'] = 'USER_NARRATIVE'; src['recordedDate'] = '2026-10-30'
src['authenticity'] = 'NOT_VALIDATED'; src['probativeScope'] = 'WHAT_USER_REPORTED'
src['text'] = "Once Mrs P dies they keep withdrawing the pension... That's unauthorized access to a computer system"
d['sources']~append(src)
ev = .directory~new
ev['eventId'] = 'EV16'; ev['eventType'] = 'CREDENTIAL_USED'
tm = .directory~new; tm['status'] = 'UNKNOWN'; tm['after'] = 'EV14'; ev['time'] = tm
roles = .directory~new; roles['ACTOR'] = 'THEY'; roles['ACCOUNT_HOLDER'] = 'P'; ev['roles'] = roles
ev['instrument'] = 'PAYMENT_CARD'; ev['function'] = 'CASH_WITHDRAWAL'
ev['repetition'] = 'REPEATED_COUNT_UNKNOWN'
ev['sourceClaimIds'] = .array~of('CLM_EV16')
ev['statementAsReported'] = 'they keep withdrawing the pension'
ev['note'] = 'A series reported as one statement: each withdrawal, once a record shows it, is its own event (partOf EV16). Distinct from EV15, a payment INTO the account.'
d['events']~append(ev)
cl = .directory~new
cl['claimId'] = 'CLM_EV16'; cl['kind'] = 'REPORTED_STATEMENT'; cl['text'] = 'Once Mrs P dies they keep withdrawing the pension'
cl['sourceId'] = 'SOURCE_NARRATIVE_2026_10_30_B'
b = .directory~new; b['eventId'] = 'EV16'; cl['binding'] = b
cl['status'] = 'ALLEGED_UNCORROBORATED'
d['claims']~append(cl)
cl = .directory~new
cl['claimId'] = 'CLM_LEGAL_CMA'; cl['kind'] = 'LEGAL_PROPOSITION'; cl['text'] = "That's unauthorized access to a computer system"
cl['sourceId'] = 'SOURCE_NARRATIVE_2026_10_30_B'; cl['status'] = 'TO_TEST_AGAINST_RULE_PACKS'
d['claims']~append(cl)
changes~append('EV16 CREDENTIAL_USED added: withdrawals after death (Tom Dyer, 2026-10-30); actor THEY, unresolved; a series, count unknown')
changes~append('CLM_LEGAL_CMA added as a LEGAL_PROPOSITION to test, not as a fact')

/* 3. Questions, not events: who made the card; who made each withdrawal. */
d['openQuestions']~append("Who made the ID card shown at EV06, and was it made or authorised by the council? (Tom Dyer, 2026-10-30: 'Fake council iD may be forgery'.) A record of it would be a DOCUMENT_MADE event; none is reported.")
d['openQuestions']~append('Which withdrawals were made after EV14, when, at which machines, and by whom? Resolve THEY for each one.')
changes~append('two open questions added (the card''s maker; each withdrawal''s maker); no DOCUMENT_MADE event is invented')

/* 4. Extent, read from each section's own markup (tests/law/source/MANIFEST_LEGISLATION.md). */
j = d['jurisdiction']
j['screen'] = .array~of('E.W.', 'S.')
j['note'] = 'Place of the events not given. Fraud Act 2006 ss.2-7, Theft Act 1968 ss.1, 21, 24A and Criminal Law Act 1977 s.1 do not extend to Scotland; Computer Misuse Act 1990, FSMA 2000, SSAA 1992 and POCA 2002 sections do. Screen both; a rule pack with no text for an extent is OUT_OF_SCOPE there.'
changes~append('jurisdiction: screen E.W. and S.; extent decides OUT_OF_SCOPE')

mg = .directory~new
mg['from'] = 'offence-event/0.1-PROPOSAL, docs/architecture/fixtures/mrs_p_roof_credit_pension_v0.1.json, commit 48470c08 (ChatGPT (GPT-6))'
mg['by'] = 'Claude (Opus 5.5), 2026-10-30, tools/migrate_case_v01_v02.rex in packages/oorexx_slam_v0.1'
mg['changes'] = changes
d['migration'] = mg
.json~toJsonFile(outFile, d, .true)
say 'wrote' outFile '(' || d['events']~items 'events,' d['claims']~items 'claims,' changes~items 'changes)'
exit 0

::requires 'json.cls'
