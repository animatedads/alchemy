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

/* Parse a rule file.  A Directory: ID EXTENT (one or more of E.W. S.; the law's text must be the official
   text in each) SECTION SOURCE ABOUT (the kinds of event the offence can be about: what the screen runs the
   rule on) ELEMENTS RULE (element ids, in order).  Each element: ID, QUOTES (one or more exact quotes: a
   condition the law writes as "(a) ...; or (b) ..." is one element with two quotes), QUOTE (the first),
   TEXT, BINDS (the kinds it takes), TAKES0 (BINDS before any guidance), LINK (the rule id of an offence that
   is itself the element, as "he commits an offence under section 1" is in s.2).  Nothing is checked here. */
::method parse class
  use strict arg path
  lines = self~linesOf(path)
  out = .directory~new
  out['ID'] = ''; out['SOURCE'] = ''; out['ELEMENTS'] = .array~new; out['RULE'] = .array~new; out['EXTENT'] = ''; out['SECTION'] = ''
  out['ABOUT'] = .array~new
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
        when expect == 'ABOUT' then out['ABOUT'] = block~translate(' ', '0a0d09'x)~space~makeArray(' ')
        when expect == 'QUOTE' & el \== .nil then do
          el['QUOTES']~append(block~strip('T', '0a'x)~strip)
          el['QUOTE'] = el['QUOTES'][1]
          i += 1
          iterate                                   /* a second quote block may follow */
        end
        when expect == 'BINDS' & el \== .nil then do
          el['BINDS'] = block~translate(' ', '0a0d09'x)~space~makeArray(' ')
          el['TAKES0'] = el['BINDS']~copy
        end
        when expect == 'LINK' & el \== .nil then el['LINK'] = block~translate(' ', '0a0d09'x)~strip
        when out['ID'] == '' then do
          parse var block 'rule:' rid '0a'x
          if rid \== '' then out['ID'] = rid~strip
          parse var block 'extent:' ext '0a'x
          out['EXTENT'] = ext~space
          parse var block 'section:' sec '0a'x
          out['SECTION'] = sec~strip
        end
        otherwise nop
      end
      expect = ''
    end
    else if t~lower == 'the law, as code:' then expect = 'SOURCE'
    else if t~lower == 'it is about an event of kind:' then expect = 'ABOUT'
    else if t~word(1)~lower == 'element' & t~right(1) == ':' & t~words = 2 then do
      el = .directory~new
      el['ID'] = t~word(2)~strip('T', ':'); el['QUOTE'] = ''; el['QUOTES'] = .array~new; el['TEXT'] = ''
      el['BINDS'] = .array~new; el['TAKES0'] = .array~new; el['LINK'] = ''
      out['ELEMENTS']~append(el)
      expect = 'QUOTE'
    end
    else if t~lower == 'it takes evidence of:' then expect = 'BINDS'
    else if t~lower == 'it is the offence:' then expect = 'LINK'
    else if t~word(1)~lower == 'rule:' then do
      rest = t~substr(6)
      do w = 1 to rest~words - 1
        if rest~word(w)~lower == 'element' then out['RULE']~append(rest~word(w + 1)~strip('T', ',.'))
      end
    end
    else if t \== '' & el \== .nil then do              /* ooRexx's & does not short-circuit */
      if expect == 'QUOTE' then do
        if el['QUOTES']~items > 0 then do; el['TEXT'] = t; expect = ''; end
      end
      else if expect == '' then if el['QUOTE'] \== '' & el['TEXT'] == '' then el['TEXT'] = t
    end
    i += 1
  end
  return out

/* The official text of RULE's section in each of its extents, from a SlamLegislation reader: a Directory,
   extent -> text, for check(). */
::method officialFor class
  use strict arg leg, rule
  out = .directory~new
  do ext over rule['EXTENT']~makeArray(' ')
    out[ext] = leg~section(rule['SECTION'], ext)
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
     already resolved for the extent (SlamLegislation~section from the XML, or resolve() on pasted text), or
     a Directory extent -> text (officialFor) for a rule that says more than one extent. */
  if official \== '' & src \== '' then do
    if rule['EXTENT'] == '' then errs~append('the rule does not say its extent (E.W. or S.)')
    else if \official~isA(.Directory) then do
      if self~words(official)~pos(self~words(rule['SOURCE'])) = 0 then
        errs~append('the law, as code, is not the official text for extent' rule['EXTENT'] || ', word for word')
    end
    else do ext over rule['EXTENT']~makeArray(' ')
      if \official~hasIndex(ext) then errs~append('no official text given for extent' ext)
      else if official[ext] == '' then errs~append('section' rule['SECTION'] 'does not extend to' ext)
      else if self~words(official[ext])~pos(self~words(rule['SOURCE'])) = 0 then
        errs~append('the law, as code, is not the official text for extent' ext || ', word for word')
    end
  end
  if rule['ELEMENTS']~items = 0 then errs~append('no elements')
  do el over rule['ELEMENTS']
    if el['QUOTES']~items = 0 then errs~append('element' el['ID'] 'has no quote')
    do q over el['QUOTES']
      if self~words(rule['SOURCE'])~pos(self~words(q)) = 0 then errs~append('element' el['ID'] 'quote is not in the section, word for word:' q~left(70))
    end
    if el['TEXT'] == '' then errs~append('element' el['ID'] 'has no sentence')
    if el['BINDS']~items = 0 & el['LINK'] == '' then errs~append('element' el['ID'] 'takes no evidence')
  end
  /* gate 3: each lettered paragraph holds a quote */
  do para over self~paragraphs(rule['SOURCE'])
    covered = .false
    do el over rule['ELEMENTS']
      do q over el['QUOTES']
        if self~flat(para[2])~pos(self~flat(q)) > 0 then covered = .true
      end
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
  forRule = ''; gext = ''; notes = .array~new; note = .nil; expect = ''
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
          parse var block 'extent:' gx '0a'x
          gext = gx~space
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
  /* guidance has an extent too: the CPS prosecutes in England and Wales, not in Scotland */
  if gext \== '' then do ext over rule['EXTENT']~makeArray(' ')
    if wordpos(ext, gext) = 0 then errs~append('the guidance is for extent' gext || ', not for' ext)
  end
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
  use strict arg reasoning, rule, links = .nil
  out = .array~new
  tiers = .array~of('STYLOMETRIC', 'TESTIMONY', 'DOCUMENTARY', 'PROVENANCE')
  do el over rule['ELEMENTS']
    g = .directory~new
    g['ELEMENT'] = el['ID']; g['REFUSED'] = .array~new
    if el['LINK'] \== '' then do                 /* the element is an offence: its own elements decide */
      linked = .nil
      if links \== .nil then if links~hasIndex(el['LINK']) then linked = links[el['LINK']]
      if linked \== .nil then do
        m = reasoning~mayAct(self~decisionId(linked))
        if m['OK'] then iterate
        g['STATUS'] = 'OFFENCE_NOT_SUPPORTED'
        g['TAKES'] = 'the elements of' el['LINK']
        g['BEAT'] = m['WHY']
        out~append(g)
        iterate
      end
      g['STATUS'] = 'NO_RULE_PACK'
      g['TAKES'] = 'the rule pack for' el['LINK']
      g['BEAT'] = ''
      out~append(g)
      iterate
    end
    d = reasoning~assess(self~elementId(rule, el['ID']))
    if d['assertible'] & d['stance'] == 'PRO' then iterate
    g['STATUS'] = d['status']
    takes = ''
    do b over el['BINDS']; takes = takes b; end
    g['TAKES'] = takes~strip
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

/* ---- gate 6: one name for one thing (tests/law/VOCABULARY.md) ----
   Architecture: Tom Dyer ("the terms used to define events in offences [must be] consistent").  Event
   names from ChatGPT (GPT-6), OFFENCE_EVENT_CONTRACT_v0.1; the event/finding gate: Claude (Opus 5.5).
   A vocabulary file lists every kind: "kind N:", its name in a code block, "it is an event." or "it is a
   finding.", then its definition in SLAM's words.  The words of a finding are listed after "the words of a
   finding are:".  Returns a Directory: KINDS (name -> Directory TYPE TEXT), FINDINGWORDS, ERRORS.  Refused:
   a kind that says it is both, or neither; a name given twice; a kind with no definition; an EVENT whose
   definition uses a word of a finding (the name would carry a conclusion: "false statement", "unauthorised
   activity", "conspirator"). */
::method vocabulary class
  use strict arg path
  lines = self~linesOf(path)
  kinds = .directory~new; errs = .array~new; fw = .array~new; order = .array~new
  k = .nil; expect = ''; i = 1
  do while i <= lines~items
    t = lines[i]~strip
    if t == '```' then do
      block = ''; i += 1
      do while i <= lines~items
        if lines[i]~strip == '```' then leave
        block = block || lines[i] || ' '
        i += 1
      end
      select
        when expect == 'NAME' then do
          name = block~space
          k = .directory~new; k['NAME'] = name; k['TYPE'] = ''; k['TEXT'] = ''; k['TYPES'] = 0
          if kinds~hasIndex(name) then errs~append('kind' name 'is given twice')
          kinds[name] = k; order~append(name)
        end
        when expect == 'FINDINGWORDS' then fw = block~lower~space~makeArray(' ')
        otherwise nop
      end
      expect = ''
    end
    else if t~word(1)~lower == 'kind' & t~right(1) == ':' & t~words = 2 then expect = 'NAME'
    else if t~lower~right(27) == 'the words of a finding are:' then expect = 'FINDINGWORDS'
    else if k \== .nil & t~lower == 'it is an event.' then do; k['TYPE'] = 'EVENT'; k['TYPES'] += 1; end
    else if k \== .nil & t~lower == 'it is a finding.' then do; k['TYPE'] = 'FINDING'; k['TYPES'] += 1; end
    else if k \== .nil & t \== '' then k['TEXT'] = (k['TEXT'] t)~strip
    i += 1
  end
  if fw~items = 0 then errs~append('the list does not say the words of a finding: an event''s definition can not be checked')
  do name over order
    k = kinds[name]
    if k['TYPES'] > 1 then errs~append('kind' name 'says it is an event and a finding: a kind is one or the other')
    if k['TYPES'] = 0 then errs~append('kind' name 'does not say if it is an event or a finding')
    if k['TEXT'] == '' then errs~append('kind' name 'has no definition')
    if k['TYPE'] == 'EVENT' & k['TYPES'] = 1 then do
      dw = self~words(k['TEXT'])
      do w over fw
        if dw~pos(' ' || w || ' ') > 0 then errs~append('kind' name 'is an event, and its definition uses "' || w || '", a word of a finding: the name carries a conclusion the evidence has to show')
      end
    end
  end
  out = .directory~new
  out['KINDS'] = kinds; out['FINDINGWORDS'] = fw; out['ERRORS'] = errs; out['ORDER'] = order
  return out

/* Each kind USED (an Array of .array(kind, where)) must be on the list; WANT 'EVENT' also requires it to be
   an event (a case's events: a finding is never an event).  An Array of reasons; empty when all pass. */
::method kindErrors class
  use strict arg vocab, used, want = ''
  errs = .array~new
  do u over used
    kind = u[1]; where = u[2]
    if \vocab['KINDS']~hasIndex(kind) then errs~append(where || ':' kind 'is not in the list of kinds')
    else if want \== '' then if vocab['KINDS'][kind]['TYPE'] \== want then
      errs~append(where || ':' kind 'is a' vocab['KINDS'][kind]['TYPE']~lower || ', not an' want~lower)
  end
  return errs

/* The kinds a rule file uses: what each element takes, and the events it can be about. */
::method kindsOfRule class
  use strict arg rule, where = ''
  out = .array~new
  do el over rule['ELEMENTS']
    do b over el['TAKES0']; out~append(.array~of(b, where 'element' el['ID'])); end
  end
  do a over rule['ABOUT']; out~append(.array~of(a, where 'about')); end
  return out

/* The kinds a guidance file uses: each code block that follows a "for element N, ..." line. */
::method kindsOfGuidance class
  use strict arg path
  out = .array~new; lines = self~linesOf(path); expect = .false; i = 1; note = ''
  do while i <= lines~items
    t = lines[i]~strip
    if t~word(1)~lower == 'note' then note = t~strip('T', ':')
    if t~lower~left(12) == 'for element ' then expect = .true
    else if t == '```' then do
      block = ''; i += 1
      do while i <= lines~items
        if lines[i]~strip == '```' then leave
        block = block lines[i]
        i += 1
      end
      if expect then do b over block~space~makeArray(' '); out~append(.array~of(b, path~substr(path~lastPos('/') + 1) note)); end
      expect = .false
    end
    i += 1
  end
  return out

/* The kinds an element-addressed case file uses (step | element | SUPPORT | tier | binding | text). */
::method kindsOfCaseLines class
  use strict arg path
  out = .array~new; name = path~substr(path~lastPos('/') + 1)
  do ln over self~linesOf(path)
    if ln~strip == '' | ln~left(1) == '#' then iterate
    parse var ln step '|' . '|' . '|' . '|' binding '|' .
    out~append(.array~of(binding~strip, name 'step' step~strip))
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

/* Each element a claim, the offence a decision resting on every element.  Returns the decision's id.
   An element that IS an offence (LINK, e.g. s.2's "he commits an offence under section 1") is not a claim:
   the decision rests on every element of the linked offence instead, found in LINKS (a Directory, rule id ->
   the linked rule, already built in this reasoning, with the same KEY scheme).  When the linked rule is not
   given, the element is a claim that no evidence can reach (it takes RULE_PACK, which no evidence binds):
   it stays open, and gaps() says which rule pack it waits for. */
::method build class
  use strict arg reasoning, rule, links = .nil
  rests = .array~new
  do el over rule['ELEMENTS']
    if el['LINK'] \== '' then do
      linked = .nil
      if links \== .nil then if links~hasIndex(el['LINK']) then linked = links[el['LINK']]
      if linked \== .nil then do
        do lel over linked['ELEMENTS']
          rests~append(.array~of(self~elementId(linked, lel['ID']), 'assertible'))
        end
        iterate
      end
      cid = reasoning~claim(self~elementId(rule, el['ID']), el['TEXT'], 'DOCUMENTARY', .array~of('RULE_PACK'))
      rests~append(.array~of(cid, 'assertible'))
      iterate
    end
    cid = reasoning~claim(self~elementId(rule, el['ID']), el['TEXT'], 'DOCUMENTARY', el['BINDS'])
    rests~append(.array~of(cid, 'assertible'))
  end
  return reasoning~decide(self~decisionId(rule), 'the elements of' rule['ID'] 'are supported on the evidence given', rests)

/* Ids: a rule built once uses its ID; the screen builds one instance per extent, event and person, and
   sets KEY to name it (cma1990.s1/E.W.@EV16#J). */
::method elementId class
  use strict arg rule, elementNo
  if rule~hasIndex('KEY') then return 'ELEMENT:' || rule['KEY'] || ':' || elementNo
  return 'ELEMENT:' || rule['ID'] || ':' || elementNo
::method decisionId class
  use strict arg rule
  if rule~hasIndex('KEY') then return 'OFFENCE:' || rule['KEY']
  return 'OFFENCE:' || rule['ID']

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
