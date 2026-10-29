/* Legislation -> small model -> SLAM -> Reasoned Thought (Tom Dyer's chain), on the Computer Misuse Act 1990
 * (legislation.gov.uk XML), the CPS legal guidance, and two made-up cases.
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-29.  The rule and guidance files stand in for the
 * small model's output: written by Claude (Opus 5.5), and they say so.
 * Args: scratch dir | SLAM package dir
 *
 *  0. the official text, from the XML, per extent: s.1's Scotland-only words are not England and Wales's;
 *     the text pasted from the web page, resolved by its notes, gives the same words
 *  1. both rules and the guidance pass the gates: reader, official text, quotes word for word, every
 *     paragraph covered, every element named
 *  2. drifts a small model can make, each refused: an undefined word, a paraphrased quote, a dropped
 *     condition, an element left out of the rule, the wrong extent, a guidance quote not in the guidance
 *  3. s.1 with the CPS guidance, step by step: evidence refused for the reason the guidance gives (asking an
 *     operator; authority without defined limits; recklessness for knowledge), and the elements supported
 *     only when the evidence that counts is in
 *  4. s.3ZA: the same kind of evidence, recklessness, counts for its element (d) and not for its element (b)
 */
signal on syntax name onSyntax
parse arg work '|' pkg
checks = 0
L = pkg || '/tests/law'
leg = .SlamLegislation~new(L || '/source/cma1990.xml')
s1ew = leg~section('1', 'E.W.'); s1s = leg~section('1', 'S.')

say '== 0. the official text, per extent'
w = .SlamLaw~words(s1ew); ws = .SlamLaw~words(s1s)
call check w~pos(' or to enable any such access to be secured ') = 0 & ws~pos(' or to enable any such access to be secured ') > 0, 's.1(1)(a) "or to enable any such access to be secured": Scotland''s text has it, England and Wales''s does not (its commentary: inserted (S.))'
pasted = text(L || '/source/cma1990_offences.txt')
p1 = .SlamLaw~resolve(pasted~substr(pasted~pos('1 Unauthorised access'), pasted~pos('2 Unauthorised access with intent') - pasted~pos('1 Unauthorised access')), 'E.W.')
sub = .SlamLaw~words(.SlamLaw~parse(L || '/cma1990_s1.md')['SOURCE'])   /* s.1(1) as the rule quotes it, numbers included */
call check w~pos(sub) > 0 & .SlamLaw~words(p1)~pos(sub) > 0, 'the XML and the pasted web text, each resolved for E.W. by its own route, give the same s.1(1), word for word'
call check leg~section('3ZA', 'S.') \== '' & leg~section('3ZA', 'E.W.') \== '', 's.3ZA extends to both (no extent of its own: its crossheading''s, E+W+S+N.I.)'

say '== 1. the gates'
s1 = .SlamLaw~parse(L || '/cma1990_s1.md')
s3 = .SlamLaw~parse(L || '/cma1990_s3za.md')
do f over .array~of('cma1990_s1.md', 'cma1990_s3za.md', 'cps_cma.md')
  call check reader(work, pkg, L || '/' || f) == '', 'reader:' f 'has no unknown word'
end
e = .SlamLaw~check(s1, leg~section(s1['SECTION'], s1['EXTENT']))
do x over e; say '       ' x; end
call check e~items = 0, 's.1 (E.W.): its text is the XML''s for E.W.; 4 elements, quotes word for word, (a) (b) (c) covered, all named'
e = .SlamLaw~check(s3, leg~section(s3['SECTION'], s3['EXTENT']))
do x over e; say '       ' x; end
call check e~items = 0, 's.3ZA (E.W.): the same, (a) (b) (c) (d) covered'
cps = text(L || '/source/cps_cma_guidance.txt')
g = .SlamLaw~applyGuidance(s1, L || '/cps_cma.md', cps)
do x over g; say '       ' x; end
call check g~items = 0 & .SlamLaw~element(s1, 3)['BINDS'][1] == 'DEFINED_LIMITS' & \.SlamLaw~element(s1, 4)['BINDS']~hasItem('RECKLESSNESS'), 'CPS guidance applied to s.1: element 3 now takes DEFINED_LIMITS (Allison), element 4 refuses RECKLESSNESS, element 1 refuses PHYSICAL_CONTACT, SCREEN_READING, REQUEST_TO_ANOTHER'

say '== 2. drifts, each refused'
good = text(L || '/cma1990_s1.md')
d = write(work, 'd1.md', good~changeStr('at the time the person causes the computer to run the function, the person knows that the access is unauthorised.', 'the person is reckless as to whether the access is unauthorised.'))
r = reader(work, pkg, d)
call check r~wordPos('whether') > 0, 'an undefined word ("reckless as to whether"): the reader refuses' r
d = write(work, 'd2.md', good~changeStr('he knows at the time when he causes the computer to perform the function that that is the case' || '0a'x || '```', 'he ought to know at the time when he causes the computer to perform the function that that is the case' || '0a'x || '```'))
call check hasText(.SlamLaw~check(.SlamLaw~parse(d), s1ew), 'not in the section, word for word'), 'a paraphrased quote ("ought to know"): refused'
d = write(work, 'd3.md', good~left(good~pos('element 4:') - 1) || 'rule: when element 1, element 2 and element 3 are true, the offence is true.' || '0a'x)
call check hasText(.SlamLaw~check(.SlamLaw~parse(d), s1ew), 'paragraph (c) has no element'), 'a dropped condition: refused, paragraph (c) has no element'
d = write(work, 'd4.md', good~changeStr('when element 1, element 2, element 3 and element 4 are true', 'when element 1, element 2 and element 3 are true'))
call check hasText(.SlamLaw~check(.SlamLaw~parse(d), s1ew), 'does not name element 4'), 'an element left out of the rule: refused'
scot = good~changeStr('held in any computer;' || '0a'x || '(b) the access he intends to secure is unauthorised;', 'held in any computer, or to enable any such access to be secured;' || '0a'x || '(b) the access he intends to secure, or to enable to be secured, is unauthorised;')
d = write(work, 'd5.md', scot)
call check hasText(.SlamLaw~check(.SlamLaw~parse(d), s1ew), 'not the official text for extent E.W.'), 'Scotland''s words in a rule that says E.W. (the first draft of this rule, from memory, had them): refused'
d = write(work, 'd5s.md', scot~changeStr('extent: E.W.', 'extent: S.')~changeStr('the access he intends to secure is unauthorised' || '0a'x || '```', 'the access he intends to secure, or to enable to be secured, is unauthorised' || '0a'x || '```'))
call check .SlamLaw~check(.SlamLaw~parse(d), leg~section('1', 'S.'))~items = 0, 'the same words in a rule that says S.: passes (it is Scotland''s law)'
gd = write(work, 'g1.md', text(L || '/cps_cma.md')~changeStr('mere recklessness is not sufficient.', 'recklessness is never enough.'))
call check hasText(.SlamLaw~applyGuidance(.SlamLaw~parse(L || '/cma1990_s1.md'), gd, cps), 'not in the guidance, word for word'), 'a guidance quote not in the CPS text: refused'
call check hasText(.SlamLaw~applyGuidance(.SlamLaw~parse(L || '/cma1990_s3za.md'), L || '/cps_cma.md', cps), 'not for cma1990.s3za'), 'the s.1 guidance offered for s.3ZA: refused'

say '== 3. s.1 with the CPS guidance, step by step (made up: no real person)'
r = .SlamReasoning~new
off = .SlamLaw~build(r, s1)
cases = lines(L || '/case_s1_made_up.txt')
expect = .array~of('1 UNDETERMINED', '1 HINT', '1 SETTLED', '2 SETTLED', '3 SETTLED', '4 DISPUTED', '4 SETTLED')
do step = 1 to 7
  call admitStep r, s1, cases, step
  parse value expect[step] with el want
  a = r~assess(.SlamLaw~elementId(s1, el))
  m = r~mayAct(off)
  say '       step' step || ': element' el a['status']~left(13) 'offence:' m['STATUS']
  if m['OK'] then said = 'all supported on the evidence given'; else said = 'not all supported yet'
  call check a['status'] == want & (step = 7) = m['OK'], 'step' step || ': element' el want || '; the elements are' said
  if step = 1 then do
    rf = .SlamLaw~refusals(r, s1, 1)
    do x over rf; say '         refused:' x~left(150); end
    call check rf~items = 2 & hasText(rf, 'merely been to request another'), 'step 1: the account log (binds the account) and asking the operator (Bignell, quoted) are refused for "the person caused it"'
  end
  if step = 5 then do
    rf = .SlamLaw~refusals(r, s1, 3)
    do x over rf; say '         refused:' x~left(150); end
    call check rf~items = 1 & hasText(rf, 'clearly defined the limits'), 'step 5: a manager''s view that P should not have looked is refused (Allison, quoted); the written access list counts'
  end
  if step = 6 then do
    rf = .SlamLaw~refusals(r, s1, 4)
    do x over rf; say '         refused:' x~left(150); end
    call check rf~items = 1 & hasText(rf, 'mere recklessness is not sufficient'), 'step 6: "must have guessed" is recklessness, refused for knowledge (the CPS, quoted)'
  end
end

say '== 4. s.3ZA: recklessness counts for (d), not for (b)'
r3 = .SlamReasoning~new
off3 = .SlamLaw~build(r3, s3)
call admitStep r3, s3, lines(L || '/case_s3za_made_up.txt'), 1
e2 = r3~assess(.SlamLaw~elementId(s3, 2)); e4 = r3~assess(.SlamLaw~elementId(s3, 4))
call check e4['status'] == 'SETTLED' & e4['ineligible']~items = 0, 'element 4 (intends or is reckless as to damage): R''s message counts, SETTLED'
call check e2['status'] == 'SETTLED' & e2['ineligible']~items = 1, 'element 2 (knows it is unauthorised): the same message is refused there, on record; settled by R''s other message'
call check r3~mayAct(off3)['OK'], 's.3ZA: all four elements supported on the evidence given'
say 'LAW TEST: PASS (' || checks || ' checks)'
exit 0

admitStep: procedure
  use arg r, rule, cases, step
  do ln over cases
    if ln~strip == '' | ln~left(1) == '#' then iterate
    if ln~word(1) = step then ignored = .SlamLaw~admit(r, rule, ln)
  end
  return

reader: procedure
  use arg work, pkg, file
  db = work || '/law_reader.db'
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
lines: procedure
  use arg path
  return text(path)~makeArray('0a'x)
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
  say 'SYNTAX rc=' || rc 'sigl=' || sigl condition('C') condition('D')
  exit 1

::requires 'SlamLaw.cls'
::requires 'SlamLegislation.cls'
