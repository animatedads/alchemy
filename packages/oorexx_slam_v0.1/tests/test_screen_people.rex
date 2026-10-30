/* Who did it, and what does not show it: Tom Dyer's fourth account (2026-10-30) names Mr H as the cheque's
 * drawer and Mr M as the worker who threw the tile; gives Mr M's previous convictions and a brick he threw at
 * a cat that day; and two interviews that agree he threw it and disagree about why.  Account E: "Mr B" was a
 * typo, an evidential error to keep.
 * Architecture: Tom Dyer.  Code and this test: Claude (Opus 5.5), 2026-10-30.
 * Args: scratch dir | SLAM package dir | alchemy checkout
 *
 *  1. case v0.4: every event on the list; the error ("hit Mr B") kept as written, corrected by a later
 *     source, the conflict RESOLVED_BY_LATER_SOURCE, not overwritten
 *  2. the cheque: Mr H, named by the account, is now the person screened (E.W., Fraud Act s.2): every element
 *     UNKNOWN, because an account naming him is not evidence that it was dishonest, or false
 *  3. the tile, NSW s.54: Mr M did it on his own word (SUPPORTED, not SETTLED); the hospital record settles
 *     the harm and its cause; his previous convictions and the brick at the cat are on the record, refused
 *  4. take away his two admissions, and the record and the cat show nothing: element 1 is open; propensity
 *     is not proof of the act
 *  5. why he threw it: first interview against second, his own word against his own word: DISPUTED
 *  6. the law not held: in England and Wales no rule pack here is about the injury or the throws, and the
 *     screen lists them
 *  7. a deliberate throw, NSW ss.33 and 35 (2026-10-30): the same injury, two more rule packs.  s.33 needs an
 *     intent to cause grievous bodily harm, and nothing in the account is offered for it: UNKNOWN.  s.35(2)
 *     needs recklessness as to hurt to a person: his first interview (he took the figure to be a man) against
 *     his second (a cat): DISPUTED.  s.35 was amended in 2012: for a 2009 injury the older text is needed
 */
signal on syntax name onSyntax
parse arg work '|' pkg '|' repo
checks = 0
L = pkg || '/tests/law'
FIXTURES = repo || '/docs/architecture/fixtures'
NSWX = repo || '/law/source_corpus/nsw_ny_20261030/nsw/state/act-1900-040_2026-10-01.xml'

say '== 1. case v0.4'
case = .json~fromJsonFile(FIXTURES || '/mrs_p_roof_credit_pension_v0.4.json')
v = .SlamLaw~vocabulary(L || '/VOCABULARY.md')
used = .array~new
do e over case['events']; used~append(.array~of(e['eventType'], e['eventId'])); end
call check v['ERRORS']~items = 0 & v['KINDS']~items = 64 & case['events']~items = 28 & .SlamLaw~kindErrors(v, used, 'EVENT')~items = 0, 'law.kinds 0.7 (64 kinds); v0.4''s 28 events (the throw, the brick, two interviews, the convictions added), each an EVENT on the list'
cf = case['conflicts'][1]
kept = .false
do c over case['claims']; if c['claimId'] == 'CLM_D_HIT_B' then kept = (c['text'] == 'the tile which hit Mr B'); end
call check cf['status'] == 'RESOLVED_BY_LATER_SOURCE' & kept & cf['claims']~hasItem('CLM_E_TYPO'), '"the tile which hit Mr B": kept as written; account E says it was a typo (Mr P); the conflict is resolved by the later source, and the error stays on the record'

ev = .json~fromJsonFile(L || '/mrs_p_evidence_made_up.json')
evm = .json~fromJsonFile(L || '/mrs_p_evidence_m_made_up.json')
do it over evm['evidenceItems']; ev['evidenceItems']~append(it); end
paths = .array~new
do f over .array~of('cma1990_s1.md', 'cma1990_s1_scotland.md', 'cma1990_s2.md', 'cma1990_s3za.md', 'fraud2006_s2.md', 'theft1968_s1.md', 'theft1968_s21.md', 'crimes1900_s192E.md', 'crimes1900_s54.md', 'crimes1900_s33.md', 'crimes1900_s35.md')
  paths~append(L || '/' || f)
end
g = .array~of(.array~of(L || '/cps_cma.md', text(L || '/source/cps_cma_guidance.txt')))
cma = .SlamLegislation~new(L || '/source/cma1990.xml'); fr = .SlamLegislation~new(L || '/source/fraud2006.xml'); th = .SlamLegislation~new(L || '/source/theft1968.xml')
nsw = .SlamNswLegislation~new(NSWX)
laws = .directory~new
laws['cma1990.s1'] = cma; laws['cma1990.s2'] = cma; laws['cma1990.s3za'] = cma
laws['fraud2006.s2'] = fr; laws['theft1968.s1'] = th; laws['theft1968.s21'] = th
laws['crimes1900nsw.s192E'] = nsw; laws['crimes1900nsw.s54'] = nsw; laws['crimes1900nsw.s33'] = nsw; laws['crimes1900nsw.s35'] = nsw

say '== 2. the cheque'
ew = .SlamScreen~screen(case, ev, paths, 'E.W.', g, laws)
x = find(ew, 'fraud2006.s2', 'EV21')
say '      ' .SlamScreen~line(x[1])
call check x~items = 1 & x[1]['PERSON'] == 'H' & allUnknown(x[1]) & x[1]['ASAT'] == 'IN_FORCE_TEXT', 'E.W. Fraud Act s.2: screened for Mr H (the account names him the drawer); every element UNKNOWN: that he wrote it is not evidence that it was false, or dishonest'

say '== 3. the tile, NSW s.54'
ns = .SlamScreen~screen(case, ev, paths, 'NSW', g, laws)
y = find(ns, 'crimes1900nsw.s54', 'EV23')
say '      ' .SlamScreen~line(y[1])
st = ''
do e over y[1]['ELEMENTS']; st = st e['STATUS']; end
call check y~items = 1 & y[1]['PERSON'] == 'M' & y[1]['OK'] & st~space == 'SUPPORTED SUPPORTED SETTLED SETTLED', 'Mr M (the account names him): he threw it, and it was unlawful, on his own word in two interviews (SUPPORTED, not SETTLED); the hospital record settles the cause and the harm; s.54 SUPPORTED on the evidence given'
rf = y[1]['ELEMENTS'][1]['REFUSED']
do r over rf; say '         refused:' r~left(140); end
call check hasText(rf, 'PREVIOUS_CONVICTION: E20') & hasText(rf, 'OBJECT_THROWN: E21'), 'his previous convictions (E20) and the brick at the cat (E21), offered for "he did it": both on the record, both refused'

say '== 4. without his admissions'
ev2 = .json~fromJsonFile(L || '/mrs_p_evidence_made_up.json')
do it over evm['evidenceItems']
  if wordpos(it['evidenceId'], 'E22 E23') = 0 then ev2['evidenceItems']~append(it)
end
z = find(.SlamScreen~screen(case, ev2, paths, 'NSW', g, laws), 'crimes1900nsw.s54', 'EV23')[1]
gp = gapOf(z, 1)
call check \z['OK'] & gp \== .nil & gp['STATUS'] == 'UNDETERMINED' & hasText(gp['REFUSED'], 'PREVIOUS_CONVICTION: E20') & hasText(gp['REFUSED'], 'OBJECT_THROWN: E21'), 'without his two admissions, 15 years of convictions and a brick at a cat leave "he threw this tile" open: propensity is not proof of the act'

say '== 5. why he threw it'
r = .SlamReasoning~new
cid = r~claim('HOSTILITY:M@EV23', 'Mr M threw the tile because of the group he took Mr P to be in', 'DOCUMENTARY', .array~of('HOSTILITY_TO_GROUP'))
do it over evm['evidenceItems']
  if it['offeredFor'] \== 'HOSTILITY_TO_GROUP' then iterate
  if it['effect'] == 'REBUT' then r~evidenceAgainst(cid, it['tier'], it['evidenceId'] || ':' it['text'], it['binding'])
  else r~evidenceFor(cid, it['tier'], it['evidenceId'] || ':' it['text'], it['binding'])
end
call check r~assess(cid)['status'] == 'DISPUTED', 'first interview ("thought Mr P might be Asian") against second ("a crazy cat"): his word against his own word, DISPUTED; the law that would weigh hostility is not held'

say '== 6. the law not held'
u = ''
do d over .SlamScreen~unscreened(case, ev, paths, 'E.W.'); u = u d['EVENT']; end
call check wordpos('EV23', u) > 0 & wordpos('EV24', u) > 0 & wordpos('EV25', u) > 0, 'E.W.: the injury (EV23), the throw (EV24) and the brick at the cat (EV25): no rule pack here is about them, and the screen lists them (Offences against the Person Act 1861, Animal Welfare Act 2006: not held)'

say '== 7. a deliberate throw: NSW ss.33 and 35'
do pk over .array~of(.array~of('crimes1900_s33.md', 25), .array~of('crimes1900_s35.md', 10))
  rr = .SlamLaw~parse(L || '/' || pk[1])
  e = .SlamLaw~check(rr, .SlamLaw~officialFor(nsw, rr))~union(.SlamLaw~checkMaximum(rr, nsw))~union(.SlamLaw~kindErrors(v, .SlamLaw~kindsOfRule(rr, pk[1])))
  do x over e; say '       ' x; end
  call check e~items = 0 & rr['MAXIMUM']['YEARS'] = pk[2] & rr['EXTENT'] == 'NSW', pk[1] || ': the NSW text word for word, quotes, paragraphs, rule line, kinds; the most the law says,' pk[2] 'years, in the XML'
end
a = find(ns, 'crimes1900nsw.s33', 'EV23'); b = find(ns, 'crimes1900nsw.s35', 'EV23')
say '      ' .SlamScreen~line(a[1]); say '      ' .SlamScreen~line(b[1])
sa = ''; do e over a[1]['ELEMENTS']; sa = sa e['STATUS']; end
sb = ''; do e over b[1]['ELEMENTS']; sb = sb e['STATUS']; end
call check a~items = 1 & a[1]['PERSON'] == 'M' & \a[1]['OK'] & sa~space == 'SUPPORTED SETTLED SETTLED UNDETERMINED' & a[1]['ASAT'] == 'IN_FORCE_TEXT', 's.33 (25 years): he threw it (his word), the cause and the harm (the hospital); the intent to cause grievous bodily harm: nothing offered, open; this text was the law in 2009 (substituted 2007)'
call check b~items = 1 & b[1]['PERSON'] == 'M' & \b[1]['OK'] & sb~space == 'SUPPORTED SETTLED SETTLED DISPUTED' & b[1]['ASAT'] == 'EARLIER_TEXT_NEEDED', 's.35(2) (10 years): recklessness as to hurt to a person is DISPUTED, his first interview (a man) against his second (a cat); amended 2012, so the 2009 text is needed'
call check hasText(a[1]['ELEMENTS'][1]['REFUSED'], 'PREVIOUS_CONVICTION: E20') & hasText(b[1]['ELEMENTS'][1]['REFUSED'], 'OBJECT_THROWN: E21'), 'in both, as in s.54: his record and the brick at the cat are refused for "he did it"'

say 'SCREEN PEOPLE TEST: PASS (' || checks || ' checks)'
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

gapOf: procedure
  use arg x, n
  do y over x['GAPS']
    if y['ELEMENT'] = n then return y
  end
  return .nil

text: procedure
  use arg path
  s = .stream~new(path); s~open('READ'); t = s~charin(1, s~chars); s~close
  return t
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
::requires 'SlamNswLegislation.cls'
::requires 'json.cls'
