/* reader.cls - a concept reader. English in, concepts out.                */
/* The reasoning works on concept ids (C.nnnn) and entity ids (Ennn) only. */
/* English exists in the lexicon and nowhere else; glosses are never read  */
/* by the reasoning (the gloss-scramble test proves it).                   */
/* Architecture: Tom Dyer. Code: Claude (Opus 5.5).                        */

::class ConceptStore public
::attribute parentOf unguarded
::attribute partOfDef unguarded
::attribute gloss unguarded

::method init
  expose parentOf partOfDef gloss
  use arg file
  parentOf  = .StringTable~new
  partOfDef = .StringTable~new
  gloss     = .StringTable~new
  s = .Stream~new(file)~~open('read')
  do while s~lines > 0
    ln = s~linein
    if ln~strip == '' then iterate
    parse var ln id '|' g '|' pid '|' defs
    parentOf[id] = pid
    gloss[id] = g
    do while defs \== ''
      parse var defs d ';' defs
      parse var d k '=' v
      if k~strip == 'part-of' then partOfDef[id] = v~strip
    end
  end
  s~close

/* true if concept id is, or descends from, concept anc */
::method isa
  expose parentOf
  use arg id, anc
  if id == '' then return .false
  cur = id
  do 64
    if cur == anc then return .true
    if \parentOf~hasIndex(cur) then return .false
    cur = parentOf[cur]
    if cur == '' then return .false
  end
  return .false

::method parent
  expose parentOf
  use arg id
  if parentOf~hasIndex(id) then return parentOf[id]
  return ''

::method wholeOf
  expose partOfDef
  use arg id
  if partOfDef~hasIndex(id) then return partOfDef[id]
  return ''

/* a nose is part of an animal because a body part is: the slot inherited.
   Used only to identify a seen part with its owner ("It was Molly") */
::method wholeOfKind
  expose partOfDef
  use arg id
  do 40 while id \== ''
    if partOfDef~hasIndex(id) then return partOfDef[id]
    id = self~parent(id)
  end
  return ''


::class Lexicon public
::attribute entries unguarded
::attribute maxLen unguarded
::attribute phrasal unguarded
::attribute reverse unguarded
::attribute nameConcept unguarded
::attribute clockConcept unguarded
::attribute genderClass unguarded
::attribute placeConcept unguarded
::attribute buildingConcept unguarded
::attribute slotConcepts unguarded

::method init
  expose entries maxLen phrasal reverse nameConcept clockConcept genderClass placeConcept buildingConcept slotConcepts
  use arg file
  entries = .StringTable~new
  phrasal = .StringTable~new
  reverse = .StringTable~new
  maxLen = 1
  nameConcept = ''
  genderClass = .StringTable~new
  placeConcept = ''
  buildingConcept = ''
  slotConcepts = ''
  s = .Stream~new(file)~~open('read')
  do while s~lines > 0
    ln = s~linein
    if ln~strip == '' then iterate
    parse var ln label '|' pos '|' cid '|' feats
    e = .Directory~new
    e['LABEL'] = label
    e['POS'] = pos
    if cid == '-' then cid = ''
    e['CONCEPT'] = cid
    f = .StringTable~new
    do while feats \== ''
      parse var feats kv ';' feats
      parse var kv k '=' v
      if k~strip \== '' then f[k~strip] = v~strip
    end
    e['FEATS'] = f
    if pos == 'name' then do
      nameConcept = cid
      iterate
    end
    if pos == 'clock' then do
      clockConcept = cid
      iterate
    end
    if pos == 'placeclass' then placeConcept = cid
    if pos == 'slotclass' then slotConcepts = (slotConcepts cid)~strip
    if pos == 'buildingclass' then buildingConcept = cid
    if pos == 'genderclass' then do
      genderClass[f['gender']] = cid
      iterate
    end
    if pos == 'phrasal' then do
      phrasal[label] = e
      parse var label vid '+' word
      reverse['PH/'||cid] = e
      iterate
    end
    if \entries~hasIndex(label) then entries[label] = .Array~new
    entries[label]~append(e)
    if words(label) > maxLen then maxLen = words(label)
    call addReverse reverse, e
  end
  s~close
  return

addReverse: procedure
  use arg reverse, e
  pos = e['POS']
  cid = e['CONCEPT']
  f = e['FEATS']
  key = ''
  select
    when pos == 'noun' then do
      num = 'sg'
      if f~hasIndex('num') then num = f['num']
      key = 'N/'||cid||'/'||num
    end
    when pos == 'verb' then do
      key = 'V/'||cid||'/'||f['form']
      if f['num'] == 'pl' then key = key'/pl'
      if f['pp'] == 'yes' then key = key'/pp'
    end
    when pos == 'adj' then key = 'A/'||cid
    when pos == 'prep' then key = 'P/'||f['role']||'/'||cid
    when pos == 'part' then key = 'T/'||cid
    when pos == 'wh' then key = 'WH/'||f['ask']
    when pos == 'aux' then do
      key = 'AUX/'||f['tense']
      if f['perfect'] == 'yes' then key = key'/perf'
    end
    otherwise key = pos~upper||'/'||cid
  end
  if key \== '' then if \reverse~hasIndex(key) then reverse[key] = e['LABEL']
  return

/* all lexicon entries starting at token i, longest first */
::method candidates
  expose entries maxLen
  use arg toks, i
  found = .Array~new
  do len = maxLen to 1 by -1
    if i + len - 1 > toks~items then iterate
    label = toks[i]
    do k = 1 to len - 1
      label = label toks[i + k]
    end
    if entries~hasIndex(label) then do e over entries[label]
      c = .Directory~new
      c['E'] = e
      c['LEN'] = len
      found~append(c)
    end
  end
  return found

/* first (longest) entry at token i whose part of speech is in posList */
::method find
  use arg toks, i, posList
  if i > toks~items then return .nil
  do c over self~candidates(toks, i)
    if wordpos(c['E']['POS'], posList) > 0 then return c
  end
  return .nil

::method known
  expose entries
  use arg tok
  return entries~hasIndex(tok)

::method phrasalFor
  expose phrasal
  use arg verbId, word
  key = verbId||'+'||word
  if phrasal~hasIndex(key) then return phrasal[key]
  return .nil

::method label
  expose reverse
  use arg key
  if reverse~hasIndex(key) then return reverse[key]
  return ''


::class Entity public
::attribute id unguarded
::attribute concept unguarded
::attribute name unguarded
::attribute attrs unguarded
::attribute loc unguarded
::attribute holder unguarded
::attribute home unguarded
::attribute owner unguarded
::attribute partOf unguarded
::attribute amount unguarded
::attribute plural unguarded
::attribute intro unguarded
::attribute introAttrs unguarded
::attribute gender unguarded
::attribute scenes unguarded
::attribute members unguarded
::attribute status unguarded
::attribute locHist unguarded
::attribute ordinal unguarded
::attribute ordval unguarded
::attribute stale unguarded
::attribute relation unguarded
::attribute locInfer unguarded
::attribute relOf unguarded

::method init
  expose id concept name attrs loc holder home owner partOf amount plural intro introAttrs gender scenes members status locHist ordinal ordval stale relation relOf locInfer
  use arg id, concept
  intro = 'def'
  introAttrs = ''
  gender = ''
  scenes = ''
  members = ''
  status = ''
  locHist = ''
  ordinal = ''
  ordval = ''
  stale = 0
  relation = ''
  relOf = ''
  locInfer = ''
  name = ''
  attrs = ''
  loc = ''
  holder = ''
  home = ''
  owner = ''
  partOf = ''
  amount = ''
  plural = .false


::class Rule public
::attribute event unguarded
::attribute pre unguarded
::attribute effects unguarded


::class Reader public
::attribute cs unguarded
::attribute lex unguarded
::attribute rules unguarded
::attribute ents unguarded
::attribute byName unguarded
::attribute mentions unguarded
::attribute props unguarded
::attribute order unguarded
::attribute findings unguarded
::attribute nextE unguarded
::attribute nextP unguarded
::attribute lastSpeaker unguarded
::attribute unread unguarded
::attribute roleNames unguarded
::attribute capSeen unguarded
::attribute castNames unguarded
::attribute lastSubj unguarded
::attribute missRef unguarded
::attribute scene unguarded
::attribute prevLineSubj unguarded
::attribute lastAsk unguarded
::attribute subjHist unguarded
::attribute sceneUsed unguarded
::attribute lastOrdConcept unguarded
::attribute remainsCond unguarded
::attribute lastPatient unguarded
::attribute voice unguarded
::attribute reporter unguarded
::attribute pronBlock unguarded
::attribute orderFrom unguarded
::attribute orderTo unguarded
::attribute orders unguarded
::attribute hiding unguarded
::attribute hidingProp unguarded
::attribute voiceTier unguarded
::attribute party unguarded
::attribute lastPlace unguarded

::method init
  expose cs lex rules ents byName mentions props order findings nextE nextP lastSpeaker unread roleNames capSeen lastSubj scene prevLineSubj lastAsk subjHist sceneUsed lastOrdConcept remainsCond lastPatient voice reporter pronBlock orderFrom orderTo orders hiding hidingProp voiceTier party lastPlace
  use arg dir
  cs  = .ConceptStore~new(dir'/concepts.words')
  lex = .Lexicon~new(dir'/lexicon.words')
  remainsCond = ''
  rules = .StringTable~new
  s = .Stream~new(dir'/rules.words')~~open('read')
  do while s~lines > 0
    ln = s~linein
    if ln~strip == '' then iterate
    parse var ln ev '|' pre '|' eff
    r = .Rule~new
    r~event = ev
    r~pre = pre
    r~effects = eff
    rules[ev] = r
    if pre == 'remains-if' then remainsCond = eff
  end
  s~close
  ents = .StringTable~new
  byName = .StringTable~new
  mentions = .Array~new
  props = .StringTable~new
  order = .Array~new
  findings = .Array~new
  nextE = 0
  nextP = 0
  lastSpeaker = ''
  unread = .Array~new
  capSeen = .StringTable~new
  self~castNames = .StringTable~new
  lastSubj = ''
  scene = 1
  prevLineSubj = ''
  lastAsk = ''
  subjHist = ''
  sceneUsed = .false
  lastOrdConcept = ''
  lastPatient = ''
  voice = ''
  reporter = ''
  pronBlock = .false
  orderFrom = ''
  orderTo = ''
  orders = .Array~new
  hiding = ''
  hidingProp = ''
  voiceTier = ''
  party = ''
  lastPlace = ''
  roleNames = 'agent patient recipient holder instrument at to from path time amount manner source about purpose content dir result kind attr company until before after ident'

/* ------------------------------------------------------------------ */
/* text handling                                                      */
/* ------------------------------------------------------------------ */
::method tokens
  use arg text
  t = text~changeStr('’', "'")~changeStr('‘', "'")~lower
  t = t~changeStr(',', ' , ')~changeStr('.', ' . ')~changeStr('!', ' ! ')~changeStr('?', ' ? ')
  toks = .Array~new
  do w over t~subWords
    if w~length > 2 then if w~right(2) == "'s" then do
      toks~append(w~left(w~length - 2))
      toks~append("'s")
      iterate
    end
    toks~append(w)
  end
  return toks

/* "# Statement 1 - Liam Carter": what follows is Liam's testimony.
   "# Official record - ...": what follows is a document. Other headings
   (chapters) leave the narrator as the source. */
::method heading
  expose lex
  use arg ln
  t = self~tokens(ln~changeStr('#', ' ')~changeStr('—', ' ')~changeStr('-', ' '))
  tier = ''
  do k = 1 to t~items
    c = lex~find(t, k, 'section')
    if c \== .nil then tier = c['E']['FEATS']['tier']
  end
  self~voiceTier = tier
  self~voice = ''
  self~party = ''
  self~lastPlace = ''
  /* "# Order - Raglan to Lucan": kept as an order from one to the other,
     never read into the world (an order says what should happen) */
  self~orderFrom = ''
  self~orderTo = ''
  do k = 1 to t~items
    c = lex~find(t, k, 'section')
    if c == .nil then iterate
    if c['E']['FEATS']['mode'] \== 'order' then iterate
    do j = k + 1 to t~items
      if \self~isName(t[j]) then iterate
      if self~orderFrom == '' then self~orderFrom = self~nameEntity(t[j])
      else if self~orderTo == '' then if j > 1 then if t[j - 1] == 'to' then self~orderTo = self~nameEntity(t[j])
    end
    return
  end
  if tier \== 'TESTIMONY' then return
  do k = 1 to t~items
    if self~isName(t[k]) then do
      self~voice = self~nameEntity(t[k])
      self~party = self~voice
      return
    end
  end

/* split text into sentences, keeping the end mark as the last token */
::method sentences
  use arg text
  out = .Array~new
  cur = .Array~new
  do w over self~tokens(text)
    cur~append(w)
    if wordpos(w, '. ! ?') > 0 then do
      out~append(cur)
      cur = .Array~new
    end
  end
  if cur~items > 0 then out~append(cur)
  return out

::method readFile
  expose capSeen
  use arg file
  capStart = .StringTable~new
  lowSeen = .StringTable~new
  text = .Array~new
  s = .Stream~new(file)~~open('read')
  do while s~lines > 0
    text~append(s~linein)
  end
  s~close
  /* a name is a word written with a capital where a sentence does not start */
  do ln over text
    t = ln~changeStr('"', ' . ')~changeStr('“', ' . ')~changeStr('”', ' . ')
    t = t~changeStr('.', ' . ')~changeStr('!', ' . ')~changeStr('?', ' . ')
    start = .true
    do w over t~subWords
      if w == '.' then do
        start = .true
        iterate
      end
      w2 = w~strip('T', ',')~changeStr('’s', '')~changeStr("'s", '')
      isCap = w2~left(1) \== w2~left(1)~lower
      /* HUGE, BIG: emphasis, not a name */
      if w2~length > 1 then if w2 == w2~upper then isCap = .false
      if isCap then do
        if start then capStart[w2~lower] = 1
        else capSeen[w2~lower] = 1
      end
      else lowSeen[w2~lower] = 1
      start = .false
    end
  end
  do w over capStart~allIndexes
    if \lowSeen~hasIndex(w) then capSeen[w] = 1
  end
  /* a cast list beside the story declares names outright (KLM is a name,
     though all capitals usually mean emphasis) */
  cf = filespec('L', file)'cast.words'
  if SysFileExists(cf) then do
    cst = .Stream~new(cf)~~open('read')
    do while cst~lines > 0
      nm = cst~linein~strip~lower
      if nm == '' then iterate
      capSeen[nm] = 1
      self~castNames[nm] = 1
    end
    cst~close
  end
  k = 0
  do while k < text~items
    k = k + 1
    ln = text[k]
    if ln~strip == '' then iterate
    /* a heading starts a new scene; text before any heading is scene 1 */
    if ln~strip~left(1) == '#' then do
      if self~sceneUsed then self~scene = self~scene + 1
      self~sceneUsed = .false
      self~prevLineSubj = ''
      self~hiding = ''
      self~heading(ln)
      iterate
    end
    self~sceneUsed = .true
    /* "Arthur called out from the door." then a line that is only a quote */
    if ln~pos('"') = 0 then if k < text~items then if text[k + 1]~strip~left(1) == '"' then do
      ss = self~sentences(ln)
      if ss~items > 0 then if self~hasSpeechVerb(ss[ss~items]) then do
        ln = ln text[k + 1]
        k = k + 1
      end
    end
    self~readLine(ln)
  end

/* one line of the story: narration, quotes and speech tags */
::method readLine
  expose lastSpeaker
  use arg ln
  t = ln~changeStr('“', '"')~changeStr('”', '"')
  segs = .Array~new
  inQ = .false
  do while t \== ''
    parse var t piece '"' t
    seg = .Directory~new
    seg['Q'] = inQ
    seg['TEXT'] = piece
    segs~append(seg)
    inQ = \inQ
  end
  /* find speech tags: a narrative sentence next to a quote with a speech verb */
  do k = 1 to segs~items
    seg = segs[k]
    seg['SENTS'] = .Array~new
    seg['TAG'] = .nil
    if seg['Q'] then iterate
    sents = self~sentences(seg['TEXT'])
    do j = 1 to sents~items
      toks = sents[j]
      isTag = .false
      if self~hasSpeechVerb(toks) then do
        if j = 1 then if k > 1 then isTag = .true
        if j = sents~items then if k < segs~items then isTag = .true
      end
      if isTag then seg['TAG'] = self~parseTag(toks)
      else seg['SENTS']~append(toks)
    end
  end
  /* read in order */
  lastSubject = ''
  hasQuote = .false
  do k = 1 to segs~items
    seg = segs[k]
    if \seg['Q'] then if self~orderFrom \== '' then do
      do toks over seg['SENTS']
        od = .Directory~new
        od['FROM'] = self~orderFrom
        od['TO'] = self~orderTo
        od['TOKS'] = toks
        od['SECTION'] = self~scene
        self~orders~append(od)
      end
      iterate
    end
    if \seg['Q'] then if self~voice \== '' then do
      /* a witness's own words: claims by the witness, never facts */
      do toks over seg['SENTS']
        self~testify(toks)
      end
      iterate
    end
    if \seg['Q'] then do
      do toks over seg['SENTS']
        p = self~narrate(toks)
        if p \== .nil then do
          if p['ROLES']~hasIndex('agent') then lastSubject = self~speakerOf(p['ROLES']['agent'])
          else if p['ROLES']~hasIndex('holder') then lastSubject = self~speakerOf(p['ROLES']['holder'])
        end
      end
      iterate
    end
    hasQuote = .true
    if seg['TEXT']~strip == '' then iterate
    tag = .nil
    if k < segs~items then tag = segs[k + 1]['TAG']
    if tag == .nil then if k > 1 then tag = segs[k - 1]['TAG']
    speaker = ''
    sverb = ''
    source = ''
    if tag \== .nil then do
      speaker = tag['SPEAKER']
      sverb = tag['EVENT']
      source = tag['SOURCE']
    end
    /* no tag: someone named in this line's narration, else the subject of the
       line before, else the person a question was put to, else the last speaker */
    if speaker == '' then speaker = lastSubject
    if speaker == '' then speaker = self~prevLineSubj
    if speaker == '' then if self~lastAsk \== '' then speaker = self~lastAsk
    if speaker == '' then speaker = lastSpeaker
    /* a quote inside a statement is what the witness says someone said */
    if self~voice \== '' then self~reporter = self~voice
    else self~reporter = ''
    self~speech(seg['TEXT'], speaker, sverb, source)
    self~reporter = ''
    lastSpeaker = speaker
  end
  if hasQuote then self~prevLineSubj = ''
  else self~prevLineSubj = lastSubject

::method hasSpeechVerb
  expose lex
  use arg toks
  do i = 1 to toks~items
    c = lex~find(toks, i, 'verb')
    if c \== .nil then if c['E']['FEATS']~hasIndex('speech') then return .true
  end
  return .false

/* a speech tag: [from NP ,] NP verb [particle] | verb NP */
::method parseTag
  expose lex
  use arg toks
  tag = .Directory~new
  tag['SPEAKER'] = ''
  tag['EVENT'] = ''
  tag['SOURCE'] = ''
  i = 1
  pp = self~parsePP(toks, i)
  if pp \== .nil then if pp['ROLE'] == 'source' then do
    tag['SOURCE'] = self~resolvePlace(pp, .nil, '')
    i = pp['NEXT']
  end
  do while i <= toks~items
    if toks[i] \== ',' then leave
    i = i + 1
  end
  v = lex~find(toks, i, 'verb')
  if v \== .nil then do
    np = self~parseNP(toks, i + v['LEN'])
    ev = v['E']['CONCEPT']
    i = i + v['LEN']
  end
  else do
    np = self~parseNP(toks, i)
    if np == .nil then return tag
    i = np['NEXT']
    v = lex~find(toks, i, 'verb')
    if v == .nil then return tag
    ev = v['E']['CONCEPT']
    i = i + v['LEN']
  end
  if i <= toks~items then do
    ph = lex~phrasalFor(ev, toks[i])
    if ph \== .nil then ev = ph['CONCEPT']
  end
  tag['EVENT'] = ev
  if np \== .nil then do
    tctx = .nil
    if self~voice \== '' then do
      tctx = .Directory~new
      tctx['SPEAKER'] = self~voice
      tctx['ADDRESSEE'] = ''
    end
    tag['SPEAKER'] = self~resolveRef(np, tctx, '', .nil)
  end
  return tag

/* ------------------------------------------------------------------ */
/* phrase parsing                                                     */
/* ------------------------------------------------------------------ */
::method isName
  expose lex capSeen
  use arg tok
  if self~castNames~hasIndex(tok) then return .true
  if lex~known(tok) then return .false
  if tok == "'s" then return .false
  if \capSeen~hasIndex(tok) then return .false
  return datatype(tok~changeStr('-', ''), 'M')

/* a run of capitalised words from i: names, and ordinary nouns or
   adjectives the text always capitalises ("Opera House", "North Valley").
   A run with no ordinary word is a person (Liam Carter: LABEL liam, as
   before); a run of two or more with one is a place, named in full. */
::method nameRun
  expose lex capSeen
  use arg toks, i
  j = i
  names = 0
  words_ = 0
  lab = ''
  do while j <= toks~items
    t = toks[j]
    if self~isName(t) then names = names + 1
    else if capSeen~hasIndex(t) & lex~find(toks, j, 'noun adj') \== .nil then words_ = words_ + 1
    else leave
    lab = lab t
    j = j + 1
  end
  if j == i then return .nil
  r = .Directory~new
  r['END'] = j
  r['PLACE'] = .false
  if words_ > 0 then do
    if names + words_ < 2 then return .nil
    r['PLACE'] = .true
    r['LABEL'] = lab~strip
  end
  else r['LABEL'] = toks[i]
  if names + words_ >= 2 then if words_ = 0 then r['LABEL'] = lab~strip
  return r

/* adjectives then a noun */
::method parseCore
  expose lex
  use arg toks, i
  attrs = ''
  remaining = 0
  do while i <= toks~items
    if toks[i] == ',' then do
      i = i + 1
      iterate
    end
    if lex~find(toks, i, 'intens') \== .nil then do
      i = i + 1
      iterate
    end
    if lex~find(toks, i, 'qual') \== .nil then do
      remaining = 1
      i = i + 1
      iterate
    end
    /* the KLM aircraft, the Pan Am aircraft: a name before a noun says which
       one (only after an article or adjective: "Pip collect" is not a noun) */
    nameMod = .false
    if self~isName(toks[i]) then if i > 1 then if lex~find(toks, i - 1, 'det adj') \== .nil then nameMod = .true
    if nameMod then do
      j = i
      do while j <= toks~items
        if \self~isName(toks[j]) then leave
        j = j + 1
      end
      if lex~find(toks, j, 'noun adj') == .nil then return .nil
      do k = i to j - 1
        attrs = attrs 'N:'toks[k]
      end
      i = j
      iterate
    end
    n = lex~find(toks, i, 'noun')
    a = lex~find(toks, i, 'adj')
    if n \== .nil then do
      /* an adjective that is also a noun start: prefer adjective if a noun follows */
      useAdj = .false
      if a \== .nil then if lex~find(toks, i + 1, 'noun adj') \== .nil then useAdj = .true
      if \useAdj then if lex~find(toks, i + n['LEN'], 'noun') \== .nil then do
        /* a noun before a noun is a modifier: fence post, pollen dust */
        attrs = attrs n['E']['CONCEPT']
        i = i + n['LEN']
        iterate
      end
      if \useAdj then do
        core = .Directory~new
        core['REMAINING'] = remaining
        core['CONCEPT'] = n['E']['CONCEPT']
        core['ATTRS'] = attrs~strip
        core['PLURAL'] = n['E']['FEATS']~hasIndex('num')
        core['MASS'] = n['E']['FEATS']~hasIndex('mass')
        core['NEXT'] = i + n['LEN']
        return core
      end
    end
    if a == .nil then return .nil
    attrs = attrs a['E']['CONCEPT']
    i = i + a['LEN']
  end
  return .nil

::method parseNP
  expose lex
  use arg toks, i
  if i > toks~items then return .nil
  ref = .Directory~new
  /* 3:10, 3:20 pm, about 3:20 */
  ci = i
  if lex~find(toks, ci, 'intens') \== .nil then if ci < toks~items then ci = ci + 1
  tk = toks[ci]
  if tk~pos(':') > 1 then do
    parse var tk hh ':' mm
    if datatype(hh, 'W') then if datatype(mm, 'W') then if mm~length = 2 then do
      ref['KIND'] = 'clock'
      ref['CONCEPT'] = lex~clockConcept
      ref['MIN'] = hh * 60 + mm
      ref['APPROX'] = (ci > i)
      ref['NEXT'] = ci + 1
      if ci < toks~items then if lex~find(toks, ci + 1, 'clockmark') \== .nil then ref['NEXT'] = ci + 2
      return ref
    end
  end
  /* the North Valley, the Causeway Heights: a proper name with its article */
  c = lex~find(toks, i, 'det')
  if c \== .nil then if c['E']['FEATS']['kind'] == 'def' then do
    run = self~nameRun(toks, i + c['LEN'])
    /* but "the KLM aircraft" is an aircraft: the names say which */
    if run \== .nil then if lex~find(toks, run['END'], 'noun') \== .nil then run = .nil
    if run \== .nil then do
      ref['KIND'] = 'name'
      ref['LABEL'] = run['LABEL']
      ref['NEXT'] = run['END']
      return ref
    end
  end
  /* all three of us */
  c = lex~find(toks, i, 'det')
  if c \== .nil then if c['E']['FEATS']['kind'] == 'all' then do
    j = i + c['LEN']
    nn = lex~find(toks, j, 'num')
    if nn \== .nil then j = j + nn['LEN']
    if j < toks~items then if toks[j] == 'of' then do
      inner = self~parseNP(toks, j + 1)
      if inner \== .nil then do
        ref['KIND'] = 'allof'
        ref['INNER'] = inner
        if nn \== .nil then ref['COUNT'] = nn['E']['FEATS']['val']
        else ref['COUNT'] = ''
        ref['NEXT'] = inner['NEXT']
        return ref
      end
    end
  end
  c = lex~find(toks, i, 'pron')
  if c \== .nil then if lex~find(toks, i, 'poss det') \== .nil then if self~parseCore(toks, i + 1) \== .nil then c = .nil
  if c \== .nil then do
    ref['KIND'] = 'pron'
    ref['FEATS'] = c['E']['FEATS']
    ref['LABEL'] = c['E']['LABEL']
    ref['NEXT'] = i + c['LEN']
    return ref
  end
  c = lex~find(toks, i, 'poss')
  if c \== .nil then do
    core = self~parseCore(toks, i + c['LEN'])
    if core == .nil then return .nil
    owner = .Directory~new
    owner['KIND'] = 'pron'
    owner['FEATS'] = c['E']['FEATS']
    ref['KIND'] = 'poss'
    ref['OWNER'] = owner
    ref['CORE'] = core
    ref['NEXT'] = core['NEXT']
    /* my brother, Noah: the name is the person, the noun his relation to the speaker */
    nx = core['NEXT']
    if nx < toks~items then if toks[nx] == ',' then if self~isName(toks[nx + 1]) then do
      ref['APPNAME'] = toks[nx + 1]
      ref['NEXT'] = nx + 2
      do while ref['NEXT'] <= toks~items
        if \self~isName(toks[ref['NEXT']]) then leave
        ref['NEXT'] = ref['NEXT'] + 1
      end
    end
    return ref
  end
  c = lex~find(toks, i, 'deixis')
  if c \== .nil then do
    ref['KIND'] = 'deixis'
    ref['CONCEPT'] = c['E']['CONCEPT']
    ref['NEXT'] = i + c['LEN']
    return ref
  end
  c = lex~find(toks, i, 'verb')
  if c \== .nil then if c['E']['FEATS']['form'] == 'ing' then do
    inner = self~parseNP(toks, i + c['LEN'])
    ref['KIND'] = 'gerund'
    ref['EVENT'] = c['E']['CONCEPT']
    ref['PATIENT'] = inner
    ref['NEXT'] = i + c['LEN']
    if inner \== .nil then ref['NEXT'] = inner['NEXT']
    return ref
  end
  /* one of the seven remaining acorns */
  c = lex~find(toks, i, 'num')
  if c \== .nil then if i + c['LEN'] <= toks~items then if toks[i + c['LEN']] == 'of' then do
    inner = self~parseNP(toks, i + c['LEN'] + 1)
    if inner \== .nil then do
      ref['KIND'] = 'partof'
      ref['INNER'] = inner
      ref['NEXT'] = inner['NEXT']
      return ref
    end
  end
  /* the sixth acorn / the final acorn / (near) the first */
  c = lex~find(toks, i, 'det')
  if c \== .nil then if c['E']['FEATS']['kind'] == 'def' then do
    o = lex~find(toks, i + c['LEN'], 'ord')
    if o \== .nil then do
      ref['KIND'] = 'ord'
      ref['ORDC'] = o['E']['CONCEPT']
      ref['ORDV'] = o['E']['FEATS']['val']
      core = self~parseCore(toks, i + c['LEN'] + o['LEN'])
      ref['CORE'] = core
      ref['NEXT'] = i + c['LEN'] + o['LEN']
      if core \== .nil then ref['NEXT'] = core['NEXT']
      return ref
    end
  end
  c = lex~find(toks, i, 'det num')
  if c \== .nil then do
    /* all twelve acorns / the seven remaining acorns */
    cnt = ''
    cntc = ''
    j = i + c['LEN']
    if c['E']['POS'] == 'num' then do
      cnt = c['E']['FEATS']['val']
      cntc = c['E']['CONCEPT']
    end
    else do
      nn = lex~find(toks, j, 'num')
      if nn \== .nil then do
        cnt = nn['E']['FEATS']['val']
        cntc = nn['E']['CONCEPT']
        j = j + nn['LEN']
      end
    end
    core = self~parseCore(toks, j)
    /* "eight o'clock": a number that starts no noun phrase leaves it to the noun */
    if core == .nil then c = .nil
  end
  if c \== .nil then do
    ref['COUNT'] = cnt
    ref['COUNTC'] = cntc
    if c['E']['POS'] == 'num' then do
      ref['KIND'] = 'indef'
      ref['AMOUNT'] = c['E']['CONCEPT']
    end
    else ref['KIND'] = c['E']['FEATS']['kind']
    ref['OTHER'] = c['E']['FEATS']~hasIndex('other')
    ref['CORE'] = core
    ref['NEXT'] = core['NEXT']
    nx = core['NEXT']
    if nx <= toks~items then if toks[nx] == "'s" then do
      core2 = self~parseCore(toks, nx + 1)
      if core2 \== .nil then do
        poss = .Directory~new
        poss['KIND'] = 'poss'
        poss['OWNER'] = ref
        poss['CORE'] = core2
        poss['NEXT'] = core2['NEXT']
        return poss
      end
    end
    if nx <= toks~items then if toks[nx] == 'of' then do
      ofnp = self~parseNP(toks, nx + 1)
      if ofnp \== .nil then do
        poss = .Directory~new
        poss['KIND'] = 'poss'
        poss['DET'] = ref['KIND']
        poss['OWNER'] = ofnp
        poss['CORE'] = core
        poss['NEXT'] = ofnp['NEXT']
        return poss
      end
    end
    return ref
  end
  /* Circular Quay, Blues Point Tower: capitalised words that are also
     ordinary words, run together, are a place's name */
  run = self~nameRun(toks, i)
  if run \== .nil then if run['PLACE'] then if lex~find(toks, run['END'], 'noun') == .nil then do
    ref['KIND'] = 'name'
    ref['LABEL'] = run['LABEL']
    ref['NEXT'] = run['END']
    return ref
  end
  core = self~parseCore(toks, i)
  if core \== .nil then do
    nx = core['NEXT']
    if nx < toks~items then if lex~find(toks, nx, 'numword') \== .nil then do
      nn = lex~find(toks, nx + 1, 'num')
      if nn \== .nil then do
        ref['KIND'] = 'ord'
        ref['ORDC'] = nn['E']['CONCEPT']
        ref['ORDV'] = nn['E']['FEATS']['val']
        ref['CORE'] = core
        ref['NEXT'] = nx + 1 + nn['LEN']
        return ref
      end
    end
    ref['KIND'] = 'bare'
    ref['CORE'] = core
    ref['NEXT'] = core['NEXT']
    return ref
  end
  if self~isName(toks[i]) then do
    if i < toks~items then if toks[i + 1] == "'s" then do
      core = self~parseCore(toks, i + 2)
      if core == .nil then return .nil
      owner = .Directory~new
      owner['KIND'] = 'name'
      owner['LABEL'] = toks[i]
      ref['KIND'] = 'poss'
      ref['OWNER'] = owner
      ref['CORE'] = core
      ref['NEXT'] = core['NEXT']
      return ref
    end
    ref['KIND'] = 'name'
    ref['LABEL'] = toks[i]
    ref['NEXT'] = i + 1
    do while ref['NEXT'] <= toks~items
      if \self~isName(toks[ref['NEXT']]) then leave
      ref['NEXT'] = ref['NEXT'] + 1
    end
    d = lex~find(toks, ref['NEXT'], 'det')
    if d \== .nil then if d['E']['FEATS']['kind'] == 'def' then do
      ap = self~parseCore(toks, ref['NEXT'] + 1)
      if ap \== .nil then do
        ref['APPOS'] = ap['CONCEPT']
        ref['NEXT'] = ap['NEXT']
      end
    end
    return ref
  end
  core = self~parseCore(toks, i)
  if core == .nil then return .nil
  ref['KIND'] = 'bare'
  ref['CORE'] = core
  ref['NEXT'] = core['NEXT']
  return ref

/* the concept a ref names, if the parse tells us */
::method refConcept
  use arg ref
  if ref == .nil then return ''
  if ref~hasIndex('CORE') then return ref['CORE']['CONCEPT']
  if ref~hasIndex('CONCEPT') then return ref['CONCEPT']
  if ref['KIND'] == 'gerund' then return ref['EVENT']
  if ref['KIND'] == 'name' then return self~lex~nameConcept
  if ref['KIND'] == 'pron' then do
    f = ref['FEATS']
    if f~hasIndex('need') then return f['need']
    if wordpos(f['ref'], 'speaker addressee we') > 0 then return self~lex~nameConcept
  end
  return ''

/* preposition + NP; picks the reading whose need the NP meets */
::method parsePP
  expose lex cs
  use arg toks, i
  if i > toks~items then return .nil
  cands = lex~candidates(toks, i)
  do c over cands
    e = c['E']
    if e['POS'] \== 'prep' then iterate
    np = self~parseNP(toks, i + c['LEN'])
    if np == .nil then iterate
    f = e['FEATS']
    if f~hasIndex('need') then do
      if \cs~isa(self~refConcept(np), f['need']) then iterate
    end
    pp = .Directory~new
    pp['ROLE'] = f['role']
    pp['REL'] = e['CONCEPT']
    pp['WORD'] = e['LABEL']
    pp['NP'] = np
    pp['NEXT'] = np['NEXT']
    return pp
  end
  return .nil

/* ------------------------------------------------------------------ */
/* clause parsing                                                     */
/* ------------------------------------------------------------------ */
::method newProp
  expose nextP
  use arg act
  p = .Directory~new
  p['ACT'] = act
  p['EVENT'] = ''
  p['ROLES'] = .StringTable~new
  p['POL'] = '+'
  p['MODAL'] = ''
  p['ASPECT'] = ''
  p['NOTE'] = ''
  return p

/* parse one clause into a prop with unresolved refs; .nil if unread */
::method parseClause
  expose lex cs
  use arg toks, act
  n = toks~items
  do while n > 0
    if wordpos(toks[n], '. ! ? ,') = 0 then leave
    n = n - 1
  end
  if n = 0 then return .nil
  t = toks~section(1, n)
  p = self~newProp(act)
  roles = p['ROLES']
  i = 1
  /* fixed formulas and sounds */
  c = lex~find(t, i, 'formula')
  if c \== .nil then if c['E']['FEATS']['act'] == 'exclaim' then if c['LEN'] \= n then c = .nil
  if c \== .nil then do
    p['ACT'] = c['E']['FEATS']['act']
    p['EVENT'] = c['E']['CONCEPT']
    if i + c['LEN'] <= n then do
      d = self~parseNP(t, i + c['LEN'])
      if d \== .nil then roles['time'] = d
    end
    return p
  end
  c = lex~find(t, i, 'sound')
  if c \== .nil then if c['LEN'] = n then do
    p['ACT'] = 'sound'
    p['EVENT'] = c['E']['CONCEPT']
    return p
  end
  /* leading adverbials */
  do forever
    if i > n then leave
    if t[i] == ',' then do
      i = i + 1
      iterate
    end
    if lex~find(t, i, 'conj intens') \== .nil then do
      i = i + 1
      iterate
    end
    c = lex~find(t, i, 'adv')
    /* "after the robbery" is a PP, not the adverb "after" */
    if c \== .nil then if lex~find(t, i, 'prep') \== .nil then if self~parsePP(t, i) \== .nil then c = .nil
    if c \== .nil then do
      if c['E']['FEATS']~hasIndex('time') then roles['time'] = c['E']['CONCEPT']
      i = i + c['LEN']
      iterate
    end
    c = lex~find(t, i, 'det')
    if c \== .nil then if c['E']['FEATS']['kind'] == 'every' then do
      np = self~parseNP(t, i)
      if np \== .nil then do
        roles['time'] = np
        i = np['NEXT']
        iterate
      end
    end
    pp = self~parsePP(t, i)
    if pp \== .nil then if wordpos(pp['ROLE'], 'time source after before') > 0 then do
      if roles~hasIndex(pp['ROLE']) then roles['time2'] = pp
      else roles[pp['ROLE']] = pp
      i = pp['NEXT']
      iterate
    end
    leave
  end
  /* there was / were (no) NP [PP] */
  c = lex~find(t, i, 'expl')
  if c \== .nil then do
    v = lex~find(t, i + 1, 'verb')
    if v \== .nil then if v['E']['FEATS']~hasIndex('cop') then do
      j = i + 1 + v['LEN']
      do while lex~find(t, j, 'intens') \== .nil
        j = j + 1
      end
      np = self~parseNP(t, j)
      if np == .nil then return .nil
      p['EVENT'] = v['E']['CONCEPT']
      p['FORM'] = v['E']['FEATS']['form']
      p['EXIST'] = 1
      if np['KIND'] == 'no' then p['POL'] = '-'
      roles['holder'] = np
      j = np['NEXT']
      pp = self~parsePP(t, j)
      if pp \== .nil then do
        roles['at'] = pp
        j = pp['NEXT']
      end
      if j <= n then p['NOTE'] = 'unread words:' self~join(t, j, n)
      return p
    end
  end
  /* inside the log was a huge pile of nuts */
  pp = self~parsePP(t, i)
  if pp \== .nil then do
    v = lex~find(t, pp['NEXT'], 'verb')
    if v \== .nil then if v['E']['FEATS']~hasIndex('cop') then do
      np = self~parseNP(t, pp['NEXT'] + v['LEN'])
      if np \== .nil then do
        p['EVENT'] = v['E']['CONCEPT']
        p['FORM'] = v['E']['FEATS']['form']
        roles['holder'] = np
        roles['at'] = pp
        if np['NEXT'] <= n then p['NOTE'] = 'unread words:' self~join(t, np['NEXT'], n)
        return p
      end
    end
  end
  /* why ... */
  c = lex~find(t, i, 'wh')
  if c \== .nil then do
    p['ACT'] = 'ask'
    p['ASKS'] = c['E']['FEATS']['ask']
    i = i + c['LEN']
    a = lex~find(t, i, 'aux')
    if a \== .nil then do
      p['AUXT'] = a['E']['FEATS']['tense']
      if a['E']['FEATS']['perfect'] == 'yes' then p['PERF'] = 1
      i = i + a['LEN']
    end
  end
  /* to + verb: a purpose fragment */
  c = lex~find(t, i, 'inf')
  if c \== .nil then do
    v = lex~find(t, i + 1, 'verb')
    if v \== .nil then do
      p['FRAG'] = 'purpose'
      return self~parseVerbPhrase(t, i + 1, n, p)
    end
  end
  /* here + copula + NP */
  c = lex~find(t, i, 'deixis')
  if c \== .nil then do
    v = lex~find(t, i + c['LEN'], 'verb')
    if v \== .nil then if v['E']['FEATS']~hasIndex('cop') then do
      np = self~parseNP(t, i + c['LEN'] + v['LEN'])
      if np \== .nil then do
        p['EVENT'] = v['E']['CONCEPT']
        roles['holder'] = np
        d = .Directory~new
        d['ROLE'] = 'at'
        d['REL'] = ''
        d['NP'] = self~parseNP(t, i)
        roles['at'] = d
        return p
      end
    end
  end
  /* subject, or none (an order) */
  v = lex~find(t, i, 'verb')
  if v \== .nil then if v['E']['FEATS']['form'] == 'ing' then v = .nil
  if v \== .nil then if p['ACT'] == 'narrate' then do
    np0 = self~parseNP(t, i)
    if np0 \== .nil then if lex~find(t, np0['NEXT'], 'verb aux modal aspect neg') \== .nil then v = .nil
  end
  subj = .nil
  if v == .nil then do
    subj = self~parseNP(t, i)
    if subj == .nil then return .nil
    i = subj['NEXT']
  end
  else if p['ACT'] \== 'ask' then do
    if p['ACT'] == 'narrate' then return .nil
    p['ACT'] = 'order'
    subj = self~parseNP(self~tokens('you'), 1)
  end
  /* aux / modal / aspect / not */
  do forever
    if i > n then leave
    c = lex~find(t, i, 'aux modal aspect neg')
    /* I also heard: an adverb between subject and verb */
    if c == .nil then do
      c = lex~find(t, i, 'adv')
      if c == .nil then leave
      if c['E']['FEATS']~hasIndex('dir') then leave
      if lex~find(t, i + c['LEN'], 'verb aux neg') == .nil then leave
      i = i + c['LEN']
      iterate
    end
    /* "do" is also a verb: an aux only if a verb or subject follows */
    if c['E']['POS'] == 'aux' then do
      if lex~find(t, i + c['LEN'], 'verb neg pron') == .nil then leave
    end
    select
      when c['E']['POS'] == 'modal' then p['MODAL'] = c['E']['CONCEPT']
      when c['E']['POS'] == 'aspect' then p['ASPECT'] = c['E']['CONCEPT']
      when c['E']['POS'] == 'neg' then p['POL'] = '-'
      otherwise nop
    end
    i = i + c['LEN']
  end
  /* Pip and Barnaby ran: one group as subject */
  if subj \== .nil then if i <= n then if t[i] == 'and' then do
    s2 = self~parseNP(t, i + 1)
    if s2 \== .nil then if lex~find(t, s2['NEXT'], 'verb aux modal') \== .nil then do
      g = .Directory~new
      g['KIND'] = 'group'
      g['REFS'] = .array~of(subj, s2)
      g['NEXT'] = s2['NEXT']
      subj = g
      i = s2['NEXT']
    end
  end
  /* why do YOU push: the subject comes after the aux */
  if subj == .nil then do
    subj = self~parseNP(t, i)
    if subj == .nil then return .nil
    i = subj['NEXT']
  end
  /* we all, they all */
  if i <= n then do
    c = lex~find(t, i, 'det')
    if c \== .nil then if c['E']['FEATS']['kind'] == 'all' then if lex~find(t, i + c['LEN'], 'verb aux modal neg') \== .nil then i = i + c['LEN']
  end
  p['SUBJ'] = subj
  return self~parseVerbPhrase(t, i, n, p)

/* verb [particle] [object] [particle] [verb] [PP...] , or copula forms */
::method parseVerbPhrase
  expose lex cs
  use arg t, i, n, p
  roles = p['ROLES']
  v = lex~find(t, i, 'verb')
  if v == .nil then return .nil
  p['EVENT'] = v['E']['CONCEPT']
  p['FORM'] = v['E']['FEATS']['form']
  i = i + v['LEN']
  subj = .nil
  if p~hasIndex('SUBJ') then subj = p['SUBJ']
  if v['E']['FEATS']~hasIndex('cop') then return self~parseCopula(t, i, n, p, subj)
  if subj \== .nil then roles['agent'] = subj
  ph = .nil
  i = self~particle(t, i, n, p)
  i = self~particle(t, i, n, p)
  /* heard that S / told the police that S / told me S */
  if self~complement(t, i, n, p, v['E']['FEATS']) then return p
  obj = .nil
  if i <= n then if lex~find(t, i, 'prep') == .nil then obj = self~parseNP(t, i)
  if obj == .nil then if i <= n then do
    /* a word that is both preposition and particle with an NP after it is a PP */
    obj = .nil
  end
  if obj \== .nil then do
    roles['patient'] = obj
    i = obj['NEXT']
    if self~complement(t, i, n, p, v['E']['FEATS']) then do
      /* told the police that S: the object is who was told */
      roles['recipient'] = roles['patient']
      roles~remove('patient')
      return p
    end
  end
  i = self~particle(t, i, n, p)
  /* looked left / looked right */
  if i = n then do
    c = lex~find(t, i, 'adv')
    if c \== .nil then if c['E']['FEATS']~hasIndex('dir') then do
      roles['dir'] = c['E']['CONCEPT']
      i = i + 1
    end
  end
  /* serial verb (come eat), or an event as object (watched Pip hide it) */
  if i <= n then do
    v2 = lex~find(t, i, 'verb')
    /* can prove I was at the supermarket: the rest is the inner copula's */
    if v2 \== .nil then if obj \== .nil then if v2['E']['FEATS']~hasIndex('cop') then do
      inner = self~newProp('content')
      inner['EVENT'] = v2['E']['CONCEPT']
      inner['FORM'] = v2['E']['FEATS']['form']
      inner = self~parseCopula(t, i + v2['LEN'], n, inner, obj)
      roles['content'] = inner
      roles~remove('patient')
      if inner['NOTE'] \== '' then p['NOTE'] = inner['NOTE']
      return p
    end
    if v2 \== .nil then do
      inner = self~newProp('content')
      inner['EVENT'] = v2['E']['CONCEPT']
      i = i + v2['LEN']
      if obj == .nil then roles['purpose'] = inner
      else do
        inner['ROLES']['agent'] = obj
        o2 = self~parseNP(t, i)
        if o2 \== .nil then do
          inner['ROLES']['patient'] = o2
          i = o2['NEXT']
        end
        roles['content'] = inner
      end
    end
  end
  /* adjective result: keep the yard clean (but "outside the bank" is a PP) */
  if i <= n then if self~parsePP(t, i) == .nil then do
    a = lex~find(t, i, 'adj')
    if a \== .nil then do
      roles['result'] = a['E']['CONCEPT']
      i = i + a['LEN']
    end
  end
  /* prepositional phrases */
  do forever
    if i > n then leave
    /* a preposition with an object beats an adverb reading of the same word */
    j = self~tailItem(t, i, n, p, 'to')
    if j > i then do
      i = j
      iterate
    end
    c = lex~find(t, i, 'inf')
    if c \== .nil then do
      v3 = lex~find(t, i + 1, 'verb')
      if v3 \== .nil then do
        inner = self~newProp('content')
        inner['EVENT'] = v3['E']['CONCEPT']
        inner['INF'] = 1
        i = i + 1 + v3['LEN']
        o3 = self~parseNP(t, i)
        if o3 \== .nil then do
          inner['ROLES']['patient'] = o3
          i = o3['NEXT']
        end
        roles['purpose'] = inner
        iterate
      end
    end
    pp = self~parsePP(t, i)
    if pp == .nil then leave
    i = pp['NEXT']
    ph = lex~phrasalFor(p['EVENT'], pp['WORD'])
    if ph \== .nil then do
      p['EVENT'] = ph['CONCEPT']
      if ph['FEATS']['pp'] == 'patient' then do
        roles['patient'] = pp['NP']
        iterate
      end
    end
    role = pp['ROLE']
    if roles~hasIndex(role) then role = role||'2'
    roles[role] = pp
  end
  if i <= n then do
    p['NOTE'] = 'unread words:' self~join(t, i, n)
  end
  return p

/* a reported clause after a verb of saying or hearing: "that" then a
   whole clause, or (for a reporting verb) a clause with no "that". The
   clause is a content prop, never a fact; who it is a claim by is decided
   by whoever weighs it. True if the rest of the sentence was taken. */
::method complement
  expose lex
  use arg t, i, n, p, vf
  if i > n then return .false
  if \vf~hasIndex('report') then if vf['speech'] \== 'yes' then return .false
  j = i
  if t[i] == 'that' then j = i + 1
  else if \vf~hasIndex('report') then return .false
  if j > n then return .false
  sub = t~section(j, n - j + 1)~~append('.')
  inner = self~parseClause(sub, 'content')
  if inner == .nil then return .false
  if inner['NOTE'] \== '' then return .false
  if inner['EVENT'] == '' then return .false
  if inner~hasIndex('SUBJ') then if \inner['ROLES']~hasIndex('agent') then if \inner['ROLES']~hasIndex('holder') then inner['ROLES']['agent'] = inner['SUBJ']
  p['ROLES']['content'] = inner
  if vf~hasIndex('report') then p['REPORT'] = vf['report']
  return .true

/* a particle is a direction word not followed by an NP */
::method particle
  expose lex
  use arg t, i, n, p
  if i > n then return i
  c = lex~find(t, i, 'part')
  if c == .nil then return i
  word = c['E']['LABEL']
  ph = lex~phrasalFor(p['EVENT'], word)
  phParticle = .false
  if ph \== .nil then if \ph['FEATS']~hasIndex('pp') then phParticle = .true
  pr = lex~find(t, i, 'prep')
  if pr \== .nil then if \phParticle then do
    if self~parseNP(t, i + pr['LEN']) \== .nil then return i
  end
  if ph \== .nil then p['EVENT'] = ph['CONCEPT']
  else if c['E']['CONCEPT'] \== '' then do
    if p['ROLES']~hasIndex('dir') then p['ROLES']['dir'] = p['ROLES']['dir'] c['E']['CONCEPT']
    else p['ROLES']['dir'] = c['E']['CONCEPT']
  end
  return i + c['LEN']

::method parseCopula
  expose lex cs
  use arg t, i, n, p, subj
  roles = p['ROLES']
  roles['holder'] = subj
  do forever
    c = lex~find(t, i, 'neg')
    if c == .nil then leave
    p['POL'] = '-'
    i = i + c['LEN']
  end
  /* was to watch the back yard */
  c = lex~find(t, i, 'inf')
  if c \== .nil then do
    inner = self~newProp('content')
    inner = self~parseVerbPhrase(t, i + 1, n, inner)
    if inner \== .nil then roles['content'] = inner
    return p
  end
  /* that is acorn number one */
  np = self~parseNP(t, i)
  /* it was Molly the mouse: who the thing just seen is */
  if np \== .nil then if np['KIND'] == 'name' then do
    roles['ident'] = np
    if np['NEXT'] <= n then p['NOTE'] = 'unread words:' self~join(t, np['NEXT'], n)
    return p
  end
  if np \== .nil then if np['KIND'] == 'ord' then if np['CORE'] \== .nil then do
    roles['kind'] = np['CORE']['CONCEPT']
    p['ORDC'] = np['ORDC']
    p['ORDV'] = np['ORDV']
    if np['NEXT'] <= n then p['NOTE'] = 'unread words:' self~join(t, np['NEXT'], n)
    return p
  end
  /* was a big, floppy dog */
  isKind = .false
  if np \== .nil then if np['KIND'] == 'indef' then isKind = .true
  /* "they are lovely sticks": a bare plural is a kind too */
  if np \== .nil then if np['KIND'] == 'bare' then if np['CORE']['PLURAL'] then isKind = .true
  if isKind then do
    roles['kind'] = np['CORE']['CONCEPT']
    roles['attr'] = np['CORE']['ATTRS']
    if np['NEXT'] <= n then p['NOTE'] = 'unread words:' self~join(t, np['NEXT'], n)
    return p
  end
  /* was not scared of Barnaby / is fun */
  a = lex~find(t, i, 'adj')
  if a \== .nil then do
    roles['attr'] = a['E']['CONCEPT']
    i = i + a['LEN']
    do forever
      j = i
      do while j <= n
        if wordpos(t[j], ', and') = 0 then leave
        j = j + 1
      end
      if j = i then leave
      a2 = lex~find(t, j, 'adj')
      if a2 == .nil then leave
      roles['attr'] = roles['attr'] a2['E']['CONCEPT']
      i = j + a2['LEN']
    end
    pp = self~parsePP(t, i)
    if pp \== .nil then do
      roles[pp['ROLE']] = pp
      i = pp['NEXT']
    end
    /* every word must be accounted for, or the sentence is unread */
    if i <= n then p['NOTE'] = 'unread words:' self~join(t, i, n)
    return p
  end
  /* am in my tree / was with me at the bank / was there */
  i0 = i
  do forever
    if i > n then leave
    j = self~tailItem(t, i, n, p, 'at')
    if j > i then do
      i = j
      iterate
    end
    pp = self~parsePP(t, i)
    if pp == .nil then leave
    role = pp['ROLE']
    if roles~hasIndex(role) then role = role||'2'
    roles[role] = pp
    i = pp['NEXT']
  end
  if i > i0 then do
    if i <= n then p['NOTE'] = 'unread words:' self~join(t, i, n)
    return p
  end
  p['NOTE'] = 'unread copula:' self~join(t, i, n)
  return p

/* one item after the verb that is not a PP: an adverb ("alone", "together"
   mark who was in company), "there" (the place last named), or a time NP
   ("that afternoon"). Returns the next index, or i if nothing was taken. */
::method tailItem
  expose lex cs
  use arg t, i, n, p, placeRole
  roles = p['ROLES']
  c = lex~find(t, i, 'locpron')
  if c \== .nil then do
    d = .Directory~new
    d['ROLE'] = placeRole
    d['REL'] = c['E']['CONCEPT']
    d['WORD'] = c['E']['LABEL']
    there = .Directory~new
    there['KIND'] = 'there'
    there['NEXT'] = i + c['LEN']
    d['NP'] = there
    d['NEXT'] = i + c['LEN']
    if roles~hasIndex(placeRole) then roles[placeRole||'2'] = d
    else roles[placeRole] = d
    return i + c['LEN']
  end
  c = lex~find(t, i, 'adv')
  if c \== .nil then if self~parsePP(t, i) == .nil then do
    if c['E']['FEATS']~hasIndex('company') then p['COMPANY'] = c['E']['FEATS']['company']
    return i + c['LEN']
  end
  if lex~find(t, i, 'det') \== .nil then do
    np = self~parseNP(t, i)
    if np \== .nil then if np['KIND'] \== 'clock' then if cs~isa(self~refConcept(np), lex~clockConcept) then do
      if roles~hasIndex('time') then roles['time2'] = np
      else roles['time'] = np
      return np['NEXT']
    end
  end
  return i

::method join
  use arg t, a, b
  s = ''
  do k = a to b
    s = s t[k]
  end
  return s~strip

/* ------------------------------------------------------------------ */
/* narration and speech                                               */
/* ------------------------------------------------------------------ */
::method narrate
  expose unread lex lastSubj ents
  use arg toks
  keepPatient = self~lastPatient
  self~lastPatient = ''
  /* "closed his eyes and rested his paws": two clauses, one subject */
  firstV = 0
  do k = 1 to toks~items
    if firstV = 0 then if lex~find(toks, k, 'verb') \== .nil then firstV = k
    v2 = .nil
    if toks[k] == 'and' then if firstV > 0 then if k > firstV then v2 = lex~find(toks, k + 1, 'verb')
    /* bread and milk: "milk" can be a verb, but not one in the same tense as "wanted" */
    if v2 \== .nil then do
      v1 = lex~find(toks, firstV, 'verb')
      if v1['E']['FEATS']['form'] \== v2['E']['FEATS']['form'] then v2 = .nil
    end
    if v2 \== .nil then do
      a = toks~section(1, k - 1)~~append('.')
      b = toks~section(1, firstV - 1)
      do m = k + 1 to toks~items
        b~append(toks[m])
      end
      self~narrate(a)
      return self~narrate(b)
    end
  end
  self~lastPatient = keepPatient
  p = self~parseClause(toks, 'narrate')
  if p == .nil then do
    self~lastPatient = ''
    unread~append(self~join(toks, 1, toks~items))
    self~salvageNames(toks)
    return .nil
  end
  if p['NOTE'] \== '' then do
    unread~append(self~join(toks, 1, toks~items) '  ['p['NOTE']']')
    self~salvageNames(toks)
    return .nil
  end
  ctx = .Directory~new
  ctx['SPEAKER'] = ''
  ctx['ADDRESSEE'] = ''
  self~missRef = ''
  self~resolveProp(p, ctx)
  if self~missRef \== '' then do
    unread~append(self~join(toks, 1, toks~items) '  [no one for "'self~missRef'" to refer to]')
    self~salvageNames(toks)
    return .nil
  end
  /* the words as read, for people checking a premise; never reasoned on */
  if \p~hasIndex('TEXT') then p['TEXT'] = self~join(toks, 1, toks~items)
  if self~voiceTier == 'DOCUMENTARY' then do
    p['TIER'] = 'DOCUMENTARY'
    p['SECTION'] = self~scene
  end
  self~store(p)
  if p['ACT'] == 'narrate' then self~apply(p)
  lastSubj = ''
  /* "that" can only point at what the previous sentence handled */
  self~lastPatient = ''
  if p['ROLES']['patient']~isA(.String) then self~lastPatient = p['ROLES']['patient']
  if p['ROLES']~hasIndex('agent') then lastSubj = p['ROLES']['agent']
  if p['ROLES']~hasIndex('holder') then lastSubj = p['ROLES']['holder']
  /* the last two different people who were subjects, for "they" */
  if lastSubj~isA(.String) then do
    sp = self~speakerOf(lastSubj)
    if sp \== '' then if ents[sp]~members == '' then do
      h = self~subjHist
      k = wordpos(sp, h)
      if k > 0 then h = delword(h, k, 1)
      self~subjHist = subword((h sp)~strip, max(1, words((h sp)~strip) - 1))
    end
  end
  return p

/* one sentence of a witness's statement: parsed like speech, stored as the
   witness's claim (testimony tier), with the witness as I and the party as we */
::method testify
  expose unread lex
  use arg toks
  blocked = self~pronBlock
  self~pronBlock = .false
  p = self~parseClause(toks, 'tell')
  if p == .nil then do
    unread~append(self~join(toks, 1, toks~items) '  [testimony of' self~nameOfEnt(self~voice)']')
    self~salvageNames(toks)
    self~pronBlock = .true
    return
  end
  if p['NOTE'] \== '' then do
    unread~append(self~join(toks, 1, toks~items) '  ['p['NOTE']'; testimony of' self~nameOfEnt(self~voice)']')
    self~salvageNames(toks)
    self~pronBlock = .true
    return
  end
  /* "I do not understand how Liam could ... He was standing next to me":
     the person "he" means may be in the sentence that was not read */
  if blocked then do k = 1 to toks~items
    c = lex~find(toks, k, 'pron')
    if c == .nil then iterate
    f = c['E']['FEATS']
    if f['ref'] \== 'third' then iterate
    if f~hasIndex('gender') then do
      unread~append(self~join(toks, 1, toks~items) '  ["'toks[k]'" may mean someone in the unread sentence before; testimony of' self~nameOfEnt(self~voice)']')
      self~pronBlock = .true
      return
    end
  end
  ctx = .Directory~new
  ctx['SPEAKER'] = self~voice
  ctx['ADDRESSEE'] = ''
  self~missRef = ''
  self~resolveProp(p, ctx)
  if self~missRef \== '' then do
    unread~append(self~join(toks, 1, toks~items) '  [no one for "'self~missRef'" to refer to; testimony of' self~nameOfEnt(self~voice)']')
    return
  end
  if p['ACT'] == 'tell' then p['ACT'] = 'testify'
  p['TEXT'] = self~join(toks, 1, toks~items)
  p['SPEAKER'] = self~voice
  p['ADDRESSEE'] = ''
  p['SVERB'] = ''
  p['SOURCE'] = ''
  p['TIER'] = 'TESTIMONY'
  p['SECTION'] = self~scene
  self~store(p)
  self~joinParty(p)
  self~notePlace(p)

/* "there" means the last place a sentence put someone at or to */
::method notePlace
  expose ents lex cs
  use arg p
  do r over .array~of('to', 'at', 'from')
    v = p['ROLES'][r]
    if v == .nil then iterate
    if \v~isA(.String) then iterate
    parse var v . '@' eid
    if eid == '' then eid = v
    if \ents~hasIndex(eid) then iterate
    if cs~isa(ents[eid]~concept, lex~clockConcept) then iterate
    self~lastPlace = eid
    return
  end

/* people who go "with" the witness, or come "with us", join the party "we" means */
::method joinParty
  expose ents
  use arg p
  roles = p['ROLES']
  c = roles['company']
  if \c~isA(.String) then return
  parse var c . '@' cid
  if cid == '' then cid = c
  if \ents~hasIndex(cid) then return
  inParty = .false
  do m over self~membersOf(cid)
    if wordpos(m, self~party) > 0 then inParty = .true
  end
  a = roles['agent']
  if a == .nil then a = roles['holder']
  if \a~isA(.String) then return
  if inParty | wordpos(a, self~party) > 0 then do
    do m over (self~membersOf(cid) self~membersOf(a))~subWords
      if wordpos(m, self~party) = 0 then self~party = (self~party m)~strip
    end
  end

::method membersOf
  expose ents
  use arg id
  if \ents~hasIndex(id) then return ''
  if ents[id]~members \== '' then return ents[id]~members
  return id

::method namesIn
  use arg toks
  do k = 1 to toks~items
    if self~isName(toks[k]) then return .true
  end
  return .false

/* "the shop" when only a supermarket has been named: a definite building with
   no match is taken as the latest building of a sibling kind (same parent),
   and the reader says so as a SAME? finding. Only buildings: the dirt and the
   lawn are different ground, but a shop and a supermarket are one place. */
::method bridge
  expose ents cs lex findings
  use arg core
  pc = lex~buildingConcept
  if pc == '' then return .nil
  c = core['CONCEPT']
  if \cs~isa(c, pc) then return .nil
  par = cs~parent(c)
  if par == '' | par == pc then return .nil
  do id over self~recent
    e = ents[id]
    if e~concept == c then iterate
    if \cs~isa(e~concept, par) then iterate
    if e~plural \== core['PLURAL'] then if (e~plural == 1) \= (core['PLURAL'] == 1) then iterate
    f = .Directory~new
    f['TYPE'] = 'BRIDGE'
    f['A'] = id
    f['CONCEPT'] = c
    findings~append(f)
    return id
  end
  return .nil

/* "It was Molly the mouse": the thing just seen is Molly, or a part of her.
   A part (its concept has a whole) gets Molly as its whole; Molly takes the
   place the thing was seen at, with the same inference trail if it had one. */
::method identify
  expose ents cs
  use arg h, n, p
  if \ents~hasIndex(h) then return
  if \ents~hasIndex(n) then return
  if h == n then return
  eh = ents[h]
  en = ents[n]
  if cs~wholeOfKind(eh~concept) \== '' then if eh~partOf == '' then eh~partOf = n
  if eh~loc \== '' then if en~loc == '' then do
    en~loc = eh~loc
    en~locHist = (en~locHist eh~loc)~strip
    en~locInfer = (eh~locInfer p['ID'])~strip
    if eh~locInfer == '' then en~locInfer = ''
  end

/* two values of one slot (red and blue; northeast and northwest) */
::method slotClash
  expose cs lex
  use arg had, new
  slots = lex~slotConcepts
  do a over new~subWords
    pa = cs~parent(a)
    if wordpos(pa, slots) = 0 then iterate
    do b over had~subWords
      if b \== a then if cs~parent(b) == pa then return .true
    end
  end
  return .false

::method properClash
  expose lex capSeen
  use arg had, new
  ph = ''
  do a over had~subWords
    if a~left(2) == 'N:' then ph = ph a
    else do
      w = lex~label('A/'a)
      if w \== '' then if capSeen~hasIndex(w) then ph = ph a
    end
  end
  if ph == '' then return .false
  do a over new~subWords
    if a~left(2) \== 'N:' then do
      w = lex~label('A/'a)
      if w == '' then iterate
      if \capSeen~hasIndex(w) then iterate
    end
    if wordpos(a, ph) = 0 then return .true
  end
  return .false

/* gender learnt from a pronoun, else from the concept (a girlfriend is female) */
::method genderOf
  expose ents cs lex
  use arg id
  if ents[id]~gender \== '' then return ents[id]~gender
  do g over lex~genderClass~allIndexes
    if cs~isa(ents[id]~concept, lex~genderClass[g]) then return g
  end
  return ''

::method nameOfEnt
  expose ents
  use arg id
  if ents~hasIndex(id) then return ents[id]~name
  return '?'

/* a quoted phrase with no verb: "No thief," "Footprints!" "Maybe a very small
   elephant?" kept as what the speaker named, with no and not as negation and
   maybe as a guess */
::method fragment
  expose lex
  use arg toks
  n = toks~items
  do while n > 0
    if wordpos(toks[n], '. ! ? ,') = 0 then leave
    n = n - 1
  end
  if n = 0 then return .nil
  p = self~newProp('fragment')
  i = 1
  do while i <= n
    c = lex~find(toks, i, 'adv neg intens conj')
    if c == .nil then leave
    if c['E']['POS'] == 'neg' then p['POL'] = '-'
    if c['E']['FEATS']~hasIndex('hypo') then p['HYPO'] = 1
    i = i + c['LEN']
  end
  np = self~parseNP(toks, i)
  if np == .nil then return .nil
  if np['NEXT'] <= n then return .nil
  if np['KIND'] == 'name' then return .nil
  if np['KIND'] == 'no' then do
    p['POL'] = '-'
    p['NODET'] = 1
  end
  p['ROLES']['content'] = np
  return p

/* an unread sentence still tells us who is in the scene: its names are
   mentioned, and a name before the first verb becomes the subject */
::method salvageNames
  expose lex lastSubj
  use arg toks
  seenVerb = .false
  first = ''
  do k = 1 to toks~items
    if lex~find(toks, k, 'verb') \== .nil then seenVerb = .true
    if \self~isName(toks[k]) then iterate
    if k > 1 then if self~isName(toks[k - 1]) then iterate
    id = self~nameEntity(toks[k])
    self~mention(id)
    self~ents[id]~stale = 1
    if \seenVerb then if first == '' then first = id
  end
  if first \== '' then lastSubj = first

/* who a subject stands for as a speaker: itself if alive, else its owner */
::method speakerOf
  expose ents cs lex
  use arg id
  if \ents~hasIndex(id) then return ''
  if cs~isa(ents[id]~concept, lex~nameConcept) then return id
  o = ents[id]~owner
  if o \== '' then if ents~hasIndex(o) then if cs~isa(ents[o]~concept, lex~nameConcept) then return o
  return ''

::method speech
  expose lastSpeaker unread ents
  use arg text, speaker, sverb, source
  self~lastAsk = ''
  sents = self~sentences(text)
  /* vocatives: a sentence that is only a name, or ", Name" at the end */
  addressee = ''
  do toks over sents
    n = toks~items
    if n = 2 then if self~isName(toks[1]) then addressee = self~nameEntity(toks[1])
    if n >= 4 then if toks[n - 2] == ',' then if self~isName(toks[n - 1]) then addressee = self~nameEntity(toks[n - 1])
  end
  voc = addressee \== ''
  if addressee == '' then if lastSpeaker \== '' then if lastSpeaker \== speaker then addressee = lastSpeaker
  if addressee == '' then addressee = self~recentOther(speaker)
  /* a guessed addressee who is named in the quote, not as a vocative, is not the addressee */
  if \voc then if addressee \== '' then do toks over sents
    n = toks~items
    do k = 1 to n
      if \self~isName(toks[k]) then iterate
      if self~nameEntity(toks[k]) \== addressee then iterate
      isVoc = .false
      if n = 2 then isVoc = .true
      if k = n - 1 then if k > 1 then if toks[k - 1] == ',' then isVoc = .true
      if \isVoc then addressee = ''
    end
  end
  ctx = .Directory~new
  ctx['SPEAKER'] = speaker
  ctx['ADDRESSEE'] = addressee
  do toks over sents
    n = toks~items
    /* strip a trailing vocative */
    if n >= 3 then if self~isName(toks[n - 1]) then if toks[n - 2] == ',' then do
      toks = toks~section(1, n - 3)~~append(toks[n])
    end
    if toks~items = 2 then if self~isName(toks[1]) then iterate
    q = toks[toks~items] == '?'
    p = self~parseClause(toks, 'tell')
    if p == .nil then p = self~fragment(toks)
    if p == .nil then do
      unread~append('"'self~join(toks, 1, toks~items)'"')
      iterate
    end
    if p['NOTE'] \== '' then do
      unread~append('"'self~join(toks, 1, toks~items)'"  ['p['NOTE']']')
      iterate
    end
    if q then if p['ACT'] \== 'fragment' then p['ACT'] = 'ask'
    p['Q'] = q
    self~missRef = ''
    p['EMPH'] = toks[toks~items] == '!'
    p['VOC'] = voc
    self~resolveProp(p, ctx)
    if self~missRef \== '' then do
      unread~append('"'self~join(toks, 1, toks~items)'"  [no one for "'self~missRef'" to refer to]')
      iterate
    end
    p['SPEAKER'] = speaker
    p['ADDRESSEE'] = addressee
    p['SVERB'] = sverb
    p['SOURCE'] = source
    self~store(p)
    self~checkSpeech(p)
    /* "Maybe a small elephant?" "Not a dog": a guess or a denial, never a fact */
    if p['ACT'] == 'fragment' then do
      cid = p['ROLES']['content']
      if ents~hasIndex(cid) then do
        if p['HYPO'] == 1 then ents[cid]~status = 'guessed'
        else if p['POL'] == '-' then ents[cid]~status = 'denied'
      end
    end
    asked = ''
    if p['ACT'] == 'ask' then asked = addressee
    self~lastAsk = asked
  end

/* ------------------------------------------------------------------ */
/* reference                                                          */
/* ------------------------------------------------------------------ */
::method newEntity
  expose ents nextE
  use arg concept
  nextE = nextE + 1
  e = .Entity~new('E'||nextE~right(2, '0'), concept)
  ents[e~id] = e
  return e

::method mention
  expose mentions ents scene
  use arg id
  if id == '' then return
  mentions~append(id)
  if ents~hasIndex(id) then if wordpos(scene, ents[id]~scenes) = 0 then ents[id]~scenes = (ents[id]~scenes scene)~strip

::method nameEntity
  expose byName lex
  use arg label
  if byName~hasIndex(label) then return byName[label]
  e = self~newEntity(lex~nameConcept)
  e~name = label
  byName[label] = e~id
  return e~id

/* recent entities, newest first, each once */
::method recent
  expose mentions
  seen = .StringTable~new
  out = .Array~new
  do k = mentions~items to 1 by -1
    id = mentions[k]
    if seen~hasIndex(id) then iterate
    seen[id] = 1
    out~append(id)
  end
  return out

/* a group entity for several members (we, Pip and Barnaby) */
::method groupOf
  expose ents lex
  use arg list
  list = list~space
  do id over ents~allIndexes
    if ents[id]~members == list then return id
  end
  e = self~newEntity(lex~nameConcept)
  e~plural = .true
  e~members = list
  e~intro = 'group'
  return e~id

::method recentOther
  expose ents lex cs
  use arg not
  do id over self~recent
    if id == not then iterate
    if cs~isa(ents[id]~concept, lex~nameConcept) then return id
  end
  return ''

::method attrsMatch
  use arg e, attrs
  do a over attrs~subWords
    if wordpos(a, e~attrs) = 0 then return .false
  end
  return .true

/* find the most recent entity of a concept (and attrs); else any; else .nil */
::method findOf
  expose ents cs
  use arg concept, attrs, owner, plural
  /* "the oak tree" is not "the trees": a singular never means a plural thing */
  num = arg(4, 'E')
  do id over self~recent
    e = ents[id]
    if e~concept \== concept then iterate
    if \self~attrsMatch(e, attrs) then iterate
    if num then if (e~plural == 1) \= (plural == 1) then iterate
    if owner \== '' then if e~owner \== owner then if e~partOf \== owner then iterate
    return id
  end
  do id over self~recent
    e = ents[id]
    if \cs~isa(e~concept, concept) then iterate
    if \self~attrsMatch(e, attrs) then iterate
    if num then if (e~plural == 1) \= (plural == 1) then iterate
    if owner \== '' then if e~owner \== owner then if e~partOf \== owner then iterate
    return id
  end
  do id over ents~allIndexes~sortWith(.CaselessComparator~new)
    e = ents[id]
    if \cs~isa(e~concept, concept) then iterate
    if \self~attrsMatch(e, attrs) then iterate
    if num then if (e~plural == 1) \= (plural == 1) then iterate
    if owner \== '' then if e~owner \== owner then do
      if ents[owner]~home \== '' then if self~placeEntity(ents[owner]~home) == id then return id
      iterate
    end
    return id
  end
  return .nil

::method addAttrs
  use arg e, attrs
  do a over attrs~subWords
    if wordpos(a, e~attrs) = 0 then e~attrs = (e~attrs a)~strip
  end

::method makeOf
  expose cs
  use arg core
  e = self~newEntity(core['CONCEPT'])
  e~attrs = core['ATTRS']
  e~introAttrs = core['ATTRS']
  e~plural = core['PLURAL']
  whole = cs~wholeOf(core['CONCEPT'])
  /* a branch joins the latest tree; a nose is never guessed onto an animal */
  if whole \== '' then if cs~isa(whole, self~lex~nameConcept) then whole = ''
  if whole \== '' then do
    w = self~findOf(whole, '', '')
    if w == .nil then if wordpos(whole, core['ATTRS']) > 0 then do
      we = self~newEntity(whole)
      w = we~id
    end
    if w \== .nil then e~partOf = w
  end
  return e

/* resolve a parsed ref to an entity id (or a value). event/role give
   the preconditions a pronoun must meet. */
::method resolveRef
  expose ents cs lex findings
  use arg ref, ctx, role, p
  if ref == .nil then return ''
  if \ref~isA(.Directory) then return ref
  kind = ref['KIND']
  select
    when kind == 'name' then do
      id = self~nameEntity(ref['LABEL'])
      if ref~hasIndex('APPOS') then if cs~isa(ref['APPOS'], ents[id]~concept) then ents[id]~concept = ref['APPOS']
      self~mention(id)
      return id
    end
    when kind == 'pron' then do
      f = ref['FEATS']
      who = f['ref']
      /* I / you with nobody known to be speaking: unread, never a blank subject */
      if who == 'speaker' | who == 'addressee' then do
        v = ''
        if ctx \== .nil then do
          if who == 'speaker' then v = ctx['SPEAKER']
          else v = ctx['ADDRESSEE']
        end
        if v == .nil then v = ''
        if v == '' then self~missRef = ref['LABEL']
        return v
      end
      /* nobody / everyone: no single referent; the reader does not invent one */
      if who == 'none' then do
        self~missRef = ref['LABEL']
        return ''
      end
      if who == 'new' then do
        e = self~newEntity(f['need'])
        e~intro = 'someone'
        if \cs~isa(f['need'], lex~nameConcept) then e~intro = 'something'
        self~mention(e~id)
        return e~id
      end
      if who == 'we' then do
        sp = ''
        if ctx \== .nil then sp = ctx['SPEAKER']
        if sp == .nil then sp = ''
        if sp == '' then do
          self~missRef = ref['LABEL']
          return ''
        end
        ad = ctx['ADDRESSEE']
        if ad == .nil then ad = ''
        if ad == '' then if self~party \== '' then do
          if words(self~party) = 1 then return self~party
          return self~groupOf(self~party)
        end
        return self~groupOf(sp ad)
      end
      id = self~pronoun(ref, role, p)
      if id == '' then self~missRef = ref['LABEL']
      else if f~hasIndex('gender') then if ents[id]~gender == '' then ents[id]~gender = f['gender']
      self~mention(id)
      return id
    end
    when kind == 'clock' then return 'CLOCK:'ref['MIN']
    when kind == 'there' then do
      if self~lastPlace == '' then do
        self~missRef = 'there'
        return ''
      end
      return self~lastPlace
    end
    when kind == 'allof' then do
      id = self~resolveRef(ref['INNER'], ctx, role, p)
      if ref['COUNT'] \== '' then if ents~hasIndex(id) then if words(self~membersOf(id)) \= ref['COUNT'] then do
        fd = .Directory~new
        fd['TYPE'] = 'COUNT'
        fd['WHAT'] = 'all'
        fd['CLAIMED'] = ref['COUNT']
        fd['ACTUAL'] = words(self~membersOf(id))
        fd['CONCEPT'] = lex~nameConcept
        fd['TRUE'] = .false
        fd['PROP'] = p
        findings~append(fd)
      end
      return id
    end
    when kind == 'poss' then if ref~hasIndex('APPNAME') then do
      /* my brother, Noah */
      owner = self~resolveRef(ref['OWNER'], ctx, 'owner', p)
      id = self~nameEntity(ref['APPNAME'])
      e = ents[id]
      if cs~isa(ref['CORE']['CONCEPT'], e~concept) then e~concept = ref['CORE']['CONCEPT']
      e~relation = ref['CORE']['CONCEPT']
      e~relOf = owner
      self~mention(id)
      return id
    end
    else do
      owner = self~resolveRef(ref['OWNER'], ctx, 'owner', p)
      core = ref['CORE']
      id = self~findOf(core['CONCEPT'], core['ATTRS'], owner)
      if id == .nil then do
        id = self~findOf(core['CONCEPT'], '', owner)
        if id \== .nil then self~addAttrs(ents[id], core['ATTRS'])
      end
      if id == .nil then do
        id = self~findOf(core['CONCEPT'], core['ATTRS'], '')
        /* Pip's head is not Molly's head: a part already belongs to its whole */
        if id \== .nil then if ents[id]~owner \== '' | ents[id]~partOf \== '' then id = .nil
      end
      if id == .nil then do
        e = self~makeOf(core)
        e~intro = 'poss'
        if ref['DET'] == 'indef' then e~intro = 'indef'
        whole = cs~wholeOf(core['CONCEPT'])
        isPart = .false
        if whole \== '' then if ents~hasIndex(owner) then if cs~isa(ents[owner]~concept, whole) then isPart = .true
        if isPart then e~partOf = owner
        else e~owner = owner
        id = e~id
      end
      else if ents[id]~owner == '' then ents[id]~owner = owner
      self~mention(id)
      return id
    end
    when kind == 'def' then do
      core = ref['CORE']
      id = self~findOf(core['CONCEPT'], core['ATTRS'], '', core['PLURAL'])
      if id == .nil then do
        id = self~findOf(core['CONCEPT'], '', '', core['PLURAL'])
        /* "the Russian guns" are not "the British guns" (proper adjectives
           pick a thing out), and "the northwest pylon" is not "the northeast
           pylon" (two values of one slot). "The soft leaf" after "a green
           leaf" is the same leaf: new words of another slot add to it. */
        if id \== .nil then if self~properClash(ents[id]~attrs, core['ATTRS']) then id = .nil
        if id \== .nil then if self~slotClash(ents[id]~attrs, core['ATTRS']) then id = .nil
        if id \== .nil then self~addAttrs(ents[id], core['ATTRS'])
      end
      if id == .nil then id = self~bridge(core)
      if id == .nil then id = self~makeOf(core)~id
      self~mention(id)
      return id
    end
    when kind == 'indef' then do
      core = ref['CORE']
      /* "Six acorns remained": a count to check, not six new acorns */
      if ref['COUNT'] \== '' then if p \== .nil then do
        r = self~ruleFor(p['EVENT'])
        if r \== .nil then if r~pre == 'remains-if' then return 'COUNT:'core['CONCEPT']':'ref['COUNTC']':'ref['COUNT']
      end
      e = self~makeOf(core)
      e~intro = 'indef'
      if ref~hasIndex('AMOUNT') then e~amount = ref['AMOUNT']
      if ref['OTHER'] == 1 then e~intro = 'other'
      else self~maybeSame(e, p)
      self~mention(e~id)
      return e~id
    end
    when kind == 'every' then return 'EVERY:'||ref['CORE']['CONCEPT']
    when kind == 'ord' then return self~resolveOrdinal(ref)
    when kind == 'all' then return self~resolveAll(ref, p)
    when kind == 'partof' then do
      id = self~resolvePartOf(ref, p)
      if id == '' then self~missRef = 'one of them'
      else self~mention(id)
      return id
    end
    when kind == 'no' then do
      if ref['CORE']['PLURAL'] then return 'KINDS:'||ref['CORE']['CONCEPT']
      return 'KIND:'||ref['CORE']['CONCEPT']
    end
    when kind == 'group' then do
      ids = ''
      do r over ref['REFS']
        ids = ids self~resolveRef(r, ctx, role, p)
      end
      g = self~groupOf(ids)
      self~mention(g)
      return g
    end
    when kind == 'deixis' then return ref['CONCEPT']
    when kind == 'bare' then do
      core = ref['CORE']
      episodic = .false
      if p \== .nil then if p['FORM'] == 'past' then episodic = .true
      /* dogs have very good noses: the kind keeps its adjectives */
      if core['PLURAL'] then if \episodic then do
        if core['ATTRS'] \== '' then return 'KINDS:'||core['CONCEPT']||'/'||core['ATTRS']~space(1, '+')
        return 'KINDS:'||core['CONCEPT']
      end
      if core['PLURAL'] then do
        e = self~makeOf(core)
        e~intro = 'bare'
        self~mention(e~id)
        return e~id
      end
      id = self~findOf(core['CONCEPT'], core['ATTRS'], '')
      if id == .nil then do
        e = self~makeOf(core)
        e~intro = 'bare'
        id = e~id
      end
      self~mention(id)
      return id
    end
    when kind == 'gerund' then do
      inner = self~newProp('content')
      inner['EVENT'] = ref['EVENT']
      if ref['PATIENT'] \== .nil then inner['ROLES']['patient'] = ref['PATIENT']
      self~resolveProp(inner, ctx)
      self~store(inner)
      return inner['ID']
    end
    otherwise return ''
  end

/* the sixth acorn: the acorn carrying that number, or else the latest
   unnumbered acorn, which takes the number */
::method resolveOrdinal
  expose ents cs lastOrdConcept
  use arg ref
  cid = ''
  if ref['CORE'] \== .nil then cid = ref['CORE']['CONCEPT']
  if cid == '' then cid = lastOrdConcept
  if cid == '' then return ''
  if ref['ORDV'] == 'last' then do
    best = ''
    bv = -1
    do id over ents~allIndexes
      e = ents[id]
      if \cs~isa(e~concept, cid) then iterate
      if datatype(e~ordval, 'W') then if e~ordval > bv then do
        bv = e~ordval
        best = id
      end
    end
    if best \== '' then self~mention(best)
    return best
  end
  do id over ents~allIndexes
    e = ents[id]
    if e~ordinal == ref['ORDC'] then if cs~isa(e~concept, cid) then do
      self~mention(id)
      return id
    end
  end
  do id over self~recent
    e = ents[id]
    if \cs~isa(e~concept, cid) then iterate
    if e~ordinal \== '' | e~members \== '' | e~plural | e~status \== '' then iterate
    e~ordinal = ref['ORDC']
    e~ordval = ref['ORDV']
    lastOrdConcept = cid
    self~mention(id)
    return id
  end
  return ''

/* singular, real things of a kind, in the world now */
::method countable
  expose ents cs
  use arg cid
  out = .Array~new
  do id over ents~allIndexes~sortWith(.CaselessComparator~new)
    e = ents[id]
    if \cs~isa(e~concept, cid) then iterate
    if e~plural | e~members \== '' | e~status \== '' then iterate
    out~append(id)
  end
  return out

/* does a thing still remain (by the rules' remains-if condition)? */
::method remains
  expose remainsCond
  use arg id, p
  if remainsCond == '' then return .true
  return self~preState(id, 'x.'remainsCond, p) \== 'fail'

::method countFinding
  expose findings
  use arg kind, claimed, actual, p, cid
  fd = .Directory~new
  fd['TYPE'] = 'COUNT'
  fd['WHAT'] = kind
  fd['CLAIMED'] = claimed
  fd['ACTUAL'] = actual
  fd['CONCEPT'] = cid
  fd['TRUE'] = claimed = actual
  fd['PROP'] = p
  findings~append(fd)

/* all twelve acorns: every one there is, checked against the number given */
::method resolveAll
  use arg ref, p
  cid = ref['CORE']['CONCEPT']
  list = self~countable(cid)
  if ref['COUNT'] \== '' then self~countFinding('all', ref['COUNT'], list~items, p, cid)
  ids = ''
  do id over list
    ids = ids id
  end
  if ids == '' then return ''
  g = self~groupOf(ids)
  ents = self~ents
  ents[g]~intro = 'all'
  ents[g]~amount = ref['COUNTC']
  self~mention(g)
  return g

/* one of the seven remaining acorns: checks the seven, picks one if any */
::method resolvePartOf
  use arg ref, p
  inner = ref['INNER']
  if inner['CORE'] == .nil then return ''
  cid = inner['CORE']['CONCEPT']
  list = self~countable(cid)
  if inner['CORE']['REMAINING'] = 1 then do
    keep = .Array~new
    do id over list
      if self~remains(id, p) then keep~append(id)
    end
    list = keep
  end
  if inner['COUNT'] \== '' then do
    what = 'all'
    if inner['CORE']['REMAINING'] = 1 then what = 'remaining'
    self~countFinding(what, inner['COUNT'], list~items, p, cid)
  end
  if list~items = 0 then return ''
  return list[list~items]

/* a new indefinite thing that may be one we already know */
::method maybeSame
  expose ents cs findings
  use arg e, p
  do id over self~recent
    o = ents[id]
    if o~id == e~id then iterate
    if o~concept \== e~concept then iterate
    if o~plural \== e~plural then iterate
    if e~attrs == '' then iterate
    if \self~attrsMatch(o, e~attrs) then iterate
    f = .Directory~new
    f['TYPE'] = 'MAYBE-SAME'
    f['A'] = e~id
    f['B'] = o~id
    findings~append(f)
    return
  end

/* pronoun: agreement, recency, then the event's precondition decides */
::method pronoun
  expose ents cs findings lastSubj
  use arg ref, role, p
  f = ref['FEATS']
  need = ''
  avoid = ''
  if f~hasIndex('need') then need = f['need']
  if f~hasIndex('avoid') then avoid = f['avoid']
  agree = .Array~new
  later = .Array~new
  others = .Array~new
  gen = ''
  if f~hasIndex('gender') then gen = f['gender']
  num = ''
  if f~hasIndex('num') then num = f['num']
  /* "it is a clever elephant": it must be something that can be an elephant */
  kind = ''
  if role == 'holder' then if p \== .nil then if p['ROLES']['kind']~isA(.String) then kind = p['ROLES']['kind']
  do id over self~recent
    c = ents[id]~concept
    if gen \== '' then do
      eg = self~genderOf(id)
      if eg \== '' then if eg \== gen then iterate
    end
    if num == 'pl' then if \ents[id]~plural then iterate
    if num == 'sg' then if ents[id]~plural then iterate
    if kind \== '' then if \cs~isa(kind, c) then if \cs~isa(c, kind) then iterate
    if need \== '' then if \cs~isa(c, need) then do
      others~append(id)
      iterate
    end
    if avoid == 'named' then if ents[id]~name \== '' then do
      later~append(id)
      iterate
    end
    agree~append(id)
  end
  if avoid \== 'named' then do id over later
    agree~append(id)
  end
  if agree~items = 0 then return ''
  /* "they" as a narrated subject: the last two different people who were subjects */
  if num == 'pl' then if wordpos(role, 'agent holder') > 0 then if p \== .nil then if p['ACT'] == 'narrate' then do
    hist = self~subjHist~subWords
    if hist~items >= 2 then do
      g = self~groupOf(hist[hist~items - 1] hist[hist~items])
      return g
    end
  end
  /* "That is acorn number two": that points at what was just handled */
  if f~hasIndex('demo') then do
    k = .nil
    if self~lastPatient \== '' then k = agree~index(self~lastPatient)
    /* "That is not true": no thing was just handled, so that is a statement, not a thing */
    if k == .nil then return ''
    return self~lastPatient
  end
  /* an owner is this clause's subject if that agrees, else the last subject */
  if role == 'owner' then if p \== .nil then do
    cur = ''
    if p['ROLES']~hasIndex('agent') then cur = p['ROLES']['agent']
    if cur~isA(.String) then if agree~index(cur) \== .nil then return cur
  end
  /* the subject of the last sentence stays the subject if it agrees */
  if wordpos(role, 'agent holder owner') > 0 then if lastSubj \== '' then do
    k = agree~index(lastSubj)
    if k \== .nil then if later~index(lastSubj) == .nil then do
      agree~delete(k)
      agree~insert(lastSubj, .nil)
    end
  end
  pre = self~preFor(p, role)
  if pre == '' then return agree[1]
  /* known to pass beats unknown; unknown beats known to fail */
  do id over agree
    if self~preState(id, pre, p) == 'pass' then return id
  end
  do id over others
    if self~preState(id, pre, p) == 'pass' then do
      fd = .Directory~new
      fd['TYPE'] = 'PRONOUN-MISMATCH'
      fd['WORD'] = ref['LABEL']
      fd['CHOSEN'] = id
      fd['TEXT'] = agree[1]
      fd['EVENT'] = p['EVENT']
      fd['PRE'] = pre
      fd['PROP'] = p
      findings~append(fd)
      return id
    end
  end
  do id over agree
    if self~preState(id, pre, p) == 'unknown' then return id
  end
  fd = .Directory~new
  fd['TYPE'] = 'PRECONDITION-FAILS'
  fd['CHOSEN'] = agree[1]
  fd['EVENT'] = p['EVENT']
  fd['PRE'] = pre
  fd['PROP'] = p
  findings~append(fd)
  return agree[1]

::method ruleFor
  expose rules cs
  use arg ev
  cur = ev
  do 64
    if cur == '' then return .nil
    if rules~hasIndex(cur) then return rules[cur]
    cur = cs~parent(cur)
  end
  return .nil

/* the precondition clause that applies to a role, if any */
::method preFor
  use arg p, role
  if p == .nil then return ''
  r = self~ruleFor(p['EVENT'])
  if r == .nil then return ''
  do clause over r~pre~makeArray(';')
    parse var clause r1 '.' .
    if r1 == role then return clause
  end
  return ''

::method placeEntity
  use arg place
  parse var place . '@' id
  return id

::method prePasses
  use arg id, clause, p
  return self~preState(id, clause, p) \== 'fail'

/* open world: 'pass', 'fail' (a known contradiction) or 'unknown' */
::method preState
  expose ents cs
  use arg id, clause, p
  if id == '' then return 'unknown'
  if \ents~hasIndex(id) then return 'unknown'
  e = ents[id]
  parse var clause . '.' rest
  if rest~pos('~') > 0 then do
    parse var rest field '~' target
    neg = field~right(1) == '!'
    if neg then field = field~left(field~length - 1)
    if field \== 'loc' then return 'unknown'
    if e~loc == '' then return 'unknown'
    parse var target trel '@' tcon
    if tcon == '' then do
      tcon = trel
      trel = ''
    end
    parse value e~loc with prel '@' pent
    ok = .false
    if trel == '' | prel == trel then do
      /* in a hole that is in the dirt is in the dirt */
      x = pent
      do 4
        if x == '' then leave
        if \ents~hasIndex(x) then leave
        if cs~isa(ents[x]~concept, tcon) then do
          ok = .true
          leave
        end
        parse value ents[x]~loc with r2 '@' x
        if r2 \== prel then leave
      end
    end
    if neg then ok = \ok
    if ok then return 'pass'
    return 'fail'
  end
  parse var rest op '=' r2
  v = p['ROLES'][r2]
  if v == .nil then return 'unknown'
  if \v~isA(.String) then return 'unknown'
  if op == 'within' then do
    if e~loc == '' then return 'unknown'
    if self~inside(id, self~placeEntity(v)) then return 'pass'
    return 'fail'
  end
  if op == 'on-same' then do
    if e~loc == '' then return 'unknown'
    up = ''
    x = self~placeEntity(e~loc)
    do 32
      if x == '' then leave
      up = up x
      x = ents[x]~partOf
    end
    x = self~placeEntity(v)
    do 32
      if x == '' then leave
      if wordpos(x, up) > 0 then return 'pass'
      x = ents[x]~partOf
    end
    return 'fail'
  end
  if e~send(op) == '' then return 'unknown'
  if e~send(op) == v then return 'pass'
  return 'fail'

/* "That is acorn number one": the thing it points at carries that number */
::method nameOrdinal
  expose ents findings lastOrdConcept
  use arg p
  h = p['ROLES']['holder']
  if \h~isA(.String) then return
  if \ents~hasIndex(h) then return
  e = ents[h]
  if e~ordinal == '' then do
    e~ordinal = p['ORDC']
    e~ordval = p['ORDV']
    lastOrdConcept = e~concept
  end
  else if e~ordinal \== p['ORDC'] then do
    fd = .Directory~new
    fd['TYPE'] = 'CONFLICT-NUMBER'
    fd['PROP'] = p
    findings~append(fd)
  end

/* is entity id in or on target (or a part of it)? */
::method inside
  expose ents
  use arg id, target
  if id == '' then return .false
  x = self~placeEntity(ents[id]~loc)
  do 32
    if x == '' then return .false
    if x == target then return .true
    x = ents[x]~partOf
  end
  return .false

::method resolvePlace
  use arg pp, ctx, role, p
  np = pp['NP']
  id = self~resolveRef(np, ctx, role, p)
  return pp['REL']||'@'||id

/* resolve all refs in a prop; the agent first, then the rest */
::method resolveProp
  expose roleNames
  use arg p, ctx
  roles = p['ROLES']
  order = 'agent holder' roleNames
  done = ''
  do r over order~subWords
    if wordpos(r, done) > 0 then iterate
    done = done r
    call one r
    call one r||'2'
  end
  if p~hasIndex('SUBJ') then p~remove('SUBJ')
  return

one:
  parse arg rr
  if \roles~hasIndex(rr) then return
  v = roles[rr]
  if \v~isA(.Directory) then return
  if v~hasIndex('ROLES') then do
    /* a nested prop: shares the outer agent if it has none */
    if \v['ROLES']~hasIndex('agent') then if \v['ROLES']~hasIndex('holder') then if roles~hasIndex('agent') then v['ROLES']['agent'] = roles['agent']
    if \v['ROLES']~hasIndex('agent') then if roles~hasIndex('holder') then do
      h = roles['holder']
      if \h~isA(.Directory) then v['ROLES']['agent'] = self~ownerOf(h)
    end
    self~resolveProp(v, ctx)
    self~store(v)
    roles[rr] = v['ID']
    return
  end
  if v~hasIndex('ROLE') then do
    if v['NP'] == .nil then roles[rr] = v['REL']
    else if v['REL'] == '' then roles[rr] = self~resolveRef(v['NP'], ctx, rr, p)
    else roles[rr] = self~resolvePlace(v, ctx, rr, p)
    return
  end
  roles[rr] = self~resolveRef(v, ctx, rr, p)
  return

::method ownerOf
  expose ents
  use arg id
  if ents~hasIndex(id) then return ents[id]~owner
  return ''

::method store
  expose props order nextP
  use arg p
  if p~hasIndex('ID') then return
  nextP = nextP + 1
  p['ID'] = 'P'||nextP~right(2, '0')
  props[p['ID']] = p
  if p['ACT'] \== 'content' then order~append(p['ID'])

/* ------------------------------------------------------------------ */
/* world: apply narrated events, check what speakers claim            */
/* ------------------------------------------------------------------ */
::method apply
  expose ents cs findings
  use arg p
  roles = p['ROLES']
  r0 = self~ruleFor(p['EVENT'])
  /* copula: kind and attributes */
  if roles~hasIndex('holder') then if roles~hasIndex('kind') then do
    h = roles['holder']
    if ents~hasIndex(h) then do
      e = ents[h]
      if e~concept == '' | cs~isa(roles['kind'], e~concept) then e~concept = roles['kind']
      e~attrs = (e~attrs roles['attr'])~strip
    end
  end
  if p~hasIndex('ORDC') then self~nameOrdinal(p)
  if p['POL'] == '-' then return
  if roles~hasIndex('holder') then if roles~hasIndex('ident') then do
    self~identify(roles['holder'], roles['ident'], p)
    return
  end
  /* "Six acorns remained": count what remains and compare */
  if r0 \== .nil then if r0~pre == 'remains-if' then if roles['agent']~isA(.String) then if roles['agent']~pos('COUNT:') = 1 then do
    parse value roles['agent'] with 'COUNT:' cid ':' . ':' cnt
    n2 = 0
    do id over self~countable(cid)
      if self~remains(id, p) then n2 = n2 + 1
    end
    self~countFinding('remaining', cnt, n2, p, cid)
    return
  end
  if roles~hasIndex('holder') then if \roles~hasIndex('kind') then if roles['attr'] \== .nil then do
    if ents~hasIndex(roles['holder']) then self~addAttrs(ents[roles['holder']], roles['attr'])
  end
  r = self~ruleFor(p['EVENT'])
  if r == .nil then return
  /* narrated preconditions that fail are findings, not stops */
  do clause over r~pre~makeArray(';')
    if clause == '' then iterate
    parse var clause r1 '.' .
    if \roles~hasIndex(r1) then iterate
    if self~preState(roles[r1], clause, p) == 'fail' then do
      fd = .Directory~new
      fd['LOC'] = ''
      if ents~hasIndex(roles[r1]) then fd['LOC'] = ents[roles[r1]]~loc
      fd['TYPE'] = 'PRECONDITION-FAILS'
      /* an unread sentence about them since their state was last known: unsure */
      if ents~hasIndex(roles[r1]) then if ents[roles[r1]]~stale = 1 then fd['UNSURE'] = 1
      fd['CHOSEN'] = roles[r1]
      fd['EVENT'] = p['EVENT']
      fd['PRE'] = clause
      fd['PROP'] = p
      findings~append(fd)
    end
  end
  do eff over r~effects~makeArray(';')
    if eff == '' then iterate
    self~effect(eff, p)
  end

::method effect
  expose ents findings cs
  use arg eff, p
  roles = p['ROLES']
  /* a bush that shakes by itself: something unseen may be in it */
  if eff~left(8) == 'hiding<-' then do
    parse var eff 'hiding<-' who '!' notc
    if \roles~hasIndex(who) then return
    id = roles[who]
    if \ents~hasIndex(id) then return
    if notc \== '' then if cs~isa(ents[id]~concept, notc) then return
    self~hiding = id
    self~hidingProp = p['ID']
    return
  end
  inferred = ''
  check = .false
  if eff~pos('?=') > 0 then do
    parse var eff lhs '?=' rhs
    check = .true
  end
  else parse var eff lhs '<-' rhs
  parse var lhs who '.' field
  if \roles~hasIndex(who) then return
  id = roles[who]
  if \ents~hasIndex(id) then return
  e = ents[id]
  val = ''
  do alt over rhs~makeArray('/')
    /* ^rel@hidden: the place last marked hiding, as an inference with its trail */
    if alt~pos('@hidden') > 0 then do
      if self~hiding == '' then iterate
      inferred = self~hidingProp p['ID']
    end
    val = self~value(alt, p)
    if val \== '' then leave
  end
  if val == '' then return
  if val == 'none' then val = ''
  if e~members \== '' then do m over e~members~subWords
    if ents~hasIndex(m) then if \check then do
      ents[m]~send(field'=', val)
      if field == 'loc' then if val \== '' then ents[m]~locHist = (ents[m]~locHist val)~strip
    end
  end
  if field == 'loc' then if val \== '' then if \check then do
    e~locHist = (e~locHist val)~strip
    e~stale = 0
    e~locInfer = inferred
  end
  if check then do
    old = e~send(field)
    if old \== '' then do
      if self~placeEntity(old) \== self~placeEntity(val) then do
        fd = .Directory~new
        fd['TYPE'] = 'CONFLICT'
        fd['ENT'] = id
        fd['OLD'] = old
        fd['NEW'] = val
        fd['PROP'] = p
        findings~append(fd)
      end
      else do
        fd = .Directory~new
        fd['TYPE'] = 'CONSISTENT'
        fd['ENT'] = id
        fd['NEW'] = val
        fd['PROP'] = p
        findings~append(fd)
      end
      return
    end
    if field == 'loc' then e~locHist = (e~locHist val)~strip
  end
  e~send(field'=', val)

::method value
  expose roleNames ents cs
  use arg alt, p
  roles = p['ROLES']
  if alt == 'none' then return 'none'
  if alt~pos('@') > 0 then do
    parse var alt rel '@' tgt
    if wordpos(tgt, roleNames) > 0 then do
      if \roles~hasIndex(tgt) then return ''
      v = roles[tgt]
      if v~pos('@') > 0 then v = self~placeEntity(v)
      return rel||'@'||v
    end
    if tgt == 'hidden' then return rel||'@'||self~hiding
    id = self~findOf(tgt, '', '')
    if id == .nil then id = self~newEntity(tgt)~id
    return rel||'@'||id
  end
  if roles~hasIndex(alt) then return roles[alt]
  return ''

::method checkSpeech
  expose ents findings
  use arg p
  roles = p['ROLES']
  /* a claim about where something is */
  if roles~hasIndex('holder') then if roles~hasIndex('at') then do
    h = roles['holder']
    tgt = self~placeEntity(roles['at'])
    if ents~hasIndex(h) then if ents~hasIndex(tgt) then do
      truth = self~inside(h, tgt)
      if p['POL'] == '-' then truth = \truth
      fd = .Directory~new
      fd['TYPE'] = 'CLAIM'
      fd['TRUE'] = truth
      fd['LOC'] = ents[h]~loc
      fd['PROP'] = p
      findings~append(fd)
    end
  end
  /* a character numbering things: "That is acorn number one," Pip chattered */
  if p~hasIndex('ORDC') then self~nameOrdinal(p)
  /* an order presupposes its precondition */
  if p['ACT'] == 'order' then do
    r = self~ruleFor(p['EVENT'])
    if r \== .nil then do clause over r~pre~makeArray(';')
      if clause == '' then iterate
      parse var clause r1 '.' .
      if \roles~hasIndex(r1) then iterate
      st = self~preState(roles[r1], clause, p)
      if st == 'unknown' then iterate
      fd = .Directory~new
      fd['TYPE'] = 'PREMISE'
      fd['TRUE'] = st == 'pass'
      fd['WHO'] = roles[r1]
      fd['LOC'] = ''
      if ents~hasIndex(roles[r1]) then fd['LOC'] = ents[roles[r1]]~loc
      fd['PROP'] = p
      findings~append(fd)
    end
  end
  /* an answer: a purpose fragment after a why-question */
  if p~hasIndex('FRAG') then do
    do k = self~order~items to 1 by -1
      q = self~props[self~order[k]]
      if q['ID'] == p['ID'] then iterate
      if q~hasIndex('ASKS') then do
        fd = .Directory~new
        fd['TYPE'] = 'ANSWER'
        fd['Q'] = q
        fd['PROP'] = p
        findings~append(fd)
        leave
      end
    end
  end
