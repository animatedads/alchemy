/* SlamLaw.cls - legislation -> small model -> SLAM -> Reasoned Thought.
 *
 * Architecture: Tom Dyer (the chain).  Code: Claude (Opus 5.5), 2026-10-29.
 *
 * A small model (Luna, Haiku) rewrites one section of legislation as a RULE FILE in SLAM's words: the
 * section verbatim as code, the words it needs as "word: definition" lines, and one element per
 * condition, each with
 *   - its QUOTE: the exact words of the section it comes from (a code block),
 *   - its SENTENCE in SLAM's words,
 *   - the kinds of evidence that bear on it (a code block of binding names, e.g. PERSON_ACT),
 * and a rule line naming every element.  Its output is testimony, so SLAM gates it before it becomes a
 * rule:
 *   1. SLAM's reader knows every word (bin/slam.rex read): no undefined term slips in
 *   2. each QUOTE is in the section, word for word: no paraphrase is passed off as the law
 *   3. every lettered paragraph of the section holds at least one QUOTE: no condition is dropped
 *   4. the rule line names every element, and no other: the offence rests on all of them
 *   0. (when the official text is given) the rule's "law, as code" is in the official text, word for word,
 *      as it stands for the rule's EXTENT.  The official text comes from the legislation.gov.uk XML
 *      (SlamLegislation.cls); resolve() does the same for text pasted from the web page, where amendment
 *      numbers (F1, F15) depend on the page, so their notes decide, not their numbers.
 * Then each element becomes a Reasoned Thought claim that accepts only its own kinds of evidence, and
 * the offence becomes a decision resting on every element.  What comes out is whether the elements are
 * supported ON THE EVIDENCE GIVEN, with the reason: not a verdict, and no standard of proof is modelled.
 *
 * Rule file format: see tests/law/cma1990_s1.md.  Evidence lines (a case file, data, not SLAM's words):
 *   step | element | SUPPORT or REBUT | tier | binding | text
 */
::requires 'SlamReasoning.cls'

::class SlamLaw public

/* Parse a rule file.  A Directory: ID SOURCE ELEMENTS (Directories: ID QUOTE TEXT BINDS) RULE (element
   ids, in order).  Nothing is checked here. */
::method parse class
  use strict arg path
  lines = self~linesOf(path)
  out = .directory~new
  out['ID'] = ''; out['SOURCE'] = ''; out['ELEMENTS'] = .array~new; out['RULE'] = .array~new; out['EXTENT'] = ''; out['SECTION'] = ''
  i = 1
  el = .nil; expect = ''
  do while i <= lines~items
    t = lines[i]~strip
    if t == '```' then do
      block = ''; i += 1
      do while i <= lines~items
        if lines[i]~strip == '```' then leave
        block = block || lines[i] || '0a'x
        i += 1
      end
      select
        when expect == 'SOURCE' then out['SOURCE'] = block
        when expect == 'QUOTE' & el \== .nil then el['QUOTE'] = block~strip('T', '0a'x)~strip
        when expect == 'BINDS' & el \== .nil then el['BINDS'] = block~translate(' ', '0a0d09'x)~space~makeArray(' ')
        when out['ID'] == '' then do
          parse var block 'rule:' rid '0a'x
          if rid \== '' then out['ID'] = rid~strip
          parse var block 'extent:' ext '0a'x
          out['EXTENT'] = ext~strip
          parse var block 'section:' sec '0a'x
          out['SECTION'] = sec~strip
        end
        otherwise nop
      end
      expect = ''
    end
    else if t~lower == 'the law, as code:' then expect = 'SOURCE'
    else if t~word(1)~lower == 'element' & t~right(1) == ':' & t~words = 2 then do
      el = .directory~new
      el['ID'] = t~word(2)~strip('T', ':'); el['QUOTE'] = ''; el['TEXT'] = ''; el['BINDS'] = .array~new
      out['ELEMENTS']~append(el)
      expect = 'QUOTE'
    end
    else if t~lower == 'it takes evidence of:' then expect = 'BINDS'
    else if t~word(1)~lower == 'rule:' then do
      rest = t~substr(6)
      do w = 1 to rest~words - 1
        if rest~word(w)~lower == 'element' then out['RULE']~append(rest~word(w + 1)~strip('T', ',.'))
      end
    end
    else if t \== '' & el \== .nil & expect == '' then do      /* ooRexx's & does not short-circuit */
      if el['QUOTE'] \== '' & el['TEXT'] == '' then el['TEXT'] = t
    end
    i += 1
  end
  return out

/* Gates 2, 3, 4 (the reader, gate 1, is run by the caller with bin/slam.rex read).  An Array of reasons
   the rule file is refused; empty when it passes. */
::method check class
  use strict arg rule, official = ''
  errs = .array~new
  src = self~flat(rule['SOURCE'])
  if src == '' then errs~append('no source text ("the law, as code:")')
  /* gate 0: the source is the official text, as it stands for the rule's extent.  OFFICIAL is that text
     already resolved for the extent (SlamLegislation~section from the XML, or resolve() on pasted text). */
  if official \== '' & src \== '' then do
    if rule['EXTENT'] == '' then errs~append('the rule does not say its extent (E.W. or S.)')
    else if self~words(official)~pos(self~words(rule['SOURCE'])) = 0 then
      errs~append('the law, as code, is not the official text for extent' rule['EXTENT'] || ', word for word')
  end
  if rule['ELEMENTS']~items = 0 then errs~append('no elements')
  do el over rule['ELEMENTS']
    if el['QUOTE'] == '' then errs~append('element' el['ID'] 'has no quote')
    else if self~words(rule['SOURCE'])~pos(self~words(el['QUOTE'])) = 0 then errs~append('element' el['ID'] 'quote is not in the section, word for word:' el['QUOTE']~left(70))
    if el['TEXT'] == '' then errs~append('element' el['ID'] 'has no sentence')
    if el['BINDS']~items = 0 then errs~append('element' el['ID'] 'takes no evidence')
  end
  /* gate 3: each lettered paragraph holds a quote */
  do para over self~paragraphs(rule['SOURCE'])
    covered = .false
    do el over rule['ELEMENTS']
      if el['QUOTE'] \== '' then if self~flat(para[2])~pos(self~flat(el['QUOTE'])) > 0 then covered = .true
    end
    if \covered then errs~append('paragraph' para[1] 'has no element: a condition of the law is missing')
  end
  /* gate 4: the rule names every element, and no other */
  ids = .set~new
  do el over rule['ELEMENTS']; ids~put(el['ID']); end
  named = .set~new
  do r over rule['RULE']; named~put(r); end
  do id over ids
    if \named~hasItem(id) then errs~append('the rule line does not name element' id)
  end
  do id over named
    if \ids~hasItem(id) then errs~append('the rule line names element' id || ', which is not defined')
  end
  return errs

/* Guidance (e.g. the CPS's) on a rule: notes, each with a QUOTE from the guidance text, a sentence in
   SLAM's words, and a change to one element's kinds of evidence:
     "for element N, it takes evidence of:"      the element takes these, and only these
     "for element N, it can not take evidence of:" these are refused, and the refusal cites the quote
   A note may say which kind of case it is for ("it is for a case of:" and a code block of tags, e.g.
   EMPLOYEE): Allison is about an employee's authority, so it must not narrow "unauthorised" for an
   outsider, where s.17(5)'s entitlement and consent decide.  Such a note applies only when TAGS (the
   case's own tags) hold one of its tags; a note with no tags applies to every case.
   Guidance narrows which evidence counts; it never adds an element.  Applied before build.  Returns an
   Array of reasons it is refused (empty when it applies): its quotes must be in GUIDANCETEXT, word for
   word, it must be for this rule, and each element it names must exist. */
::method applyGuidance class
  use strict arg rule, path, guidanceText, tags = .nil
  if tags == .nil then tags = .array~new
  errs = .array~new
  lines = self~linesOf(path)
  forRule = ''; notes = .array~new; note = .nil; expect = ''
  i = 1
  do while i <= lines~items
    t = lines[i]~strip
    if t == '```' then do
      block = ''; i += 1
      do while i <= lines~items
        if lines[i]~strip == '```' then leave
        block = block || lines[i] || '0a'x
        i += 1
      end
      select
        when expect == 'QUOTE' & note \== .nil then note['QUOTE'] = block~strip('T', '0a'x)~strip
        when expect == 'BINDS' & note \== .nil then note['BINDS'] = block~translate(' ', '0a0d09'x)~space~makeArray(' ')
        when expect == 'TAGS' & note \== .nil then note['TAGS'] = block~translate(' ', '0a0d09'x)~space~makeArray(' ')
        when forRule == '' then do
          parse var block 'for:' fr '0a'x
          forRule = fr~strip
        end
        otherwise nop
      end
      expect = ''
    end
    else if t~word(1)~lower == 'note' & t~right(1) == ':' & t~words = 2 then do
      note = .directory~new; note['ID'] = t~word(2)~strip('T', ':'); note['QUOTE'] = ''; note['BINDS'] = .array~new; note['TAGS'] = .array~new
      notes~append(note); expect = 'QUOTE'
    end
    else if t~lower == 'it is for a case of:' & note \== .nil then expect = 'TAGS'
    else if t~lower~left(12) == 'for element ' & note \== .nil then do
      note['ELEMENT'] = t~word(3)~strip('T', ',')
      if t~lower~pos('can not take') > 0 then note['MODE'] = 'EXCLUDE'; else note['MODE'] = 'ONLY'
      expect = 'BINDS'
    end
    i += 1
  end
  if forRule \== rule['ID'] then errs~append('the guidance is for' forRule || ', not for' rule['ID'])
  gwords = self~words(guidanceText)
  do note over notes
    if note['QUOTE'] == '' then errs~append('note' note['ID'] 'has no quote')
    else if gwords~pos(self~words(note['QUOTE'])) = 0 then errs~append('note' note['ID'] 'quote is not in the guidance, word for word:' note['QUOTE']~left(70))
    el = self~element(rule, note['ELEMENT'])
    if el == .nil then errs~append('note' note['ID'] 'names element' note['ELEMENT'] || ', which the rule does not have')
  end
  if errs~items > 0 then return errs
  do note over notes
    if note['TAGS']~items > 0 then do                 /* a note for some cases only */
      hit = .false
      do tg over note['TAGS']; if tags~hasItem(tg) then hit = .true; end
      if \hit then iterate
    end
    el = self~element(rule, note['ELEMENT'])
    if \el~hasIndex('EXCLUDES') then el['EXCLUDES'] = .directory~new
    if note['MODE'] == 'ONLY' then do
      do b over el['BINDS']
        if \note['BINDS']~hasItem(b) then el['EXCLUDES'][b] = note['QUOTE']
      end
      el['BINDS'] = note['BINDS']
    end
    else do b over note['BINDS']
      el['BINDS'] = self~without(el['BINDS'], b)
      el['EXCLUDES'][b] = note['QUOTE']
    end
  end
  return errs

/* Why the evidence refused for element N was refused: one line per ineligible ground, citing the guidance
   quote when guidance excluded its kind. */
::method refusals class
  use strict arg reasoning, rule, n
  cid = self~elementId(rule, n)
  d = reasoning~assess(cid)
  out = .array~new
  el = self~element(rule, n)
  do g over reasoning~net~proposition(cid)~grounds
    if \d['ineligible']~hasItem(g~id) then iterate
    why = 'not a kind of evidence element' n 'takes'
    if el~hasIndex('EXCLUDES') then if el['EXCLUDES']~hasIndex(g~binds) then why = 'the guidance says: "' || el['EXCLUDES'][g~binds] || '"'
    out~append(g~binds || ':' g~note '--' why)
  end
  return out

/* What is missing: one Directory per element that is not assertible on the evidence given, with its
   STATUS, the kinds of evidence it takes (TAKES), the tier that evidence must beat (BEAT: the live rebut's,
   or the floor to assert), and the refusals.  SLAM does not invent the evidence; it says what would count. */
::method gaps class
  use strict arg reasoning, rule
  out = .array~new
  do el over rule['ELEMENTS']
    d = reasoning~assess(self~elementId(rule, el['ID']))
    if d['assertible'] & d['stance'] == 'PRO' then iterate
    g = .directory~new
    g['ELEMENT'] = el['ID']; g['STATUS'] = d['status']
    takes = ''
    do b over el['BINDS']; takes = takes b; end
    g['TAKES'] = takes~strip
    tiers = .array~of('STYLOMETRIC', 'TESTIMONY', 'DOCUMENTARY', 'PROVENANCE')
    if d['rebutTier'] > 0 then g['BEAT'] = 'more than' tiers[d['rebutTier']]
    else g['BEAT'] = 'TESTIMONY or more'
    g['REFUSED'] = self~refusals(reasoning, rule, el['ID'])
    out~append(g)
  end
  return out

/* Case names a text cites ("R v Bignell", "DPP v Bignell", "R v Bow Street ..."), each checked against
   SOURCES (the texts SLAM holds).  A Directory per citation: TEXT, NAME (the party after "v"), FOUND.  A
   citation not FOUND is unverified testimony: a model's word for a case nobody here can read. */
::method citations class
  use strict arg text, sources
  out = .array~new; seen = .set~new
  src = self~words(sources)
  w = text~translate(' ', '0a0d09'x)~space
  do i = 2 to w~words - 1
    if w~word(i) \== 'v' then iterate
    before = w~word(i - 1); after = w~word(i + 1)
    if \datatype(before~left(1), 'U') | \datatype(after~left(1), 'U') then iterate
    name = after~strip('T', ',.;:)')
    if after~strip('T', ',.;:)') == 'Bow' & i + 2 <= w~words then name = 'Bow' w~word(i + 2)~strip('T', ',.;:)')
    cite = before name
    if seen~hasItem(cite) then iterate
    seen~put(cite)
    c = .directory~new
    c['TEXT'] = before 'v' name; c['NAME'] = name
    c['FOUND'] = src~pos(self~words(name)) > 0
    out~append(c)
  end
  return out

::method element class
  use strict arg rule, n
  do el over rule['ELEMENTS']
    if el['ID'] == n then return el
  end
  return .nil

::method without class private
  use strict arg arr, item
  out = .array~new
  do x over arr
    if x \== item then out~append(x)
  end
  return out

/* Each element a claim, the offence a decision resting on every element.  Returns the decision's id. */
::method build class
  use strict arg reasoning, rule
  rests = .array~new
  do el over rule['ELEMENTS']
    cid = reasoning~claim(self~elementId(rule, el['ID']), el['TEXT'], 'DOCUMENTARY', el['BINDS'])
    rests~append(.array~of(cid, 'assertible'))
  end
  return reasoning~decide('OFFENCE:' || rule['ID'], 'the elements of' rule['ID'] 'are supported on the evidence given', rests)

::method elementId class
  use strict arg rule, elementNo
  return 'ELEMENT:' || rule['ID'] || ':' || elementNo

/* Admit one evidence line: step | element | SUPPORT or REBUT | tier | binding | text */
::method admit class
  use strict arg reasoning, rule, line
  parse var line step '|' elementNo '|' kind '|' tier '|' binding '|' text
  cid = self~elementId(rule, elementNo~strip)
  if kind~strip~upper == 'SUPPORT' then reasoning~evidenceFor(cid, tier~strip~upper, text~strip, binding~strip~upper)
  else reasoning~evidenceAgainst(cid, tier~strip~upper, text~strip, binding~strip~upper)
  return cid

/* Lettered paragraphs of the source: .array(letter, text). */
::method paragraphs class private
  use strict arg source
  out = .array~new
  do ln over source~makeArray('0a'x)
    t = ln~strip
    if t~left(1) == '(' & t~substr(3, 1) == ')' & datatype(t~substr(2, 1), 'L') then out~append(.array~of(t~left(3), t))
  end
  return out

/* The official text as it stands for EXTENT (E.W. or S.): each bracketed amendment [Fn ...] is kept or
   dropped by what its own note says, not by its number. */
::method resolve class
  use strict arg text, extent
  notes = .directory~new
  do ln over text~makeArray('0a'x)
    t = ln~strip
    if t~left(1) == 'F' then do
      n = ''
      do i = 2 to t~length while datatype(t~substr(i, 1), 'W'); n = n || t~substr(i, 1); end
      if n \== '' & \notes~hasIndex(n) then notes[n] = t~substr(n~length + 2)
    end
  end
  out = ''; i = 1; len = text~length
  do while i <= len
    if text~substr(i, 2) == '[F' & datatype(text~substr(i + 2, 1), 'W') then do
      j = i + 2; n = ''
      do while j <= len & datatype(text~substr(j, 1), 'W'); n = n || text~substr(j, 1); j += 1; end
      depth = 1; k = j
      do while k <= len & depth > 0
        ch = text~substr(k, 1)
        if ch == '[' then depth += 1
        if ch == ']' then depth -= 1
        k += 1
      end
      inner = text~substr(j, k - j - 1)
      if self~applies(notes[n], extent) then out = out || self~resolve(inner, extent)
      i = k
      iterate
    end
    out = out || text~substr(i, 1)
    i += 1
  end
  return out

/* Does the amendment with NOTE stand in EXTENT?  A note that limits itself to (S.) is Scotland's; one that
   limits itself to (E.W.N.I.) is England, Wales and Northern Ireland's; a note that says neither stands in
   both. */
::method applies class private
  use strict arg note, extent
  if note == .nil then return .true
  ew = extent~upper~pos('E') > 0
  if note~pos('(S.)') > 0 then do
    if note~pos('repealed for E.W.N.I.') > 0 | note~pos('(E.W.N.I.)') = 0 then return \ew
  end
  if note~pos('(E.W.N.I.)') > 0 then return ew
  return .true

/* Words only: lower case letters and digits, everything else a single blank (so "(a)he" is "a he"). */
::method words class
  use strict arg text
  t = text~lower
  keep = 'abcdefghijklmnopqrstuvwxyz0123456789'
  out = ''
  do i = 1 to t~length
    ch = t~substr(i, 1)
    if keep~pos(ch) > 0 then out = out || ch; else out = out || ' '
  end
  return ' ' || out~space || ' '

::method flat class private
  use strict arg text
  return text~translate(' ', '0a0d09'x)~space~lower

::method linesOf class private
  use strict arg path
  out = .array~new
  s = .stream~new(path)
  if s~open('READ') \== 'READY:' then return out
  do while s~lines > 0
    out~append(s~linein)
  end
  s~close
  return out
