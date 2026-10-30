/* One set of events, many offences: the shared word list (gate 6) and the screen.
 * Architecture: Tom Dyer.  Event names and case schema: ChatGPT (GPT-6), OFFENCE_EVENT_CONTRACT_v0.1 and the
 * Mrs P fixture v0.1; v0.2 and this test: Claude (Opus 5.5), 2026-10-30.  The Reasoned Thought engine
 * (Claude (Opus 4.8); combiner design ChatGPT (GPT-6)) is used unchanged.
 * Args: scratch dir | SLAM package dir | alchemy checkout
 *
 *  1. the word list: SLAM's reader knows every word; 50 kinds, each an event or a finding
 *  2. every kind used is on the list: rule packs, guidance, the element-addressed cases, the v0.2 case (its
 *     events must be EVENTS) and the made-up evidence; ChatGPT's v0.1 file is refused until migrated
 *  3. refused: an old name (KEY_USE), a synonym (MISREPRESENTATION), a finding used as an event, a kind typed
 *     both ways, and event names that carry a conclusion: Gemini's tokens and two of v0.1's
 *  4. the law: s.2 in both extents, from one file; s.1 for Scotland; England's guidance refused for Scotland
 *  5. the screen, E.W. and S.: the results written down before the run
 *  6. what the screen refuses, and why: a log, a card held later, a read receipt, a death certificate, a
 *     model's word on the law
 *  7. the case entered once; one item counts in more than one offence
 *  8. benign: the bank gave the executor a mandate: the access is no longer shown unauthorised (fails
 *     closed); the narrative alone: one UNRESOLVED instance, nothing CONTRADICTED, as-at NOT_RUN
 */
signal on syntax name onSyntax
parse arg work '|' pkg '|' repo
checks = 0
L = pkg || '/tests/law'
FIXTURES = repo || '/docs/architecture/fixtures'

say '== 1. the word list'
call check reader(work, pkg, L || '/VOCABULARY.md') == '', 'SLAM''s reader knows every word of VOCABULARY.md (definitions in SLAM''s words)'
v = .SlamLaw~vocabulary(L || '/VOCABULARY.md')
ne = 0; nf = 0
do k over v['ORDER']
  if v['KINDS'][k]['TYPE'] == 'EVENT' then ne += 1; else nf += 1
end
call check v['ERRORS']~items = 0 & v['KINDS']~items = 50, '50 kinds (law.kinds 0.3),' ne 'events and' nf 'findings; no kind both, none untyped, no event carries a word of a finding'

say '== 2. every kind used is on the list'
leg = .SlamLegislation~new(L || '/source/cma1990.xml')
rules = .array~of('cma1990_s1.md', 'cma1990_s1_scotland.md', 'cma1990_s2.md', 'cma1990_s3za.md')
used = .array~new
do f over rules
  used = used~union(.SlamLaw~kindsOfRule(.SlamLaw~parse(L || '/' || f), f))
end
used = used~union(.SlamLaw~kindsOfGuidance(L || '/cps_cma.md'))
do f over .array~of('case_s1_made_up.txt', 'case_s1_mr_s_made_up.txt', 'case_s3za_made_up.txt')
  used = used~union(.SlamLaw~kindsOfCaseLines(L || '/' || f))
end
e = .SlamLaw~kindErrors(v, used)
do x over e; say '       ' x; end
call check e~items = 0, used~items 'uses of a kind in 4 rule packs, the CPS guidance and 3 element-addressed cases: all on the list'
case = .json~fromJsonFile(FIXTURES || '/mrs_p_roof_credit_pension_v0.2.json')
ev = .json~fromJsonFile(L || '/mrs_p_evidence_made_up.json')
e = .SlamLaw~kindErrors(v, caseEvents(case)~union(caseEvents(ev)), 'EVENT')
do x over e; say '       ' x; end
call check e~items = 0 & case['events']~items = 16, 'the v0.2 case''s 16 events and the evidence''s 4: each type on the list, and an EVENT'
e = .SlamLaw~kindErrors(v, evidenceKinds(ev))
call check e~items = 0 & ev['evidenceItems']~items = 18, 'the 18 evidence items: what each is offered for, and what it binds, are on the list'
v01 = .json~fromJsonFile(FIXTURES || '/mrs_p_roof_credit_pension_v0.1.json')
e = .SlamLaw~kindErrors(v, caseEvents(v01), 'EVENT')
do x over e; say '       ' x; end
call check e~items = 1 & hasText(e, 'CREDENTIAL_PRESENTED'), 'ChatGPT''s v0.1 file is refused for one name, CREDENTIAL_PRESENTED, until migrated (tools/migrate_case_v01_v02.rex)'

say '== 3. refused'
d = write(work, 'old_name.txt', '1 | 1 | SUPPORT | PROVENANCE | KEY_USE | the hardware key' || '0a'x || '2 | 4 | SUPPORT | TESTIMONY | MISREPRESENTATION | he lied' || '0a'x)
e = .SlamLaw~kindErrors(v, .SlamLaw~kindsOfCaseLines(d))
call check e~items = 2 & hasText(e, 'KEY_USE is not in') & hasText(e, 'MISREPRESENTATION is not in'), 'the old name KEY_USE and the synonym MISREPRESENTATION: not on the list, refused'
e = .SlamLaw~kindErrors(v, .array~of(.array~of('PERSON_ACT', 'an event')), 'EVENT')
call check e~items = 1 & hasText(e, 'is a finding, not an event'), 'a finding (PERSON_ACT) used as an event: refused'
bad = text(L || '/VOCABULARY.md')
tokens = .array~of( -
  .array~of('FALSE_STATEMENT_AUTHORITY', 'a person says a false thing about a council', 'Gemini'), -
  .array~of('FALSE_STATEMENT_NEED', 'a person says a false thing about the change a house has to have', 'Gemini'), -
  .array~of('COERCION_TACTIC', 'a person forces an other person to do a thing', 'Gemini'), -
  .array~of('UNAUTHORIZED_FINANCIAL_ACTIVITY', 'a person gives a loan, and it is unauthorised', 'Gemini'), -
  .array~of('POST_MORTEM_MISAPPROPRIATION', 'after a person died, an other person takes the money of that person, and it is dishonest', 'Gemini'), -
  .array~of('ACTOR_COCONSPIRATOR', 'a person that acts with an other person to do an offence', 'Gemini'), -
  .array~of('INFORMATION_WITHHELD', 'a person knows a thing, and does not say it', 'ChatGPT v0.1'), -
  .array~of('AGREEMENT_TO_OFFEND_ALLEGED', 'two persons say, each to each, that each is to do a part of an offence', 'ChatGPT v0.1'))
n = 43
do t over tokens
  bad = bad || '0a'x || 'kind' n || ':' || '0a0a'x || '```' || '0a'x || t[1] || '0a'x || '```' || '0a0a'x || 'it is an event.' || '0a0a'x || t[2] || '.' || '0a'x
  n += 1
end
bad = bad || '0a'x || 'kind' n || ':' || '0a0a'x || '```' || '0a'x || 'BOTH_WAYS' || '0a'x || '```' || '0a0a'x || 'it is an event.' || '0a'x || 'it is a finding.' || '0a0a'x || 'a person says a thing.' || '0a'x
vb = .SlamLaw~vocabulary(write(work, 'bad_vocabulary.md', bad))
do x over vb['ERRORS']; say '       ' x~left(150); end
caught = 0
do t over tokens
  if hasText(vb['ERRORS'], 'kind' t[1] 'is an event, and its definition uses') then caught += 1
end
call check caught = 8, 'event names that carry a conclusion, each refused with the word of a finding it needs: Gemini''s six tokens and two of ChatGPT''s v0.1 names (definitions: their glosses, put in SLAM''s words by Claude)'
call check hasText(vb['ERRORS'], 'kind BOTH_WAYS says it is an event and a finding'), 'a kind typed both ways: refused'

say '== 4. the law'
s2 = .SlamLaw~parse(L || '/cma1990_s2.md')
e = .SlamLaw~check(s2, .SlamLaw~officialFor(leg, s2))
do x over e; say '       ' x; end
call check e~items = 0 & s2['EXTENT'] == 'E.W. S.' & .SlamLaw~element(s2, 2)['QUOTES']~items = 2, 's.2, one file for E.W. and S.: the XML''s text in both; (1)(a) or (b) is one element with two quotes; (2)(a) or (b) the same'
call check .SlamLaw~element(s2, 1)['LINK'] == 'cma1990.s1', 's.2''s element 1, "he commits an offence under section 1", is the s.1 offence itself, not a claim'
s1s = .SlamLaw~parse(L || '/cma1990_s1_scotland.md')
call check .SlamLaw~check(s1s, .SlamLaw~officialFor(leg, s1s))~items = 0 & reader(work, pkg, L || '/cma1990_s1_scotland.md') == '' & reader(work, pkg, L || '/cma1990_s2.md') == '', 's.1 for Scotland (its words "or to enable any such access to be secured") and s.2 pass the gates and the reader'
cpsText = text(L || '/source/cps_cma_guidance.txt')
call check hasText(.SlamLaw~applyGuidance(s1s, L || '/cps_cma.md', cpsText), 'the guidance is for extent E.W., not for S.'), 'the CPS guidance (England and Wales) offered for the Scottish s.1: refused'

say '== 5. the screen (made up: no real person, bank or record)'
paths = .array~new
do f over rules; paths~append(L || '/' || f); end
g = .array~of(.array~of(L || '/cps_cma.md', cpsText))
vf = .directory~new
do id over .array~of('cma1990.s1', 'cma1990.s2', 'cma1990.s3za'); vf[id] = leg~validFrom; end
expect = .array~of( -
  'cma1990.s1 EV16.1 J: 1=SUPPORTED 2=SUPPORTED 3=SUPPORTED 4=SUPPORTED -> SUPPORTED', -
  'cma1990.s1 EV16.2 UNRESOLVED: 1=UNKNOWN 2=SUPPORTED 3=SUPPORTED 4=UNKNOWN -> NOT_SUPPORTED', -
  'cma1990.s1 EV16.3 H: 1=UNKNOWN 2=SUPPORTED 3=SUPPORTED 4=UNKNOWN -> NOT_SUPPORTED', -
  'cma1990.s2 EV16.1 J: 1=SUPPORTED 2=SUPPORTED 3=UNKNOWN -> NOT_SUPPORTED', -
  'cma1990.s2 EV16.2 UNRESOLVED: 1=UNKNOWN 2=UNKNOWN 3=UNKNOWN -> NOT_SUPPORTED', -
  'cma1990.s2 EV16.3 H: 1=UNKNOWN 2=UNKNOWN 3=UNKNOWN -> NOT_SUPPORTED', -
  'cma1990.s3za EV16.1 J: 1=SUPPORTED 2=SUPPORTED 3=SUPPORTED 4=UNKNOWN 5=UNKNOWN -> NOT_SUPPORTED', -
  'cma1990.s3za EV16.2 UNRESOLVED: 1=UNKNOWN 2=SUPPORTED 3=UNKNOWN 4=UNKNOWN 5=UNKNOWN -> NOT_SUPPORTED', -
  'cma1990.s3za EV16.3 H: 1=UNKNOWN 2=SUPPORTED 3=UNKNOWN 4=UNKNOWN 5=UNKNOWN -> NOT_SUPPORTED')
byExt = .directory~new
do ext over .array~of('E.W.', 'S.')
  res = .SlamScreen~screen(case, ev, paths, ext, g, vf)
  byExt[ext] = res
  got = .array~new; oos = ''; asat = .set~new
  do x over res
    say '      ' .SlamScreen~line(x)
    if x['STATUS'] == 'OUT_OF_SCOPE' then oos = oos x['FILE']
    else do
      got~append(short(x)); asat~put(x['ASAT'])
    end
  end
  same = got~items = expect~items
  do x over expect; if \got~hasItem(x) then do; same = .false; say '       missing:' x; end; end
  call check same, ext || ': 9 results, each as written down before the run: s.1 SUPPORTED on the evidence given only where a person is shown at the machine (J, EV16.1)'
  if ext == 'E.W.' then call check oos~strip == 'cma1990_s1_scotland.md', 'E.W.: the Scottish s.1 file is OUT_OF_SCOPE; s.2 and s.3ZA (one file each, both extents) run'
  else call check oos~strip == 'cma1990_s1.md', 'S.: the English s.1 file is OUT_OF_SCOPE; the Computer Misuse Act reaches the withdrawals in Scotland too (the Fraud and Theft Acts would not)'
  call check asat~items = 1 & asat~hasItem('IN_FORCE_TEXT'), ext || ': every withdrawal (2025-2029, made up) is on or after the date the text is valid from (' || leg~validFrom || ')'
end
ew = byExt['E.W.']
call check find(ew, 'cma1990.s1', 'EV16')~items = 0, 'EV16, the series as told ("they keep withdrawing"), is screened through its three recorded parts, not as one act'
x = find(ew, 'cma1990.s1', 'EV16.2')
call check x~items = 1 & x[1]['PERSON'] == 'UNRESOLVED', 'EV16.2: no evidence names a person: UNRESOLVED; "they" is not filled in with J or H'

say '== 6. refused, and why'
x = find(ew, 'cma1990.s1', 'EV16.3')[1]
gp = gapOf(x, 1)
call check gp \== .nil & hasText(gp['REFUSED'], 'CREDENTIAL_USED: E05') & hasText(gp['REFUSED'], 'CREDENTIAL_HELD: E08'), 'EV16.3, element 1: the bank log (the card was used) and the card in H''s wallet at his arrest (held, a month later) are refused: neither shows who used it'
gp = gapOf(x, 4)
call check gp \== .nil & hasText(gp['REFUSED'], 'READ_RECEIPT: E11'), 'EV16.3, element 4: H''s phone showing J''s message as read is refused for "H knew" (as in the s.1 case: opened is not understood)'
x = find(ew, 'cma1990.s1', 'EV16.1')[1]
call check x['OK'] & x['WHY'] == '', 'EV16.1, J: the camera puts J at the machine; J''s own message, two days after the death, shows she knew; the bank''s letter shows no consent (s.17(5))'
x2 = find(ew, 'cma1990.s2', 'EV16.1')[1]
gp = gapOf(x2, 3)
do y over x2['GAPS']; say '       missing: element' y['ELEMENT'] y['STATUS'] 'takes' y['TAKES']; end
call check gp \== .nil & gp['TAKES'] == 'MAXIMUM_SENTENCE' & hasText(gp['REFUSED'], 'MODEL_STATEMENT: E12'), 's.2 for J: s.1 holds and her intent to keep the cash is shown, but "the further offence carries five years" waits for its rule pack: a model''s word on the law (mine) is refused'
call check gapOf(find(ew, 'cma1990.s2', 'EV16.3')[1], 1)['STATUS'] == 'OFFENCE_NOT_SUPPORTED', 's.2 for H at EV16.3: element 1 is the s.1 offence, and it is not supported: s.2 can not be'
ev3 = .json~fromJsonFile(L || '/mrs_p_evidence_made_up.json')
keep = .array~new
do it over ev3['evidenceItems']; if it['evidenceId'] \== 'E02' then keep~append(it); end
ev3['evidenceItems'] = keep
gp = gapOf(find(.SlamScreen~screen(case, ev3, paths, 'E.W.', g, vf), 'cma1990.s1', 'EV16.1')[1], 3)
call check gp \== .nil & gp['STATUS'] == 'UNDETERMINED' & hasText(gp['REFUSED'], 'PERSON_DIED: E01'), 'without the bank''s letter, "unauthorised" is open: the death certificate alone is refused for it (s.17(5): the one entitled to control access, the bank, decides)'

say '== 7. entered once'
in1 = 0; in3 = 0
do x over ew
  if x['STATUS'] == 'OUT_OF_SCOPE' then iterate
  if x['RULE'] == 'cma1990.s1' & x['ELEMENTS'][3]['REPORT'] == 'SUPPORTED' then in1 += 1
  if x['RULE'] == 'cma1990.s3za' & x['ELEMENTS'][2]['REPORT'] == 'SUPPORTED' then in3 += 1
end
call check ev['evidenceItems']~items = 18 & in1 = 3 & in3 = 3, 'the bank''s letter (E02) is one item in the file; it supports "unauthorised" in s.1 and in s.3ZA, for each of the 3 withdrawals'

say '== 8. benign, and the narrative alone'
ev2 = .json~fromJsonFile(L || '/mrs_p_evidence_made_up.json')
m = .directory~new
m['evidenceId'] = 'B01'; m['eventId'] = '*'; m['subject'] = 'J'; m['offeredFor'] = 'AUTHORITY'; m['effect'] = 'REBUT'
m['tier'] = 'DOCUMENTARY'; m['binding'] = 'AUTHORITY'; m['sourceKind'] = 'BANK_RECORD'
m['text'] = 'the bank''s record: Ms J, the executor, was given a mandate to use the account after the death'
ev2['evidenceItems']~append(m)
x = find(.SlamScreen~screen(case, ev2, paths, 'E.W.', g, vf), 'cma1990.s1', 'EV16.1')[1]
call check \x['OK'] & x['ELEMENTS'][3]['REPORT'] == 'DISPUTED', 'benign: a bank record of a mandate for J, against the bank''s letter: element 3 DISPUTED (record against record), and s.1 is no longer supported: it fails closed'
res = .SlamScreen~screen(case, .nil, paths, 'E.W.', g, vf)
x = find(res, 'cma1990.s1', 'EV16')
allUnknown = .true; contradicted = .false
do y over x[1]['ELEMENTS']
  if y['REPORT'] \== 'UNKNOWN' then allUnknown = .false
  if y['REPORT'] == 'CONTRADICTED' then contradicted = .true
end
call check x~items = 1 & x[1]['PERSON'] == 'UNRESOLVED' & allUnknown & \contradicted & x[1]['ASAT'] == 'NOT_RUN', 'the narrative alone: one instance for the series EV16, UNRESOLVED, every element UNKNOWN (no evidence is not CONTRADICTED), as-at NOT_RUN (no date)'
say 'SCREEN TEST: PASS (' || checks || ' checks)'
exit 0

short: procedure
  use arg x
  t = x['RULE'] x['EVENT'] x['PERSON'] || ':'
  do e over x['ELEMENTS']; t = t e['ELEMENT'] || '=' || e['REPORT']; end
  return t '->' x['STATUS']

find: procedure
  use arg res, rule, event
  out = .array~new
  do x over res
    if x['RULE'] == rule & x['EVENT'] == event then out~append(x)
  end
  return out

gapOf: procedure
  use arg x, n
  do y over x['GAPS']
    if y['ELEMENT'] = n then return y
  end
  return .nil

caseEvents: procedure
  use arg d
  out = .array~new
  if d~hasIndex('events') then do e over d['events']; out~append(.array~of(e['eventType'], e['eventId'])); end
  return out

evidenceKinds: procedure
  use arg d
  out = .array~new
  do it over d['evidenceItems']
    out~append(.array~of(it['offeredFor'], it['evidenceId'] 'offered for'))
    out~append(.array~of(it['binding'], it['evidenceId'] 'binds'))
  end
  return out

reader: procedure
  use arg work, pkg, file
  db = work || '/screen_reader.db'
  call SysFileDelete db; call SysFileDelete db || '-wal'; call SysFileDelete db || '-shm'
  address system 'rexx "' || pkg || '/bin/slam.rex" corpus "' || db || '" "' || pkg || '/corpus/circular_corpus_v2.csv"' with output stem ignore.
  address system 'rexx "' || pkg || '/bin/slam.rex" read "' || db || '" "' || file || '"' with output stem o.
  out = ''
  do i = 1 to o.0
    if o.i~strip~word(1)~right(1) == ':' & datatype(o.i~strip~word(1)~strip('T', ':'), 'W') then out = out o.i~strip~word(2)
  end
  return out~strip

text: procedure
  use arg path
  s = .stream~new(path); s~open('READ'); t = s~charin(1, s~chars); s~close
  return t
write: procedure
  use arg work, name, body
  path = work || '/' || name
  call SysFileDelete path
  s = .stream~new(path); s~open('WRITE REPLACE'); s~charout(body); s~close
  return path
hasText: procedure
  use arg arr, needle
  do e over arr
    if e~pos(needle) > 0 then return .true
  end
  return .false

check: procedure expose checks
  use arg ok, label
  checks += 1
  if ok then say 'PASS ' label
  else do
    say 'FAIL ' label
    exit 1
  end
  return

onSyntax:
  say 'SYNTAX rc=' || rc 'sigl=' || sigl condition('C') condition('D') condition('O')~message
  exit 1

::requires 'SlamScreen.cls'
::requires 'SlamLegislation.cls'
::requires 'json.cls'
