/* HeelTurnPlanner.cls - Heel Turn SLAM: orders from a position and a policy.
   Architecture: Tom Dyer. Code: Claude (Opus 5.5).
   Writes literal orders in the competition's grammar:
     A BUD - SER        F TRI H         A VIE S A BUD - GAL
     A LON - NWY  with  F NTH C A LON - NWY
     A PAR R PIC        A PAR D
     BUILD F STP/NC     DISBAND A WAR   WAIVE
   Every fleet reference to a split coast names the coast, as the strict
   rules require. Nothing here asks the referee what is legal. */
::requires 'HeelTurnBoard.cls'

::class HeelTurnPlanner public
::method init
  expose map view a policy ctx relations constraints me fall
  use strict arg map, view, a, policy, ctx, relations, constraints
  me = view~me
  fall = view~phase~left(4) == 'FALL'
::method knob private
  expose policy ctx
  use strict arg name
  return policy~value(name, ctx)
::method rel
  expose relations
  use strict arg power
  if relations~hasIndex(power) then return relations[power]['REL']
  return 'NEUTRAL'
::method hostility
  use strict arg power
  select
    when power == 'N' then return 0
    when self~rel(power) == 'ALLY' then return 0.05
    when self~rel(power) == 'ENEMY' then return 1.0
    when self~rel(power) == 'TARGET' then return 1.15
    otherwise return 0.6
  end
::method forbidden
  -- A destination this plan may not enter: a sincere promise, or an
  -- ally's ground (unless the ally is the stab target).
  expose a constraints me
  use strict arg province
  b = a~map~base(province)
  if constraints['NOMOVE']~hasIndex(b) then return .true
  owner = a~owner(b)
  occupant = ''
  if a~unitAt~hasIndex(b) then occupant = a~unitAt[b]['OWNER']
  do p over .array~of(owner, occupant)
    if p == '' | p == '-' | p == 'N' | p == me then iterate
    if constraints['NOATTACK']~hasIndex(p) then return .true
    if self~rel(p) == 'ALLY' then return .true
  end
  return .false
::method hostileThreats
  -- Units that could hit a province, ignoring allies and powers whose
  -- promise about it Reasoned Thought lets us plan on (PRO, assertible).
  expose a relations constraints
  use strict arg province
  exclude = ''
  do p over heelTurnSorted(relations~allIndexes)
    if relations[p]['REL'] == 'ALLY' then exclude = exclude p
  end
  if constraints~hasIndex('RELY') then do e over constraints['RELY']
    if wordpos(e['KIND'], 'NOATTACK ALLY') > 0 then exclude = exclude e['FROM']
    if e['KIND'] == 'NOMOVE' then if e['PROV'] == a~map~base(province) then exclude = exclude e['FROM']
  end
  return a~threats(province, exclude)~items
::method targetDistances
  -- Moves from every province to the nearest centre worth taking.
  expose a me
  targets = .array~new
  do code over heelTurnSorted(a~view~centres~allIndexes)
    owner = a~view~centres[code]
    if owner == me then iterate
    if owner \== 'N' then if self~rel(owner) == 'ALLY' then iterate
    targets~append(code)
  end
  if targets~items = 0 then return .directory~new
  return a~map~distances(targets)
::method moveScore
  expose map a me fall
  use strict arg u, dest, tdist
  db = map~base(dest)
  if self~forbidden(db) then return .nil
  aggr = self~knob('aggression')
  expandK = self~knob('expand')
  def = self~knob('defence')
  bully = self~knob('bully')
  s = 0
  owner = a~owner(db)
  gainFactor = 0.8
  if fall then gainFactor = 1.6
  if map~isCentre(db) then do
    select
      when owner == me then do
        if \a~unitAt~hasIndex(db) then s += self~hostileThreats(db) * 3 * def
      end
      when owner == 'N' then s += 10 * expandK * gainFactor
      otherwise do
        v = 8 * (0.4 + aggr) * self~hostility(owner)
        if self~isWeakest(owner) then v += 2 * bully
        s += v * gainFactor
      end
    end
  end
  if a~unitAt~hasIndex(db) then do
    occ = a~unitAt[db]
    if occ['OWNER'] \== me then s = s * 0.7 - 1
    else s -= 0.5
  end
  posFactor = 1
  if fall then posFactor = 0.4
  do q over map~neighbours(db)
    if \map~isCentre(q) then iterate
    qo = a~owner(q)
    if qo == me then iterate
    if qo == 'N' then s += 1.5 * expandK * posFactor
    else s += 1.0 * aggr * self~hostility(qo) * posFactor
  end
  here = u['BASE']
  if a~owner(here) == me then do
    t = self~hostileThreats(here)
    if t > 0 then do
      leaveFactor = 1
      if fall then leaveFactor = 1.6
      s -= t * 5 * def * leaveFactor
    end
  end
  if tdist~hasIndex(here) & tdist~hasIndex(db) then s += (tdist[here] - tdist[db]) * 1.5
  return s
::method holdScore
  expose a me fall
  use strict arg u
  here = u['BASE']
  s = 0
  if a~owner(here) == me then do
    t = self~hostileThreats(here)
    f = 1
    if fall then f = 1.6
    s += t * 5 * self~knob('defence') * f
    if fall then s += 0.2
  end
  return s
::method isWeakest
  expose a me
  use strict arg power
  low = 99
  who = ''
  do p over a~alive
    if p == me then iterate
    if a~centreCount[p] < low then do
      low = a~centreCount[p]
      who = p
    end
  end
  return who == power
::method movement
  expose map a me constraints
  plan = heelTurnPlan()
  mine = a~myUnits
  if mine~items = 0 then return plan
  tdist = self~targetDistances
  cands = .array~new
  do u over mine
    cands~append(heelTurnCand(u, 'H', '', self~holdScore(u), .nil))
    do d over map~dests(u['TYPE'], u['LOC'])
      sc = self~moveScore(u, d, tdist)
      if sc \== .nil then cands~append(heelTurnCand(u, 'M', d, sc, .nil))
    end
  end
  -- single-fleet convoys: army on a coast, my fleet at sea next to it
  do f over mine
    if f['TYPE'] \== 'F' then iterate
    if map~kindOf(f['LOC']) \== 'sea' then iterate
    do u over mine
      if u['TYPE'] \== 'A' then iterate
      if \map~reaches('F', f['LOC'], u['BASE']) then iterate
      landDests = map~dests('A', u['LOC'])
      do t over map~dests('F', f['LOC'])
        tb = map~base(t)
        if tb == u['BASE'] then iterate
        if map~kindOf(tb) \== 'coast' then iterate
        if landDests~hasItem(tb) then iterate
        sc = self~moveScore(u, tb, tdist)
        if sc == .nil then iterate
        cands~append(heelTurnCand(u, 'C', tb, sc - 0.5, f))
      end
    end
  end
  cands = heelTurnSortCands(cands)
  assigned = .directory~new
  taken = .directory~new
  do pass = 1 to 6
    changed = .false
    do c over cands
      u = c['UNIT']
      if assigned~hasIndex(u['LOC']) then iterate
      if c['KIND'] == 'H' then do
        if pass < 3 then if self~betterPending(c, cands, assigned, taken) then iterate
        assigned[u['LOC']] = c
        taken[u['BASE']] = u['LOC']
        changed = .true
        iterate
      end
      db = map~base(c['DEST'])
      if taken~hasIndex(db) then iterate
      if c['KIND'] == 'C' then if assigned~hasIndex(c['FLEET']['LOC']) then iterate
      blocker = self~myUnitAt(db)
      if blocker \== .nil then do
        if \assigned~hasIndex(blocker['LOC']) then iterate
        bc = assigned[blocker['LOC']]
        if bc['KIND'] == 'H' then iterate
        if map~base(bc['DEST']) == u['BASE'] then iterate
      end
      assigned[u['LOC']] = c
      taken[db] = u['LOC']
      if c['KIND'] == 'C' then do
        fc = heelTurnCand(c['FLEET'], 'CF', c['DEST'], 0, u)
        assigned[c['FLEET']['LOC']] = fc
        taken[c['FLEET']['BASE']] = c['FLEET']['LOC']
      end
      changed = .true
    end
    if \changed then leave
  end
  -- anyone left holds (a hold candidate exists for every unit)
  do u over mine
    if \assigned~hasIndex(u['LOC']) then assigned[u['LOC']] = heelTurnCand(u, 'H', '', 0, .nil)
  end
  -- promised supports first: a promise is kept before any choice of ours
  do promise over constraints['SUPPORTS']
    self~giveSupport(assigned, promise, plan)
  end
  -- supports for our own contested moves
  do loc over heelTurnSorted(assigned~allIndexes)
    c = assigned[loc]
    if c['KIND'] \== 'M' & c['KIND'] \== 'C' then iterate
    db = map~base(c['DEST'])
    contested = .false
    if a~unitAt~hasIndex(db) then if a~unitAt[db]['OWNER'] \== me then contested = .true
    if a~threats(db)~items > 0 then contested = .true
    if \contested then iterate
    do hl over heelTurnSorted(assigned~allIndexes)
      h = assigned[hl]
      if h['KIND'] \== 'H' then iterate
      hu = h['UNIT']
      if hu['BASE'] == db then iterate
      if \map~reaches(hu['TYPE'], hu['LOC'], db) then iterate
      h['KIND'] = 'S'
      h['SUP'] = c['UNIT']['TYPE'] c['UNIT']['LOC'] '-' c['DEST']
      leave
    end
  end
  -- hold supports for threatened centres we keep
  do loc over heelTurnSorted(assigned~allIndexes)
    c = assigned[loc]
    if c['KIND'] \== 'H' then iterate
    base = c['UNIT']['BASE']
    if a~owner(base) \== me then iterate
    if self~hostileThreats(base) = 0 then iterate
    do hl over heelTurnSorted(assigned~allIndexes)
      h = assigned[hl]
      if hl == loc then iterate
      if h['KIND'] \== 'H' then iterate
      hu = h['UNIT']
      if \map~reaches(hu['TYPE'], hu['LOC'], base) then iterate
      h['KIND'] = 'S'
      h['SUP'] = c['UNIT']['TYPE'] c['UNIT']['LOC']
      leave
    end
  end
  do loc over heelTurnSorted(assigned~allIndexes)
    c = assigned[loc]
    u = c['UNIT']
    select
      when c['KIND'] == 'H' then plan['ORDERS']~append(u['TYPE'] u['LOC'] 'H')
      when c['KIND'] == 'S' then plan['ORDERS']~append(u['TYPE'] u['LOC'] 'S' c['SUP'])
      when c['KIND'] == 'CF' then plan['ORDERS']~append(u['TYPE'] u['LOC'] 'C A' c['FLEET']['LOC'] '-' c['DEST'])
      otherwise do
        plan['ORDERS']~append(u['TYPE'] u['LOC'] '-' c['DEST'])
        self~noteMove(plan, u, c['DEST'])
      end
    end
  end
  return plan
::method betterPending private
  -- Early passes leave a unit unassigned while a move it wants is only
  -- waiting for one of our own units to step out first.
  expose map
  use strict arg holdCand, cands, assigned, taken
  u = holdCand['UNIT']
  do c over cands
    if c['UNIT'] \== u then iterate
    if c['KIND'] == 'H' then return .false
    if c['SCORE'] <= holdCand['SCORE'] then return .false
    db = map~base(c['DEST'])
    if \taken~hasIndex(db) then if self~myUnitAt(db) \== .nil then return .true
  end
  return .false
::method myUnitAt private
  expose a me
  use strict arg province
  if \a~unitAt~hasIndex(province) then return .nil
  u = a~unitAt[province]
  if u['OWNER'] \== me then return .nil
  return u
::method giveSupport private
  expose map
  use strict arg assigned, promise, plan
  tdest = promise['TDEST']
  aim = promise['TLOC']
  if tdest \== '' then aim = tdest
  do hl over heelTurnSorted(assigned~allIndexes)
    h = assigned[hl]
    if h['KIND'] \== 'H' then iterate
    hu = h['UNIT']
    if promise['LOC'] \== '' then if hu['BASE'] \== map~base(promise['LOC']) then iterate
    if hu['BASE'] == map~base(aim) then iterate
    if \map~reaches(hu['TYPE'], hu['LOC'], aim) then iterate
    h['KIND'] = 'S'
    if tdest == '' then h['SUP'] = promise['TTYPE'] promise['TLOC']
    else h['SUP'] = promise['TTYPE'] promise['TLOC'] '-' tdest
    plan['KEPT']~append(promise['ID'])
    return
  end
::method noteMove private
  expose a me
  use strict arg plan, u, dest
  db = a~map~base(dest)
  plan['INTO'][db] = 1
  victims = .array~new
  owner = a~owner(db)
  if owner \== '-' & owner \== 'N' & owner \== me then victims~append(owner)
  if a~unitAt~hasIndex(db) then do
    occ = a~unitAt[db]['OWNER']
    if occ \== me then if \victims~hasItem(occ) then victims~append(occ)
  end
  do v over victims
    if \plan['ATTACKS']~hasIndex(v) then plan['ATTACKS'][v] = .array~new
    plan['ATTACKS'][v]~append(db)
  end
::method retreats
  expose map a view me
  plan = heelTurnPlan()
  standoff = self~standoffs
  do u over view~task
    from = ''
    do d over view~dislodged
      if d['LOC'] == u['LOC'] then from = map~base(d['FROM'])
    end
    best = ''
    bestScore = -999
    do d over map~dests(u['TYPE'], u['LOC'])
      db = map~base(d)
      if db == from then iterate
      if a~unitAt~hasIndex(db) then iterate
      if standoff~hasIndex(db) then iterate
      if plan['INTO']~hasIndex(db) then iterate
      s = 0
      owner = a~owner(db)
      if owner == me then s += 5
      else if owner == 'N' then s += 4
      else if owner \== '-' then s += 3 * self~hostility(owner)
      s -= self~hostileThreats(db) * 0.5
      if s > bestScore then do
        bestScore = s
        best = d
      end
    end
    if best == '' then plan['ORDERS']~append(u['TYPE'] u['LOC'] 'D')
    else do
      plan['ORDERS']~append(u['TYPE'] u['LOC'] 'R' best)
      plan['INTO'][map~base(best)] = 1
    end
  end
  return plan
::method standoffs private
  -- Provinces left empty after two or more failed moves into them this
  -- phase: a retreat there is not allowed.
  expose a view
  count = .directory~new
  do r over view~results
    if r['YEAR'] \== view~year then iterate
    if r['PHASE']~right(8) \== 'MOVEMENT' then iterate
    if r['STATUS'] \== 'FAILS' then iterate
    o = heelTurnParseOrder(r['LINE'])
    if o['ACTION'] \== 'MOVE' then iterate
    db = a~map~base(o['DEST'])
    if \count~hasIndex(db) then count[db] = 0
    count[db] += 1
  end
  out = .directory~new
  do db over count~allIndexes
    if count[db] >= 2 then if \a~unitAt~hasIndex(db) then out[db] = 1
  end
  return out
::method adjustments
  expose map a view me
  plan = heelTurnPlan()
  bal = view~balance
  if bal > 0 then do
    free = .array~new
    do h over map~homes(me)
      if a~owner(h) \== me then iterate
      if a~unitAt~hasIndex(h) then iterate
      free~append(h)
    end
    -- the most threatened home first
    ranked = .array~new
    do h over free
      ranked~append((1000 - self~hostileThreats(h) * 10)~right(4, '0') h)
    end
    ranked = ranked~sort
    fleets = 0
    total = 0
    do u over a~myUnits
      total += 1
      if u['TYPE'] == 'F' then fleets += 1
    end
    coastal = 0
    homes = map~homes(me)
    do h over homes
      if map~kindOf(h) == 'coast' then coastal += 1
    end
    want = coastal / max(1, homes~items) * (0.6 + 0.8 * (self~knob('fleetPref') - 0.5))
    built = 0
    do entry over ranked
      if built >= bal then leave
      h = entry~word(2)
      utype = 'A'
      if map~kindOf(h) == 'coast' then if fleets / max(1, total + 1) < want then utype = 'F'
      loc = h
      if utype == 'F' then do
        cs = map~coasts(h)
        if cs~items > 0 then loc = self~bestCoast(cs)
      end
      plan['ORDERS']~append('BUILD' utype loc)
      total += 1
      if utype == 'F' then fleets += 1
      built += 1
    end
    do k = built + 1 to bal
      plan['ORDERS']~append('WAIVE')
    end
    return plan
  end
  if bal < 0 then do
    owned = .array~new
    do code over heelTurnSorted(view~centres~allIndexes)
      if view~centres[code] == me then owned~append(code)
    end
    dist = map~distances(owned)
    ranked = .array~new
    do u over a~myUnits
      d = 99
      if dist~hasIndex(u['BASE']) then d = dist[u['BASE']]
      tie = 1
      if u['TYPE'] == 'F' then tie = 0
      ranked~append((100 - d)~right(3, '0') tie u['LOC'] u['TYPE'])
    end
    ranked = ranked~sort
    do k = 1 to min(-bal, ranked~items)
      parse value ranked[k] with . . loc utype
      plan['ORDERS']~append('DISBAND' utype loc)
    end
  end
  return plan
::method bestCoast private
  -- The coast whose fleet column touches the most seas.
  expose map
  use strict arg coasts
  best = coasts[1]
  bestN = -1
  do c over coasts
    n = 0
    do d over map~dests('F', c)
      if map~kindOf(d) == 'sea' then n += 1
    end
    if n > bestN then do
      bestN = n
      best = c
    end
  end
  return best
::method check
  -- Every line is read back and checked against the graph before it goes
  -- out: the unit is ours and where we say, the destination is in its own
  -- column (coast literal), a supporter reaches the province, the unit it
  -- supports exists as written, a convoy has its fleet at sea. A line that
  -- fails is not sent: the unit holds (movement), disbands (retreat), or the
  -- line is dropped (adjustment). Returns array(lines, failures).
  expose map a view me
  use strict arg lines, kind
  good = .array~new
  bad = .array~new
  convoys = .directory~new
  do line over lines
    o = heelTurnParseOrder(line)
    if o['ACTION'] == 'CONVOY' then convoys[o['TLOC']'|'o['DEST']] = o['LOC']
  end
  do line over lines
    o = heelTurnParseOrder(line)
    why = self~checkOne(o, kind, convoys)
    if why == '' then good~append(line)
    else do
      bad~append(line '=>' why)
      if kind == 'MOVEMENT' then if o['TYPE'] \== '' then good~append(o['TYPE'] o['LOC'] 'H')
      if kind == 'RETREAT' then if o['TYPE'] \== '' then good~append(o['TYPE'] o['LOC'] 'D')
    end
  end
  return .array~of(good, bad)
::method checkOne private
  expose map a view me
  use strict arg o, kind, convoys
  act = o['ACTION']
  if act == 'UNREAD' then return 'UNREAD'
  if kind == 'ADJUSTMENT' then do
    if act == 'WAIVE' then return ''
    if act == 'BUILD' then do
      b = map~base(o['LOC'])
      if map~homeOf(b) \== me then return 'NOT_HOME'
      if a~owner(b) \== me then return 'NOT_OWNED'
      if a~unitAt~hasIndex(b) then return 'OCCUPIED'
      if o['TYPE'] == 'A' then if o['LOC'] \== b then return 'ARMY_HAS_NO_COAST'
      if o['TYPE'] == 'F' then do
        if map~kindOf(b) \== 'coast' then return 'FLEET_INLAND'
        if map~coasts(b)~items > 0 then if \map~coasts(b)~hasItem(o['LOC']) then return 'NO_COAST'
      end
      return ''
    end
    if act == 'DISBAND' then do
      if self~mine(o['TYPE'], o['LOC']) then return ''
      return 'NO_SUCH_UNIT'
    end
    return 'WRONG_PHASE'
  end
  if kind == 'RETREAT' then do
    found = .false
    do u over view~task
      if u['TYPE'] == o['TYPE'] then if u['LOC'] == o['LOC'] then found = .true
    end
    if \found then return 'NOT_DISLODGED'
    if act == 'DISBAND' then return ''
    if act \== 'RETREAT' then return 'WRONG_PHASE'
    if \map~dests(o['TYPE'], o['LOC'])~hasItem(o['DEST']) then return 'NOT_IN_COLUMN'
    if a~unitAt~hasIndex(map~base(o['DEST'])) then return 'OCCUPIED'
    do d over view~dislodged
      if d['LOC'] == o['LOC'] then if map~base(d['FROM']) == map~base(o['DEST']) then return 'ATTACKER_ORIGIN'
    end
    return ''
  end
  if \self~mine(o['TYPE'], o['LOC']) then return 'NO_SUCH_UNIT'
  select
    when act == 'HOLD' then return ''
    when act == 'MOVE' then do
      if map~dests(o['TYPE'], o['LOC'])~hasItem(o['DEST']) then return ''
      if o['TYPE'] == 'A' then if convoys~hasIndex(o['LOC']'|'o['DEST']) then return ''
      return 'NOT_IN_COLUMN'
    end
    when act == 'SUPPORT_HOLD' | act == 'SUPPORT_MOVE' then do
      aim = o['TLOC']
      if act == 'SUPPORT_MOVE' then aim = o['DEST']
      if map~base(aim) == map~base(o['LOC']) then return 'SUPPORTS_OWN_PROVINCE'
      if \map~reaches(o['TYPE'], o['LOC'], aim) then return 'CANNOT_REACH'
      target = .nil
      do u over view~units
        if u['TYPE'] == o['TTYPE'] then if u['LOC'] == o['TLOC'] then target = u
      end
      if target == .nil then return 'NO_SUCH_TARGET'
      if act == 'SUPPORT_MOVE' then do
        if target['TYPE'] == 'F' then if \map~dests('F', target['LOC'])~hasItem(o['DEST']) then return 'TARGET_COAST'
        if target['TYPE'] == 'A' then if o['DEST'] \== map~base(o['DEST']) then return 'ARMY_HAS_NO_COAST'
      end
      return ''
    end
    when act == 'CONVOY' then do
      if o['TYPE'] \== 'F' then return 'NOT_A_FLEET'
      if map~kindOf(o['LOC']) \== 'sea' then return 'NOT_AT_SEA'
      if \map~reaches('F', o['LOC'], o['TLOC']) then return 'NOT_NEXT_TO_ARMY'
      if \map~reaches('F', o['LOC'], o['DEST']) then return 'NOT_NEXT_TO_DEST'
      return ''
    end
    otherwise return 'WRONG_PHASE'
  end
::method mine private
  expose view me
  use strict arg utype, loc
  do u over view~units
    if u['OWNER'] == me then if u['TYPE'] == utype then if u['LOC'] == loc then return .true
  end
  return .false
::method module_version class
  return '0.1r6'
::method module_version
  return self~class~module_version
::method module_lastChanged class
  return '2026-11-27'
::method module_lastChanged
  return self~class~module_lastChanged

::routine heelTurnPlan public
  plan = .directory~new
  plan['ORDERS'] = .array~new
  plan['INTO'] = .directory~new
  plan['ATTACKS'] = .directory~new
  plan['KEPT'] = .array~new
  return plan

::routine heelTurnCand
  use strict arg unit, kind, dest, score, fleet
  c = .directory~new
  c['UNIT'] = unit
  c['KIND'] = kind
  c['DEST'] = dest
  c['SCORE'] = score
  c['FLEET'] = fleet
  return c

::routine heelTurnSortCands
  -- Highest score first; ties by unit location then destination, so the
  -- same position always gives the same orders.
  use strict arg cands
  keyed = .array~new
  idx = 0
  do c over cands
    idx += 1
    key = (100000 - format(c['SCORE'] * 100,, 0))~right(8, '0') c['UNIT']['LOC']~left(6, '_') c['DEST']~left(6, '_') c['KIND'] idx
    keyed~append(key)
  end
  keyed = keyed~sort
  out = .array~new
  do key over keyed
    out~append(cands[key~word(words(key))])
  end
  return out

::routine heelTurnParseOrder public
  -- A raw order line as published, read just enough for checking promises.
  -- ACTION: MOVE HOLD SUPPORT_MOVE SUPPORT_HOLD CONVOY RETREAT DISBAND BUILD
  -- WAIVE, or UNREAD. The referee's own reading is the one that counts.
  use strict arg raw
  o = .directory~new
  o['ACTION'] = 'UNREAD'
  o['TYPE'] = ''
  o['LOC'] = ''
  o['DEST'] = ''
  o['TTYPE'] = ''
  o['TLOC'] = ''
  text = raw~upper~translate(' ', '09'x)~changestr('-', ' - ')~space
  parse var text w1 w2 w3 w4 w5 w6 w7 .
  if w1 == 'WAIVE' then do
    o['ACTION'] = 'WAIVE'
    return o
  end
  if wordpos(w1, 'BUILD DISBAND') > 0 then do
    o['ACTION'] = w1
    o['TYPE'] = w2
    o['LOC'] = w3
    return o
  end
  if wordpos(w1, 'A F') = 0 then return o
  o['TYPE'] = w1
  o['LOC'] = w2
  select
    when w3 == 'H' then o['ACTION'] = 'HOLD'
    when w3 == '-' then do
      o['ACTION'] = 'MOVE'
      o['DEST'] = w4
    end
    when w3 == 'R' then do
      o['ACTION'] = 'RETREAT'
      o['DEST'] = w4
    end
    when w3 == 'D' then o['ACTION'] = 'DISBAND'
    when w3 == 'S' then do
      o['TTYPE'] = w4
      o['TLOC'] = w5
      if w6 == '-' then do
        o['ACTION'] = 'SUPPORT_MOVE'
        o['DEST'] = w7
      end
      else o['ACTION'] = 'SUPPORT_HOLD'
    end
    when w3 == 'C' then do
      o['ACTION'] = 'CONVOY'
      o['TTYPE'] = w4
      o['TLOC'] = w5
      o['DEST'] = w7
    end
    otherwise nop
  end
  return o
