/* SlamWords.cls - the word loop: what is said, the words SLAM does not know, their definitions, a review of
 * how each definition links to the words SLAM knows, and the shared list.  Round and round until every word
 * is known.
 *
 * Architecture: Tom Dyer ("a circular submission for words missing": a tool which uses intentions, loads what
 * is said, allows definitions to be entered, reviews meaning for definitions when added to ensure correct
 * linkages are made; rinse and repeat).  Code: Claude (Opus 5.5), 2026-10-30.
 *
 * The words SLAM knows are the circular corpus (corpus/circular_corpus_v2.csv) and the shared list
 * (corpus/law_words.csv): the same format, word,category,definition, so `slam.rex corpus` loads both.  A
 * round (bin/words.rex) has an INTENTION (what the words are for: "write the rule for s.33", "read Tom's
 * fifth account") and SOURCES (what is said).  One turn of the loop:
 *   load    read each source as SLAM's reader does (bin/slam.rex read): the words it does not know, where
 *           each one is, and the definitions a source already writes for itself ("word: definition" lines)
 *   define  definitions for the missing words, in the same "word: definition" lines
 *   review  each definition, against what SLAM knows and against the other definitions of the turn:
 *             CONFLICT          the word is known with another meaning: one word, one meaning      REFUSE
 *             GIVEN_TWICE       the same word twice in one turn                                     REFUSE
 *             UNKNOWN_WORD      a word of the definition is not known and not defined in the turn:
 *                               it goes round again                                                 REFUSE
 *             ONLY_ITSELF       the definition has no word but the word                             REFUSE
 *             CIRCLE            new words defined only through each other, with no word i know
 *                               under them (a circle that rests on known words is a WARN: the
 *                               circular corpus is circles too)                                     REFUSE
 *             EVENT_WOULD_CARRY an event kind's definition uses a word that, with this meaning,
 *                               carries a finding (VOCABULARY.md, gate 6)                           REFUSE
 *             WAITS_FOR         a new word it uses is waiting or refused: it waits with it          WAIT
 *             USES_ITSELF       the word is in its own definition                                   WARN
 *             FORM              "throws" when "throw" is known, and the definition does not use it   WARN
 *             DEFINED_ELSEWHERE a source defines the word with other words: those lines will differ
 *                               from the shared list                                                WARN
 *             CARRIES_FINDING   the definition uses a word of a finding (knows, intends, ...), here
 *                               or through another new word: the word is a finding's word too       NOTE
 *             SAME_MEANING      another word has the same definition                                NOTE
 *           PASSED; WAITING when it is refused only for words not yet defined, or waits for a word
 *           that is (it goes round again, and is not written again); REFUSED (it has to be written again);
 *           and LINKS: each word of the definition with its own definition, for a person or a second
 *           model to read the meaning one step down
 *   accept  a passed definition goes into the shared list, only when someone other than its writer
 *           accepts it: a definition is testimony, and a writer does not review their own
 * then load again: fewer words are missing, or the definitions brought new ones.  The round ends when a
 * load finds none.
 *
 * The reader's rules are copied here, not called (bin/slam.rex is a command, not a class): a word is what
 * is left between blanks when . , ; : ( ) " ' ? ! # * ` [ ] { } < > are blanks; text between ``` fences is
 * code, not words; a numeral in text is a value, not a word; a line "word: definition" whose word is not
 * known defines it for the rest of that source.  tests/test_words.rex checks that both agree.
 *
 * A finding's words spread only through the law's own definitions (this turn's and the shared list's),
 * not through the circular corpus: there "false" is a value of logic ("not true"), and in the law it is a
 * finding ("a false representation").  The same spelling, two meanings.
 *
 * Senses (Tom Dyer, 2026-10-30: "preparse on entry; where two words have different meanings, we need to ask:
 * is this false, or false [legal], with the latter using a fixed word replacement [false-legal] internally,
 * and replace in input as the corrected item as we go").  corpus/senses.csv lists each second meaning as a
 * word of its own, in the circular corpus's format, so the reader loads it:
 *     false-legal,sense false legal,"the word false, as a rule has it: ..."
 * the token is the word, a hyphen and the label; the word keeps its first meaning.  preparse() finds each
 * word that has a second meaning in what is said, outside code, and asks which it is; the answer replaces
 * the word in the input (resolve()).  A token is never the word: "false-legal" is one word to the reader
 * (a hyphen is not a blank), so a second run finds nothing to ask, and nothing becomes "false-legal-legal".
 * An answer that keeps the first meaning is recorded against the line as it then reads, so it is not asked
 * again; if the line changes, it is.
 */
::class SlamWords public

/* Words the review does not unfold in LINKS: their meaning is not where a definition goes wrong. */
::method grammar class
  return ' a an the of and or to in on at for is are be it its this that not no with by as from one '

/* The words SLAM knows, from one or more CSV files (word,category,definition; a header line first).  A
   Directory: WORDS (word -> Directory WORD TEXT CAT FROM), CONFLICTS (a word given two meanings: the first
   stands, the second is listed). */
::method known class
  use strict arg paths
  words = .directory~new; conflicts = .array~new
  do p over paths
    if .stream~new(p)~query('exists') == '' then iterate
    lines = self~linesOf(p)
    do i = 2 to lines~items
      ln = lines[i]~strip('T', '0d'x)
      if ln~strip == '' then iterate
      parse var ln w ',' cat ',' rest
      if rest~left(1) == '"' then rest = rest~substr(2, rest~length - 2)~changestr('""', '"')
      w = w~lower~strip
      if words~hasIndex(w) then do
        if \self~same(words[w]['TEXT'], rest) then
          conflicts~append(w || ': "' || words[w]['TEXT'] || '" (' || words[w]['FROM'] || ') and "' || rest || '" (' || p || ')')
        iterate
      end
      d = .directory~new; d['WORD'] = w; d['TEXT'] = rest; d['CAT'] = cat~strip; d['FROM'] = p
      words[w] = d
    end
  end
  out = .directory~new; out['WORDS'] = words; out['CONFLICTS'] = conflicts
  return out

/* What is said, read as SLAM's reader reads it.  SOURCES: an Array; each a path, or .array(label, lines)
   for words that are not in a file (a round's intention).  KNOWN: Directory word -> anything.  A Directory:
     MISSING   word -> Array of places ("file:line", or "file:line, in the definition of w")
     ORDER     the missing words, first seen first
     INLINE    each definition a source writes for itself: Directory WORD TEXT FILE LINE
     DIFFER    word -> Array of "file:line: text", when the sources define a word in more than one way */
::method load class
  use strict arg sources, known
  missing = .directory~new; order = .array~new; inline = .array~new
  do src over sources
    if src~isA(.array) then do; label = src[1]; lines = src[2]; end
    else do; label = src; lines = self~linesOf(src); end
    local = .directory~new; inCode = .false; n = 0
    do ln over lines
      n += 1
      s = ln~strip('T', '0d'x)~strip
      if s~left(3) == '```' then do; inCode = \inCode; iterate; end
      if inCode then iterate
      parse var s head ':' tail
      isDef = .false
      if tail \== '' then if head~words == 1 then if datatype(head, 'M') then
        if \known~hasIndex(head~lower) then if \local~hasIndex(head~lower) then isDef = .true
      if isDef then do
        w = head~lower; local[w] = .true
        d = .directory~new; d['WORD'] = w; d['TEXT'] = tail~strip; d['FILE'] = label; d['LINE'] = n
        inline~append(d)
        do x over self~clean(tail)
          if known~hasIndex(x) | local~hasIndex(x) then iterate
          call place missing, order, x, label || ':' || n || ', in the definition of' w
        end
        iterate
      end
      do x over self~clean(s)
        if datatype(x, 'N') then iterate
        if known~hasIndex(x) | local~hasIndex(x) then iterate
        call place missing, order, x, label || ':' || n
      end
    end
  end
  differ = .directory~new
  do d over inline
    do e over inline
      if e['WORD'] \== d['WORD'] then iterate
      if self~same(e['TEXT'], d['TEXT']) then iterate
      if \differ~hasIndex(d['WORD']) then differ[d['WORD']] = .array~new
      at = d['FILE'] || ':' || d['LINE'] || ':' d['TEXT']
      if \differ[d['WORD']]~hasItem(at) then differ[d['WORD']]~append(at)
    end
  end
  out = .directory~new
  out['MISSING'] = missing; out['ORDER'] = order; out['INLINE'] = inline; out['DIFFER'] = differ
  return out

/* Definitions entered: "word: definition" lines.  Blank lines, lines that start with #, and ``` blocks are
   skipped.  A Directory: ENTRIES (Directory WORD TEXT LINE), BAD (lines that are not a definition). */
::method definitions class
  use strict arg path
  entries = .array~new; bad = .array~new; inCode = .false; n = 0
  do ln over self~linesOf(path)
    n += 1
    s = ln~strip('T', '0d'x)~strip
    if s~left(3) == '```' then do; inCode = \inCode; iterate; end
    if inCode | s == '' | s~left(1) == '#' then iterate
    parse var s head ':' tail
    if tail~strip \== '' & head~words == 1 & datatype(head~strip, 'M') then do
      d = .directory~new; d['WORD'] = head~strip~lower; d['TEXT'] = tail~strip; d['LINE'] = n
      entries~append(d)
    end
    else bad~append(n || ':' s)
  end
  out = .directory~new; out['ENTRIES'] = entries; out['BAD'] = bad
  return out

/* Review one turn's definitions.  ENTRIES: Directory WORD TEXT.  KNOWN: the WORDS of known().  OPTS (a
   Directory, each optional): FINDING (Array of the words of a finding), KINDS (the KINDS of
   SlamLaw~vocabulary), INLINE (the INLINE of load()), LAW (Directory word -> text: the shared list's own
   definitions, through which a finding's words spread).  An Array, one Directory per entry: WORD TEXT
   STATUS (PASSED, REFUSED, KNOWN) FINDINGS (Directories SEVERITY CODE TEXT) LINKS NEEDS CARRIES LEVEL. */
::method review class
  use strict arg entries, known, opts = (.directory~new)
  fw = .array~new; if opts~hasIndex('FINDING') then fw = opts['FINDING']
  new = .directory~new; out = .array~new
  do e over entries
    r = .directory~new
    r['WORD'] = e['WORD']; r['TEXT'] = e['TEXT']; r['STATUS'] = ''; r['FINDINGS'] = .array~new
    r['LINKS'] = .array~new; r['NEEDS'] = .array~new; r['CARRIES'] = ''; r['LEVEL'] = ''
    r['USES'] = self~distinct(self~clean(e['TEXT']))
    if new~hasIndex(e['WORD']) then call note r, 'REFUSE', 'GIVEN_TWICE', 'this turn defines "' || e['WORD'] || '" twice: one word, one meaning'
    else new[e['WORD']] = r
    out~append(r)
  end
  do r over out
    w = r['WORD']; uses = r['USES']
    if known~hasIndex(w) then do
      if self~same(known[w]['TEXT'], r['TEXT']) then do
        r['STATUS'] = 'KNOWN'
        call note r, 'NOTE', 'ALREADY_KNOWN', 'known already, with this meaning (' || known[w]['FROM'] || ')'
        iterate
      end
      call note r, 'REFUSE', 'CONFLICT', 'known already with another meaning: "' || known[w]['TEXT'] || '" (' || known[w]['FROM'] || '). One word, one meaning: use another word, or change the old meaning in a round of its own'
    end
    do x over uses
      if x == w | known~hasIndex(x) | new~hasIndex(x) then iterate
      r['NEEDS']~append(x)
    end
    if r['NEEDS']~items > 0 then
      call note r, 'REFUSE', 'UNKNOWN_WORD', r['NEEDS']~makeString('L', ', ') || ': not known, and not defined in this turn; they go round again'
    if uses~items = 0 | (uses~items = 1 & uses[1] == w) then
      call note r, 'REFUSE', 'ONLY_ITSELF', 'the definition has no word but "' || w || '": it says nothing'
    else if uses~hasItem(w) then
      call note r, 'WARN', 'USES_ITSELF', '"' || w || '" is in its own definition'
    stem = self~formOf(w, known, new)
    if stem \== '' then if \uses~hasItem(stem) then
      call note r, 'WARN', 'FORM', '"' || w || '" looks like a form of "' || stem || '", a word i know, and its definition does not use it: link them ("' || stem || ', for one thing"), or say why not'
    if opts~hasIndex('INLINE') then do
      other = .array~new; sameAt = .array~new
      do d over opts['INLINE']
        if d['WORD'] \== w then iterate
        at = d['FILE']~substr(d['FILE']~lastPos('/') + 1) || ':' || d['LINE']
        if self~same(d['TEXT'], r['TEXT']) then sameAt~append(at)
        else other~append(at || ': "' || d['TEXT'] || '"')
      end
      if other~items > 0 then call note r, 'WARN', 'DEFINED_ELSEWHERE', 'a source defines it with other words:' other~makeString('L', '; ')
    end
    do x over known~allIndexes~sort
      if x \== w then if self~same(known[x]['TEXT'], r['TEXT']) then
        call note r, 'NOTE', 'SAME_MEANING', 'the same definition as "' || x || '" (' || known[x]['FROM'] || ')'
    end
    do q over out
      if q['WORD'] \== w then if self~same(q['TEXT'], r['TEXT']) then
        call note r, 'NOTE', 'SAME_MEANING', 'the same definition as "' || q['WORD'] || '" (this turn)'
    end
    g = self~grammar
    do x over uses
      if x == w | g~pos(' ' || x || ' ') > 0 then iterate
      select
        when new~hasIndex(x) then r['LINKS']~append(x || ': ' || new[x]['TEXT'] || '   (this turn)')
        when known~hasIndex(x) then r['LINKS']~append(x || ': ' || known[x]['TEXT'])
        otherwise r['LINKS']~append(x || ': ?')
      end
    end
  end
  /* circles: new words that reach themselves through other new words */
  do r over out
    if r['STATUS'] == 'KNOWN' then iterate
    w = r['WORD']
    reach = self~reach(w, new)
    if \reach~hasIndex(w) then iterate
    ring = .array~new
    do x over reach~allIndexes~sort
      if self~reach(x, new)~hasIndex(w) then ring~append(x)
    end
    anchors = .array~new; g = self~grammar
    do x over ring
      do y over new[x]['USES']
        if known~hasIndex(y) & g~pos(' ' || y || ' ') = 0 & \anchors~hasItem(y) then anchors~append(y)
      end
    end
    if anchors~items = 0 then
      call note r, 'REFUSE', 'CIRCLE', ring~makeString('L', ', ') || ' are defined only through each other: define one of them from words i know first'
    else
      call note r, 'WARN', 'CIRCLE', ring~makeString('L', ', ') || ' are defined through each other; the circle rests on' anchors~makeString('L', ', ')
  end
  /* level: 0 when a definition uses only known words; 1 + the highest level of the new words it uses */
  do r over out
    if r['STATUS'] \== 'KNOWN' then r['LEVEL'] = self~level(r['WORD'], new, .directory~new)
  end
  /* a finding's words, spread through the law's definitions: this turn's, and the shared list's */
  carry = .directory~new
  do x over fw; carry[x~lower] = x~lower; end
  defs = .directory~new
  if opts~hasIndex('LAW') then do x over opts['LAW']~allIndexes; defs[x] = self~distinct(self~clean(opts['LAW'][x])); end
  do r over out; defs[r['WORD']] = r['USES']; end
  changed = .true
  do while changed
    changed = .false
    do x over defs~allIndexes~sort
      if carry~hasIndex(x) then iterate
      do y over defs[x]
        if y \== x & carry~hasIndex(y) then do
          if carry[y] == y then carry[x] = y; else carry[x] = y carry[y]     /* the path, ending in the finding's word */
          changed = .true; leave
        end
      end
    end
  end
  do r over out
    w = r['WORD']
    if \carry~hasIndex(w) | fw~hasItem(w) then iterate
    r['CARRIES'] = carry[w]
    path = carry[w]
    if path~words = 1 then how = 'its definition uses "' || path || '", a word of a finding'
    else how = 'its definition uses "' || path~word(1) || '", and through it "' || path~word(path~words) || '", a word of a finding (' || w '->' path~changestr(' ', ' -> ') || ')'
    call note r, 'NOTE', 'CARRIES_FINDING', how || ': "' || w || '" carries a finding too, and an event kind can not use it'
    if opts~hasIndex('KINDS') then do k over opts['KINDS']~allIndexes~sort
      kd = opts['KINDS'][k]
      if kd['TYPE'] \== 'EVENT' then iterate
      if self~distinct(self~clean(kd['TEXT']))~hasItem(w) then
        call note r, 'REFUSE', 'EVENT_WOULD_CARRY', 'kind' k 'is an event, and its definition uses "' || w || '": with this meaning the event would carry a finding. Change this meaning, or the kind''s definition'
    end
  end
  /* PASSED, or WAITING (refused only for words not yet defined: it goes round again, and need not be
     written again), or REFUSED (it has to be written again) */
  do r over out
    if r['STATUS'] == 'KNOWN' then iterate
    r['STATUS'] = 'PASSED'
    do f over r['FINDINGS']
      if f['SEVERITY'] \== 'REFUSE' then iterate
      if f['CODE'] == 'UNKNOWN_WORD' then do; if r['STATUS'] == 'PASSED' then r['STATUS'] = 'WAITING'; end
      else r['STATUS'] = 'REFUSED'
    end
  end
  /* a definition passes only when every new word it uses passes: else it waits for them */
  changed = .true
  do while changed
    changed = .false
    do r over out
      if r['STATUS'] \== 'PASSED' then iterate
      do x over r['USES']
        if x == r['WORD'] | \new~hasIndex(x) then iterate
        if new[x]['STATUS'] == 'PASSED' | new[x]['STATUS'] == 'KNOWN' then iterate
        r['STATUS'] = 'WAITING'
        call note r, 'WAIT', 'WAITS_FOR', '"' || x || '" is defined in this turn, and is' new[x]['STATUS']~lower || ': this waits for it'
        changed = .true; leave
      end
    end
  end
  return out

/* One review as lines of text: what a person or a second model reads. */
::method sheet class
  use strict arg results
  out = .array~new
  do r over results
    out~append(r['WORD'] || ':' r['TEXT'])
    if r['LEVEL'] == '' then out~append('   ' || r['STATUS'])
    else out~append('   ' || r['STATUS'] '   level' r['LEVEL'])
    do f over r['FINDINGS']
      out~append('   ' || f['SEVERITY']~left(6) f['CODE'] || ':' f['TEXT'])
    end
    if r['LINKS']~items > 0 then do
      out~append('   links:')
      do x over r['LINKS']; out~append('      ' || x); end
    end
    out~append('')
  end
  return out

/* A word for the shared list, as a line of the CSV (word,category,definition). */
::method csvLine class
  use strict arg word, cat, text
  if text~pos(',') > 0 | text~pos('"') > 0 then text = '"' || text~changestr('"', '""') || '"'
  return word~lower || ',' || cat || ',' || text

/* The senses register: a CSV (token,category,definition) whose category is "sense WORD LABEL".  A
   Directory: WORDS (word -> Array of Directories TOKEN LABEL TEXT), TOKENS (token -> Directory WORD LABEL
   TEXT), ERRORS.  Refused: a token that is not WORD-LABEL; a token given twice; a token that is itself a
   word with senses (it would be asked about, and replaced, again: false-legal-legal). */
::method senses class
  use strict arg path
  words = .directory~new; tokens = .directory~new; errs = .array~new
  lines = self~linesOf(path)
  do i = 2 to lines~items
    ln = lines[i]~strip('T', '0d'x)
    if ln~strip == '' then iterate
    parse var ln tok ',' cat ',' rest
    if rest~left(1) == '"' then rest = rest~substr(2, rest~length - 2)~changestr('""', '"')
    tok = tok~lower~strip
    parse var cat kw w label .
    w = w~lower; label = label~lower
    if kw~lower \== 'sense' | w == '' | label == '' then do; errs~append(tok || ': the category is not "sense WORD LABEL"'); iterate; end
    if tok \== w || '-' || label then do; errs~append(tok || ': a sense of "' || w || '" labelled' label 'is "' || w || '-' || label || '"'); iterate; end
    if tokens~hasIndex(tok) then do; errs~append(tok || ': given twice'); iterate; end
    d = .directory~new; d['TOKEN'] = tok; d['WORD'] = w; d['LABEL'] = label; d['TEXT'] = rest
    tokens[tok] = d
    if \words~hasIndex(w) then words[w] = .array~new
    words[w]~append(d)
  end
  do t over tokens~allIndexes
    if words~hasIndex(t) then errs~append(t || ': a sense is itself a word with senses; it would be replaced again')
  end
  out = .directory~new; out['WORDS'] = words; out['TOKENS'] = tokens; out['ERRORS'] = errs
  return out

/* Each whole word of LINE that has a second meaning: Directories WORD POS LEN NTH (the Nth time that word
   is on the line).  A word is what the reader takes as one: "false-legal" is not "false". */
::method occurrences class
  use strict arg line, words
  c = line~lower~translate('', '.,;:()"''?!#*`[]{}<>')~translate(' ', '09'x)
  out = .array~new; seen = .directory~new
  do k = 1 to c~words
    w = c~word(k)
    if \words~hasIndex(w) then iterate
    if \seen~hasIndex(w) then seen[w] = 0
    seen[w] = seen[w] + 1
    d = .directory~new; d['WORD'] = w; d['POS'] = c~wordIndex(k); d['LEN'] = w~length; d['NTH'] = seen[w]
    out~append(d)
  end
  return out

/* The key that records an answer: the source, the line as it reads, the word, and which time on the line */
::method senseKey class
  use strict arg label, text, word, nth
  return label || '|' || word || '|' || nth || '|' || text

/* Preparse: every word with a second meaning in SOURCES (as load() takes them), outside code, that has no
   answer in RESOLVED (a Directory of senseKey()s).  An Array of questions: FILE LINE TEXT WORD POS LEN NTH
   KEY OPTIONS (the word's first meaning, then each sense: Directories TOKEN LABEL TEXT). */
::method preparse class
  use strict arg sources, senses, resolved, known = (.directory~new)
  out = .array~new
  do src over sources
    if src~isA(.array) then do; label = src[1]; lines = src[2]; end
    else do; label = src; lines = self~linesOf(src); end
    inCode = .false; n = 0
    do ln over lines
      n += 1
      if ln~strip~left(3) == '```' then do; inCode = \inCode; iterate; end
      if inCode then iterate
      do o over self~occurrences(ln, senses['WORDS'])
        /* "act: a thing that a person does" defines the word: its first meaning, nothing to ask */
        if ln~left(o['POS'] - 1)~strip == '' & ln~substr(o['POS'] + o['LEN'], 1) == ':' then iterate
        key = self~senseKey(label, ln, o['WORD'], o['NTH'])
        if resolved~hasIndex(key) then iterate
        q = .directory~new
        q['FILE'] = label; q['LINE'] = n; q['TEXT'] = ln; q['WORD'] = o['WORD']; q['POS'] = o['POS']
        q['LEN'] = o['LEN']; q['NTH'] = o['NTH']; q['KEY'] = key
        first = .directory~new; first['TOKEN'] = o['WORD']; first['LABEL'] = ''
        if known~hasIndex(o['WORD']) then first['TEXT'] = known[o['WORD']]['TEXT']; else first['TEXT'] = '(its first meaning)'
        opts = .array~of(first)
        do sd over senses['WORDS'][o['WORD']]; opts~append(sd); end
        q['OPTIONS'] = opts
        out~append(q)
      end
    end
  end
  return out

/* One line, with its answers: CHOICES is an Array of .array(question, token), for questions on this line.
   The words are replaced from the right, so each position still holds.  Returns the new line.  A token is
   never a word with senses (senses() refuses it), so the new line has nothing more to replace. */
::method resolve class
  use strict arg line, choices
  order = .array~new
  do c over choices; order~append(c); end
  do i = 1 to order~items - 1                        /* rightmost first */
    do j = i + 1 to order~items
      if order[j][1]['POS'] > order[i][1]['POS'] then do; t = order[i]; order[i] = order[j]; order[j] = t; end
    end
  end
  do c over order
    q = c[1]; tok = c[2]
    if tok == q['WORD'] then iterate
    line = line~left(q['POS'] - 1) || tok || line~substr(q['POS'] + q['LEN'])
  end
  return line

/* The reader's words: everything but letters, digits and the few other characters it keeps is not a
   blank; these are. */
::method clean class
  use strict arg text
  c = text~lower~translate('', '.,;:()"''?!#*`[]{}<>')
  out = .array~new
  do k = 1 to c~words; out~append(c~word(k)); end
  return out

::method distinct class
  use strict arg arr
  out = .array~new
  do x over arr
    if \out~hasItem(x) then out~append(x)
  end
  return out

/* Two definitions are the same when they are the same words in the same order. */
::method same class
  use strict arg a, b
  return self~clean(a)~makeString('L', ' ') == self~clean(b)~makeString('L', ' ')

/* The word WORD looks like a form of: "throws" -> "throw", "carries" -> "carry", "used" -> "use",
   "throwing" -> "throw".  Only a stem that is known, or defined in the turn, counts. */
::method formOf class
  use strict arg w, known, new
  c = .array~new
  if w~length > 4 & w~right(3) == 'ies' then c~append(w~left(w~length - 3) || 'y')
  if w~length > 4 & w~right(3) == 'ied' then c~append(w~left(w~length - 3) || 'y')
  if w~length > 5 & w~right(3) == 'ing' then do; c~append(w~left(w~length - 3)); c~append(w~left(w~length - 3) || 'e'); end
  if w~length > 4 & w~right(2) == 'ed' then do; c~append(w~left(w~length - 2)); c~append(w~left(w~length - 1)); end
  if w~length > 4 & w~right(2) == 'es' then do; c~append(w~left(w~length - 2)); c~append(w~left(w~length - 1)); end
  if w~length > 3 & w~right(1) == 's' & w~right(2) \== 'ss' then c~append(w~left(w~length - 1))
  do s over c
    if s~length >= 3 then if known~hasIndex(s) | new~hasIndex(s) then return s
  end
  return ''

/* The new words W reaches through the definitions of new words (not W itself, unless a path comes back). */
::method reach class
  use strict arg w, new
  seen = .directory~new; todo = .array~new
  do x over new[w]['USES']; if new~hasIndex(x) & x \== w then todo~append(x); end
  do while todo~items > 0
    x = todo[1]; todo~delete(1)
    if seen~hasIndex(x) then iterate
    seen[x] = .true
    do y over new[x]['USES']
      if new~hasIndex(y) & \seen~hasIndex(y) then todo~append(y)
    end
  end
  return seen

::method level class
  use strict arg w, new, busy
  if busy~hasIndex(w) then return 0
  busy[w] = .true
  m = 0
  do x over new[w]['USES']
    if x \== w & new~hasIndex(x) then m = max(m, 1 + self~level(x, new, busy))
  end
  busy~remove(w)
  return m

::method linesOf class
  use strict arg path
  out = .array~new
  s = .stream~new(path)
  if s~open('READ') \== 'READY:' then return out
  do while s~lines > 0
    out~append(s~linein)
  end
  s~close
  return out

::routine place
  use arg missing, order, word, at
  if \missing~hasIndex(word) then do; missing[word] = .array~new; order~append(word); end
  missing[word]~append(at)
  return

::routine note
  use arg r, sev, code, text
  f = .directory~new; f['SEVERITY'] = sev; f['CODE'] = code; f['TEXT'] = text
  r['FINDINGS']~append(f)
  return
