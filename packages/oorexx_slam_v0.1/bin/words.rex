/* words.rex - the word loop (src/SlamWords.cls): a round of words for one intention.
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-30.
 *
 *   rexx words.rex open   ROUND BY -- INTENTION -- FILE [FILE...]   a round: who opens it, what the words are
 *                                                  for, and what is said
 *   rexx words.rex load   ROUND                    read what is said; the words not known, and where.  Writes
 *                                                  ROUND.missing.md (a form: "word:" for each) and, when the
 *                                                  sources define words for themselves, ROUND.inline.md
 *   rexx words.rex define ROUND BY -- FILE          enter definitions ("word: definition" lines) and review
 *                                                  them; writes ROUND.review.md
 *   rexx words.rex accept ROUND BY                  passed definitions into the shared list, when BY did not
 *                                                  write them
 *   rexx words.rex status ROUND
 * BY is a name ("Tom Dyer", "Claude (Opus 5.5)"): quote it for the shell; " -- " ends it.
 * Then load again.  The round is closed when a load finds no word missing.
 *
 * A round is a JSON file, corpus/rounds/ROUND.json (json.cls ships with ooRexx).  Places: SLAM_WORDS_DIR
 * (the rounds), SLAM_WORDS_SHARED (the shared list, default corpus/law_words.csv); the circular corpus and
 * tests/law/VOCABULARY.md are read from this package.
 */
signal on syntax name onSyntax
parse source . . me
pkg = me~left(me~lastPos('/') - 1); pkg = pkg~left(pkg~lastPos('/') - 1)
.local~pkg = pkg
parse arg cmd round rest
cmd = cmd~lower
dir = value('SLAM_WORDS_DIR', , 'ENVIRONMENT'); if dir == '' then dir = pkg || '/corpus/rounds'
if cmd == '' | round == '' then do
  say 'usage: rexx words.rex open|load|define|accept|status ROUND ...'
  exit 2
end
file = dir || '/' || round || '.json'
select
  when cmd == 'open' then exit open(file, round, rest)
  when cmd == 'load' then exit load(file, dir || '/' || round)
  when cmd == 'define' then exit define(file, dir || '/' || round, rest)
  when cmd == 'accept' then exit accept(file, rest)
  when cmd == 'status' then exit status(file)
  otherwise do
    say 'unknown command' cmd
    exit 2
  end
end

open: procedure
  use arg file, round, rest
  if .stream~new(file)~query('exists') \== '' then do
    say 'round' round 'is open already:' file
    return 1
  end
  parse var rest by ' -- ' intention ' -- ' files
  by = by~strip; intention = intention~strip
  if by == '' | intention == '' | files~strip == '' then do
    say 'open ROUND BY -- INTENTION -- FILE [FILE...]: who opens it, what the words are for, and what is said'
    return 2
  end
  srcs = .array~new
  do k = 1 to files~words
    f = files~word(k)
    if .stream~new(f)~query('exists') == '' then do
      say 'no file' f
      return 1
    end
    srcs~append(rel(.stream~new(f)~query('exists')))
  end
  shared = value('SLAM_WORDS_SHARED', , 'ENVIRONMENT'); if shared == '' then shared = 'corpus/law_words.csv'
  led = .directory~new
  led['round'] = round; led['intention'] = intention; led['openedBy'] = by; led['opened'] = today()
  led['category'] = 'law'; led['status'] = 'OPEN'
  led['base'] = .array~of('corpus/circular_corpus_v2.csv'); led['shared'] = rel(shared)
  led['vocabulary'] = 'tests/law/VOCABULARY.md'
  led['sources'] = srcs; led['turns'] = .array~new; led['entries'] = .array~new
  call save file, led
  say 'round' round 'opened by' by || ':' intention
  say srcs~items 'sources; next: load'
  return 0

load: procedure
  use arg file, stem
  led = .json~fromJsonFile(file)
  known = knownOf(led)
  srcs = .array~of(.array~of('INTENTION', .array~of(led['intention'])))
  do s over led['sources']; srcs~append(abs(s)); end
  l = .SlamWords~load(srcs, known['WORDS'])
  /* a definition that passed waits to be accepted: its word is not asked for again.  A definition that
     waits for words: those words are asked for, with the definition that needs them */
  passed = .directory~new; needs = .directory~new; order = l['ORDER']~copy
  do e over led['entries']
    if e['status'] == 'PASSED' | e['status'] == 'WAITING' then passed[e['word']] = e['status']
  end
  do e over led['entries']
    if e['status'] \== 'WAITING' then iterate
    do x over e['needs']~makeArray(' ')
      if passed~hasIndex(x) | known['WORDS']~hasIndex(x) then iterate
      if \needs~hasIndex(x) then needs[x] = .array~new
      needs[x]~append('needed by the definition of' e['word'] '(turn' e['turn'] || ')')
      if \order~hasItem(x) then order~append(x)
    end
  end
  ask = .array~new; waiting = 0
  do w over order
    if passed~hasIndex(w) then do; if passed[w] == 'PASSED' then waiting += 1; end
    else ask~append(w)
  end
  t = .directory~new; t['turn'] = led['turns']~items + 1; t['date'] = today()
  t['missing'] = ask~items; t['words'] = ask~makeString('L', ' '); t['defined, not accepted'] = waiting
  led['turns']~append(t)
  say 'turn' t['turn'] 'of round' led['round'] || ':' led['intention']
  out = .array~new
  out~append('# round' led['round'] 'turn' t['turn'] || ':' led['intention'])
  out~append('# the words SLAM does not know.  Write a definition after each colon, in words SLAM knows or')
  out~append('# words defined here; leave out a word you will not define this turn.  Then: words.rex define')
  out~append('')
  do w over ask
    at = .array~new
    if l['MISSING']~hasIndex(w) then do x over l['MISSING'][w]; at~append(x~substr(x~lastPos('/') + 1)); end
    if needs~hasIndex(w) then do x over needs[w]; at~append(x); end
    say '  ' w~left(16) at~items~right(3) ' ' at[1]
    do x over at; out~append('# ' || x); end
    out~append(w || ':')
    out~append('')
  end
  call write stem || '.missing.md', out
  nwait = 0
  do e over led['entries']; if e['status'] == 'WAITING' then nwait += 1; end
  select
    when ask~items = 0 & waiting = 0 & nwait = 0 then do
      led['status'] = 'CLOSED'
      say 'every word is known: the round is closed'
    end
    when ask~items = 0 then say 'no word to ask for;' waiting 'defined and waiting to be accepted'
    otherwise say ask~items 'words missing:' rel(stem || '.missing.md')
  end
  if waiting > 0 & ask~items > 0 then say waiting 'more are defined and wait to be accepted'
  if known['CONFLICTS']~items > 0 then do
    say 'the known words disagree:'
    do c over known['CONFLICTS']; say '  ' c; end
  end
  /* the definitions the sources write for themselves: one form, each word once */
  inl = .array~new; seen = .directory~new
  inl~append('# round' led['round'] 'turn' t['turn'] || ': the definitions the sources write for themselves.')
  inl~append('# One word, one meaning: where the sources disagree, each version is above the word and the line is')
  inl~append('# left for you to write.  Then: words.rex define')
  inl~append('')
  nd = 0
  do d over l['INLINE']
    w = d['WORD']
    if seen~hasIndex(w) then iterate
    seen[w] = .true
    if l['DIFFER']~hasIndex(w) then do
      nd += 1
      do v over l['DIFFER'][w]; inl~append('# ' || v~substr(v~lastPos('/') + 1)); end
      inl~append(w || ':')
    end
    else inl~append(w || ':' d['TEXT'])
  end
  if seen~items > 0 then do
    call write stem || '.inline.md', inl
    say seen~items 'words the sources define for themselves,' nd 'in more than one way:' rel(stem || '.inline.md')
    do w over l['DIFFER']~allIndexes~sort
      say '  ' w || ':'
      do v over l['DIFFER'][w]; say '      ' v~substr(v~lastPos('/') + 1); end
    end
  end
  call save file, led
  return 0

define: procedure
  use arg file, stem, rest
  parse var rest by ' -- ' path
  by = by~strip; path = path~strip
  if by == '' | path == '' then do
    say 'define ROUND BY -- FILE: who wrote the definitions, and the file'
    return 2
  end
  led = .json~fromJsonFile(file)
  d = .SlamWords~definitions(path)
  do b over d['BAD']; say 'not a definition, line' b; end
  turn = led['turns']~items
  /* this turn's words, every word still waiting to be accepted, and every definition waiting for words:
     reviewed again together, so a word defined now lets a waiting definition pass.  A later definition of
     the same word replaces the earlier one */
  pend = .array~new
  do e over led['entries']
    if e['status'] \== 'PASSED' & e['status'] \== 'WAITING' then iterate
    replaced = .false
    do n over d['ENTRIES']; if n['WORD'] == e['word'] then replaced = .true; end
    if replaced then do; e['status'] = 'REPLACED'; iterate; end
    pend~append(e)
  end
  ents = .array~new
  do e over pend
    x = .directory~new; x['WORD'] = e['word']; x['TEXT'] = e['definition']; ents~append(x)
  end
  do n over d['ENTRIES']; ents~append(n); end
  res = .SlamWords~review(ents, knownOf(led)['WORDS'], opts(led))
  i = 0; passed = 0; refused = 0; waiting = 0
  do r over res
    i += 1
    if i <= pend~items then e = pend[i]
    else do
      e = .directory~new; e['word'] = r['WORD']; e['definition'] = r['TEXT']; e['writtenBy'] = by
      e['turn'] = turn; e['entered'] = today()
      led['entries']~append(e)
    end
    /* WAITING: it needs words not yet defined, and the next load asks for them */
    st = r['STATUS']
    e['status'] = st; e['level'] = r['LEVEL']; e['needs'] = r['NEEDS']~makeString('L', ' ')
    f = .array~new
    do x over r['FINDINGS']; f~append(x['SEVERITY'] x['CODE'] || ':' x['TEXT']); end
    e['findings'] = f
    select
      when st == 'PASSED' then passed += 1
      when st == 'WAITING' then waiting += 1
      when st == 'REFUSED' then refused += 1
      otherwise nop
    end
  end
  sh = .SlamWords~sheet(res)
  hdr = .array~of('# round' led['round'] 'turn' turn || ': review of the definitions by' by, '# ' || led['intention'], '')
  do s over sh; hdr~append(s); end
  call write stem || '.review.md', hdr
  do s over sh; say s; end
  say passed 'passed,' waiting 'waiting for words,' refused 'refused:' rel(stem || '.review.md')
  if waiting > 0 then say 'the words a waiting definition needs go round again: load'
  if refused > 0 then say 'a refused definition has to be written again'
  call save file, led
  return 0

accept: procedure
  use arg file, rest
  by = rest~strip
  if by == '' then do
    say 'accept ROUND BY: who accepts'
    return 2
  end
  led = .json~fromJsonFile(file)
  pend = .array~new; ents = .array~new
  do e over led['entries']
    if e['status'] \== 'PASSED' & e['status'] \== 'WAITING' then iterate
    pend~append(e)
    x = .directory~new; x['WORD'] = e['word']; x['TEXT'] = e['definition']; ents~append(x)
  end
  res = .SlamWords~review(ents, knownOf(led)['WORDS'], opts(led))  /* again: the shared list may have changed */
  shared = abs(led['shared']); add = .array~new; n = 0; mine = 0
  known = knownOf(led)['WORDS']
  /* who may accept what: not the writer; and a word goes in only with every word its definition uses */
  ok = .directory~new
  do i = 1 to pend~items
    e = pend[i]; r = res[i]
    if r['STATUS'] \== 'PASSED' then do
      if e['status'] == 'PASSED' then say e['word'] || ':' r['STATUS'] 'on review again'
      e['status'] = r['STATUS']
      iterate
    end
    if e['writtenBy'] == by then do
      mine += 1
      say e['word'] || ': written by' by || '; it waits for someone else to accept it'
      iterate
    end
    ok[e['word']] = r['USES']
  end
  changed = .true
  do while changed
    changed = .false
    do w over ok~allIndexes
      do x over ok[w]
        if x == w | known~hasIndex(x) | ok~hasIndex(x) then iterate
        say w || ': uses "' || x || '", which is not accepted yet; it waits'
        ok~remove(w); changed = .true; leave
      end
    end
  end
  do i = 1 to pend~items
    e = pend[i]
    if \ok~hasIndex(e['word']) then iterate
    add~append(.SlamWords~csvLine(e['word'], led['category'], e['definition']))
    e['status'] = 'ACCEPTED'; e['acceptedBy'] = by; e['accepted'] = today()
    n += 1
  end
  if add~items > 0 then do
    s = .stream~new(shared)
    if s~query('exists') == '' then do
      s~open('WRITE REPLACE'); s~lineout('word,category,definition')
    end
    else s~open('WRITE APPEND')
    do a over add; s~lineout(a); end
    s~close
  end
  call save file, led
  say n 'accepted into' led['shared'] || ';' mine 'wait for another reviewer.  Next: load'
  return 0

status: procedure
  use arg file
  led = .json~fromJsonFile(file)
  say 'round' led['round'] '(' || led['status'] || '), opened by' led['openedBy'] led['opened'] || ':' led['intention']
  do t over led['turns']; say '  turn' t['turn'] t['date'] || ':' t['missing'] 'missing'; end
  c = .directory~new
  do e over led['entries']
    k = e['status']; if \c~hasIndex(k) then c[k] = 0
    c[k] = c[k] + 1
  end
  do k over c~allIndexes~sort; say '  ' k~left(10) c[k]; end
  return 0

knownOf: procedure
  use arg led
  ps = .array~new
  do b over led['base']; ps~append(abs(b)); end
  ps~append(abs(led['shared']))
  return .SlamWords~known(ps)

/* review options: the words of a finding and the kinds (VOCABULARY.md), and the law's own definitions */
opts: procedure
  use arg led
  o = .directory~new
  v = .SlamLaw~vocabulary(abs(led['vocabulary']))
  o['FINDING'] = v['FINDINGWORDS']; o['KINDS'] = v['KINDS']
  law = .directory~new
  k = .SlamWords~known(.array~of(abs(led['shared'])))
  do w over k['WORDS']~allIndexes; law[w] = k['WORDS'][w]['TEXT']; end
  o['LAW'] = law
  inl = .array~new; base = .array~new
  do b over led['base']; base~append(abs(b)); end
  bw = .SlamWords~known(base)['WORDS']
  do s over led['sources']
    l = .SlamWords~load(.array~of(abs(s)), bw)
    do d over l['INLINE']; inl~append(d); end
  end
  o['INLINE'] = inl
  return o

rel: procedure
  use arg p
  if p~left(.pkg~length + 1) == .pkg || '/' then return p~substr(.pkg~length + 2)
  return p

abs: procedure
  use arg p
  if p~left(1) == '/' then return p
  return .pkg || '/' || p

today: procedure
  d = date('S')
  return d~left(4) || '-' || d~substr(5, 2) || '-' || d~right(2)

save: procedure
  use arg file, led
  .json~toJsonFile(file, led, .true)
  return

write: procedure
  use arg path, lines
  s = .stream~new(path); s~open('WRITE REPLACE')
  do ln over lines; s~lineout(ln); end
  s~close
  return

onSyntax:
  say 'SYNTAX rc=' || rc 'sigl=' || sigl condition('C') condition('D') condition('O')~message
  exit 1

::requires 'SlamWords.cls'
::requires 'SlamLaw.cls'
::requires 'json.cls'
