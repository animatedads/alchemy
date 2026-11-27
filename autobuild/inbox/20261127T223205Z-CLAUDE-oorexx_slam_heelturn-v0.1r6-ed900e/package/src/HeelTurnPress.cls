/* HeelTurnPress.cls - Heel Turn SLAM: reading and writing press.
   Architecture: Tom Dyer. Code: Claude (Opus 5.5).
   Reading is deterministic. Each sentence gets a speech act (PROMISE,
   PROPOSAL, REQUEST, THREAT, ACCEPT, REFUSE, ACCUSE, THANKS, APOLOGY,
   GREETING, QUESTION, CLAIM), the commitments and claims it makes about the
   board, and tone marks. Tone and intent come from the Librarian's closed
   classes (modals, negators, pronouns) and lexicon tone concepts, never
   from guessing at strings. Writing realises chosen acts in a small fixed
   English the same reader reads back. */
::requires 'HeelTurnBoard.cls'
::requires 'HeelTurnPolicy.cls'

::class HeelTurnMessageReader public
::method init
  expose reader vocab map a
  use strict arg reader, map, a
  vocab = reader~vocab
::method readMail
  -- frame: ID FROM TO TEXT. Returns a reading directory.
  expose reader a
  use strict arg frame
  r = .directory~new
  r['ID'] = frame['ID']
  r['FROM'] = frame['FROM']
  r['TO'] = frame['TO']
  r['ACTS'] = .array~new
  r['COMMITS'] = .array~new
  r['REQUESTS'] = .array~new
  r['CLAIMS'] = .array~new
  r['ACCUSE'] = .array~new
  r['THIRD'] = .array~new
  r['UNREAD'] = .array~new
  r['REFS'] = .array~new
  r['THREATS'] = .array~new
  tone = .directory~new
  do t over .array~of('warm', 'cold', 'flattery', 'urgency', 'hedge', 'assurance', 'fear')
    tone[t] = 0
  end
  r['TONE'] = tone
  do sentence over reader~sentences(frame['TEXT'])
    items = reader~fixNegverbs(reader~items(sentence))
    items = self~resolveRefs(r, items, sentence)
    self~readSentence(r, items, sentence)
  end
  self~judge(r)
  return r
::method resolveRefs private
  -- Boston Crab's reference policy (oorexx_slam_bostoncrab order_check.rex),
  -- on the board: a reference ("my army", "your fleet", "Germany's army") is
  -- matched by concept against the units that owner has, narrowed by what the
  -- sentence asks of it (move into, support into). The board is public, so
  -- writer and recipient see the same candidates:
  --   CLEAR             one unit: the reference is bound to it
  --   AMBIGUOUS         several of the recipient's units fit; which is not said
  --   WRITER AMBIGUOUS  several of the writer's units fit; which will act is not said
  --   NO REFERENT       no unit of that owner and kind can do it
  -- NOT VISIBLE and MEANS DIFFERENT THINGS need private sight; a public board
  -- has none, so they cannot arise here.
  expose map a
  use strict arg r, items, sentence
  sender = r['FROM']
  me = a~me
  n = items~items
  idx = 0
  do while idx < n
    idx += 1
    it = items[idx]
    owner = ''
    if it['K'] == 'PRONOUN' then do
      if wordpos(it['C'], 'MY OUR') > 0 then owner = sender
      if it['C'] == 'YOUR' then owner = me
    end
    if it['K'] == 'POWER' then owner = it['CODE']
    if owner == '' | idx = n then iterate
    nx = items[idx + 1]
    if nx['K'] \== 'OBJ' then iterate
    if wordpos(nx['C'], 'army fleet unit') = 0 then iterate
    utype = ''
    if nx['C'] == 'army' then utype = 'A'
    if nx['C'] == 'fleet' then utype = 'F'
    -- what is asked of it: support before it (it is supported), support after
    -- it (it supports), otherwise it moves; the first province after it is
    -- where
    role = 'MOVE'
    do k = idx - 1 to 1 by -1
      if items[k]['K'] == 'PUNCT' then leave
      if items[k]['K'] == 'ACT' then do
        if items[k]['C'] == 'support' then role = 'SUPPORTED'
        leave
      end
    end
    if role == 'MOVE' then do k = idx + 2 to n
      if items[k]['K'] == 'PUNCT' then leave
      if items[k]['K'] == 'ACT' then do
        if items[k]['C'] == 'support' then role = 'SUPPORTER'
        if heelTurnHoldAct(items[k]['C']) then role = 'HOLD'
        leave
      end
    end
    dest = ''
    do k = idx + 2 to n
      if items[k]['K'] == 'PUNCT' then if items[k]['C'] \== ',' then leave
      if items[k]['K'] == 'PROV' then do
        dest = items[k]['CODE']
        leave
      end
    end
    cands = .array~new
    do u over a~view~units
      if u['OWNER'] \== owner then iterate
      if utype \== '' then if u['TYPE'] \== utype then iterate
      if dest \== '' & role \== 'HOLD' then do
        ok = map~reaches(u['TYPE'], u['LOC'], dest)
        if \ok then if role \== 'SUPPORTER' then if u['TYPE'] == 'A' then ok = map~convoyRoute(a~view~units, u['LOC'], dest)
        if \ok then iterate
      end
      cands~append(u)
    end
    phrase = it['T'] nx['T']
    select
      when cands~items = 1 then verdict = 'CLEAR'
      when cands~items = 0 then verdict = 'NO REFERENT'
      when owner == sender then verdict = 'WRITER AMBIGUOUS'
      otherwise verdict = 'AMBIGUOUS'
    end
    ref = .directory~new
    ref['VERDICT'] = verdict
    ref['PHRASE'] = phrase
    ref['OWNER'] = owner
    ref['ROLE'] = role
    ref['DEST'] = dest
    names = .array~new
    do u over cands
      names~append(u['TYPE'] u['LOC'])
    end
    ref['CANDIDATES'] = names~makeString('L', ', ')
    r['REFS']~append(ref)
    -- bind: a CLEAR reference becomes that unit; a writer's own reference that
    -- no unit of that kind could carry out becomes a unit that does not exist,
    -- so the promise reads as one that cannot be done
    bind = .nil
    if verdict == 'CLEAR' then bind = cands[1]
    if verdict == 'NO REFERENT' then if owner == sender then if utype \== '' then if dest \== '' then if role \== 'HOLD' then bind = heelTurnUnit(owner, utype, 'NONE')
    if bind \== .nil then do
      ui = heelTurnItem('UNIT', bind['TYPE'] bind['LOC'], phrase)
      ui['TYPE'] = bind['TYPE']
      ui['LOC'] = bind['LOC']
      ui['REF'] = 1
      items[idx + 1] = ui
    end
  end
  return items
::method readSentence private
  -- A sentence with a condition ("If you ..., I will ...") is read as its
  -- main clause, marked conditional: the condition's acts are the other
  -- side's, never the writer's commitments.
  expose vocab a
  use strict arg r, items, sentence, condPart = .nil
  if condPart == .nil then do
    split = heelTurnCondSplit(items)
    if split \== .nil then do
      self~readSentence(r, split[2], sentence, split[1])
      return
    end
  end
  sender = r['FROM']
  n = items~items
  isQ = sentence~strip~right(1) == '?'
  subject = ''
  neg = 0
  force = 0
  hasCond = .false
  acts = .array~new
  units = .array~new
  provs = .array~new
  powers = .array~new
  possessor = ''
  dmz = .false
  alliance = .false
  scope = 'NOW'
  firstKind = ''
  known = 0
  selfAny = .false
  do idx = 1 to n
    it = items[idx]
    k = it['K']
    if firstKind == '' then if k \== 'PUNCT' then firstKind = k
    if k \== 'UNKNOWN' & k \== 'PUNCT' then known += 1
    select
      when k == 'TONE' then r['TONE'][it['C']] += 1
      when k == 'NEGATOR' | k == 'NEGVERB' then neg += 1
      when k == 'MODAL' then do
        if force = 0 then force = heelTurnModalForce(it['C'])
        if wordpos(it['C'], 'MIGHT MAY COULD') > 0 then r['TONE']['hedge'] += 1
      end
      when k == 'FORCE' then do
        if it['F']~hasIndex('force') then force = it['F']['force']
        if it['F']~hasIndex('polar') then neg += 1
        if it['C'] == 'always' then scope = 'ALWAYS'
      end
      when k == 'CONDWORD' then hasCond = .true
      when k == 'COND' then if it['C'] == 'betrayed' then acts~append('break')
      when k == 'TIME' then do
        if it['C'] == 'next' then scope = 'NEXT'
        if it['C'] == 'always' then scope = 'ALWAYS'
      end
      when k == 'PRONOUN' then do
        c = it['C']
        if subject == '' then do
          if wordpos(c, 'I WE MY OUR') > 0 then subject = 'SELF'
          if wordpos(c, 'YOU YOUR') > 0 then subject = 'YOU'
          if wordpos(c, 'HE SHE THEY') > 0 then subject = 'THIRD'
        end
        if wordpos(c, 'I WE MY OUR') > 0 then selfAny = .true
        if wordpos(c, 'MY OUR') > 0 then possessor = 'SELF'
        if c == 'YOUR' then possessor = 'YOU'
      end
      when k == 'POWER' then do
        powers~append(it['CODE'])
        if subject == '' then if acts~items = 0 then subject = it['CODE']
      end
      when k == 'UNIT' then do
        u = .directory~new
        u['TYPE'] = it['TYPE']
        u['LOC'] = it['LOC']
        u['OWNER'] = possessor
        u['AT'] = idx
        u['REF'] = it~hasIndex('REF')
        units~append(u)
        possessor = ''
        if subject == '' then subject = 'SELF?'
      end
      when k == 'PROV' then do
        pv = .directory~new
        pv['CODE'] = it['CODE']
        pv['AT'] = idx
        provs~append(pv)
      end
      when k == 'OBJ' then do
        if it['C'] == 'dmz' then dmz = .true
        if it['C'] == 'alliance' then alliance = .true
      end
      when k == 'ACT' then do
        acts~append(it['C'])
        if it['C'] == 'ally' then alliance = .true
      end
      otherwise nop
    end
  end
  if known = 0 then do
    r['UNREAD']~append(sentence)
    return
  end
  if subject == 'SELF?' then do
    subject = ''
    do u over units
      if u['OWNER'] == 'SELF' then subject = 'SELF'
      if u['OWNER'] == 'YOU' then if subject == '' then subject = 'YOU'
    end
  end
  orders = self~embeddedOrders(items, units)
  threatSubject = subject
  condProvs = .array~new
  if hasCond & selfAny then threatSubject = 'SELF'
  -- "If you ..., I will ...": the promise is the writer's, on a condition
  r['_COND'] = ''
  r['_THEN'] = scope
  if condPart \== .nil then do
    r['_COND'] = heelTurnConditionOf(condPart, vocab)
    hasCond = .true
    if selfAny & force > 0 then subject = 'SELF'
    if selfAny then threatSubject = 'SELF'
    scope = 'COND'
    -- a threat's condition names the province it guards: if you move to GAL
    do it over condPart
      if it['K'] == 'PROV' then do
        pv = .directory~new
        pv['CODE'] = it['CODE']
        pv['AT'] = 0
        condProvs~append(pv)
      end
    end
  end
  act = self~speechAct(acts, subject, isQ, hasCond, neg, force, firstKind, dmz, alliance, threatSubject)
  r['ACTS']~append(act)
  strength = force
  if strength = 0 then strength = 0.7
  -- commitments the sender makes about its own play
  if act == 'PROMISE' | act == 'PROPOSAL' | act == 'ACCEPT' | act == 'CLAIM' | act == 'THREAT' then do
    if act == 'THREAT' then strength = 0
    if act == 'CLAIM' then strength = strength * 0.6
    if act == 'PROPOSAL' then strength = strength * 0.7
    if strength > 0 then if subject == 'SELF' | act == 'ACCEPT' | act == 'PROPOSAL' then self~commitments(r, acts, neg, orders, provs, powers, dmz, alliance, scope, strength, act)
  end
  if act == 'REQUEST' then self~requests(r, acts, neg, orders, provs, dmz)
  if act == 'PROPOSAL' then if dmz then self~requests(r, acts, 1, orders, provs, dmz)
  if act == 'THREAT' then do pv over provs
    r['THREATS']~append(pv['CODE'])
  end
  if act == 'THREAT' then do pv over condProvs
    r['THREATS']~append(pv['CODE'])
  end
  if act == 'ACCUSE' then do
    target = r['TO']~word(1)
    if powers~items > 0 then target = powers[1]
    r['ACCUSE']~append(target)
  end
  -- what a third power will do, by the sender's account (hearsay)
  if powers~items > 0 then if subject \== 'SELF' & subject \== 'YOU' then do
    do pw over powers
      if pw == sender then iterate
      hostile = .false
      do c over acts
        if vocab~isa(c, 'attack') | vocab~isa(c, 'move') | vocab~isa(c, 'lie') then hostile = .true
      end
      if hostile then do
        info = .directory~new
        info['POWER'] = pw
        info['NEG'] = neg // 2
        info['PROVS'] = provs
        info['ACCUSES'] = act == 'ACCUSE'
        r['THIRD']~append(info)
      end
    end
  end
  -- claims the board can check now
  do u over units
    if u['REF'] then iterate
    if u['OWNER'] == 'SELF' then do
      c = .directory~new
      c['KIND'] = 'UNIT_AT'
      c['TYPE'] = u['TYPE']
      c['LOC'] = u['LOC']
      r['CLAIMS']~append(c)
    end
  end
  if subject == 'SELF' then if neg // 2 = 1 then do
    hasUnitWord = .false
    do it over items
      if it['K'] == 'OBJ' then if vocab~isa(it['C'], 'unit') then hasUnitWord = .true
    end
    if hasUnitWord then do pv over provs
      c = .directory~new
      c['KIND'] = 'NO_UNITS_NEAR'
      c['PROV'] = pv['CODE']
      r['CLAIMS']~append(c)
    end
  end
::method speechAct private
  expose vocab
  use strict arg acts, subject, isQ, hasCond, neg, force, firstKind, dmz, alliance, threatSubject
  has = .directory~new
  do c over acts
    has[c] = 1
    do p over vocab~chain(c)
      has[p] = 1
    end
  end
  if has~hasIndex('accuse') then return 'ACCUSE'
  if subject == 'YOU' then if has~hasIndex('lie') | has~hasIndex('betray') | has~hasIndex('break') then return 'ACCUSE'
  if has~hasIndex('threaten') then return 'THREAT'
  if hasCond & threatSubject == 'SELF' then if has~hasIndex('attack') then if neg // 2 = 0 then return 'THREAT'
  if hasCond then if has~hasIndex('attack') & has~hasIndex('punish') then return 'THREAT'
  if has~hasIndex('apologise') then return 'APOLOGY'
  if has~hasIndex('thank') then return 'THANKS'
  if has~hasIndex('refuse') then return 'REFUSE'
  if has~hasIndex('accept') & \isQ then return 'ACCEPT'
  if has~hasIndex('request') | has~hasIndex('ask') then return 'REQUEST'
  if subject == 'YOU' & isQ & force > 0 then return 'REQUEST'
  if has~hasIndex('propose') | has~hasIndex('offer') then return 'PROPOSAL'
  if subject == 'SELF' & force > 0 then do
    if dmz | alliance then return 'PROPOSAL'
    return 'PROMISE'
  end
  if subject == 'SELF' & has~hasIndex('promise') then return 'PROMISE'
  if isQ then return 'QUESTION'
  if firstKind == 'ACT' | firstKind == 'NEGATOR' then do
    if has~hasIndex('greet') then return 'GREETING'
    return 'REQUEST'
  end
  if has~hasIndex('greet') then return 'GREETING'
  if dmz | alliance then return 'PROPOSAL'
  return 'CLAIM'
::method embeddedOrders private
  -- Orders written into the text: A BUD - SER, A VIE S A BUD - GAL,
  -- support my A BUD into SER, move A BUD to SER.
  expose vocab
  use strict arg items, units
  out = .array~new
  n = items~items
  do u over units
    at = u['AT']
    o = .directory~new
    o['TYPE'] = u['TYPE']
    o['LOC'] = u['LOC']
    o['OWNER'] = u['OWNER']
    o['ACTION'] = ''
    o['DEST'] = ''
    o['TTYPE'] = ''
    o['TLOC'] = ''
    o['TOWNER'] = ''
    k1 = .nil
    if at < n then k1 = items[at + 1]
    if k1 \== .nil then do
      select
        when k1['K'] == 'DASH' then do
          if at + 2 <= n then if items[at + 2]['K'] == 'PROV' then do
            o['ACTION'] = 'MOVE'
            o['DEST'] = items[at + 2]['CODE']
          end
        end
        when k1['T'] == 'S' | (k1['K'] == 'ACT' & k1['C'] == 'support') then do
          do j = at + 2 to min(n, at + 3)
            if items[j]['K'] == 'UNIT' then do
              o['TTYPE'] = items[j]['TYPE']
              o['TLOC'] = items[j]['LOC']
              o['ACTION'] = 'SUPPORT_HOLD'
              dj = self~destAfter(items, j)
              if dj \== '' then do
                o['ACTION'] = 'SUPPORT_MOVE'
                o['DEST'] = dj
              end
              leave
            end
          end
        end
        when k1['T'] == 'H' | (k1['K'] == 'ACT' & vocab~isa(k1['C'], 'hold')) then o['ACTION'] = 'HOLD'
        otherwise do
          dj = self~destAfter(items, at)
          if dj \== '' then o['ACTION'] = 'MOVE'
          o['DEST'] = dj
        end
      end
    end
    -- the unit is the one being supported or moved by a verb before it
    if o['ACTION'] == '' | o['ACTION'] == 'MOVE' then do
      before = ''
      do j = at - 1 to max(1, at - 3) by -1
        if items[j]['K'] == 'ACT' then do
          before = items[j]['C']
          leave
        end
      end
      if before == 'support' then do
        o['TTYPE'] = o['TYPE']
        o['TLOC'] = o['LOC']
        o['TOWNER'] = o['OWNER']
        o['TYPE'] = ''
        o['LOC'] = ''
        o['OWNER'] = ''
        -- the supporter is the writer's own unit named before the verb:
        -- MY F SEV will support your A BUD - RUM
        do v over units
          if v['AT'] >= at then leave
          if v['OWNER'] == 'SELF' then do
            o['TYPE'] = v['TYPE']
            o['LOC'] = v['LOC']
            o['OWNER'] = 'SELF'
          end
        end
        if o['DEST'] == '' then o['DEST'] = self~destAfter(items, at)
        if o['DEST'] == '' then o['ACTION'] = 'SUPPORT_HOLD'
        else o['ACTION'] = 'SUPPORT_MOVE'
      end
      else if o['ACTION'] == '' then if before \== '' then if vocab~isa(before, 'move') | vocab~isa(before, 'attack') then do
        dj = self~destAfter(items, at)
        if dj \== '' then do
          o['ACTION'] = 'MOVE'
          o['DEST'] = dj
        end
      end
    end
    if o['ACTION'] \== '' then out~append(o)
  end
  -- drop a bare unit order that is the supporter of a support in the list
  keep = .array~new
  do o over out
    dup = .false
    if o['ACTION'] == 'MOVE' & o['DEST'] == '' then dup = .true
    do q over out
      if q \== o then if q['ACTION']~left(7) == 'SUPPORT' then if q['LOC'] == o['LOC'] then if o['ACTION']~left(7) \== 'SUPPORT' then dup = .true
    end
    if \dup then keep~append(o)
  end
  return keep
::method destAfter private
  -- A destination after position at: "- SER", "to SER", "into SER".
  use strict arg items, at
  do j = at + 1 to min(items~items, at + 6)
    it = items[j]
    if it['K'] == 'PROV' then return it['CODE']
    if it['K'] == 'UNIT' then return ''
    if it['K'] == 'PUNCT' then return ''
  end
  return ''
::method commitments private
  expose vocab a
  use strict arg r, acts, neg, orders, provs, powers, dmz, alliance, scope, strength, act
  negated = neg // 2 = 1
  added = .false
  if act == 'ACCEPT' | act == 'PROPOSAL' then if dmz then do pv over provs
    self~addCommit(r, 'NOMOVE', '', pv['CODE'], '', '', '', scope, strength)
    added = .true
  end
  if added then return
  hasKeepOut = .false
  hasAttack = .false
  hasMove = .false
  hasSupport = .false
  hasHold = .false
  do c over acts
    if c == 'keep-out' then hasKeepOut = .true
    if vocab~isa(c, 'attack') then hasAttack = .true
    if vocab~isa(c, 'move') then hasMove = .true
    if vocab~isa(c, 'support') then hasSupport = .true
    if vocab~isa(c, 'hold') then hasHold = .true
  end
  -- orders written out in the sentence
  do o over orders
    if o['OWNER'] == 'YOU' then iterate
    select
      when o['ACTION'] == 'MOVE' then do
        if negated then self~addCommit(r, 'NOMOVE', '', o['DEST'], '', '', '', scope, strength)
        else self~addCommit(r, 'MOVE', (o['TYPE'] o['LOC'])~strip, o['DEST'], '', '', '', scope, strength)
        added = .true
      end
      when o['ACTION'] == 'SUPPORT_MOVE' | o['ACTION'] == 'SUPPORT_HOLD' then do
        if \negated then self~addCommit(r, 'SUPPORT', (o['TYPE'] o['LOC'])~strip, '', o['TTYPE'], o['TLOC'], o['DEST'], scope, strength)
        added = .true
      end
      when o['ACTION'] == 'HOLD' then do
        if \negated then self~addCommit(r, 'HOLD', (o['TYPE'] o['LOC'])~strip, o['LOC'], '', '', '', scope, strength)
        added = .true
      end
      otherwise nop
    end
  end
  if added then return
  -- "I will not move into GAL", "I will stay out of GAL"
  if hasKeepOut & \negated then do pv over provs
    self~addCommit(r, 'NOMOVE', '', pv['CODE'], '', '', '', scope, strength)
    added = .true
  end
  if (hasMove | hasAttack) & negated then do pv over provs
    self~addCommit(r, 'NOMOVE', '', pv['CODE'], '', '', '', scope, strength)
    added = .true
  end
  if (hasMove | hasAttack) & \negated & \hasSupport then do pv over provs
    self~addCommit(r, 'MOVE', '', pv['CODE'], '', '', '', scope, strength)
    added = .true
  end
  -- "I will not attack you"
  if hasAttack & negated & provs~items = 0 then do
    self~addCommit(r, 'NOATTACK', '', '', '', '', '', scope, strength)
    added = .true
  end
  if alliance & \negated & \added then self~addCommit(r, 'ALLY', '', '', '', '', '', scope, strength * 0.5)
::method addCommit private
  use strict arg r, kind, unit, prov, ttype, tloc, tdest, scope, strength
  c = .directory~new
  c['KIND'] = kind
  c['UNIT'] = unit
  c['PROV'] = prov
  c['TTYPE'] = ttype
  c['TLOC'] = tloc
  c['TDEST'] = tdest
  c['SCOPE'] = scope
  c['COND'] = ''
  c['THEN'] = ''
  if scope == 'COND' then do
    c['COND'] = r['_COND']
    c['THEN'] = r['_THEN']
  end
  c['STRENGTH'] = format(min(1, strength),, 2)
  r['COMMITS']~append(c)
::method requests private
  use strict arg r, acts, neg, orders, provs, dmz
  negated = neg // 2 = 1
  added = .false
  do o over orders
    if o['ACTION'] == 'SUPPORT_MOVE' | o['ACTION'] == 'SUPPORT_HOLD' then do
      q = heelTurnRequest()
      q['KIND'] = 'SUPPORT'
      q['TTYPE'] = o['TTYPE']
      q['TLOC'] = o['TLOC']
      q['TDEST'] = o['DEST']
      r['REQUESTS']~append(q)
      added = .true
    end
  end
  if added then return
  if negated | dmz then do pv over provs
    q = heelTurnRequest()
    q['KIND'] = 'NOMOVE'
    q['PROV'] = pv['CODE']
    r['REQUESTS']~append(q)
  end
::method judge private
  -- Tone label, intent and the tells of a message, from counts only.
  expose a
  use strict arg r
  t = r['TONE']
  acts = r['ACTS']
  cnt = .directory~new
  do x over .array~of('PROMISE', 'PROPOSAL', 'REQUEST', 'THREAT', 'ACCEPT', 'REFUSE', 'ACCUSE', 'THANKS', 'APOLOGY', 'GREETING', 'QUESTION', 'CLAIM')
    cnt[x] = 0
  end
  do x over acts
    cnt[x] += 1
  end
  r['COUNTS'] = cnt
  warmth = t['warm'] + cnt['THANKS'] + cnt['GREETING'] + cnt['APOLOGY'] + t['flattery'] * 0.5
  coldness = t['cold'] + cnt['THREAT'] * 2 + cnt['ACCUSE'] * 2 + cnt['REFUSE']
  select
    when coldness > warmth & coldness > 0 then label = 'HOSTILE'
    when t['flattery'] >= 2 then label = 'FLATTERING'
    when t['fear'] >= 1 then label = 'PLEADING'
    when t['urgency'] >= 1 & cnt['REQUEST'] > 0 then label = 'PRESSING'
    when warmth > 0 then label = 'FRIENDLY'
    otherwise label = 'NEUTRAL'
  end
  r['TONE_LABEL'] = label
  concrete = 0
  do c over r['COMMITS']
    if c['PROV'] \== '' | c['TLOC'] \== '' | c['UNIT'] \== '' then concrete += 1
  end
  flags = ''
  if t['assurance'] >= 2 then flags = flags 'OVERASSURED'
  if t['assurance'] >= 1 & concrete = 0 then flags = flags 'EMPTY_ASSURANCE'
  if t['hedge'] >= 2 then flags = flags 'HEDGED'
  if cnt['PROMISE'] + cnt['PROPOSAL'] > 0 & concrete = 0 then flags = flags 'VAGUE'
  asks = cnt['REQUEST']
  gives = cnt['PROMISE'] + cnt['ACCEPT']
  if asks >= 2 & gives = 0 then flags = flags 'TAKER'
  r['FLAGS'] = flags~strip
  select
    when cnt['THREAT'] > 0 then intent = 'COERCE'
    when cnt['ACCUSE'] > 0 & r['ACCUSE']~items > 0 then do
      intent = 'ACCUSE'
      do target over r['ACCUSE']
        if wordpos(target, r['TO']) = 0 then intent = 'WEDGE'
      end
    end
    when r['THIRD']~items > 0 then intent = 'WEDGE'
    when gives + cnt['PROPOSAL'] > 0 then intent = 'COOPERATE'
    when asks > 0 then intent = 'ASK'
    when cnt['QUESTION'] > 0 then intent = 'PROBE'
    otherwise intent = 'INFORM'
  end
  r['INTENT'] = intent
::method summary
  use strict arg r
  acts = r['ACTS']~makeString('L', ',')
  commits = .array~new
  do c over r['COMMITS']
    commits~append(c['KIND']':'c['UNIT']':'c['PROV']':'c['TLOC']'>'c['TDEST']'@'c['STRENGTH'])
  end
  reqs = .array~new
  do q over r['REQUESTS']
    reqs~append(q['KIND']':'q['TLOC']'>'q['TDEST']':'q['PROV'])
  end
  refs = .array~new
  do f over r['REFS']
    refs~append(f['PHRASE']'->'f['VERDICT']'('f['CANDIDATES']')')
  end
  return r['FROM'] 'tone='r['TONE_LABEL'] 'intent='r['INTENT'] 'flags='r['FLAGS'] 'acts='acts 'commits='commits~makeString('L', ';') 'requests='reqs~makeString('L', ';') 'refs='refs~makeString('L', ';')
::method module_version class
  return '0.1r6'
::method module_version
  return self~class~module_version
::method module_lastChanged class
  return '2026-11-27'
::method module_lastChanged
  return self~class~module_lastChanged

/* Writing: chosen acts said in the small English the reader reads back.
   Powers by name (England, not ENG, which is also the Channel); places by
   code; units as A BUD / F STP/SC. */
::class HeelTurnMessageWriter public
::method init
  expose warmth brevity
  use strict arg warmth, brevity
::method powerName class
  use strict arg code
  names = 'AUS=Austria ENG=England FRA=France GER=Germany ITA=Italy RUS=Russia TUR=Turkey'
  do pair over names~makeArray(' ')
    parse var pair c '=' nm
    if c == code then return nm
  end
  return code
::method say
  -- act: a directory with ACT and its fields. Returns one sentence.
  use strict arg act
  k = act['ACT']
  select
    when k == 'GREET' then return 'Hello' self~class~powerName(act['TO'])'.'
    when k == 'ALLY' then do
      if act['AGAINST'] \== '' then return 'I propose an alliance against' self~class~powerName(act['AGAINST'])'.'
      return 'I propose an alliance between us.'
    end
    when k == 'DMZ' then return 'I propose a DMZ in' act['PROV']'. I will not move into' act['PROV'] 'this turn.'
    when k == 'AGREE_DMZ' then return 'Agreed: ' || act['PROV'] 'is a DMZ. I will not move into' act['PROV'] 'this turn.'
    when k == 'REFUSE_DMZ' then return 'I cannot agree to a DMZ in' act['PROV'] 'this turn.'
    when k == 'NOMOVE' then return 'I will not move into' act['PROV'] 'this turn.'
    when k == 'NOATTACK' then return 'I will not attack you this turn.'
    when k == 'MOVE' then return 'My' act['UNIT'] 'will move to' act['PROV'] 'this turn.'
    when k == 'HOLD' then return 'My' act['UNIT'] 'will hold this turn.'
    when k == 'ASK_SUPPORT' then return 'Please support my' act['UNIT'] '-' act['PROV']'.'
    when k == 'GIVE_SUPPORT' then return 'I will support your' act['UNIT'] '-' act['PROV']'.'
    when k == 'GIVE_SUPPORT_HOLD' then return 'I will support your' act['UNIT'] 'to hold.'
    when k == 'REFUSE_SUPPORT' then return 'I cannot support your' act['UNIT'] 'this turn.'
    when k == 'ACCUSE' then return 'You broke your promise about' act['PROV']'. I will not trust you again.'
    when k == 'THREAT' then return 'If you move against me again, I will attack you.'
    when k == 'THANK' then return 'Thank you for keeping your word.'
    when k == 'CLARIFY_MINE' then return 'Which of my units do you mean for' act['PROV']'?'
    when k == 'CLARIFY_YOURS' then return 'Which of your units do you mean for' act['PROV']'?'
    when k == 'CONFIRM_NOMOVE' then return 'Please confirm that you will not move into' act['PROV'] 'this turn.'
    when k == 'ASK_PLANS' then return 'What are your plans for' act['PROV']'?'
    when k == 'WARN' then return self~class~powerName(act['POWER']) 'can attack you in' act['PROV']'.'
    otherwise return ''
  end
::method module_version class
  return '0.1r6'
::method module_version
  return self~class~module_version
::method module_lastChanged class
  return '2026-11-27'
::method module_lastChanged
  return self~class~module_lastChanged

::routine heelTurnRequest
  q = .directory~new
  do key over .array~of('KIND', 'TTYPE', 'TLOC', 'TDEST', 'PROV')
    q[key] = ''
  end
  return q

::routine heelTurnCondSplit
  -- array(condItems, mainItems) when the sentence has a condition word, else
  -- .nil. A condition that opens the sentence runs to the first comma or
  -- "then"; a later one runs to the end.
  use strict arg items
  n = items~items
  at = 0
  do idx = 1 to n
    if items[idx]['K'] == 'CONDWORD' then do
      at = idx
      leave
    end
  end
  if at = 0 then return .nil
  cond = .array~new
  main = .array~new
  first = 1
  do while first <= n
    if items[first]['K'] \== 'PUNCT' then leave
    first += 1
  end
  if at = first then do
    stop = n
    do k = at + 1 to n
      if items[k]['K'] == 'PUNCT' then if items[k]['C'] == ',' then do
        stop = k
        leave
      end
      if items[k]['T']~lower == 'then' then do
        stop = k
        leave
      end
      -- no comma: the main clause starts at the writer's own I / we / my
      if k > at + 1 then if items[k]['K'] == 'PRONOUN' then if wordpos(items[k]['C'], 'I WE MY OUR') > 0 then do
        stop = k - 1
        leave
      end
    end
    do k = 1 to n
      if k >= at & k <= stop then cond~append(items[k])
      else main~append(items[k])
    end
  end
  else do k = 1 to n
    if k >= at then cond~append(items[k])
    else main~append(items[k])
  end
  return .array~of(cond, main)

::routine heelTurnHoldAct
  use strict arg c
  return wordpos(c, 'hold defend') > 0

::routine heelTurnConditionOf public
  -- The condition of a conditional promise, when it is about the reader's own
  -- orders and the published orders can show it: NOMOVE:P, MOVE:P, NOATTACK:,
  -- ATTACK:, SUPPORT:, NOSUPPORT:. '' when it cannot be checked (then the
  -- promise is never planned on and never judged).
  use strict arg condItems, vocab
  subject = ''
  neg = 0
  prov = ''
  hasMe = .false
  kind = ''
  do it over condItems
    k = it['K']
    if k == 'PRONOUN' then do
      if subject == '' then subject = it['C']
      if wordpos(it['C'], 'ME US') > 0 then hasMe = .true
    end
    if k == 'NEGATOR' | k == 'NEGVERB' then neg += 1
    if k == 'PROV' then if prov == '' then prov = it['CODE']
    if k == 'ACT' then if kind == '' then do
      c = it['C']
      if c == 'keep-out' then kind = 'KEEPOUT'
      else if vocab~isa(c, 'support') then kind = 'SUPPORT'
      else if vocab~isa(c, 'attack') then kind = 'ATTACK'
      else if vocab~isa(c, 'move') then kind = 'MOVE'
    end
  end
  if subject \== 'YOU' then return ''
  negated = neg // 2 = 1
  select
    when kind == 'KEEPOUT' & prov \== '' then do
      if negated then return 'MOVE:'prov
      return 'NOMOVE:'prov
    end
    when (kind == 'MOVE' | kind == 'ATTACK') & prov \== '' then do
      if negated then return 'NOMOVE:'prov
      return 'MOVE:'prov
    end
    when kind == 'ATTACK' & hasMe then do
      if negated then return 'NOATTACK:'
      return 'ATTACK:'
    end
    when kind == 'SUPPORT' then do
      if negated then return 'NOSUPPORT:'
      return 'SUPPORT:'
    end
    otherwise return ''
  end
