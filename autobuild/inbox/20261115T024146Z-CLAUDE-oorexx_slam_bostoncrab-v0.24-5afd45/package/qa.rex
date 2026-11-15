/* qa.rex - answer questions about a story by weighing evidence, not choosing. */
/* Reads storydir/story.txt with the Reader, then storydir/questions.txt   */
/* (Q|question, A|option lines). For each option the reader gathers grounds */
/* from its concept graph and hands them to Reasoned Thought, whose ordinal */
/* combiner decides. How each ground is known sets its tier and binding:    */
/*   narration                 DOCUMENTARY  (the story text is the document)*/
/*   a character's words       TESTIMONY, source = the speaker              */
/*   "the thief" in an order   TESTIMONY, binding PRESUPPOSED (not on point)*/
/*   same chapter only         STYLOMETRIC, source ASSOCIATION (below the   */
/*                             assert floor: it never settles anything)     */
/*   an inference by a rule    the tier of its weakest premise, binding     */
/*                             INFERRED: it can make an answer assertible,  */
/*                             never settled (an inference is not proof)    */
/* An option is the answer only if it is PRO and assertible; otherwise the  */
/* answer is CANNOT TELL, with every option's standing shown.               */
/* If storydir/key.txt exists it is read only after all answers are made.   */
/* Usage: rexx qa.rex storydir                                              */
/* Architecture: Tom Dyer. Reasoned Thought: Claude (Opus 4.8) / ChatGPT.   */
/* This file: Claude (Opus 5.5).                                            */
parse arg dir .
if dir == '' then dir = '.'
parse source . . me
here = filespec('L', me)~strip('T', '/')
/* the story's own compiled words when it has them (the scramble test does), else ours */
wdir = here
if SysFileExists(dir'/concepts.words') then wdir = dir
rd = .Reader~new(wdir)
rd~readFile(dir'/story.txt')
rz = .Realiser~new(rd)
do id over rd~ents~allIndexes
  rz~seen[id] = 1
end
qa = .QA~new(rd, rz, here'/qa_rules.src')

qs = .Array~new
s = .Stream~new(dir'/questions.txt')~~open('read')
do while s~lines > 0
  ln = s~linein
  if ln~strip == '' then iterate
  parse var ln tag '|' text
  if tag == 'Q' then do
    q = .Directory~new
    q['TEXT'] = text
    q['OPTS'] = .Array~new
    qs~append(q)
  end
  else if tag == 'A' then qs[qs~items]['OPTS']~append(text)
end
s~close

call SysMkDir dir'/out'
out = .Stream~new(dir'/out/answers.txt')~~open('write replace')
chosen = .Array~new
do k = 1 to qs~items
  q = qs[k]
  r = qa~answer(q['TEXT'], q['OPTS'])
  chosen~append(r['CHOICE'])
  lines = .Array~new
  lines~append(k'.' q['TEXT'])
  if r['CHOICE'] = -1 then lines~append('   answer:' r['FREE'] '   ['r['KIND']']')
  else if r['CHOICE'] = 0 then lines~append('   answer: CANNOT TELL -' r['WHY'])
  else lines~append('   answer:' q['OPTS'][r['CHOICE']] '   ['r['KIND']']')
  do e over r['EVIDENCE']
    lines~append('   because:' e)
  end
  do x over r['REJECTED']
    lines~append('   not:' x)
  end
  do x over lines
    say x
    out~lineout(x)
  end
end
out~close

/* the key is opened only now, after every answer has been written */
if SysFileExists(dir'/key.txt') then do
  s = .Stream~new(dir'/key.txt')~~open('read')
  right = 0
  cannot = 0
  k = 0
  do while s~lines > 0
    k = k + 1
    kv = s~linein~strip
    if k <= chosen~items then do
      if chosen[k] = kv then right = right + 1
      if chosen[k] = 0 then cannot = cannot + 1
    end
  end
  s~close
  say
  say 'score against key:' right 'of' qs~items '  (CANNOT TELL:' cannot')'
end
exit 0

::requires 'reader.cls'
::requires 'realiser.cls'
::requires 'ReasonedThought.cls'

::class QA public
::attribute rd
::attribute rz
::attribute meaning
::attribute kinds

::method init
  expose rd rz meaning kinds
  use arg rd, rz, rulesFile
  meaning = .StringTable~new
  kinds = .StringTable~new
  s = .Stream~new(rulesFile)~~open('read')
  do while s~lines > 0
    ln = s~linein
    if ln~strip == '' | ln~left(1) == '#' then iterate
    if ln~left(5) == 'kind:' then do
      parse var ln 'kind:' kw '|' ev
      do c over self~conceptsOf(kw)
        kinds[c] = self~conceptList(ev)
      end
      iterate
    end
    parse var ln ew '|' cond '|' ev
    d = .Directory~new
    d['COND'] = cond~strip
    d['EVIDENCE'] = self~conceptList(ev)
    do c over self~conceptsOf(ew)
      meaning[c] = d
    end
  end
  s~close

::method conceptsOf
  expose rd
  use arg word
  out = .Array~new
  if \rd~lex~known(word~strip) then return out
  do c over rd~lex~candidates(.array~of(word~strip), 1)
    if c['E']['CONCEPT'] \== '' then out~append(c['E']['CONCEPT'])
  end
  return out

::method conceptList
  use arg words
  out = ''
  do w over words~subWords
    do c over self~conceptsOf(w)
      out = out c
    end
  end
  return out~strip

/* ------------------------------------------------------------------ */
/* evidence                                                           */
/* ------------------------------------------------------------------ */
/* a ground from a proposition of the story: how it is known decides its tier */
::method groundOf
  expose rd rz
  use arg p, kind, binds, note
  if arg(3, 'O') then binds = 'GENERAL'
  if arg(4, 'O') then note = ''
  g = .Directory~new
  g['KIND'] = kind
  g['BINDS'] = binds
  if p['ACT'] == 'narrate' | p['ACT'] == 'content' then do
    g['TIER'] = 'DOCUMENTARY'
    g['SOURCE'] = 'NARRATION'
  end
  else do
    g['TIER'] = 'TESTIMONY'
    sp = p['SPEAKER']
    if sp == .nil then sp = ''
    g['SOURCE'] = 'SPEAKER:'sp
  end
  g['TEXT'] = rz~sentence(p)
  if note \== '' then g['TEXT'] = g['TEXT'] '('note')'
  return g

::method sourceName
  expose rd
  use arg src
  if src~pos('SPEAKER:') \= 1 then return src~lower
  id = src~substr(9)
  if rd~ents~hasIndex(id) then do
    n = rd~ents[id]~name
    return n~left(1)~upper||n~substr(2)
  end
  return 'someone'

/* Reasoned Thought decides each option from its grounds */
::method decide
  expose rd
  use arg opts, groundsFor, r
  net = .ThoughtNetwork~new
  do k = 1 to opts~items
    net~propose('O'k, opts[k], 'DOCUMENTARY', 'TESTIMONY', .array~of('INFERRED'))
  end
  /* one utterance per source, across all options */
  us = .StringTable~new
  order = .Array~new
  n = 0
  do k = 1 to opts~items
    do g over groundsFor[k]
      src = g['SOURCE']
      if \us~hasIndex(src) then do
        us[src] = .Utterance~new(src, src)
        order~append(src)
      end
      n = n + 1
      g['GID'] = 'G'n
      us[src]~assert(g['KIND'], g['TIER'], 'O'k, '', g['BINDS'], g['TEXT'], 'G'n)
    end
  end
  do src over order
    net~admit(us[src])
  end
  best = 0
  bestTier = 0
  tied = .false
  standing = .Array~new
  do k = 1 to opts~items
    d = net~assess('O'k)
    /* settled only on a live support that is not an inference */
    if d['settled'] then do
      proof = .false
      do g over groundsFor[k]
        if g['KIND'] \== 'SUPPORT' then iterate
        if g['BINDS'] \== 'GENERAL' then iterate
        if \d['live']~hasItem(g['GID']) then iterate
        if .EvidenceClass~of(g['TIER'])~rank >= .EvidenceClass~of('DOCUMENTARY')~rank then proof = .true
      end
      if \proof then do
        d['settled'] = .false
        d['status'] = 'SUPPORTED (inferred, not settled)'
      end
    end
    standing~append(d)
    if d['stance'] == 'PRO' then if d['assertible'] then do
      if d['supportTier'] > bestTier then do
        best = k
        bestTier = d['supportTier']
        tied = .false
      end
      else if d['supportTier'] = bestTier then tied = .true
    end
  end
  if tied then best = 0
  r['CHOICE'] = best
  do k = 1 to opts~items
    d = standing[k]
    lines = self~groundLines(d, groundsFor[k])
    if k = best then do
      r['KIND'] = d['status']
      do x over lines
        r['EVIDENCE']~append(x)
      end
    end
    else do
      why = d['stance']
      if groundsFor[k]~items = 0 then why = 'UNDETERMINED: the story gives no evidence for it'
      if self~optionNote(k, r) \== '' then why = why '-' self~optionNote(k, r)
      r['REJECTED']~append(opts[k] '-' why)
      if best = 0 then do x over lines
        r['REJECTED']~append('   ' x)
      end
    end
  end
  if best = 0 then do
    if tied then r['WHY'] = 'more than one option is equally supported'
    else r['WHY'] = 'no option is both supported and assertible on the evidence'
  end
  return r

::method optionNote
  use arg k, r
  if r['NOTES'] == .nil then return ''
  if r['NOTES']~hasIndex(k) then return r['NOTES'][k]
  return ''

/* live grounds, said in English, with their source and tier */
::method groundLines
  use arg d, grounds
  out = .Array~new
  do g over grounds
    state = 'live'
    if g['BINDS'] == 'INFERRED' then state = 'inferred'
    else if g['BINDS'] \== 'GENERAL' then state = 'not on point ('g['BINDS']~lower')'
    out~append(self~sourceName(g['SOURCE']) '('g['TIER']~lower', 'g['KIND']~lower', 'state'):' g['TEXT'])
  end
  return out

/* ------------------------------------------------------------------ */
/* questions                                                          */
/* ------------------------------------------------------------------ */
::method answer
  expose rd rz
  use arg text, opts
  toks = rd~tokens(text)
  do while toks~items > 0
    if wordpos(toks[toks~items], '? . !') = 0 then leave
    toks~delete(toks~items)
  end
  q = self~parseQuestion(toks)
  r = .Directory~new
  r['CHOICE'] = 0
  r['KIND'] = ''
  r['WHY'] = ''
  r['EVIDENCE'] = .Array~new
  r['REJECTED'] = .Array~new
  r['NOTES'] = .Directory~new
  if q == .nil then do
    r['WHY'] = 'the reader could not parse the question'
    return r
  end
  select
    when q['TYPE'] == 'identity' then return self~byKind(q, opts, r)
    when q['TYPE'] == 'location' then return self~byLocation(q, opts, r)
    when q['TYPE'] == 'exists' then return self~byExistence(q, opts, r)
    when q['TYPE'] == 'patient' then return self~byPatient(q, opts, r)
    when q['TYPE'] == 'count' then return self~byCount(q, opts, r)
    otherwise r['WHY'] = 'no method for this question type'
  end
  return r

::method parseQuestion
  expose rd
  use arg t
  lex = rd~lex
  q = .Directory~new
  i = 1
  c = lex~find(t, i, 'wh')
  if c \== .nil then do
    q['WH'] = c['E']['FEATS']['ask']
    i = i + c['LEN']
    if q['WH'] == 'count' then do
      core = rd~parseCore(t, i)
      if core == .nil then return .nil
      q['CONCEPT'] = core['CONCEPT']
      v = lex~find(t, core['NEXT'], 'verb')
      if v == .nil then return .nil
      q['EVENT'] = v['E']['CONCEPT']
      q['TYPE'] = 'count'
      return q
    end
    if i + 1 <= t~items then if t[i] == 'kind' then if t[i + 1] == 'of' then do
      f = rd~parseCore(t, i + 2)
      if f \== .nil then do
        q['FRAME'] = f['CONCEPT']
        i = f['NEXT']
      end
    end
    v = lex~find(t, i, 'verb')
    if v \== .nil then if v['E']['FEATS']~hasIndex('cop') then do
      np = rd~parseNP(t, i + v['LEN'])
      if np == .nil then return .nil
      q['TARGET'] = np
      if q['WH'] == 'place' then q['TYPE'] = 'location'
      else q['TYPE'] = 'identity'
      return q
    end
    a = lex~find(t, i, 'aux')
    if a == .nil then return .nil
    i = i + a['LEN']
    np = rd~parseNP(t, i)
    if np == .nil then return .nil
    q['SUBJ'] = np
    i = np['NEXT']
    v = lex~find(t, i, 'verb')
    if v == .nil then return .nil
    q['EVENT'] = v['E']['CONCEPT']
    i = i + v['LEN']
    pp = rd~parsePP(t, i)
    if pp \== .nil then q['PP'] = pp
    q['TYPE'] = 'patient'
    return q
  end
  v = lex~find(t, i, 'verb')
  if v \== .nil then if v['E']['FEATS']~hasIndex('cop') then do
    c = lex~find(t, i + v['LEN'], 'expl')
    if c \== .nil then do
      np = rd~parseNP(t, i + v['LEN'] + c['LEN'])
      if np == .nil then return .nil
      q['TARGET'] = np
      q['TYPE'] = 'exists'
      return q
    end
  end
  return .nil

::method optionRef
  expose rd
  use arg text
  return rd~parseNP(rd~tokens(text), 1)

::method refConcept
  expose rd
  use arg ref
  if ref == .nil then return ''
  if ref['KIND'] == 'name' then do
    if ref~hasIndex('APPOS') then return ref['APPOS']
    return ''
  end
  return rd~refConcept(ref)

::method nameOf
  expose rd
  use arg ref
  if ref == .nil then return ''
  if ref['KIND'] \== 'name' then return ''
  if rd~byName~hasIndex(ref['LABEL']) then return rd~byName[ref['LABEL']]
  return ''

::method entitiesOf
  expose rd
  use arg concept
  out = .Array~new
  if concept == '' then return out
  do id over rd~ents~allIndexes~sortWith(.CaselessComparator~new)
    e = rd~ents[id]
    if e~status \== '' then iterate
    if rd~cs~isa(e~concept, concept) then out~append(id)
  end
  return out

::method propsAbout
  expose rd
  use arg id
  out = .Array~new
  do pid over rd~order
    p = rd~props[pid]
    do role over p['ROLES']~allIndexes
      v = p['ROLES'][role]
      if \v~isA(.String) then iterate
      if v == id | v~pos('@'id) > 0 then do
        out~append(p)
        leave
      end
    end
  end
  return out

/* who is Pip / what kind of animal is Barnaby: what the story says he is.
   Kinds that are neither above nor below each other exclude each other. */
::method byKind
  expose rd
  use arg q, opts, r
  e = self~nameOf(q['TARGET'])
  if e == '' then do
    r['WHY'] = 'the question names no one the story knows'
    return r
  end
  frame = ''
  if q~hasIndex('FRAME') then frame = q['FRAME']
  gf = .Array~new
  do k = 1 to opts~items
    gs = .Array~new
    oc = self~refConcept(self~optionRef(opts[k]))
    gf~append(gs)
    if oc == '' then iterate
    if frame \== '' then if \rd~cs~isa(oc, frame) then do
      r['NOTES'][k] = 'not a kind of the thing asked about'
      iterate
    end
    do p over self~propsAbout(e)
      kd = p['ROLES']['kind']
      if \kd~isA(.String) then iterate
      if p['ROLES']['holder'] \== e then iterate
      if p['POL'] == '-' then iterate
      if rd~cs~isa(kd, oc) then gs~append(self~groundOf(p, 'SUPPORT'))
      else if \rd~cs~isa(oc, kd) then gs~append(self~groundOf(p, 'REBUT', 'GENERAL', 'a different kind'))
    end
  end
  return self~decide(opts, gf, r)

/* where were the nuts: places the story or a speaker puts them, or a pile of them */
::method byLocation
  expose rd
  use arg q, opts, r
  tc = self~refConcept(q['TARGET'])
  holders = .Array~new
  do id over self~entitiesOf(tc)
    holders~append(id)
    do o over rd~ents~allIndexes
      if rd~ents[o]~owner == id then holders~append(o)
    end
  end
  gf = .Array~new
  do k = 1 to opts~items
    gs = .Array~new
    gf~append(gs)
    t = rd~tokens(opts[k])
    pp = rd~parsePP(t, 1)
    if pp == .nil then iterate
    pc = self~refConcept(pp['NP'])
    seen = .StringTable~new
    do h over holders
      do p over self~propsAbout(h)
        if seen~hasIndex(p['ID']) then iterate
        do role over .array~of('at', 'to')
          v = p['ROLES'][role]
          if \v~isA(.String) then iterate
          parse var v rel '@' pe
          if \rd~ents~hasIndex(pe) then iterate
          if rel \== pp['REL'] then iterate
          if \rd~cs~isa(rd~ents[pe]~concept, pc) then iterate
          if p['POL'] == '-' then iterate
          seen[p['ID']] = 1
          gs~append(self~groundOf(p, 'SUPPORT'))
        end
      end
    end
  end
  return self~decide(opts, gf, r)

/* was there a thief: what the narration and each speaker say about whether one existed */
::method byExistence
  expose rd kinds
  use arg q, opts, r
  tc = self~refConcept(q['TARGET'])
  takers = ''
  if kinds~hasIndex(tc) then takers = kinds[tc]
  yes = .Array~new
  no = .Array~new
  do pid over rd~order
    p = rd~props[pid]
    if p['ACT'] == 'ask' then iterate
    content = p['ROLES']['content']
    /* "No thief," / "There was no thief." */
    hit = .false
    if content~isA(.String) then if content == 'KIND:'tc | content == 'KINDS:'tc then hit = .true
    h = p['ROLES']['holder']
    if p['EXIST'] == 1 then if h~isA(.String) then if h == 'KIND:'tc | h == 'KINDS:'tc then hit = .true
    if hit then do
      if p['POL'] == '-' then no~append(self~groundOf(p, 'SUPPORT'))
      else yes~append(self~groundOf(p, 'SUPPORT'))
      iterate
    end
    /* "Let us find the thief!": speaks of one, which presupposes it but asserts nothing */
    do role over p['ROLES']~allIndexes
      v = p['ROLES'][role]
      if \v~isA(.String) then iterate
      if \rd~ents~hasIndex(v) then iterate
      if rd~ents[v]~status \== '' then iterate
      if rd~cs~isa(rd~ents[v]~concept, tc) then do
        binds = 'GENERAL'
        if p['ACT'] \== 'narrate' then binds = 'PRESUPPOSED'
        yes~append(self~groundOf(p, 'SUPPORT', binds, 'speaks of one as real'))
      end
    end
    /* "Someone took my nuts!": a taking makes a thief, by meaning */
    if takers \== '' then if wordpos(p['EVENT'], takers) > 0 then if p['POL'] == '+' then
      yes~append(self~groundOf(p, 'SUPPORT', 'GENERAL', 'a taking, so a thief by meaning'))
  end
  gf = .Array~new
  do k = 1 to opts~items
    o = opts[k]~strip~lower
    gs = .Array~new
    if o == 'yes' then do
      do g over yes
        gs~append(g)
      end
      do g over no
        g2 = g~copy
        g2['KIND'] = 'REBUT'
        gs~append(g2)
      end
    end
    if o == 'no' then do
      do g over no
        gs~append(g)
      end
      do g over yes
        g2 = g~copy
        g2['KIND'] = 'REBUT'
        gs~append(g2)
      end
    end
    gf~append(gs)
  end
  return self~decide(opts, gf, r)

/* what did Pip lose / who did they find in the bush */
::method byPatient
  expose rd meaning
  use arg q, opts, r
  subj = self~nameOf(q['SUBJ'])
  ev = q['EVENT']
  rule = .nil
  if meaning~hasIndex(ev) then rule = meaning[ev]
  placeEnt = ''
  if q~hasIndex('PP') then do
    pl = self~entitiesOf(self~refConcept(q['PP']['NP']))
    if pl~items > 0 then placeEnt = pl[1]
  end
  gf = .Array~new
  do k = 1 to opts~items
    gs = .Array~new
    gf~append(gs)
    o = self~optionRef(opts[k])
    oc = self~refConcept(o)
    cands = .Array~new
    nm = self~nameOf(o)
    if nm \== '' then cands~append(nm)
    else do id over self~entitiesOf(oc)
      if o \== .nil then if o['KIND'] == 'poss' then if subj \== '' then if rd~ents[id]~owner \== subj then iterate
      cands~append(id)
    end
    if cands~items = 0 then do
      if self~guessedOnly(oc) then r['NOTES'][k] = 'only ever a guess or a denial in the story'
      else r['NOTES'][k] = 'the story has none'
      iterate
    end
    do id over cands
      do p over self~propsAbout(id)
        /* direct: an event of this kind with the option as its patient */
        if p['EVENT'] == ev then if p['ROLES']['patient'] == id then if p['POL'] == '+' then gs~append(self~groundOf(p, 'SUPPORT'))
        /* meaning: lose = something of the subject's said to be gone, or taken */
        if rule \== .nil then do
          hit = .false
          if wordpos(p['EVENT'], rule['EVIDENCE']) > 0 then hit = .true
          at = p['ROLES']['attr']
          if at~isA(.String) then do a over at~subWords
            if wordpos(a, rule['EVIDENCE']) > 0 then hit = .true
          end
          if hit then gs~append(self~groundOf(p, 'SUPPORT', 'GENERAL', 'by the meaning of the question'))
        end
      end
      /* where the reader's rules put it: found in the bush = was in the bush.
         The ground is as strong as its weakest premise, and is an inference */
      if placeEnt \== '' then do
        e = rd~ents[id]
        if e~locInfer \== '' then if rd~placeEntity(e~loc) == placeEnt then do
          g = self~inferenceGround(e~locInfer, 'SUPPORT', 'by the reader''s rules: came into view where the' rd~lex~label('N/'rd~ents[placeEnt]~concept'/sg') 'moved by itself')
          if g \== .nil then gs~append(g)
        end
      end
      /* same chapter as the place asked about: association, the weakest tier */
      if placeEnt \== '' then do
        common = ''
        do sc over rd~ents[id]~scenes~subWords
          if wordpos(sc, rd~ents[placeEnt]~scenes) > 0 then common = sc
        end
        if common \== '' then do
          g = .Directory~new
          g['KIND'] = 'SUPPORT'
          g['TIER'] = 'STYLOMETRIC'
          g['BINDS'] = 'GENERAL'
          g['SOURCE'] = 'ASSOCIATION'
          g['TEXT'] = 'appears in chapter' common 'with the' rd~lex~label('N/'rd~ents[placeEnt]~concept'/sg')'; the story never says it was found there'
          gs~append(g)
        end
      end
    end
  end
  return self~decide(opts, gf, r)

/* an inference from story props: its tier is its weakest premise's */
::method inferenceGround
  expose rd rz
  use arg pids, kind, note
  tier = ''
  texts = ''
  do pid over pids~subWords
    if \rd~props~hasIndex(pid) then return .nil
    pg = self~groundOf(rd~props[pid], 'SUPPORT')
    if tier == '' then tier = pg['TIER']
    else if .EvidenceClass~of(pg['TIER'])~rank < .EvidenceClass~of(tier)~rank then tier = pg['TIER']
    pt = rd~props[pid]['TEXT']
    if pt == .nil then pt = rz~sentence(rd~props[pid])~strip
    texts = texts '/ "'pt'"'
  end
  g = .Directory~new
  g['KIND'] = kind
  g['TIER'] = tier
  g['BINDS'] = 'INFERRED'
  g['SOURCE'] = 'INFERENCE'
  g['TEXT'] = note '-' texts~substr(4)
  return g

/* how many acorns remain: counted from the world the narration built */
::method byCount
  expose rd
  use arg q, opts, r
  list = rd~countable(q['CONCEPT'])
  n = 0
  last = .nil
  do id over list
    if rd~remains(id, .nil) then n = n + 1
    do p over self~propsAbout(id)
      if p['ACT'] == 'narrate' then last = p
    end
  end
  do pid over rd~order
    p = rd~props[pid]
    if p['ACT'] \== 'narrate' then iterate
    do role over p['ROLES']~allIndexes
      v = p['ROLES'][role]
      if \v~isA(.String) then iterate
      if \rd~ents~hasIndex(v) then iterate
      if rd~ents[v]~members == '' then iterate
      if list~items > 0 then if wordpos(list[1], rd~ents[v]~members) > 0 then last = p
    end
  end
  r['FREE'] = n 'of' list~items 'remain'
  r['CHOICE'] = -1
  r['KIND'] = 'DERIVED FROM NARRATION'
  if last \== .nil then r['EVIDENCE']~append('last change:' self~rz~sentence(last))
  return r

::method guessedOnly
  expose rd
  use arg c
  any = .false
  do id over rd~ents~allIndexes
    e = rd~ents[id]
    if \rd~cs~isa(e~concept, c) then iterate
    if e~status == '' then return .false
    any = .true
  end
  return any
