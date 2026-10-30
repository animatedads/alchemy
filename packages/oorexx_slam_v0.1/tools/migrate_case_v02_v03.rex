/* migrate_case_v02_v03.rex - offence-event case file v0.2 -> v0.3: Tom Dyer's third account (2026-10-30):
 * a refund cheque in 2008, dishonoured three times; the tile removal from 2009; Mr P's injury in 2009.
 * Architecture: Tom Dyer.  Migration: Claude (Opus 5.5), 2026-10-30.  json.cls (ooRexx).  Nothing in v0.2 is
 * deleted.  Who wrote the cheque and who let the tile fall are not stated: they stay UNRESOLVED, and are open
 * questions; the screen must not fill them in.
 * Usage: rexx tools/migrate_case_v02_v03.rex v0.2.json v0.3.json
 */
parse arg inFile outFile
inFile = inFile~strip; outFile = outFile~strip
d = .json~fromJsonFile(inFile)
if d['schemaVersion'] \== 'offence-event/0.2-PROPOSAL' then do
  say 'not a v0.2 file:' d['schemaVersion']; exit 1
end
d['schemaVersion'] = 'offence-event/0.3-PROPOSAL'
d['dictionary'] = 'law.kinds 0.4: packages/oorexx_slam_v0.1/tests/law/VOCABULARY.md'
changes = .array~new
SOURCEID = 'SOURCE_NARRATIVE_2026_10_30_C'

src = .directory~new
src['id'] = SOURCEID; src['type'] = 'USER_NARRATIVE'; src['recordedDate'] = '2026-10-30'
src['authenticity'] = 'NOT_VALIDATED'; src['probativeScope'] = 'WHAT_USER_REPORTED'
src['text'] = "let's add a failed refund to Mrs P when her son Mr P complained in 2008. The refund was by cheque / check and it bounced, three times. She forgot it. Silly old dear. Mr P was hit on the head by a falling roof tile whilst they began the 6 year process of removing the tiles from her house and lost the power of communication in 2009."
d['sources']~append(src)

en = .directory~new; en['id'] = 'SON_P'; en['type'] = 'PERSON'; en['label'] = 'Mr P (Mrs P''s son)'
d['entities']~append(en)
changes~append('entity SON_P added: Mr P, Mrs P''s son')

call addEvent 'EV20', 'MESSAGE_SENT', '2008', roles('SPEAKER', 'SON_P', 'RECIPIENT', 'UNRESOLVED'), 'Mr P complained in 2008', 'To whom is not stated.'
call addEvent 'EV21', 'CHEQUE_DRAWN', '2008', roles('DRAWER', 'UNRESOLVED', 'RECIPIENT', 'P'), 'a refund to Mrs P, by cheque', 'Who wrote the cheque, and on what account, is not stated.'
call addEvent 'EV22', 'CHEQUE_DISHONOURED', '2008', roles('RECIPIENT', 'P'), 'it bounced, three times', 'A series: three dishonours, EV22.1 to EV22.3.'
do n = 1 to 3
  call addEvent 'EV22.' || n, 'CHEQUE_DISHONOURED', '2008', roles('RECIPIENT', 'P'), 'bounce' n 'of 3', 'partOf EV22'
  d['events'][d['events']~items]['partOf'] = 'EV22'
end
call addEvent 'EV23', 'PERSON_INJURED', '2009', roles('TARGET', 'SON_P', 'ACTOR', 'UNRESOLVED'), 'Mr P was hit on the head by a falling roof tile', 'During the tile removal (EV10). Who, if anyone, let it fall is not stated ("they").'
d['events'][d['events']~items]['outcomeAsReported'] = 'lost the power of communication, in 2009'
changes~append('events EV20 (complaint), EV21 (refund cheque), EV22 with EV22.1-3 (three dishonours), all 2008; EV23 (Mr P injured), 2009')

/* EV10, the roof removal: the third account dates it */
do e over d['events']
  if e['eventId'] == 'EV10' then do
    tm = .directory~new; tm['status'] = 'YEAR_ONLY'; tm['value'] = '2009'
    tm['note'] = 'began in 2009; "the 6 year process of removing the tiles" (SOURCE_NARRATIVE_2026_10_30_C)'
    e['time'] = tm
    changes~append('EV10 time: UNKNOWN -> began 2009, six years (from the third account)')
  end
end

call addClaim 'CLM_FORGOT', 'REPORTED_ATTRIBUTE', 'She forgot it', 'P', 'Not evidence of incapacity at any time (contract Q4); it may bear on why the refund was not pursued.'
call addClaim 'CLM_SON_COMMUNICATION', 'REPORTED_ATTRIBUTE', 'Mr P lost the power of communication in 2009', 'SON_P', 'If so, he cannot give evidence: his 2008 complaint survives only as a record, if one exists.'
changes~append('claims: she forgot the refund (P); Mr P lost the power of communication (SON_P)')

d['openQuestions']~append('Who wrote the refund cheque (EV21), on whose account, and why was it dishonoured each time (no funds, stopped, closed account)? Bank records for EV22.1-3.')
d['openQuestions']~append('To whom did Mr P complain in 2008 (EV20), and is there a record of it?')
d['openQuestions']~append('Who was removing the tiles when one fell on Mr P (EV23), how did it fall, and what do the medical records say of his injury?')
d['openQuestions']~append('Where was Mrs P''s house? The 2008-2009 events need the law of that place and of that date: in NSW, Crimes Act ss.192B-192M were inserted by Act 2009 No 99, and the old s.178B (valueless cheques) repealed by it.')
changes~append('four open questions added: the cheque, the complaint, the injury, the place and date of the law')

mg = d['migration']
prev = .directory~new; prev['from'] = mg['from']; prev['by'] = mg['by']; prev['changes'] = mg['changes']
mg = .directory~new
mg['from'] = 'offence-event/0.2-PROPOSAL, docs/architecture/fixtures/mrs_p_roof_credit_pension_v0.2.json'
mg['by'] = 'Claude (Opus 5.5), 2026-10-30, tools/migrate_case_v02_v03.rex in packages/oorexx_slam_v0.1'
mg['changes'] = changes
mg['previous'] = prev
d['migration'] = mg
.json~toJsonFile(outFile, d, .true)
say 'wrote' outFile '(' || d['events']~items 'events,' d['claims']~items 'claims,' changes~items 'changes)'
exit 0

roles: procedure
  r = .directory~new
  do i = 1 to arg() by 2; r[arg(i)] = arg(i + 1); end
  return r

addEvent: procedure expose d SOURCEID
  use arg id, type, year, rl, said, note
  e = .directory~new
  e['eventId'] = id; e['eventType'] = type
  tm = .directory~new; tm['status'] = 'YEAR_ONLY'; tm['value'] = year; e['time'] = tm
  e['roles'] = rl
  e['sourceClaimIds'] = .array~of('CLM_' || id~changeStr('.', '_'))
  e['statementAsReported'] = said; e['note'] = note
  d['events']~append(e)
  c = .directory~new
  c['claimId'] = 'CLM_' || id~changeStr('.', '_'); c['kind'] = 'REPORTED_STATEMENT'; c['text'] = said
  c['sourceId'] = SOURCEID
  b = .directory~new; b['eventId'] = id; c['binding'] = b
  c['status'] = 'ALLEGED_UNCORROBORATED'
  d['claims']~append(c)
  return

addClaim: procedure expose d SOURCEID
  use arg id, kind, text, subject, note
  c = .directory~new
  c['claimId'] = id; c['kind'] = kind; c['text'] = text; c['subject'] = subject
  c['sourceId'] = SOURCEID; c['status'] = 'ALLEGED_UNCORROBORATED'; c['note'] = note
  d['claims']~append(c)
  return

::requires 'json.cls'
