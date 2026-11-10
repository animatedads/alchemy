/* realiser.cls - English out, from concepts only.                         */
/* Every word comes from a reverse lookup in the lexicon, keyed by concept */
/* id. No gloss is read and nothing is predicted.                          */
/* Architecture: Tom Dyer. Code: Claude (Opus 5.5).                        */

::class Realiser public
::attribute rd unguarded
::attribute seen unguarded

::method init
  expose rd seen
  use arg rd
  seen = .StringTable~new

::method lex
  expose rd
  return rd~lex

::method w
  use arg key
  return self~lex~label(key)

::method cap
  use arg s
  if s == '' then return s
  return s~left(1)~upper||s~substr(2)

::method adj
  use arg a
  /* a name used to say which one: the KLM aircraft */
  if a~left(2) == 'N:' then do
    nm = a~substr(3)
    return nm~left(1)~upper||nm~substr(2)
  end
  t = self~w('A/'||a)
  if t == '' then t = self~noun(a, .false)
  return t

/* "cool and wet", "dark, warm and damp" */
::method adjList
  use arg list
  n = words(list)
  out = ''
  do k = 1 to n
    if k > 1 then do
      if k = n then out = out 'and'
      else out = out||','
    end
    out = out self~adj(word(list, k))
  end
  return out~strip

::method noun
  use arg c, plural
  if plural then do
    t = self~w('N/'||c||'/pl')
    if t \== '' then return t
  end
  return self~w('N/'||c||'/sg')

/* how to say an entity or value. ctx: SPEAKER ADDRESSEE AGENT CASE */
::method ent
  expose rd seen
  use arg id, ctx
  if id == '' then return '[someone]'
  if ctx~hasIndex('SPEAKER') then if id == ctx['SPEAKER'] then do
    if ctx['CASE'] == 'obj' then return 'me'
    return 'I'
  end
  if ctx~hasIndex('ADDRESSEE') then if id == ctx['ADDRESSEE'] then return 'you'
  if id~pos('COUNT:') = 1 then do
    parse var id 'COUNT:' cc ':' nc ':' nv
    return self~w('NUM/'nc) self~noun(cc, nv \= 1)
  end
  if id~pos('KINDS:') = 1 then do
    parse value id~substr(7) with kc '/' ka
    if ka \== '' then return self~adjList(ka~changeStr('+', ' ')) self~noun(kc, .true)
    return self~noun(kc, .true)
  end
  if id~pos('KIND:') = 1 then return self~noun(id~substr(6), .false)
  if id~pos('EVERY:') = 1 then return 'every' self~noun(id~substr(7), .false)
  if \rd~ents~hasIndex(id) then do
    /* a bare concept: here, now, tomorrow */
    t = self~w('DEIXIS/'||id)
    if t == '' then t = self~w('ADV/'||id)
    if t == '' then t = self~noun(id, .false)
    return t
  end
  e = rd~ents[id]
  /* a name is said with each word capitalised: Circular Quay */
  if e~name \== '' then do
    nm = ''
    do wd over e~name~subWords
      nm = nm self~cap(wd)
    end
    return nm~strip
  end
  if e~intro == 'someone' then return 'someone'
  if e~intro == 'something' then return 'something'
  if e~intro == 'all' then if e~amount \== '' then return 'all' self~w('NUM/'e~amount) self~noun(rd~ents[e~members~word(1)]~concept, .true)
  if e~members \== '' then do
    if ctx~hasIndex('SPEAKER') then if wordpos(ctx['SPEAKER'], e~members) > 0 then do
      if ctx['CASE'] == 'obj' then return 'us'
      return 'we'
    end
    out = ''
    do m over e~members~subWords
      if out \== '' then out = out 'and'
      out = out self~ent(m, ctx)
    end
    return out~strip
  end
  first = \seen~hasIndex(id)
  seen[id] = 1
  adjs = ''
  if first then do a over e~introAttrs~subWords
    adjs = adjs self~adj(a)
  end
  /* "the north shore" again, when a south shore has been said too: the
     words that told them apart are said every time */
  if \first then if e~introAttrs \== '' then do
    twin = .false
    do other over seen~allIndexes
      if other == id then iterate
      if \rd~ents~hasIndex(other) then iterate
      if rd~ents[other]~concept == e~concept then twin = .true
    end
    if twin then do a over e~introAttrs~subWords
      adjs = adjs self~adj(a)
    end
  end
  n = (adjs~strip self~noun(e~concept, e~plural))~strip
  /* a body part known only as part of someone reads as theirs: his head */
  o = e~owner
  /* "A little nose appeared": whose it was is learnt later, so not said yet */
  if o == '' then if \(first & e~intro == 'indef') then if e~partOf \== '' then if rd~ents~hasIndex(e~partOf) then if rd~cs~isa(rd~ents[e~partOf]~concept, rd~lex~nameConcept) then o = e~partOf
  if o \== '' then do
    if ctx~hasIndex('SPEAKER') then if o == ctx['SPEAKER'] then return 'my' n
    if ctx~hasIndex('ADDRESSEE') then if o == ctx['ADDRESSEE'] then return 'your' n
    if ctx~hasIndex('AGENT') then if o == ctx['AGENT'] then do
      if rd~ents~hasIndex(o) then do
        if rd~ents[o]~name == '' then return 'its' n
        if rd~ents[o]~gender == 'f' then return 'her' n
      end
      return 'his' n
    end
    oc = ctx~copy
    oc['CASE'] = 'subj'
    alive = .true
    if rd~ents~hasIndex(o) then alive = rd~cs~isa(rd~ents[o]~concept, rd~lex~nameConcept)
    if \alive then do
      det = 'the'
      if first then if e~intro == 'indef' then det = 'a'
      oc['CASE'] = 'obj'
      return self~an(det n) 'of' self~ent(o, oc)
    end
    return self~ent(o, oc)||"'s" n
  end
  if e~intro == 'bare' then if first then return n
  if e~intro == 'bare' then if \e~plural then return n
  if first then if e~intro == 'other' then return 'another' n
  if first then if e~intro == 'indef' then do
    if e~amount \== '' then return self~w('NUM/'||e~amount) n
    return self~an('a' n)
  end
  return 'the' n

/* "a earthworm" -> "an earthworm": by the next word's first letter */
::method an
  use arg text
  if word(text, 1) \== 'a' then return text
  nx = word(text, 2)
  if pos(nx~left(1)~lower, 'aeiou') > 0 then return 'an' subword(text, 2)
  return text

/* verb text for a form; phrasal concepts come back as verb + word */
::method verb
  use arg c, form
  t = self~w('V/'||c||'/'||form)
  if t \== '' then return t
  ph = self~lex~reverse['PH/'||c]
  if ph == .nil then do
    do f2 over .array~of('base', 'past', 'pres3', 'ing')
      t = self~w('V/'||c||'/'||f2)
      if t \== '' then return t
    end
    return '[?]'
  end
  parse value ph['LABEL'] with vid '+' word
  v = self~w('V/'||vid||'/'||form)
  if v == '' then v = self~verb(vid, form)
  if ph['FEATS']['pp'] == 'keep' then return v
  return v word

/* phrasal "pick up": the word goes after the patient */
::method splitVerb
  use arg c, form
  ph = self~lex~reverse['PH/'||c]
  d = .Directory~new
  d['V'] = self~verb(c, form)
  d['AFTER'] = ''
  d['BEFOREP'] = ''
  if self~w('V/'||c||'/'||form) \== '' then return d
  if ph == .nil then return d
  parse value ph['LABEL'] with vid '+' word
  d['V'] = self~w('V/'||vid||'/'||form)
  if ph['FEATS']~hasIndex('pp') then do
    if ph['FEATS']['pp'] == 'patient' then d['BEFOREP'] = word
    return d
  end
  d['AFTER'] = word
  return d

::method pp
  use arg role, v, ctx
  oc = ctx~copy
  oc['CASE'] = 'obj'
  if v~pos('@') > 0 then do
    parse var v rel '@' id
    pw = self~w('P/'||role||'/'||rel)
    if pw == '' then do r2 over 'at to path from'~subWords
      pw = self~w('P/'||r2||'/'||rel)
      if pw \== '' then leave
    end
    return (pw self~ent(id, oc))~strip
  end
  return (self~w('P/'||role||'/') self~ent(v, oc))~strip

/* a whole clause. mode: past (narration) or present (speech) */
::method clause
  expose rd
  use arg p, ctx, mode
  roles = p['ROLES']
  ev = p['EVENT']
  c = ctx~copy
  subjId = ''
  if roles~hasIndex('agent') then subjId = roles['agent']
  if roles~hasIndex('holder') then subjId = roles['holder']
  c['AGENT'] = subjId
  c['CASE'] = 'subj'
  subj = ''
  /* It was Molly: the thing seen was part of her, so say "it" */
  identPart = .false
  if roles~hasIndex('ident') then if rd~ents~hasIndex(subjId) then if rd~ents[subjId]~partOf == roles['ident'] then identPart = .true
  if subjId \== '' then do
    if identPart then subj = 'it'
    else if rd~props~hasIndex(subjId) then subj = self~gerund(rd~props[subjId], c)
    else subj = self~ent(subjId, c)
  end
  order = p['ACT'] == 'order'
  frag = p~hasIndex('FRAG')
  if order then subj = ''
  if frag then subj = ''
  if mode == 'inf' then subj = ''
  if mode == 'bare' then form = 'base'
  /* the verb group */
  isBe = roles~hasIndex('holder')
  vg = ''
  after = ''
  form = 'past'
  if mode == 'present' then do
    form = 'pres3'
    plural = .false
    if rd~ents~hasIndex(subjId) then plural = rd~ents[subjId]~plural
    if subjId~pos('KINDS:') = 1 then plural = .true
    if isBe then do
      if subjId == c['SPEAKER'] then form = 'pres1'
      if subjId == c['ADDRESSEE'] | plural then form = 'pres2'
    end
    else if subjId == c['SPEAKER'] | subjId == c['ADDRESSEE'] | plural then form = 'base'
    else if self~w('V/'||ev||'/pres3') == '' then form = 'base'
  end
  pre = ''
  if p['MODAL'] \== '' then do
    pre = self~w('MODAL/'||p['MODAL'])
    form = 'base'
  end
  if p['ASPECT'] \== '' then do
    pre = self~w('ASPECT/'||p['ASPECT'])
    form = 'base'
  end
  if order then form = 'base'
  if mode == 'bare' then form = 'base'
  if frag | mode == 'inf' then do
    pre = 'to'
    form = 'base'
  end
  if p~hasIndex('ASKS') then do
    at = 'pres'
    if p['AUXT'] == 'past' then at = 'past'
    if p['PERF'] == 1 then do
      pre = self~w('AUX/'at'/perf')
      form = 'past'
    end
    else do
      pre = self~w('AUX/'at)
      form = 'base'
    end
  end
  if p['POL'] == '-' then do
    if isBe then after = 'not'
    else do
      if pre == '' then pre = self~w('AUX/past') 'not'
      else pre = pre 'not'
      form = 'base'
    end
  end
  sv = self~splitVerb(ev, form)
  vg = sv['V']
  if isBe then if form == 'past' then if rd~ents~hasIndex(subjId) then if rd~ents[subjId]~plural then do
    pl = self~w('V/'||ev||'/past/pl')
    if pl \== '' then vg = pl
  end
  if p['EXIST'] == 1 then do
    neg = ''
    if p['POL'] == '-' then neg = 'no'
    pl = rd~ents~hasIndex(subjId)
    if pl then pl = rd~ents[subjId]~plural
    if subjId~pos('KINDS:') = 1 then pl = .true
    w2 = vg
    if pl then if self~w('V/'||ev||'/past/pl') \== '' then w2 = self~w('V/'||ev||'/past/pl')
    out = 'there' w2 neg subj
    if roles~hasIndex('at') then out = out self~pp('at', roles['at'], c)
    return space(out)
  end
  out = ''
  if p~hasIndex('ASKS') then out = self~w('WH/'||p['ASKS']) pre subj vg
  else out = subj pre vg after
  dirw = ''
  if roles~hasIndex('dir') then do d over roles['dir']~subWords
    t2 = self~w('T/'||d)
    if t2 == '' then t2 = self~w('ADV/'||d)
    dirw = dirw t2
  end
  dirw = dirw~strip
  if dirw \== '' then if sv['BEFOREP'] \== '' | \roles~hasIndex('patient') then do
    out = out dirw
    dirw = ''
  end
  out = out sv['BEFOREP']
  /* copula complements */
  if isBe then do
    if p~hasIndex('ORDC') then out = out self~noun(roles['kind'], .false) 'number' self~w('NUM/'p['ORDC'])
    else if roles~hasIndex('kind') then do
      adjs = ''
      at = roles['attr']
      if at == .nil then at = ''
      do a over at~subWords
        adjs = adjs self~adj(a)
      end
      out = out self~an(('a' adjs~strip self~noun(roles['kind'], .false))~space)
    end
    else if roles['attr'] \== .nil then out = out self~adjList(roles['attr'])
    if roles~hasIndex('ident') then do
      ic = .Directory~new
      ic['CASE'] = 'obj'
      /* it was Molly: the nose was Molly's */
      out = out self~ent(roles['ident'], ic)
    end
    if roles~hasIndex('content') then out = out self~clause(rd~props[roles['content']], c, 'inf')~strip
  end
  skipPat = .false
  if \isBe then if roles~hasIndex('content') then if roles~hasIndex('patient') then do
    if rd~props[roles['content']]['ROLES']['agent'] == roles['patient'] then skipPat = .true
  end
  if roles~hasIndex('patient') then if \skipPat then do
    oc = c~copy
    oc['CASE'] = 'obj'
    pv = roles['patient']
    if rd~props~hasIndex(pv) then out = out self~gerund(rd~props[pv], oc)
    else out = out self~ent(pv, oc)
  end
  if \isBe then if roles~hasIndex('content') then if rd~props~hasIndex(roles['content']) then out = out self~clause(rd~props[roles['content']], c, 'bare')
  out = out sv['AFTER'] dirw
  if roles~hasIndex('result') then out = out self~w('A/'||roles['result'])
  do r over 'to at path from source instrument manner about'~subWords
    if \roles~hasIndex(r) then iterate
    v = roles[r]
    if r == 'at' then if v~pos('@') = 0 then do
      out = out self~ent(v, c)
      iterate
    end
    out = out self~pp(r, v, c)
  end
  if roles~hasIndex('purpose') then do
    q = rd~props[roles['purpose']]
    if q['INF'] == 1 then do
      out = out 'to' self~verb(q['EVENT'], 'base')
      if q['ROLES']~hasIndex('patient') then out = out self~ent(q['ROLES']['patient'], c)
    end
    else out = out self~verb(q['EVENT'], 'base')
  end
  t = ''
  if roles~hasIndex('time') then t = self~ent(roles['time'], c)
  if roles~hasIndex('time2') then t = t self~pp('time', roles['time2'], c)
  t = t~strip
  if t \== '' then do
    if p['ACT'] == 'narrate' then out = t',' out
    else out = t out
  end
  return space(out)

/* "throwing leaves" */
::method gerund
  use arg q, ctx
  out = self~verb(q['EVENT'], 'ing')
  if q['ROLES']~hasIndex('patient') then out = out self~ent(q['ROLES']['patient'], ctx)
  return out

::method say
  expose rd
  use arg p
  act = p['ACT']
  speaker = p['SPEAKER']
  ctx = .Directory~new
  ctx['SPEAKER'] = speaker
  ctx['ADDRESSEE'] = p['ADDRESSEE']
  nc = .Directory~new
  nc['CASE'] = 'subj'
  who = self~ent(speaker, nc)
  sv = 'said'
  if p['SVERB'] \== '' then sv = self~verb(p['SVERB'], 'past')
  if p['SOURCE'] \== '' then sv = sv self~pp('source', p['SOURCE'], nc)
  voc = ''
  if p['VOC'] == 1 then if act \== 'farewell' then voc = self~ent(p['ADDRESSEE'], nc)'! '
  end1 = ','
  if p['EMPH'] == 1 then end1 = '!'
  /* a quote keeps its own tense: "We found them!" */
  md = 'present'
  if p['FORM'] == 'past' then md = 'past'
  select
    when act == 'sound' then return '"'self~cap(self~w('SOUND/'||p['EVENT']))'!"' who sv'.'
    when act == 'fragment' then do
      t = self~ent(p['ROLES']['content'], ctx)
      if p['HYPO'] == 1 then t = 'maybe' t
      if p['NODET'] == 1 then t = 'no' t
      else if p['POL'] == '-' then t = 'not' t
      mark = '!'
      if p['Q'] == 1 then mark = '?'
      return '"'self~cap(t)||mark'"' who sv'.'
    end
    when act == 'exclaim' then return '"'self~cap(self~w('FORMULA/'||p['EVENT']))'!"' who sv'.'
    when act == 'farewell' then do
      t = self~w('FORMULA/'||p['EVENT'])
      return '"'self~cap(t)',' self~ent(p['ADDRESSEE'], nc)'," 'who sv'.'
    end
    when act == 'ask' then return '"'voc||self~cap(self~clause(p, ctx, md))'?"' who sv'.'
    when act == 'order' then return '"'voc||self~cap(self~clause(p, ctx, 'present'))'!"' who sv'.'
    otherwise return '"'voc||self~cap(self~clause(p, ctx, md))||end1'" 'who sv'.'
  end

::method sentence
  use arg p
  act = p['ACT']
  if act == 'narrate' then do
    ctx = .Directory~new
    return self~cap(self~clause(p, ctx, 'past'))'.'
  end
  if \p~hasIndex('SPEAKER') then do
    if act == 'ask' then return self~cap(self~clause(p, .Directory~new, 'past'))'?'
    if act == 'sound' then return self~cap(self~w('SOUND/'||p['EVENT']))'!'
    if act == 'exclaim' then return self~cap(self~w('FORMULA/'||p['EVENT']))'!'
    return '[?]'
  end
  return self~say(p)
