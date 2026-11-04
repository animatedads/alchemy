/* migrate_case_v03_v04.rex - offence-event case file v0.3 -> v0.4: Tom Dyer's fourth account (2026-10-30):
 * Mr H wrote the cheque; Mr M, a worker for the roofers, threw the tile; his previous convictions; a brick
 * thrown at a cat that day; two interviews that disagree about why.
 * Architecture: Tom Dyer.  Migration: Claude (Opus 5.5), 2026-10-30.  json.cls (ooRexx).  Nothing in v0.3 is
 * deleted.  Where the accounts disagree (the tile "hit Mr B"; account C and the rest of account D say Mr P),
 * both are kept and the disagreement is recorded in "conflicts": the case does not choose.
 * Usage: rexx tools/migrate_case_v03_v04.rex v0.3.json v0.4.json
 */
parse arg inFile outFile
inFile = inFile~strip; outFile = outFile~strip
d = .json~fromJsonFile(inFile)
if d['schemaVersion'] \== 'offence-event/0.3-PROPOSAL' then do
  say 'not a v0.3 file:' d['schemaVersion']; exit 1
end
d['schemaVersion'] = 'offence-event/0.4-PROPOSAL'
d['dictionary'] = 'law.kinds 0.5: packages/oorexx_slam_v0.1/tests/law/VOCABULARY.md'
changes = .array~new
SOURCEID = 'SOURCE_NARRATIVE_2026_10_30_D'

rec = .directory~new
rec['id'] = SOURCEID; rec['type'] = 'USER_NARRATIVE'; rec['recordedDate'] = '2026-10-30'
rec['authenticity'] = 'NOT_VALIDATED'; rec['probativeScope'] = 'WHAT_USER_REPORTED'
rec['text'] = 'Mr H wrote the cheque check. The worker Mr M working for the roofers threw the tile which hit Mr B he had 15 years of priors for threats with menaces, and assault, including theft of a mailbag when he was working for the postal service. On the day in question he was seen throwing a brick at a cat. He claims to have a hatred of cats, and ethnic minorities, and thought Mr P might be Asian when questioned. He has since recanted that evidence at second interview and now claims that he thought Mr P was a crazy cat.'
d['sources']~append(rec)

call entity 'M', 'PERSON', 'Mr M, a worker for the roofers'
call entity 'B', 'PERSON', 'Mr B: named once, as the person the tile hit (see conflicts)'
call entity 'CAT', 'ANIMAL', 'a cat'
changes~append('entities M (Mr M), B (Mr B, named once), CAT')

do e over d['events']
  select
    when e['eventId'] == 'EV21' then do
      e['roles']['DRAWER'] = 'H'
      e['note'] = 'Account D names Mr H as the drawer (alleged); account C did not say. Whose account it was drawn on is still not stated.'
      e['sourceClaimIds']~append('CLM_EV21_DRAWER')
    end
    when e['eventId'] == 'EV23' then do
      e['roles']['ACTOR'] = 'M'
      e['howAsReported'] = 'account C: "hit on the head by a falling roof tile"; account D: Mr M "threw the tile"'
      e['sourceClaimIds']~append('CLM_D_THROWN')
    end
    otherwise nop
  end
end
changes~append('EV21 DRAWER: UNRESOLVED -> H (account D); EV23 ACTOR: UNRESOLVED -> M, thrown not fallen (account D)')

call addEvent 'EV24', 'OBJECT_THROWN', '2009', roles('ACTOR', 'M'), 'Mr M threw the tile', 'The act behind EV23. Who it hit: see conflicts (account D: Mr B; account C and the rest of D: Mr P).'
d['events'][d['events']~items]['object'] = 'a roof tile'
call addEvent 'EV25', 'OBJECT_THROWN', '2009', roles('ACTOR', 'M', 'TARGET', 'CAT'), 'he was seen throwing a brick at a cat', '"On the day in question": the day of EV23. A different throw, at a different target.'
d['events'][d['events']~items]['object'] = 'a brick'
call addEvent 'EV26', 'INTERVIEW_ANSWER', '', roles('SPEAKER', 'M'), 'He claims to have a hatred of cats, and ethnic minorities, and thought Mr P might be Asian', 'First interview; its date is not stated.'
call addEvent 'EV27', 'INTERVIEW_ANSWER', '', roles('SPEAKER', 'M'), 'He has since recanted that evidence at second interview and now claims that he thought Mr P was a crazy cat', 'Second interview, after EV26. On the throw itself the two do not differ; on why, they do.'
call addEvent 'EV28', 'PREVIOUS_CONVICTION', '', roles('SUBJECT', 'M'), '15 years of priors for threats with menaces, and assault, including theft of a mailbag when he was working for the postal service', 'A series, count unknown, all before 2009. Not evidence that he threw this tile.'
changes~append('events EV24 (the tile thrown), EV25 (a brick at a cat), EV26 and EV27 (two interviews), EV28 (previous convictions)')

call addClaim 'CLM_EV21_DRAWER', 'REPORTED_STATEMENT', 'Mr H wrote the cheque', 'H'
call addClaim 'CLM_D_THROWN', 'REPORTED_STATEMENT', 'The worker Mr M working for the roofers threw the tile', 'M'
call addClaim 'CLM_D_HIT_B', 'REPORTED_STATEMENT', 'the tile which hit Mr B', 'B'
call addClaim 'CLM_M_PRIORS', 'REPORTED_ATTRIBUTE', '15 years of priors for threats with menaces, and assault, including theft of a mailbag', 'M'
changes~append('claims: the drawer (H); the throw (M); "hit Mr B"; the previous convictions (M)')

cf = .directory~new
cf['id'] = 'CONFLICT_WHO_WAS_HIT'
cf['about'] = 'who the tile hit (EV23, EV24)'
cf['claims'] = .array~of('CLM_EV23', 'CLM_D_HIT_B')
cf['accounts'] = .array~of('account C: Mr P (SON_P) was hit', 'account D: "the tile which hit Mr B"; later in the same account: "thought Mr P might be Asian", "thought Mr P was a crazy cat"')
cf['status'] = 'UNRESOLVED'
cf['note'] = 'Recorded, not resolved. The elements of a harm offence ("any person") do not turn on it; hostility based on the group a person is taken to be in does: Mr M speaks of Mr P.'
/* Account E, the narrator's own correction (Tom Dyer, 2026-10-30 12:27): "Mr B" was a typo.  The claim
   stays as it was written; the correction is a later source; the conflict is resolved BY it, and the error
   stays on the record, as an inconsistency in an account would in a real file. */
rec2 = .directory~new
rec2['id'] = 'SOURCE_NARRATIVE_2026_10_30_E'; rec2['type'] = 'USER_NARRATIVE'; rec2['recordedDate'] = '2026-10-30'
rec2['authenticity'] = 'NOT_VALIDATED'; rec2['probativeScope'] = 'WHAT_USER_REPORTED'
rec2['text'] = 'That''s a typo, but it might well be an evidential error which we use'
d['sources']~append(rec2)
c = .directory~new
c['claimId'] = 'CLM_E_TYPO'; c['kind'] = 'CORRECTION'; c['text'] = '"Mr B" in account D was a typo: the tile hit Mr P'
c['corrects'] = 'CLM_D_HIT_B'; c['sourceId'] = 'SOURCE_NARRATIVE_2026_10_30_E'; c['status'] = 'ALLEGED_UNCORROBORATED'
d['claims']~append(c)
cf['claims']~append('CLM_E_TYPO')
cf['accounts']~append('account E (the narrator): "That''s a typo": Mr P')
cf['status'] = 'RESOLVED_BY_LATER_SOURCE'
cf['resolution'] = 'SON_P (Mr P), on account E. CLM_D_HIT_B is kept as written: an error in an account, corrected later, is itself evidence about the account.'
do en over d['entities']
  if en['id'] == 'B' then en['label'] = 'Mr B: named once, in account D, in error (a typo for Mr P, account E)'
end
d['conflicts'] = .array~of(cf)
changes~append('conflicts: who the tile hit: account D "Mr B", corrected by account E (a typo: Mr P); RESOLVED_BY_LATER_SOURCE, the error kept')

d['openQuestions']~append('Mr M''s previous convictions and the brick at the cat: may they be used at all, and for what? (England and Wales: Criminal Justice Act 2003, bad character; NSW: Evidence Act 1995, tendency and coincidence.) Neither shows that he threw this tile.')
d['openQuestions']~append('A thrown tile is a deliberate act: NSW Crimes Act 1900 s.33 (intent) or s.35 (reckless) may fit better than s.54 (negligence); in England and Wales, the Offences against the Person Act 1861, not held.')
d['openQuestions']~append('Hostility based on the group Mr M took Mr P to be in: the law that would weigh it (England and Wales: Crime and Disorder Act 1998 s.28, and the sentencing provisions; NSW: Crimes (Sentencing Procedure) Act 1999 s.21A) is not held. His two interviews disagree.')
changes~append('three open questions: the previous convictions; the law for a deliberate throw; hostility')

mg = d['migration']
prev = .directory~new; prev['from'] = mg['from']; prev['by'] = mg['by']; prev['changes'] = mg['changes']
if mg~hasIndex('previous') then prev['previous'] = mg['previous']
mg = .directory~new
mg['from'] = 'offence-event/0.3-PROPOSAL, docs/architecture/fixtures/mrs_p_roof_credit_pension_v0.3.json'
mg['by'] = 'Claude (Opus 5.5), 2026-10-30, tools/migrate_case_v03_v04.rex in packages/oorexx_slam_v0.1'
mg['changes'] = changes
mg['previous'] = prev
d['migration'] = mg
.json~toJsonFile(outFile, d, .true)
say 'wrote' outFile '(' || d['events']~items 'events,' d['claims']~items 'claims,' changes~items 'changes)'
exit 0

entity: procedure expose d
  use arg id, type, label
  en = .directory~new; en['id'] = id; en['type'] = type; en['label'] = label
  d['entities']~append(en)
  return

roles: procedure
  r = .directory~new
  do i = 1 to arg() by 2; r[arg(i)] = arg(i + 1); end
  return r

addEvent: procedure expose d SOURCEID
  use arg id, type, year, rl, said, note
  e = .directory~new
  e['eventId'] = id; e['eventType'] = type
  tm = .directory~new
  if year == '' then tm['status'] = 'UNKNOWN'
  else do; tm['status'] = 'YEAR_ONLY'; tm['value'] = year; end
  e['time'] = tm
  e['roles'] = rl
  e['sourceClaimIds'] = .array~of('CLM_' || id)
  e['statementAsReported'] = said; e['note'] = note
  d['events']~append(e)
  c = .directory~new
  c['claimId'] = 'CLM_' || id; c['kind'] = 'REPORTED_STATEMENT'; c['text'] = said
  c['sourceId'] = SOURCEID
  b = .directory~new; b['eventId'] = id; c['binding'] = b
  c['status'] = 'ALLEGED_UNCORROBORATED'
  d['claims']~append(c)
  return

addClaim: procedure expose d SOURCEID
  use arg id, kind, text, subject
  c = .directory~new
  c['claimId'] = id; c['kind'] = kind; c['text'] = text; c['subject'] = subject
  c['sourceId'] = SOURCEID; c['status'] = 'ALLEGED_UNCORROBORATED'
  d['claims']~append(c)
  return

::requires 'json.cls'
