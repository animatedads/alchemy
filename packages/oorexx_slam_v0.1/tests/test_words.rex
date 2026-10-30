/* The word loop (src/SlamWords.cls, bin/words.rex): a circular submission for words missing.
 * Tom Dyer, 2026-10-30: a tool which uses intentions, loads what is said, allows definitions to be entered,
 * reviews meaning for definitions when added to ensure correct linkages are made; rinse and repeat.
 * Architecture: Tom Dyer.  Code and this test: Claude (Opus 5.5), 2026-10-30.
 * Args: scratch dir | SLAM package dir
 *
 *  1. the loop reads as SLAM's reader reads: the same missing words, on an account and on a document that
 *     defines a word for itself and has code in it
 *  2. three turns on a made-up account (tests/words): 20 words missing, then 18 (the words the definitions
 *     need), then 4, then none: the round closes.  The writer can not accept their own definitions
 *  3. after the round, SLAM's own reader, given the circular corpus and the shared list, knows every word
 *     of the account
 *  4. what the review said on the way: definitions that waited for words; two circles that rest on known
 *     words (man and mr; year, day, days); "priors" carries a finding through "offences" to "offence"
 *  5. each refusal, one at a time: a known word given another meaning; a word given twice; a definition with
 *     nothing in it but the word; new words defined only through each other; a meaning that would make an
 *     event kind carry a finding (CHEQUE_DRAWN, gate 6); a definition that waits for a refused word
 *  6. warnings and notes: a form not linked to its stem; two sources defining a word in two ways; two words
 *     with one definition
 *  7. two meanings (corpus/senses.csv): load stops at entry on each "false" with no answer; sense asks
 *     "false, or false [legal]?" and corrects the line as it goes; run again and nothing changes (no
 *     "false-legal-legal"); with "false-legal" in the words of a finding, "evidence" no longer carries one
 */
signal on syntax name onSyntax
parse arg work '|' pkg
checks = 0
W = pkg || '/tests/words'
base = pkg || '/corpus/circular_corpus_v2.csv'
k = .SlamWords~known(.array~of(base))

say '== 1. the same words as the reader'
l = .SlamWords~load(.array~of(W || '/account_made_up.txt'), k['WORDS'])
mine = l['ORDER']~copy~sort~makeString('L', ' ')
theirs = reader(work, pkg, .array~of(base), W || '/account_made_up.txt')
call check mine == theirs & l['ORDER']~items = 18, 'the account: 18 words not known, the same 18 as SLAM''s reader (' || mine~left(60) || '...)'
doc = work || '/words_doc.md'
call write doc, .array~of('glorp: a thing that is a frob', 'the glorp is here, in 15 places', '```', 'zzz code is not words', '```', 'glorp: a second definition is text, and qqq is not known')
l2 = .SlamWords~load(.array~of(doc), k['WORDS'])
mine2 = l2['ORDER']~copy~sort~makeString('L', ' ')
theirs2 = reader(work, pkg, .array~of(base), doc)
call check mine2 == theirs2 & mine2 == 'definition frob places qqq second text' & l2['INLINE']~items = 1, 'a word a document defines for itself; code; a numeral; a second "glorp:" line is text: the same as the reader (' || mine2 || ')'

say '== 2. three turns'
dir = work || '/words_rounds'
call SysMkDir dir
call SysFileDelete dir || '/T1.json'; call SysFileDelete dir || '/law_words.csv'
call value 'SLAM_WORDS_DIR', dir, 'ENVIRONMENT'
call value 'SLAM_WORDS_SHARED', dir || '/law_words.csv', 'ENVIRONMENT'
WRITER = '"Claude (Opus 5.5)"'; REVIEWER = '"Reviewer B (test)"'     /* quoted for the shell */
o = words(pkg, 'open T1' WRITER '-- read the words of the fourth account --' W || '/account_made_up.txt')
missing = .array~new
o = words(pkg, 'load T1'); missing~append(said(o, 'words missing:'))
o = words(pkg, 'define T1' WRITER '--' W || '/turn1.md')
call check said(o, 'passed,') = 3 & o~makeString('L', ' ')~pos('17 waiting for words') > 0, 'turn 1: 20 definitions; 3 pass (wrote, had, which); 17 wait for the words they need'
o = words(pkg, 'accept T1' WRITER)
call check said(o, 'accepted into') = 0, 'the writer accepts: nothing goes into the shared list (a definition is testimony; its writer does not review it)'
o = words(pkg, 'accept T1' REVIEWER); call check said(o, 'accepted into') = 3, 'a second reviewer accepts the 3'
o = words(pkg, 'load T1'); missing~append(said(o, 'words missing:'))
o = words(pkg, 'define T1' WRITER '--' W || '/turn2.md'); o = words(pkg, 'accept T1' REVIEWER)
o = words(pkg, 'load T1'); missing~append(said(o, 'words missing:'))
o = words(pkg, 'define T1' WRITER '--' W || '/turn3.md'); o = words(pkg, 'accept T1' REVIEWER)
o = words(pkg, 'load T1')
closed = o~makeString('L', ' ')~pos('the round is closed') > 0
led = .json~fromJsonFile(dir || '/T1.json')
call check missing~makeString('L', ' ') == '20 18 4' & closed & led['status'] == 'CLOSED' & count(led, 'ACCEPTED') = 44, 'missing: 20, then 18, then 4, then none; the round is CLOSED, 44 words accepted'

say '== 3. the reader, after'
r3 = reader(work, pkg, .array~of(base, dir || '/law_words.csv'), W || '/account_made_up.txt')
call check r3 == '', 'SLAM''s reader, given the circular corpus and the shared list, knows every word of the account'

say '== 4. what the review said'
call check has(led, 'man', 'WARN CIRCLE: man, mr') & has(led, 'year', 'WARN CIRCLE: day, days, year') & has(led, 'priors', 'priors -> offences -> offence') & has(led, 'theft', 'uses "offence", a word of a finding'), 'two circles that rest on known words (man, mr; day, days, year), warned; "priors" carries a finding through "offences" to "offence"; "theft" carries one'

say '== 5. refused'
v = .SlamLaw~vocabulary(pkg || '/tests/law/VOCABULARY.md')
op = .directory~new; op['FINDING'] = v['FINDINGWORDS']; op['KINDS'] = v['KINDS']
res = .SlamWords~review(entries('rule: a law|glorp: a thing|glorp: an other thing|nothing: nothing|frob: a blit|blit: a frob'), k['WORDS'], op)
call check code(res, 'rule') == 'REFUSED CONFLICT' & code(res, 'glorp', 2) == 'REFUSED GIVEN_TWICE' & code(res, 'nothing') == 'REFUSED ONLY_ITSELF' & code(res, 'frob') == 'REFUSED CIRCLE' & code(res, 'blit') == 'REFUSED CIRCLE', 'a known word with another meaning; a word given twice; a definition of nothing but itself; new words defined only through each other: each refused'
res = .SlamWords~review(entries('cheque: a thing that a person knows a bank will pay|person: a thing that can know|bank: a place for money|money: a thing to give'), k['WORDS'], op)
c = find(res, 'cheque')
call check c['STATUS'] == 'REFUSED' & hasCode(c, 'CARRIES_FINDING') & hasText(c, 'kind CHEQUE_DRAWN is an event'), '"cheque" defined with "knows": it carries a finding, and CHEQUE_DRAWN, an event, uses "cheque": refused (gate 6 reads only a kind''s own words; this reads one step down)'
res = .SlamWords~review(entries('tile: a part of a roof|roof: the top of a house|house: a place'), k['WORDS'], op)
call check find(res, 'roof')['STATUS'] == 'WAITING' & find(res, 'tile')['STATUS'] == 'WAITING' & hasCode(find(res, 'tile'), 'WAITS_FOR') & find(res, 'house')['STATUS'] == 'PASSED', '"roof" needs "top": it waits; "tile" uses "roof", so it waits too; "house" passes'

say '== 6. warnings and notes'
res = .SlamWords~review(entries('throw: make a thing go|throws: make a thing go|go: change place'), k['WORDS'], op)
call check hasCode(find(res, 'throws'), 'FORM') & hasCode(find(res, 'throws'), 'SAME_MEANING') & find(res, 'throws')['STATUS'] == 'PASSED', '"throws" does not use "throw": warned (FORM); it has the same definition as "throw" (noted); it passes'
d1 = work || '/words_a.md'; d2 = work || '/words_b.md'
call write d1, .array~of('reckless: makes a change, and knows that damage can be the result of it')
call write d2, .array~of('reckless: makes a change, and knows that a false result can be the result of it')
l3 = .SlamWords~load(.array~of(d1, d2), k['WORDS'])
op['INLINE'] = l3['INLINE']
res = .SlamWords~review(entries('reckless: makes a change, and knows that a bad result can be the result of it'), k['WORDS'], op)
call check l3['DIFFER']~hasIndex('reckless') & l3['DIFFER']['reckless']~items = 2 & hasCode(find(res, 'reckless'), 'DEFINED_ELSEWHERE'), 'two sources define "reckless" in two ways: load lists both; a definition for the shared list is warned that they differ from it'

say '== 7. two meanings: false, or false [legal]'
sn = .SlamWords~senses(pkg || '/corpus/senses.csv')
call check sn['ERRORS']~items = 0 & sn['TOKENS']~hasIndex('false-legal') & sn['WORDS']['false']~items = 1 & v['FINDINGWORDS']~hasItem('false-legal') & \v['FINDINGWORDS']~hasItem('false') & v['ERRORS']~items = 0, 'the register: "false-legal" is the law''s false; VOCABULARY.md''s words of a finding name "false-legal", not "false"; gate 6 passes'
bad = work || '/words_senses_bad.csv'
call write bad, .array~of('token,category,definition', 'false-legal,sense false legal,x', 'false-legal-legal,sense false-legal legal,y', 'untrue,sense false legal,z')
sb = .SlamWords~senses(bad)
call check sb['ERRORS']~items = 2 & hasItemText(sb['ERRORS'], 'it would be replaced again') & hasItemText(sb['ERRORS'], 'is "false-legal"'), 'a register that would replace a replacement ("false-legal-legal": its word, "false-legal", is itself a sense) is refused; so is a token that is not WORD-LABEL'
ev = entries('evidence: data that says an element is true or false')
old = .directory~new; old['FINDING'] = .array~of('knows', 'false')
call check hasCode(.SlamWords~review(ev, k['WORDS'], old)[1], 'CARRIES_FINDING') & \hasCode(.SlamWords~review(ev, k['WORDS'], op)[1], 'CARRIES_FINDING'), 'with "false" in the words of a finding, "evidence" (true or false) carried a finding; with "false-legal", it does not'
doc = work || '/words_false.md'
call write doc, .array~of('evidence: data that says an element is true or false', 'a thing a person said, as true, is false.', '```', 'false in code is not asked', '```', 'false-legal is not asked', 'it is false, and false again')
qs = .SlamWords~preparse(.array~of(doc), sn, .directory~new, k['WORDS'])
lns = ''; do q over qs; lns = lns q['LINE']; end
call check qs~items = 4 & lns~space == '1 2 7 7' & qs[1]['OPTIONS']~items = 2 & qs[1]['OPTIONS'][1]['TEXT'] == 'not true', 'preparse: four "false" to ask (lines 1, 2, and 7 twice); not in code; not "false-legal"; the choices are "false" (not true) and "false [legal]"'
call SysFileDelete dir || '/T2.json'
o = words(pkg, 'open T2' WRITER '-- read what is false --' doc)
o = words(pkg, 'load T2')
stopped = o~makeString('L', ' ')~pos('nothing is read until they have one') > 0 & said(o, 'words have more than one meaning') = 5
ans = work || '/words_answers.txt'
call write ans, .array~of('1')
o = words(pkg, 'sense T2' REVIEWER '<"' || ans || '"')
part = linesOf(doc)
call write ans, .array~of('1', 'legal', 'false-legal', 'false')
o = words(pkg, 'sense T2' REVIEWER '<"' || ans || '"')
after = linesOf(doc)
call check stopped & part[1] == 'evidence: data that says an element is true or false' & after[2] == 'a thing a person said, as true, is false-legal.' & after[7] == 'it is false-legal, and false again' & after[1] == part[1], 'load stops at entry and asks (five: the intention''s "false" too); one answer, then the input ends: kept, and the rest asked next time; then each line corrected as it is answered'
o = words(pkg, 'sense T2' REVIEWER '<"' || ans || '"')
o2 = words(pkg, 'sense T2' REVIEWER '<"' || ans || '"')
again = linesOf(doc)
o3 = words(pkg, 'load T2')
led2 = .json~fromJsonFile(dir || '/T2.json')
call check o~makeString('L', ' ')~pos('nothing to ask') > 0 & o2~makeString('L', ' ')~pos('nothing to ask') > 0 & again~makeString('L', '|') == after~makeString('L', '|') & again~makeString('L', ' ')~pos('false-legal-legal') = 0 & o3~makeString('L', ' ')~pos('more than one meaning') = 0 & led2['intention'] == 'read what is false', 'run again, and again: nothing to ask, nothing changed, no "false-legal-legal"; load reads on'
call check .SlamWords~occurrences('it is false-legal, and false-legal.', sn['WORDS'])~items = 0 & .SlamWords~resolve('is false-legal', .array~new) == 'is false-legal', 'a replaced word is not a word with senses: there is nothing left on the line to replace'

say 'WORDS TEST: PASS (' || checks || ' checks)'
exit 0

/* SLAM's own reader (bin/slam.rex) on FILE, with a new database and the given word lists: its unknown words */
reader: procedure
  use arg work, pkg, lists, file
  db = work || '/words_reader.db'
  call SysFileDelete db; call SysFileDelete db || '-wal'; call SysFileDelete db || '-shm'
  do p over lists
    address system 'rexx "' || pkg || '/bin/slam.rex" corpus "' || db || '" "' || p || '"' with output stem ignore.
  end
  address system 'rexx "' || pkg || '/bin/slam.rex" read "' || db || '" "' || file || '"' with output stem o.
  out = .array~new
  do i = 1 to o.0
    w1 = o.i~strip~word(1)
    if w1~right(1) == ':' & datatype(w1~strip('T', ':'), 'W') then do
      x = o.i~strip~word(2)
      if \out~hasItem(x) then out~append(x)
    end
  end
  return out~sort~makeString('L', ' ')

linesOf: procedure
  use arg path
  out = .array~new; s = .stream~new(path); s~open('READ')
  do while s~lines > 0; out~append(s~linein); end
  s~close
  return out

hasItemText: procedure
  use arg arr, needle
  do e over arr; if e~pos(needle) > 0 then return .true; end
  return .false

words: procedure
  use arg pkg, args
  address system 'rexx "' || pkg || '/bin/words.rex"' args with output stem o.
  out = .array~new
  do i = 1 to o.0; out~append(o.i); end
  return out

/* the number before WHAT on a line of the output, or -1 */
said: procedure
  use arg out, what
  do ln over out
    p = ln~pos(what)
    if p > 0 then return ln~left(p - 1)~strip~word(ln~left(p - 1)~strip~words)
  end
  return -1

count: procedure
  use arg led, st
  n = 0
  do e over led['entries']; if e['status'] == st then n += 1; end
  return n

has: procedure
  use arg led, word, needle
  do e over led['entries']
    if e['word'] \== word then iterate
    do f over e['findings']; if f~pos(needle) > 0 then return .true; end
  end
  return .false

entries: procedure
  use arg spec
  out = .array~new
  do while spec \== ''
    parse var spec one '|' spec
    parse var one w ':' t
    d = .directory~new; d['WORD'] = w~strip; d['TEXT'] = t~strip; out~append(d)
  end
  return out

find: procedure
  use arg res, w, n = 1
  do r over res
    if r['WORD'] == w then do
      n -= 1
      if n = 0 then return r
    end
  end
  return .nil

/* the status and the first refusal of the Nth entry for W */
code: procedure
  use arg res, w, n = 1
  r = find(res, w, n)
  do f over r['FINDINGS']
    if f['SEVERITY'] == 'REFUSE' then return r['STATUS'] f['CODE']
  end
  return r['STATUS']

hasCode: procedure
  use arg r, cd
  do f over r['FINDINGS']; if f['CODE'] == cd then return .true; end
  return .false

hasText: procedure
  use arg r, needle
  do f over r['FINDINGS']; if f['TEXT']~pos(needle) > 0 then return .true; end
  return .false

write: procedure
  use arg path, lines
  s = .stream~new(path); s~open('WRITE REPLACE')
  do ln over lines; s~lineout(ln); end
  s~close
  return

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

::requires 'SlamWords.cls'
::requires 'SlamLaw.cls'
::requires 'json.cls'
