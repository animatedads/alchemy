/* HeelTurnMind.cls - Heel Turn SLAM: memory, the truth ledger and relations.
   Architecture: Tom Dyer. Code: Claude (Opus 5.5).
   Every call is fresh, as for any runner: what Heel Turn knows of the past
   is what it wrote in its own MEMORY block. The ledger holds promises made
   to it (IN), promises it made (OUT, with whether it meant them), lies it
   caught (LIE) and lies it told (MYLIE), so its own stories stay straight.

   Whether a promise is kept is decided by Reasoned Thought (the estate's
   ThoughtNetwork and OrdinalEvidenceCombiner), never by a score. One
   proposition per promise: "P keeps commitment c", settle floor DOCUMENTARY.
     TESTIMONY    the promise itself (binds ORDERS_OF_SUBJECT); hearsay from
                  a third power (REBUT), undercut for PARTIALITY when the
                  speaker is the subject's rival;
     STYLOMETRIC  tells (OVERASSURED, EMPTY_ASSURANCE, HEDGED, VAGUE, TAKER):
                  visible, below the assert floor, never decisive;
     DOCUMENTARY  the orders the framework publishes, and the board it sends
                  (a promise that cannot be done; a claim the board denies).
                  As the rules read an order as a contract, an impossible
                  promise counts as meant;
     PROVENANCE   the framework's mail header, binding MAIL_ENVELOPE: who
                  sent it, never that it is true, so INELIGIBLE here.
   A lie is a DOCUMENTARY rebuttal. DISPUTED, UNDETERMINED and HINT are
   CANNOT TELL: Heel Turn does not rely on such a promise. Trust moves only
   on documentary verdicts; tone and hearsay never move it.
   Memory lines (one fact a line, fields split by |):
     HT|version  TRUST|P|v  REL|P|ALLY/ENEMY/NEUTRAL/TARGET|year
     IN|year|phase|from|kind|unit|prov|ttype|tloc|tdest|scope|strength|status|targets|flags
     HS|year|phase|from|about|partial  (hearsay: from says about will move against me)
     OUT|year|phase|to|kind|unit|prov|ttype|tloc|tdest|sincere|status
     LIE|P|year|phase|kind|detail   MYLIE|P|year|phase|kind|detail
     GROUND|year|phase|provinces    ATK|P|year|count   SAID|year|phase|P|key */
::requires 'HeelTurnPlanner.cls'
::requires 'HeelTurnPress.cls'
::requires 'ReasonedThought.cls'

::class HeelTurnMind public
::attribute trust get
::attribute events get
::attribute keptBy get
::attribute brokeBy get
::attribute requests get
::attribute threatsBy get
::method init
  expose view map a policy me trust rels ins outs lies mylies grounds atk said events keptBy brokeBy requests threatsBy hearsay decisions
  use strict arg memoryLines, view, map, a, policy
  hearsay = .array~new
  decisions = .directory~new
  me = view~me
  trust = .directory~new
  rels = .directory~new
  ins = .array~new
  outs = .array~new
  lies = .array~new
  mylies = .array~new
  grounds = .array~new
  atk = .directory~new
  said = .directory~new
  events = .array~new
  keptBy = .directory~new
  brokeBy = .directory~new
  requests = .directory~new
  threatsBy = .directory~new
  start = policy~value('trust')
  do p over map~powers
    if p == me then iterate
    trust[p] = start
  end
  do line over memoryLines
    f = heelTurnSplit(line)
    if f~items = 0 then iterate
    known = .true
    select
      when f[1] == 'TRUST' then if f~items >= 3 then if f[3]~datatype('N') then trust[f[2]] = f[3]
      when f[1] == 'REL' then if f~items >= 4 then rels[f[2]] = .array~of(f[3], f[4])
      when f[1] == 'IN' then if f~items >= 15 then ins~append(heelTurnFields(f, 'TAG YEAR PHASE FROM KIND UNIT PROV TTYPE TLOC TDEST SCOPE STRENGTH STATUS TARGETS FLAGS'))
      when f[1] == 'OUT' then if f~items >= 13 then outs~append(heelTurnFields(f, 'TAG YEAR PHASE TO KIND UNIT PROV TTYPE TLOC TDEST SINCERE STATUS'))
      when f[1] == 'LIE' then if f~items >= 6 then lies~append(heelTurnFields(f, 'TAG POWER YEAR PHASE KIND DETAIL'))
      when f[1] == 'MYLIE' then if f~items >= 6 then mylies~append(heelTurnFields(f, 'TAG POWER YEAR PHASE KIND DETAIL'))
      when f[1] == 'GROUND' then if f~items >= 4 then grounds~append(heelTurnFields(f, 'TAG YEAR PHASE PROVS'))
      when f[1] == 'ATK' then if f~items >= 4 then atk[f[2]'|'f[3]] = f[4]
      when f[1] == 'HS' then if f~items >= 6 then hearsay~append(heelTurnFields(f, 'TAG YEAR PHASE FROM ABOUT PARTIAL'))
      when f[1] == 'SAID' then if f~items >= 5 then said[f[2]'|'f[3]'|'f[4]'|'f[5]] = 1
      when f[1] == 'HT' then nop
      otherwise known = .false
    end
    if \known then self~event('MEMORY_LINE_NOT_READ' line~left(60))
  end
  -- Memory written by the designer prompt's own words is not ours: an
  -- unknown line is ignored, so a tampered memory cannot steer the ledger.
::method ledgerIn
  expose ins
  return ins
::method event private
  expose events
  use strict arg text
  events~append(text)
::method phaseKey
  use strict arg year, phase
  return year'|'phase
::method movementPhaseNow
  -- The movement phase this call's promises are about.
  expose view
  phase = view~phase
  if phase~right(8) == 'MOVEMENT' then return view~year'|'phase
  if phase == 'SPRING_RETREATS' then return view~year'|FALL_MOVEMENT'
  return view~year + 1'|SPRING_MOVEMENT'
::method nextMovementPhase
  expose view
  parse value self~movementPhaseNow with y '|' p
  if p == 'SPRING_MOVEMENT' then return y'|FALL_MOVEMENT'
  return y + 1'|SPRING_MOVEMENT'
::method verify
  -- Check open promises made to me against the published orders, and count
  -- moves into my ground and supports of my units.
  expose view map ins grounds atk trust keptBy brokeBy me policy
  use strict arg results
  byPhase = .directory~new
  do r over results
    if r['PHASE']~right(8) \== 'MOVEMENT' then iterate
    key = r['YEAR']'|'r['PHASE']
    if \byPhase~hasIndex(key) then byPhase[key] = .directory~new
    d = byPhase[key]
    if \d~hasIndex(r['POWER']) then d[r['POWER']] = .array~new
    d[r['POWER']]~append(heelTurnParseOrder(r['LINE']))
  end
  do key over heelTurnSorted(byPhase~allIndexes)
    orders = byPhase[key]
    parse var key y '|' ph
    do c over ins
      if c['STATUS'] \== 'OPEN' then iterate
      due = .false
      if c['YEAR']'|'c['PHASE'] == key then due = .true
      if c['SCOPE'] == 'ALWAYS' then if (c['YEAR'] < y) | (c['YEAR'] = y & c['PHASE'] <= ph) then due = .true
      if \due then iterate
      list = .array~new
      if orders~hasIndex(c['FROM']) then list = orders[c['FROM']]
      verdict = self~check(c, list)
      if verdict == 'KEPT' then do
        c['STATUS'] = 'KEPT'
        c['NEW'] = 1
        c['WHEN'] = key
      end
      if verdict == 'BROKEN' then do
        c['STATUS'] = 'BROKEN'
        c['NEW'] = 1
        c['WHEN'] = key
      end
    end
    -- hostile moves into my ground, and supports given to me
    mine = ''
    do g over grounds
      if g['YEAR']'|'g['PHASE'] == key then mine = g['PROVS']
    end
    if mine \== '' then do p over heelTurnSorted(orders~allIndexes)
      if p == me then iterate
      hits = 0
      helps = 0
      do o over orders[p]
        if o['ACTION'] == 'MOVE' then if wordpos(map~base(o['DEST']), mine) > 0 then hits += 1
        if o['ACTION'] == 'SUPPORT_MOVE' | o['ACTION'] == 'SUPPORT_HOLD' then if wordpos(map~base(o['TLOC']), mine) > 0 then if self~wasMine(o['TTYPE'], o['TLOC']) then helps += 1
      end
      if hits > 0 then do
        k = p'|'y
        if \atk~hasIndex(k) then atk[k] = 0
        atk[k] += hits
        trust[p] = heelTurnClip(trust[p] - min(0.3, 0.12 * hits))
        self~event('ATTACKED_BY' p hits key)
      end
      if helps > 0 then do
        trust[p] = heelTurnClip(trust[p] + 0.05 * helps)
        self~event('SUPPORTED_BY' p helps key)
      end
    end
  end
::method wasMine private
  -- A support of a unit that stands where one of mine stands now.
  expose a
  use strict arg ttype, tloc
  do u over a~myUnits
    if u['TYPE'] == ttype then if u['BASE'] == a~map~base(tloc) then return .true
  end
  return .false
::method check private
  expose map
  use strict arg c, orders
  kind = c['KIND']
  select
    when kind == 'NOMOVE' then do
      do o over orders
        if o['ACTION'] == 'MOVE' then if map~base(o['DEST']) == map~base(c['PROV']) then return 'BROKEN'
      end
      return 'KEPT'
    end
    when kind == 'NOATTACK' | kind == 'ALLY' then do
      do o over orders
        if o['ACTION'] == 'MOVE' then if wordpos(map~base(o['DEST']), c['TARGETS']) > 0 then return 'BROKEN'
      end
      return 'KEPT'
    end
    when kind == 'MOVE' then do
      do o over orders
        if o['ACTION'] \== 'MOVE' then iterate
        if map~base(o['DEST']) \== map~base(c['PROV']) then iterate
        if c['UNIT'] == '' then return 'KEPT'
        if o['TYPE'] o['LOC'] == c['UNIT'] then return 'KEPT'
      end
      return 'BROKEN'
    end
    when kind == 'SUPPORT' then do
      do o over orders
        if wordpos(o['ACTION'], 'SUPPORT_MOVE SUPPORT_HOLD') = 0 then iterate
        if map~base(o['TLOC']) \== map~base(c['TLOC']) then iterate
        if c['TDEST'] == '' then return 'KEPT'
        if map~base(o['DEST']) == map~base(c['TDEST']) then return 'KEPT'
      end
      return 'BROKEN'
    end
    when kind == 'HOLD' then do
      do o over orders
        if o['TYPE'] o['LOC'] == c['UNIT'] then if o['ACTION'] == 'MOVE' then return 'BROKEN'
      end
      return 'KEPT'
    end
    otherwise return 'NONE'
  end
::method caught private
  -- A lie (or a promise broken, which the rules treat as the same thing).
  expose lies trust policy
  use strict arg power, year, phase, kind, detail
  lies~append(heelTurnFields(.array~of('LIE', power, year, phase, kind, detail), 'TAG POWER YEAR PHASE KIND DETAIL'))
  factor = 0.55 - 0.25 * policy~value('suspicion')
  trust[power] = heelTurnClip(trust[power] * factor)
  self~event('LIE' power kind detail year phase)
::method absorb
  -- What this call's inbox says: commitments into the ledger at the
  -- strength the sender wrote it with; claims checked against the board.
  expose view map a ins trust requests threatsBy me policy hearsay
  use strict arg readings
  parse value self~movementPhaseNow with y '|' ph
  parse value self~nextMovementPhase with ny '|' nph
  targets = a~myGround~makeString('L', ' ')
  do r over readings
    from = r['FROM']
    if from == me then iterate
    if \trust~hasIndex(from) then iterate
    flags = r['FLAGS']~changestr(' ', ',')
    do c over r['COMMITS']
      feasible = self~feasible(from, c)
      cy = y
      cp = ph
      if c['SCOPE'] == 'NEXT' then do
        cy = ny
        cp = nph
      end
      if self~hasIn(from, c, cy, cp) then iterate
      status = 'OPEN'
      if feasible \== '' then status = 'IMPOSSIBLE'
      f = .array~of('IN', cy, cp, from, c['KIND'], c['UNIT'], map~base(c['PROV']), c['TTYPE'], c['TLOC'], c['TDEST'], c['SCOPE'], c['STRENGTH'], status, targets, flags)
      e = heelTurnFields(f, 'TAG YEAR PHASE FROM KIND UNIT PROV TTYPE TLOC TDEST SCOPE STRENGTH STATUS TARGETS FLAGS')
      if feasible \== '' then do
        e['NEW'] = 1
        e['WHEN'] = view~year'|'view~phase
        e['WHY'] = feasible
      end
      ins~append(e)
    end
    do c over r['CLAIMS']
      bad = self~falseClaim(from, c)
      if bad \== '' then self~caught(from, view~year, view~phase, 'FALSE_CLAIM', bad)
    end
    if r['THREATS']~items > 0 | wordpos('THREAT', r['ACTS']~makeString('L', ' ')) > 0 then do
      threatsBy[from] = r['THREATS']
      self~event('THREAT' from r['THREATS']~makeString('L', ' '))
    end
    -- hearsay about a third power is recorded as TESTIMONY against that
    -- power's promises; PARTIALITY when the speaker is not its ally and
    -- borders it. It never moves trust.
    do info over r['THIRD']
      third = info['POWER']
      if third == me | \trust~hasIndex(third) then iterate
      if info['NEG'] = 1 then iterate
      partial = 0
      if self~relOf(from) \== 'ALLY' then partial = 1
      hearsay~append(heelTurnFields(.array~of('HS', y, ph, from, third, partial), 'TAG YEAR PHASE FROM ABOUT PARTIAL'))
      self~event('HEARSAY' from 'about' third 'partial='partial)
    end
    if \requests~hasIndex(from) then requests[from] = .array~new
    do q over r['REQUESTS']
      requests[from]~append(q)
    end
  end
::method judge
  -- Build the ThoughtNetwork from the ledger and let the combiner decide.
  -- New documentary verdicts move trust once: a lie, or a kept promise.
  expose ins hearsay decisions trust keptBy brokeBy
  net = .ThoughtNetwork~new
  idx = 0
  do e over ins
    idx += 1
    id = 'K'idx
    e['PID'] = id
    net~propose(id, e['FROM'] 'keeps' e['KIND'] (e['UNIT'] e['PROV'] e['TLOC'] e['TDEST'])~space, 'DOCUMENTARY', 'TESTIMONY', .array~of('ORDERS_OF_SUBJECT', 'BOARD_STATE'))
    u = .Utterance~new('u'id, 'mail from' e['FROM'])
    u~assert('SUPPORT', 'TESTIMONY', id, , 'ORDERS_OF_SUBJECT', 'the promise, in the sender''s own words', 't'id)
    u~assert('SUPPORT', 'PROVENANCE', id, , 'MAIL_ENVELOPE', 'framework header: who sent it, not that it is true')
    do flag over e['FLAGS']~makeArray(',')
      if flag~strip \== '' then u~assert('REBUT', 'STYLOMETRIC', id, , 'GENERAL', 'tell' flag~strip)
    end
    select
      when e['STATUS'] == 'KEPT' then u~assert('SUPPORT', 'DOCUMENTARY', id, , 'ORDERS_OF_SUBJECT', 'published orders match')
      when e['STATUS'] == 'BROKEN' then u~assert('REBUT', 'DOCUMENTARY', id, , 'ORDERS_OF_SUBJECT', 'published orders contradict')
      when e['STATUS'] == 'IMPOSSIBLE' then u~assert('REBUT', 'DOCUMENTARY', id, , 'BOARD_STATE', 'the board: it cannot be done')
      otherwise nop
    end
    net~admit(u)
  end
  hidx = 0
  do h over hearsay
    hidx += 1
    do e over ins
      if e['FROM'] \== h['ABOUT'] then iterate
      if wordpos(e['KIND'], 'NOMOVE NOATTACK ALLY') = 0 then iterate
      if e['STATUS'] \== 'OPEN' then iterate
      if e['YEAR'] \= h['YEAR'] | e['PHASE'] \== h['PHASE'] then if e['SCOPE'] \== 'ALWAYS' then iterate
      u = .Utterance~new('h'hidx || e['PID'], h['FROM'] 'says' h['ABOUT'] 'will move against me')
      gid = 'g'hidx || e['PID']
      u~assert('REBUT', 'TESTIMONY', e['PID'], , 'ORDERS_OF_SUBJECT', 'hearsay from' h['FROM'], gid)
      if h['PARTIAL'] = 1 then u~assert('UNDERCUT', 'TESTIMONY', e['PID'], gid, 'GENERAL', 'PARTIALITY:' h['FROM'] 'gains if I fight' h['ABOUT'])
      net~admit(u)
    end
  end
  decisions = .directory~new
  do e over ins
    d = net~assess(e['PID'])
    decisions[e['PID']] = d
    e['VERDICT'] = d['status']
    if e~hasIndex('NEW') then do
      if d['stance'] == 'CONTRA' & d['rebutTier'] >= 3 then do
        detail = (e['UNIT'] e['PROV'] e['TLOC'] e['TDEST'])~space~changestr(' ', '_')
        if e~hasIndex('WHY') then detail = e['WHY']
        parse value e['WHEN'] with wy '|' wp
        kind = 'BROKE_'e['KIND']
        if e['STATUS'] == 'IMPOSSIBLE' then kind = 'IMPOSSIBLE_'e['KIND']
        self~caught(e['FROM'], wy, wp, kind, detail)
        brokeBy[e['FROM']] = e
      end
      if d['settled'] then do
        trust[e['FROM']] = heelTurnClip(trust[e['FROM']] + 0.06 * e['STRENGTH'] + 0.02)
        keptBy[e['FROM']] = e
        self~event('KEPT' e['FROM'] e['KIND'] (e['UNIT'] e['PROV'] e['TLOC'] e['TDEST'])~space e['WHEN'] 'SETTLED')
      end
      e~remove('NEW')
    end
  end
  return net
::method relied
  -- Promises Heel Turn may plan on this phase: PRO and assertible, not
  -- disputed. Everything else is CANNOT TELL and the board is played as if
  -- the promise had not been made.
  expose ins decisions
  parse value self~movementPhaseNow with y '|' ph
  out = .array~new
  do e over ins
    if e['STATUS'] \== 'OPEN' then iterate
    if e['YEAR'] \= y | e['PHASE'] \== ph then if e['SCOPE'] \== 'ALWAYS' then iterate
    if \decisions~hasIndex(e['PID']) then iterate
    d = decisions[e['PID']]
    if d['disputed'] then iterate
    if wordpos(d['status'], 'SUPPORTED SETTLED') = 0 then iterate
    if self~recentLies(e['FROM']) > 0 then iterate
    out~append(e)
  end
  return out
::method cannotTell
  expose ins decisions
  parse value self~movementPhaseNow with y '|' ph
  out = .array~new
  do e over ins
    if e['STATUS'] \== 'OPEN' then iterate
    if e['YEAR'] \= y | e['PHASE'] \== ph then if e['SCOPE'] \== 'ALWAYS' then iterate
    if \decisions~hasIndex(e['PID']) then iterate
    d = decisions[e['PID']]
    if d['disputed'] | wordpos(d['status'], 'SUPPORTED SETTLED') = 0 then out~append(e)
  end
  return out
::method decisionFor
  expose decisions
  use strict arg e
  if \e~hasIndex('PID') then return .nil
  if decisions~hasIndex(e['PID']) then return decisions[e['PID']]
  return .nil
::method hasIn private
  expose ins map
  use strict arg from, c, y, ph
  do e over ins
    if e['FROM'] \== from then iterate
    if e['YEAR'] \= y | e['PHASE'] \== ph then iterate
    if e['KIND'] \== c['KIND'] then iterate
    if e['PROV'] \== map~base(c['PROV']) then iterate
    if e['TLOC'] \== c['TLOC'] then iterate
    return .true
  end
  return .false
::method feasible private
  -- '' when the promise could be done, else why it cannot.
  expose view map
  use strict arg from, c
  if c['UNIT'] == '' then return ''
  parse value c['UNIT'] with utype loc
  found = .false
  do u over view~units
    if u['OWNER'] == from then if u['TYPE'] == utype then if u['BASE'] == map~base(loc) then do
      found = .true
      loc = u['LOC']
    end
  end
  if \found then return 'NO_UNIT_'utype'_'loc
  if c['KIND'] == 'MOVE' then if \map~reaches(utype, loc, c['PROV']) then do
    if utype == 'A' then if map~convoyRoute(view~units, loc, c['PROV']) then return ''
    return 'CANNOT_REACH_'utype'_'loc'_'c['PROV']
  end
  if c['KIND'] == 'SUPPORT' then do
    aim = c['TLOC']
    if c['TDEST'] \== '' then aim = c['TDEST']
    if \map~reaches(utype, loc, aim) then return 'CANNOT_SUPPORT_'utype'_'loc'_'aim
  end
  return ''
::method falseClaim private
  expose view map
  use strict arg from, c
  if c['KIND'] == 'UNIT_AT' then do
    do u over view~units
      if u['OWNER'] == from then if u['TYPE'] == c['TYPE'] then if u['BASE'] == map~base(c['LOC']) then return ''
    end
    return 'NO_'c['TYPE']'_'c['LOC']
  end
  if c['KIND'] == 'NO_UNITS_NEAR' then do
    do u over view~units
      if u['OWNER'] \== from then iterate
      if u['BASE'] == c['PROV'] then return 'UNIT_IN_'c['PROV']
      if map~reaches(u['TYPE'], u['LOC'], c['PROV']) then return 'UNIT_NEXT_TO_'c['PROV']
    end
  end
  return ''
::method recentLies
  expose lies view
  use strict arg power
  n = 0
  do e over lies
    if e['POWER'] == power then if e['YEAR'] >= view~year - 2 then n += 1
  end
  return n
::method recentAttacks
  expose atk view
  use strict arg power
  n = 0
  do y = view~year - 1 to view~year
    if atk~hasIndex(power'|'y) then n += atk[power'|'y]
  end
  return n
::method relOf
  expose rels
  use strict arg power
  if rels~hasIndex(power) then return rels[power][1]
  return 'NEUTRAL'
::method context
  -- Conditions that hold now, for the policy's conditional settings.
  -- With a power: conditions about that power too (weak, betrayed, gain).
  expose view a me
  use strict arg power = ''
  ctx = .directory~new
  if view~year <= 1902 then ctx['early'] = 1
  if view~year >= 1907 then ctx['late'] = 1
  if a~leader == me then ctx['leader'] = 1
  if self~recentAttacks(power) > 0 then ctx['attacked'] = 1
  if power \== '' then do
    if self~recentLies(power) > 0 then ctx['betrayed'] = 1
    if a~centreCount[power] < a~centreCount[me] - 1 then ctx['weak'] = 1
    if a~contact(power) <= 1 then ctx['weak'] = 1
    if a~centreCount[power] > a~centreCount[me] + 1 then ctx['strong'] = 1
    do g over a~groundOf(power)
      if a~map~isCentre(g) then do u over a~myUnits
        if a~map~reaches(u['TYPE'], u['LOC'], g) then ctx['gain'] = 1
      end
    end
    if ctx~hasIndex('gain') | ctx~hasIndex('attacked') then ctx['needed'] = 1
  end
  return ctx
::method relations
  -- Who is an ally, an enemy, or the one to stab, from trust, geography,
  -- the board's leader, caught lies and attacks, and the policy.
  expose view a policy me rels trust
  pol = policy
  ctx = self~context
  alive = a~alive
  scored = .array~new
  do p over alive
    if p == me then iterate
    s = 2 * (trust[p] - 0.5)
    if a~isNeighbour(p) then s += pol~value('allyNear', ctx) - 0.5
    else s += (pol~value('allyFar', ctx) - 0.4) * 0.8
    if p == a~leader then if a~centreCount[p] > a~centreCount[me] then s += (pol~value('bandwagon', ctx) - 0.3) - (pol~value('balance', ctx) - 0.4) * 1.5
    s -= self~recentLies(p) * 1.2 * pol~value('retaliate', ctx)
    s -= self~recentAttacks(p) * 0.4
    if self~relOf(p) == 'ALLY' | self~relOf(p) == 'TARGET' then s += 0.4 * pol~value('loyal', ctx)
    scored~append((50000 - format(s * 100,, 0))~right(6, '0') p)
  end
  scored = scored~sort
  allies = 1
  if pol~value('alliance', ctx) >= 0.75 then allies = 2
  out = .directory~new
  taken = 0
  do entry over scored
    s = (50000 - entry~word(1)) / 100
    p = entry~word(2)
    rel = 'NEUTRAL'
    if s < -0.4 then rel = 'ENEMY'
    if self~recentLies(p) > 0 then if pol~value('retaliate', self~context(p)) >= 0.45 then rel = 'ENEMY'
    if rel == 'NEUTRAL' then if taken < allies then if s > -0.1 then do
      rel = 'ALLY'
      taken += 1
    end
    d = .directory~new
    d['REL'] = rel
    d['TRUST'] = trust[p]
    d['SCORE'] = s
    out[p] = d
  end
  -- the stab: one ally, when the policy says so for that ally now
  if view~year > 1901 then do
    best = ''
    bestV = 0.55
    do p over heelTurnSorted(out~allIndexes)
      if out[p]['REL'] \== 'ALLY' then iterate
      v = pol~value('stab', self~context(p))
      if v >= bestV then do
        best = p
        bestV = v
      end
    end
    if best \== '' then out[best]['REL'] = 'TARGET'
  end
  do p over heelTurnSorted(out~allIndexes)
    since = view~year
    if rels~hasIndex(p) then if rels[p][1] == out[p]['REL'] then since = rels[p][2]
    rels[p] = .array~of(out[p]['REL'], since)
  end
  return out
::method constraints
  -- My own promises this movement phase that I meant. Kept unless the
  -- policy no longer keeps its word.
  expose outs policy
  cons = .directory~new
  cons['NOMOVE'] = .directory~new
  cons['NOATTACK'] = .directory~new
  cons['SUPPORTS'] = .array~new
  keep = policy~value('keepWord', self~context)
  if keep < 0.35 then return cons
  parse value self~movementPhaseNow with y '|' ph
  do o over outs
    if o['SINCERE'] \== '1' then iterate
    if o['YEAR'] \= y | o['PHASE'] \== ph then iterate
    select
      when o['KIND'] == 'NOMOVE' then cons['NOMOVE'][o['PROV']] = 1
      when o['KIND'] == 'NOATTACK' then cons['NOATTACK'][o['TO']] = 1
      when o['KIND'] == 'SUPPORT' then do
        s = .directory~new
        s['ID'] = o['TO'] o['TLOC'] o['TDEST']
        s['LOC'] = o['UNIT']~word(2)
        s['TTYPE'] = o['TTYPE']
        s['TLOC'] = o['TLOC']
        s['TDEST'] = o['TDEST']
        cons['SUPPORTS']~append(s)
      end
      otherwise nop
    end
  end
  return cons
::method promise
  -- Record what I said: sincere 1 when I mean it, 0 when it is a lie.
  expose outs mylies view
  use strict arg to, kind, unit, prov, ttype, tloc, tdest, sincere
  parse value self~movementPhaseNow with y '|' ph
  f = .array~of('OUT', y, ph, to, kind, unit, prov, ttype, tloc, tdest, sincere, 'OPEN')
  outs~append(heelTurnFields(f, 'TAG YEAR PHASE TO KIND UNIT PROV TTYPE TLOC TDEST SINCERE STATUS'))
  if sincere == '0' then do
    detail = (kind unit prov tloc tdest)~space~changestr(' ', '_')
    mylies~append(heelTurnFields(.array~of('MYLIE', to, y, ph, kind, detail), 'TAG POWER YEAR PHASE KIND DETAIL'))
    self~event('TOLD_LIE' to kind detail)
  end
::method promisedTo
  -- What I have already told this power about a province this phase.
  expose outs
  use strict arg to, prov
  parse value self~movementPhaseNow with y '|' ph
  do o over outs
    if o['TO'] == to then if o['YEAR'] = y then if o['PHASE'] == ph then if o['PROV'] == prov then return o
  end
  return .nil
::method said
  expose said view
  use strict arg to, key
  return said~hasIndex(view~year'|'view~phase'|'to'|'key)
::method markSaid
  expose said view
  use strict arg to, key
  said[view~year'|'view~phase'|'to'|'key] = 1
::method recordGround
  expose grounds view a
  grounds~append(heelTurnFields(.array~of('GROUND', view~year, view~phase, a~myGround~makeString('L', ' ')), 'TAG YEAR PHASE PROVS'))
::method serialize
  -- Newest facts kept; old ones dropped so memory stays well under 8000.
  expose trust rels ins outs lies mylies grounds atk said view hearsay
  out = .array~of('HT|0.1')
  do p over heelTurnSorted(trust~allIndexes)
    out~append('TRUST|'p'|'format(trust[p],, 2))
  end
  do p over heelTurnSorted(rels~allIndexes)
    out~append('REL|'p'|'rels[p][1]'|'rels[p][2])
  end
  keepYear = view~year - 1
  do e over heelTurnLast(ins, 40)
    if e['YEAR'] < keepYear then iterate
    if e['STATUS'] \== 'OPEN' then if e['YEAR'] < view~year then iterate
    out~append(heelTurnJoin(e, 'TAG YEAR PHASE FROM KIND UNIT PROV TTYPE TLOC TDEST SCOPE STRENGTH STATUS TARGETS FLAGS'))
  end
  do e over heelTurnLast(hearsay, 8)
    if e['YEAR'] < keepYear then iterate
    out~append(heelTurnJoin(e, 'TAG YEAR PHASE FROM ABOUT PARTIAL'))
  end
  do e over heelTurnLast(outs, 30)
    if e['YEAR'] < keepYear then iterate
    out~append(heelTurnJoin(e, 'TAG YEAR PHASE TO KIND UNIT PROV TTYPE TLOC TDEST SINCERE STATUS'))
  end
  do e over heelTurnLast(lies, 14)
    out~append(heelTurnJoin(e, 'TAG POWER YEAR PHASE KIND DETAIL'))
  end
  do e over heelTurnLast(mylies, 10)
    out~append(heelTurnJoin(e, 'TAG POWER YEAR PHASE KIND DETAIL'))
  end
  do e over heelTurnLast(grounds, 3)
    out~append(heelTurnJoin(e, 'TAG YEAR PHASE PROVS'))
  end
  do k over heelTurnSorted(atk~allIndexes)
    parse var k p '|' y
    if y >= view~year - 1 then out~append('ATK|'p'|'y'|'atk[k])
  end
  do k over heelTurnSorted(said~allIndexes)
    parse var k y '|' ph '|' .
    if y = view~year then if ph == view~phase then out~append('SAID|'k)
  end
  text = out~makeString('L', '0A'x)
  do while text~length > 7600 & out~items > 10
    out~delete(out~items)
    text = out~makeString('L', '0A'x)
  end
  return text
::method module_version class
  return '0.1'
::method module_version
  return self~class~module_version
::method module_lastChanged class
  return '2026-11-27'
::method module_lastChanged
  return self~class~module_lastChanged

::routine heelTurnFields public
  use strict arg f, names
  d = .directory~new
  idx = 0
  do nm over names~makeArray(' ')
    idx += 1
    if idx <= f~items then d[nm] = f[idx]
    else d[nm] = ''
  end
  return d

::routine heelTurnJoin public
  use strict arg d, names
  parts = .array~new
  do nm over names~makeArray(' ')
    parts~append(d[nm]~string~changestr('|', '/')~changestr('0A'x, ' '))
  end
  return parts~makeString('L', '|')

::routine heelTurnLast public
  use strict arg arr, n
  out = .array~new
  first = max(1, arr~items - n + 1)
  do idx = first to arr~items
    out~append(arr[idx])
  end
  return out

::routine heelTurnSplit public
  -- Fields split by |, keeping empty fields, the last one included
  -- (makeArray drops a trailing empty field).
  use strict arg line
  if line == '' then return .array~new
  f = (line'|.')~makeArray('|')
  f~delete(f~items)
  return f
