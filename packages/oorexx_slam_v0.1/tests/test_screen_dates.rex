/* The law on the date: Tom Dyer's third account (2026-10-30) adds dated events (a refund cheque in 2008,
 * dishonoured three times; Mr P injured by a falling tile in 2009), and the same case runs in England and
 * Wales and in New South Wales, where the law of 2008 is not today's.
 * Architecture: Tom Dyer.  Code, rule packs and this test: Claude (Opus 5.5), 2026-10-30.  NSW XML: NSW
 * Parliamentary Counsel, attached by Tom Dyer.
 * Args: scratch dir | SLAM package dir | alchemy checkout
 *
 *  1. NSW's own XML: the version dates; a section's text; its history notes (Ins, Subst, Am, Rep, by year);
 *     what that says of a date: s.192E did not exist in 2008 (inserted by Act 2009 No 99); s.178B (valueless
 *     cheques) is not in today's text at all; s.253 was substituted in 2009; s.54 carries no note
 *  2. the NSW rule packs (s.192E fraud, s.54 grievous bodily harm) pass every gate, against the NSW XML
 *  3. the UK's own dates, per section: Fraud Act s.2's text from 2007-01-15, its s.1 from 2023-02-07, CMA
 *     s.3ZA from 2015-05-03
 *  4. the v0.3 case: its 23 events are EVENTS on the list; who wrote the cheque and who let the tile fall
 *     are not stated, and the screen does not fill them in
 *  5. the same 2008 cheque: in E.W. the Fraud Act s.2 text was the law (IN_FORCE_TEXT); in NSW s.192E did
 *     not exist yet (OUT_OF_SCOPE: the law of 2008 is an older text)
 *  6. the same withdrawal of 2025: fraud in both places, from the same evidence, on each one's own text
 *  7. Mr P's injury: NSW s.54 screens it (all UNKNOWN; its date can not be placed from the file); England
 *     and Wales has no rule pack for it here, and the screen says so instead of saying nothing
 *  8. entered once: three jurisdictions, one case file, unchanged by any screen
 */
signal on syntax name onSyntax
parse arg work '|' pkg '|' repo
checks = 0
L = pkg || '/tests/law'
FIXTURES = repo || '/docs/architecture/fixtures'
NSWX = repo || '/law/source_corpus/nsw_ny_20261030/nsw/state/act-1900-040_2026-10-01.xml'

say '== 1. NSW''s own XML'
nsw = .SlamNswLegislation~new(NSWX)
call check nsw~title == 'Crimes Act 1900' & nsw~validFrom == '2026-10-01' & nsw~validTo == '2026-10-28', 'Crimes Act 1900 (NSW): the version valid 2026-10-01 to 2026-10-28 (not the current one), read from the file''s own header'
t = nsw~section('192E', 'NSW')
call check t~pos('(1) A person who, by any deception, dishonestly') = 1 & t~pos('(b) obtains any financial advantage') > 0 & t~pos('Ins 2009') = 0 & nsw~section('192E', 'E.W.') == '', 's.192E: its text, a line per subsection and paragraph, history notes left out; nothing for an extent that is not NSW'
call check nsw~asAt('192E', '2008') == 'NOT_IN_FORCE' & nsw~asAt('192E', '2025-02-03') == 'IN_FORCE_TEXT', 's.192E: "Ins 2009 No 99": not the law in 2008; the law in 2025'
call check nsw~asAt('178B', '2008') == 'NOT_IN_THIS_TEXT', 's.178B (valueless cheques, repealed 2009): not in this text; a 2008 cheque needs the older text'
call check nsw~asAt('253', '2008') == 'EARLIER_TEXT_NEEDED' & nsw~asAt('117', '2008') == 'IN_FORCE_TEXT' & nsw~asAt('54', '2009') == 'NO_HISTORY_NOTE', 's.253 (substituted 2009): an earlier text for 2008; s.117 (amended 1974, 1999): this text in 2008; s.54: no note, no date'

say '== 2. the NSW rule packs'
v = .SlamLaw~vocabulary(L || '/VOCABULARY.md')
do pk over .array~of(.array~of('crimes1900_s192E.md', 10), .array~of('crimes1900_s54.md', 2))
  r = .SlamLaw~parse(L || '/' || pk[1])
  e = .SlamLaw~check(r, .SlamLaw~officialFor(nsw, r))~union(.SlamLaw~checkMaximum(r, nsw))~union(.SlamLaw~kindErrors(v, .SlamLaw~kindsOfRule(r, pk[1])))
  do x over e; say '       ' x; end
  call check e~items = 0 & reader(work, pkg, L || '/' || pk[1]) == '' & r['MAXIMUM']['YEARS'] = pk[2] & r['EXTENT'] == 'NSW', pk[1] || ': reader, the NSW text word for word, quotes, paragraphs, rule line, kinds; the most the law says,' pk[2] 'years, in the XML'
end

say '== 3. the UK''s own dates, per section'
fr = .SlamLegislation~new(L || '/source/fraud2006.xml'); cma = .SlamLegislation~new(L || '/source/cma1990.xml'); th = .SlamLegislation~new(L || '/source/theft1968.xml')
call check fr~sectionValidFrom('2') == '2007-01-15' & fr~sectionValidFrom('1') == '2023-02-07' & cma~sectionValidFrom('3ZA') == '2015-05-03', 'Fraud Act s.2: this text from 2007-01-15; s.1 (the penalty, amended): 2023-02-07; CMA s.3ZA: 2015-05-03'
call check fr~asAt('2', '2008') == 'IN_FORCE_TEXT' & cma~asAt('3ZA', '2009') == 'EARLIER_TEXT_NEEDED' & fr~asAt('1', '2008') == 'EARLIER_TEXT_NEEDED', 'in 2008 the s.2 text we hold was the law; for s.3ZA in 2009, and s.1''s penalty in 2008, an earlier text is needed'

say '== 4. the v0.3 case'
before = hash(FIXTURES || '/mrs_p_roof_credit_pension_v0.3.json')
case = .json~fromJsonFile(FIXTURES || '/mrs_p_roof_credit_pension_v0.3.json')
ev = .json~fromJsonFile(L || '/mrs_p_evidence_made_up.json')
used = .array~new
do e over case['events']; used~append(.array~of(e['eventType'], e['eventId'])); end
call check case['events']~items = 23 & .SlamLaw~kindErrors(v, used, 'EVENT')~items = 0, 'v0.3: 23 events (the cheque, its three dishonours, the complaint, the injury added), each an EVENT on the list'
ev21 = .nil; ev23 = .nil
do e over case['events']
  if e['eventId'] == 'EV21' then ev21 = e
  if e['eventId'] == 'EV23' then ev23 = e
end
call check ev21['roles']['DRAWER'] == 'UNRESOLVED' & ev23['roles']['ACTOR'] == 'UNRESOLVED', 'who wrote the cheque and who let the tile fall: not stated, UNRESOLVED (and open questions), not filled in'

paths = .array~new
do f over .array~of('cma1990_s1.md', 'cma1990_s1_scotland.md', 'cma1990_s2.md', 'cma1990_s3za.md', 'fraud2006_s2.md', 'theft1968_s1.md', 'theft1968_s21.md', 'crimes1900_s192E.md', 'crimes1900_s54.md')
  paths~append(L || '/' || f)
end
g = .array~of(.array~of(L || '/cps_cma.md', text(L || '/source/cps_cma_guidance.txt')))
laws = .directory~new
laws['cma1990.s1'] = cma; laws['cma1990.s2'] = cma; laws['cma1990.s3za'] = cma
laws['fraud2006.s2'] = fr; laws['theft1968.s1'] = th; laws['theft1968.s21'] = th
laws['crimes1900nsw.s192E'] = nsw; laws['crimes1900nsw.s54'] = nsw
ew = .SlamScreen~screen(case, ev, paths, 'E.W.', g, laws)
ns = .SlamScreen~screen(case, ev, paths, 'NSW', g, laws)

say '== 5. the same 2008 cheque'
x = find(ew, 'fraud2006.s2', 'EV21')
say '      ' .SlamScreen~line(x[1])
call check x~items = 1 & x[1]['ASAT'] == 'IN_FORCE_TEXT' & x[1]['PERSON'] == 'UNRESOLVED' & allUnknown(x[1]), 'E.W.: Fraud Act s.2 (a cheque given as payment is an implied representation, s.2(4)): its 2007 text was the law in 2008; the drawer is UNRESOLVED and every element UNKNOWN'
y = find(ns, 'crimes1900nsw.s192E', 'EV21')
say '      ' .SlamScreen~line(y[1])
call check y~items = 1 & y[1]['STATUS'] == 'OUT_OF_SCOPE' & y[1]['ASAT'] == 'NOT_IN_FORCE' & y[1]['WHY']~pos('not in force in 2008') > 0, 'NSW: s.192E did not exist in 2008: OUT_OF_SCOPE, not matched against today''s words (the law then was older: s.178B valueless cheques among it)'

say '== 6. the same withdrawal of 2025'
a = find(ew, 'fraud2006.s2', 'EV16.1')[1]; b = find(ns, 'crimes1900nsw.s192E', 'EV16.1')[1]
say '      ' .SlamScreen~line(a)
say '      ' .SlamScreen~line(b)
call check a['OK'] & b['OK'] & a['ASAT'] == 'IN_FORCE_TEXT' & b['ASAT'] == 'IN_FORCE_TEXT', 'J at the machine, 2025: E.W. Fraud Act s.2 (5 elements) and NSW s.192E (4 elements, "by any deception": a computer can be deceived, s.192B) both SUPPORTED on the evidence given, each on its own text'

say '== 7. Mr P''s injury'
z = find(ns, 'crimes1900nsw.s54', 'EV23')
say '      ' .SlamScreen~line(z[1])
gp = ''
do q over z[1]['GAPS']; gp = gp q['TAKES']; end
call check z~items = 1 & z[1]['PERSON'] == 'UNRESOLVED' & allUnknown(z[1]) & z[1]['ASAT'] == 'NO_HISTORY_NOTE' & gp~space == 'PERSON_ACT UNLAWFUL_OR_NEGLIGENT CAUSED GRIEVOUS_BODILY_HARM', 'NSW s.54: every element UNKNOWN; what is missing: who acted, an unlawful or negligent act, that it caused the harm, that the harm is grievous; its date can not be placed from this file'
u = ''
do d over .SlamScreen~unscreened(case, ev, paths, 'E.W.'); u = u d['EVENT']; end
call check wordpos('EV23', u) > 0 & find(ew, 'crimes1900nsw.s54', 'EV23')~items = 0, 'E.W.: no rule pack here is about an injury, and the screen lists EV23 as such, rather than reporting nothing (a source is needed, e.g. the Offences against the Person Act 1861)'

say '== 8. entered once'
call check hash(FIXTURES || '/mrs_p_roof_credit_pension_v0.3.json') == before, 'one case file for E.W. and NSW (and S.): unchanged by every screen'
say 'SCREEN DATES TEST: PASS (' || checks || ' checks)'
exit 0

allUnknown: procedure
  use arg x
  do e over x['ELEMENTS']; if e['REPORT'] \== 'UNKNOWN' then return .false; end
  return .true

find: procedure
  use arg res, rule, event
  out = .array~new
  do x over res
    if x['RULE'] == rule & x['EVENT'] == event then out~append(x)
  end
  return out

hash: procedure
  use arg path
  address system 'sha256sum "' || path || '"' with output stem h.
  return h.1~word(1)

reader: procedure
  use arg work, pkg, file
  db = work || '/screen_dates_reader.db'
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
::requires 'SlamNswLegislation.cls'
::requires 'json.cls'
