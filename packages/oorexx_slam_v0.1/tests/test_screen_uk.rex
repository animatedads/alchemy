/* The same events, more offences: Fraud Act 2006 s.2, Theft Act 1968 ss.1 and 21, beside the Computer Misuse
 * Act.  Adding an offence is adding a rule pack: the case and the evidence do not change for it.
 * Architecture: Tom Dyer.  Code and rule packs: Claude (Opus 5.5), 2026-10-30, standing in for the small model.
 * The Acts' XML: fetched by Tom Dyer from legislation.gov.uk (tests/law/source/MANIFEST_LEGISLATION.md).
 * Args: scratch dir | SLAM package dir | alchemy checkout
 *
 *  1. the sources are the ones pinned: each Act's SHA-256 is the manifest's
 *  2. the three rule packs pass every gate: the reader, the official text (E.W.), quotes, paragraphs, the
 *     rule line, the list of kinds, and "the most the law says" (10, 7 and 14 years), checked in the XML
 *  3. drifts refused: a maximum the law does not say; a maximum from the wrong section
 *  4. the screen, E.W.: the results written down before the run
 *  5. scope: no event of the roof, the card, the threat or the savings gets a supported element from
 *     evidence about the withdrawals; with the bank's letter widened to every event, the roof would
 *  6. CMA s.2 for J: "the further offence carries five years" is now answered by the further offence's own
 *     rule pack (theft, section 7, seven years), in England and Wales; in Scotland the Theft Act does not
 *     run, so it stays open, and the record says why
 *  7. persons from the case's own roles: T for the threat, S for the savings; nothing filled in for "they"
 */
signal on syntax name onSyntax
parse arg work '|' pkg '|' repo
checks = 0
L = pkg || '/tests/law'
FIXTURES = repo || '/docs/architecture/fixtures'
mfText = text(L || '/source/MANIFEST_LEGISLATION.md')

say '== 1. the sources are the ones pinned'
legs = .directory~new
do pair over .array~of(.array~of('fraud2006', 'b3a267d809d0b3e1a6a872b29c4192bdd47515ca70d8335d3c46f6714a0c4107'), .array~of('theft1968', '34afb7e66bd1c99c6e79af6c9c54f58db32cc5227a9595da7c7dd9014ee3cefc'))
  path = L || '/source/' || pair[1] || '.xml'
  address system 'sha256sum "' || path || '"' with output stem h.
  call check h.1~word(1) == pair[2] & mfText~pos(pair[2]) > 0, pair[1] || '.xml: SHA-256' pair[2]~left(16) || '..., as the manifest says'
  legs[pair[1]] = .SlamLegislation~new(path)
end

say '== 2. the three rule packs pass every gate'
v = .SlamLaw~vocabulary(L || '/VOCABULARY.md')
packs = .array~of(.array~of('fraud2006_s2.md', 'fraud2006', 10), .array~of('theft1968_s1.md', 'theft1968', 7), .array~of('theft1968_s21.md', 'theft1968', 14))
do pk over packs
  r = .SlamLaw~parse(L || '/' || pk[1])
  leg = legs[pk[2]]
  e = .SlamLaw~check(r, .SlamLaw~officialFor(leg, r))~union(.SlamLaw~checkMaximum(r, leg))~union(.SlamLaw~kindErrors(v, .SlamLaw~kindsOfRule(r, pk[1])))
  do x over e; say '       ' x; end
  call check e~items = 0 & reader(work, pkg, L || '/' || pk[1]) == '' & r['MAXIMUM']['YEARS'] = pk[3] & leg~section(r['SECTION'], 'S.') == '', pk[1] || ': reader, official text (E.W.), quotes, paragraphs, rule line, kinds; the most the law says,' pk[3] 'years (section' r['MAXIMUM']['SECTION'] || '), in the XML; the section does not extend to Scotland'
end

say '== 3. drifts refused'
good = text(L || '/theft1968_s1.md')
d = .SlamLaw~parse(write(work, 'max12.md', good~changeStr('imprisonment for a term not exceeding seven years', 'imprisonment for a term not exceeding twelve years')))
call check hasText(.SlamLaw~checkMaximum(d, legs['theft1968']), 'is not in section 7'), 'a maximum the law does not say (twelve years for theft): refused'
d = .SlamLaw~parse(write(work, 'maxsec.md', good~changeStr('section: 7' || '0a'x, 'section: 1' || '0a'x)))
call check hasText(.SlamLaw~checkMaximum(d, legs['theft1968']), 'is not in section 1'), 'the right words quoted from the wrong section (1, not 7): refused'

say '== 4. the screen, England and Wales (made up: no real person, bank or record)'
case = .json~fromJsonFile(FIXTURES || '/mrs_p_roof_credit_pension_v0.2.json')
ev = .json~fromJsonFile(L || '/mrs_p_evidence_made_up.json')
paths = .array~new
do f over .array~of('cma1990_s1.md', 'cma1990_s1_scotland.md', 'cma1990_s2.md', 'cma1990_s3za.md', 'fraud2006_s2.md', 'theft1968_s1.md', 'theft1968_s21.md')
  paths~append(L || '/' || f)
end
g = .array~of(.array~of(L || '/cps_cma.md', text(L || '/source/cps_cma_guidance.txt')))
vf = .directory~new
cmaLeg = .SlamLegislation~new(L || '/source/cma1990.xml')
do id over .array~of('cma1990.s1', 'cma1990.s2', 'cma1990.s3za'); vf[id] = cmaLeg~validFrom; end
vf['fraud2006.s2'] = legs['fraud2006']~validFrom; vf['theft1968.s1'] = legs['theft1968']~validFrom; vf['theft1968.s21'] = legs['theft1968']~validFrom
ew = .SlamScreen~screen(case, ev, paths, 'E.W.', g, vf)
expect = .array~of( -
  'fraud2006.s2 EV02 S: 1=UNKNOWN 2=UNKNOWN 3=UNKNOWN 4=UNKNOWN 5=UNKNOWN -> NOT_SUPPORTED', -
  'fraud2006.s2 EV03 S: 1=UNKNOWN 2=UNKNOWN 3=UNKNOWN 4=UNKNOWN 5=UNKNOWN -> NOT_SUPPORTED', -
  'fraud2006.s2 EV06 T: 1=UNKNOWN 2=UNKNOWN 3=UNKNOWN 4=UNKNOWN 5=UNKNOWN -> NOT_SUPPORTED', -
  'fraud2006.s2 EV07 T: 1=UNKNOWN 2=UNKNOWN 3=UNKNOWN 4=UNKNOWN 5=UNKNOWN -> NOT_SUPPORTED', -
  'fraud2006.s2 EV16.1 J: 1=SUPPORTED 2=SUPPORTED 3=SUPPORTED 4=SUPPORTED 5=SUPPORTED -> SUPPORTED', -
  'fraud2006.s2 EV16.2 UNRESOLVED: 1=UNKNOWN 2=SUPPORTED 3=UNKNOWN 4=UNKNOWN 5=UNKNOWN -> NOT_SUPPORTED', -
  'fraud2006.s2 EV16.3 H: 1=UNKNOWN 2=SUPPORTED 3=UNKNOWN 4=UNKNOWN 5=UNKNOWN -> NOT_SUPPORTED', -
  'theft1968.s1 EV09 S: 1=UNKNOWN 2=UNKNOWN 3=UNKNOWN 4=UNKNOWN -> NOT_SUPPORTED', -
  'theft1968.s1 EV16.1 J: 1=SUPPORTED 2=SUPPORTED 3=SUPPORTED 4=SUPPORTED -> SUPPORTED', -
  'theft1968.s1 EV16.2 UNRESOLVED: 1=UNKNOWN 2=SUPPORTED 3=UNKNOWN 4=UNKNOWN -> NOT_SUPPORTED', -
  'theft1968.s1 EV16.3 H: 1=UNKNOWN 2=SUPPORTED 3=UNKNOWN 4=UNKNOWN -> NOT_SUPPORTED', -
  'theft1968.s21 EV08 T: 1=UNKNOWN 2=UNKNOWN 3=UNKNOWN 4=UNKNOWN -> NOT_SUPPORTED', -
  'cma1990.s2 EV16.1 J: 1=SUPPORTED 2=SUPPORTED 3=SUPPORTED -> SUPPORTED', -
  'cma1990.s2 EV16.2 UNRESOLVED: 1=UNKNOWN 2=UNKNOWN 3=UNKNOWN -> NOT_SUPPORTED', -
  'cma1990.s2 EV16.3 H: 1=UNKNOWN 2=UNKNOWN 3=UNKNOWN -> NOT_SUPPORTED')
got = .array~new
do x over ew
  if x['STATUS'] == 'OUT_OF_SCOPE' then iterate
  if wordpos(x['RULE'], 'fraud2006.s2 theft1968.s1 theft1968.s21 cma1990.s2') = 0 then iterate
  say '      ' .SlamScreen~line(x)
  got~append(short(x))
end
same = got~items = expect~items
do x over expect; if \got~hasItem(x) then do; same = .false; say '       missing:' x; end; end
call check same, 'E.W.: 15 results for the new rule packs and CMA s.2, each as written down before the run'
call check find(ew, 'fraud2006.s2', 'EV16.1')[1]['OK'] & find(ew, 'theft1968.s1', 'EV16.1')[1]['OK'], 'J, withdrawal 1: fraud by false representation (s.2(5): to a machine) and theft are SUPPORTED on the evidence given, from the same events and evidence as the CMA'

say '== 5. scope'
narrative = 0; wrong = 0
do x over ew
  if x['STATUS'] == 'OUT_OF_SCOPE' then iterate
  if wordpos(x['EVENT'], 'EV02 EV03 EV06 EV07 EV08 EV09') = 0 then iterate
  narrative += 1
  do e over x['ELEMENTS']; if e['REPORT'] \== 'UNKNOWN' then wrong += 1; end
end
call check narrative = 6 & wrong = 0, 'the roof statements (EV02, EV03), the card and the claim to be the council (EV06, EV07), the threat (EV08) and the savings (EV09): 6 instances, every element UNKNOWN; none of the withdrawals'' evidence reaches them'
ev2 = .json~fromJsonFile(L || '/mrs_p_evidence_made_up.json')
do it over ev2['evidenceItems']; if it['evidenceId'] == 'E16' then it['eventId'] = '*'; end
x = find(.SlamScreen~screen(case, ev2, paths, 'E.W.', g, vf), 'fraud2006.s2', 'EV02')[1]
call check x['ELEMENTS'][2]['REPORT'] == 'SUPPORTED', 'the bank''s letter about the machine, widened to every event ("*"), would make S''s roof statement "false" on no evidence about the roof: the evidence''s scope is what stops it (found by this screen, 2026-10-30)'

say '== 6. CMA s.2: the further offence''s maximum, from its own rule pack'
x = find(ew, 'cma1990.s2', 'EV16.1')[1]
call check x['OK'] & x['ELEMENTS'][3]['STATUS'] == 'SETTLED', 'E.W.: J''s message names the further offence (theft1968.s1); its rule pack says section 7, "not exceeding seven years", checked in the XML: five years or more, SETTLED, and s.2 is SUPPORTED on the evidence given'
sc = .SlamScreen~screen(case, ev, paths, 'S.', g, vf)
oos = ''
do y over sc; if y['STATUS'] == 'OUT_OF_SCOPE' then oos = oos y['RULE']; end
call check wordpos('fraud2006.s2', oos) > 0 & wordpos('theft1968.s1', oos) > 0 & wordpos('theft1968.s21', oos) > 0, 'S.: the Fraud Act and Theft Act rule packs are OUT_OF_SCOPE (their sections do not extend to Scotland)'
x = find(sc, 'cma1990.s2', 'EV16.1')[1]
gp = gapOf(x, 3)
call check \x['OK'] & gp \== .nil & hasText(gp['REFUSED'], 'RULE_PACK_OUT_OF_SCOPE: E10: the further offence theft1968.s1 has no rule pack for S.'), 'S.: the same evidence, but theft is a common-law crime there: element 3 stays open, and the record says the further offence has no rule pack for Scotland'

say '== 7. persons from the case''s own roles'
call check find(ew, 'theft1968.s21', 'EV08')[1]['PERSON'] == 'T' & find(ew, 'theft1968.s1', 'EV09')[1]['PERSON'] == 'S', 'the threat is screened for T (its SPEAKER), the savings for S (their PAYEE): the narrative names them; the evidence must still show them'
call check find(ew, 'theft1968.s1', 'EV16.2')[1]['PERSON'] == 'UNRESOLVED', '"they" (EV16''s ACTOR) is not a person in the case: withdrawal 2 stays UNRESOLVED'
say 'SCREEN UK TEST: PASS (' || checks || ' checks)'
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

reader: procedure
  use arg work, pkg, file
  db = work || '/screen_uk_reader.db'
  call SysFileDelete db; call SysFileDelete db || '-wal'; call SysFileDelete db || '-shm'
  address system 'rexx "' || pkg || '/bin/slam.rex" corpus "' || db || '" "' || pkg || '/corpus/circular_corpus_v2.csv"' with output stem ignore.
  address system 'rexx "' || pkg || '/bin/slam.rex" corpus "' || db || '" "' || pkg || '/corpus/senses.csv"' with output stem ignore.     /* second meanings: false-legal */
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
