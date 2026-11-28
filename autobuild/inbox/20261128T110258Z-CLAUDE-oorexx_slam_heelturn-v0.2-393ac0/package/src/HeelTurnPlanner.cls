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
  -- a province I agreed to dislodge an ally from is mine to enter
  if constraints~hasIndex('TREATY') then if constraints['TREATY']~hasIndex(b) then return .false
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
  -- a move I said I would make comes first, where it is still a legal move my
  -- other promises allow (moveScore gives none for a forbidden move)
  if constraints~hasIndex('MOVES') then do c over cands
    if c['KIND'] \== 'M' then iterate
    if \constraints['MOVES']~hasIndex(c['UNIT']['LOC']) then iterate
    if constraints['MOVES'][c['UNIT']['LOC']] == map~base(c['DEST']) then c['SCORE'] = c['SCORE'] + 100
  end
  cands = heelTurnSortCands(cands)
  reserved = .directory~new
  assigned = .directory~new
  taken = .directory~new
  -- a unit I agreed will be dislodged holds, unsupported, whatever else it wanted
  if constraints~hasIndex('HOLDS') then do u over mine
    if \constraints['HOLDS']~hasIndex(u['LOC']) then iterate
    hc = heelTurnCand(u, 'H', '', 0, .nil)
    hc['ROLE'] = 'TREATY'
    assigned[u['LOC']] = hc
    taken[u['BASE']] = u['LOC']
  end
  if constraints~hasIndex('MOVES') then do loc over constraints['MOVES']~allIndexes
    reserved[constraints['MOVES'][loc]] = loc
  end
  do pass = 1 to 6
    changed = .false
    do c over cands
      u = c['UNIT']
      if assigned~hasIndex(u['LOC']) then iterate
      -- a unit with a promised move waits for it (its own blocker may still
      -- step out) and takes anything else only when the move cannot be made
      if pass < 6 then if self~waitForPromise(c, cands, taken) then iterate
      if c['KIND'] == 'H' then do
        if pass < 3 then if self~betterPending(c, cands, assigned, taken) then iterate
        assigned[u['LOC']] = c
        taken[u['BASE']] = u['LOC']
        changed = .true
        iterate
      end
      db = map~base(c['DEST'])
      if taken~hasIndex(db) then iterate
      -- a province I promised another of my units will move into is kept for it
      if pass < 6 then if reserved~hasIndex(db) then if reserved[db] \== u['LOC'] then if \assigned~hasIndex(reserved[db]) then iterate
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
    self~giveSupport(assigned, promise, plan, taken)
  end
  -- tactics (v0.2): defend my centres by strength, dislodge with enough
  -- support, cut supports, bounce to deny
  self~tactics(assigned, taken)
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
::method waitForPromise private
  expose map constraints
  use strict arg c, cands, taken
  if \constraints~hasIndex('MOVES') then return .false
  u = c['UNIT']
  if \constraints['MOVES']~hasIndex(u['LOC']) then return .false
  pd = constraints['MOVES'][u['LOC']]
  if c['KIND'] == 'M' then if map~base(c['DEST']) == pd then return .false
  if taken~hasIndex(pd) then return .false
  do o over cands
    if o['UNIT'] \== u | o['KIND'] \== 'M' then iterate
    if map~base(o['DEST']) == pd then return .true
  end
  return .false
::method tactics private
  expose map
  -- After the units have their own best moves: count strengths and spend the
  -- spare units (holding, not defending) where they change an outcome.
  -- Worst case: every hostile unit that can reach a province supports the
  -- strongest move into it (hostile: not an ally, not a power whose promise
  -- Reasoned Thought lets us plan on).
  use strict arg assigned, taken
  self~defend(assigned, taken)
  self~attack(assigned, taken)
  if self~knob('aggression') >= 0.45 then self~dislodge(assigned, taken)
  self~deny(assigned, taken)
  -- a unit kept back may have been the one leaving a province another of
  -- mine was moving into: that move would only bounce off my own unit
  do forever
    changed = .false
    do loc over heelTurnSorted(assigned~allIndexes)
      c = assigned[loc]
      if c['KIND'] \== 'M' then iterate
      b = self~myUnitAt(map~base(c['DEST']))
      if b == .nil then iterate
      if assigned[b['LOC']]['KIND'] == 'M' then iterate
      self~release(assigned, taken, c['UNIT'])
      if c['KIND'] == 'M' then do
        taken~remove(map~base(c['DEST']))
        c['KIND'] = 'H'
        c['DEST'] = ''
        taken[c['UNIT']['BASE']] = loc
      end
      changed = .true
    end
    if \changed then leave
  end
::method hostileUnits
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
  out = .array~new
  b = a~map~base(province)
  do u over a~threats(province, exclude)
    if u['BASE'] \== b then out~append(u)
  end
  return out
::method available private
  -- units a tactic may use, best first: units holding (a holder of a
  -- threatened centre only to support, or to dislodge the one unit that
  -- threatens it); then movers whose move gains nothing (a non-centre or a
  -- centre of mine); then, to defend a centre, any mover. Promised moves and
  -- units already given a tactical role are never taken.
  expose a me map constraints
  use strict arg assigned, purpose, target = ''
  first = .array~new
  second = .array~new
  third = .array~new
  do loc over heelTurnSorted(assigned~allIndexes)
    c = assigned[loc]
    u = c['UNIT']
    -- a unit holding a centre (role HOLD) still supports, and may attack or
    -- cut the unit that threatens it; any other role is spoken for
    if c~hasIndex('ROLE') then if c['ROLE'] \== 'HOLD' then iterate
    if c~hasIndex('ROLE') then if purpose == 'OCCUPY' | purpose == 'DENY' then iterate
    if c['KIND'] == 'H' then do
      if purpose \== 'SUPPORT' then if a~owner(u['BASE']) == me then do
        foes = self~hostileUnits(u['BASE'])
        ok = foes~items = 0
        if \ok & purpose == 'DISLODGE' then do
          ok = .true
          do f over foes
            if f['BASE'] \== target then ok = .false
          end
        end
        -- a cut on a unit that threatens my own centre is safe: it stays to
        -- support (I bounce back and still hold) or comes at me (head to head)
        if \ok & purpose == 'CUT' & target \== '' then do f over foes
          if f['BASE'] == target then ok = .true
        end
        if \ok then iterate
      end
      first~append(u)
      iterate
    end
    if c['KIND'] \== 'M' then iterate
    if constraints~hasIndex('MOVES') then if constraints['MOVES']~hasIndex(loc) then iterate
    db = map~base(c['DEST'])
    if \map~isCentre(db) | a~owner(db) == me then second~append(u)
    else if purpose == 'SUPPORT' | purpose == 'OCCUPY' then third~append(u)
  end
  do u over second
    first~append(u)
  end
  do u over third
    first~append(u)
  end
  return first
::method take private
  -- a unit given a tactical role: its own move is set aside (kept to give back)
  expose map
  use strict arg assigned, taken, u
  c = assigned[u['LOC']]
  if \c~hasIndex('WAS') then c['WAS'] = .array~of(c['KIND'], c['DEST'])
  if c['KIND'] == 'M' then do
    taken~remove(map~base(c['DEST']))
    taken[u['BASE']] = u['LOC']
  end
  c['KIND'] = 'H'
  c['DEST'] = ''
  return c
::method holders private
  use strict arg assigned
  out = .array~new
  do loc over heelTurnSorted(assigned~allIndexes)
    if assigned[loc]['KIND'] == 'H' then out~append(assigned[loc]['UNIT'])
  end
  return out
::method reliable private
  -- a supporter whose support an enemy can cut with a unit that could not
  -- have joined the attack instead is counted last
  expose map
  use strict arg s, target
  do h over self~hostileUnits(s['BASE'])
    if \map~reaches(h['TYPE'], h['LOC'], target) then return .false
  end
  return .true
::method supportersFor private
  -- units able to support into a province, reliable ones first
  expose map
  use strict arg assigned, target, except
  good = .array~new
  weak = .array~new
  do s over self~available(assigned, 'SUPPORT')
    if s['LOC'] == except then iterate
    if s['BASE'] == target then iterate
    if \map~reaches(s['TYPE'], s['LOC'], target) then iterate
    if self~reliable(s, target) then good~append(s)
    else weak~append(s)
  end
  do w over weak
    good~append(w)
  end
  return good
::method holdStrength private
  use strict arg assigned, loc
  n = 1
  do k over assigned~allIndexes
    c = assigned[k]
    if c['KIND'] \== 'S' then iterate
    if c['SUP']~words = 2 then if c['SUP']~word(2) == loc then n += 1
  end
  return n
::method moveStrength private
  expose map
  use strict arg assigned, mover
  m = assigned[mover['LOC']]
  n = 1
  want = mover['TYPE'] mover['LOC'] '-' m['DEST']
  do k over assigned~allIndexes
    c = assigned[k]
    if c['KIND'] == 'S' then if c['SUP'] == want then n += 1
  end
  return n
::method cutters private
  -- units that can move into a hostile unit's province (a move there cuts
  -- its support; it bounces unless the unit leaves)
  use strict arg assigned, foes, notFrom, taken, except = ''
  out = .array~new
  used = .directory~new
  do f over foes
    do s over self~available(assigned, 'CUT', f['BASE'])
      if s['LOC'] == except then iterate
      if used~hasIndex(s['LOC']) then iterate
      if s['BASE'] == notFrom then iterate
      if taken~hasIndex(f['BASE']) then iterate
      if self~forbidden(f['BASE']) then iterate
      d = self~destInto(s, f['BASE'])
      if d == '' then iterate
      out~append(.array~of(s, f, d))
      used[s['LOC']] = 1
      leave
    end
  end
  return out
::method destInto private
  expose map
  use strict arg u, province
  do d over map~dests(u['TYPE'], u['LOC'])
    if map~base(d) == province then return d
  end
  return ''
::method giveHold private
  use strict arg assigned, taken, s, holder
  c = self~take(assigned, taken, s)
  c['KIND'] = 'S'
  c['SUP'] = holder['TYPE'] holder['LOC']
  c['ROLE'] = 'DEFEND'
::method giveMoveSupport private
  use strict arg assigned, taken, s, mover
  c = self~take(assigned, taken, s)
  c['KIND'] = 'S'
  c['SUP'] = mover['TYPE'] mover['LOC'] '-' assigned[mover['LOC']]['DEST']
  c['ROLE'] = 'ATTACK'
::method sendCut private
  expose map
  use strict arg assigned, taken, s, dest
  c = self~take(assigned, taken, s)
  c['KIND'] = 'M'
  c['DEST'] = dest
  c['ROLE'] = 'CUT'
  taken~remove(s['BASE'])
  taken[map~base(dest)] = s['LOC']
::method swaps private
  -- a move into a province whose unit of mine moves into mine: the two
  -- bounce off each other (no convoy), so a tactic never orders one
  expose map
  use strict arg assigned, s, dest
  b = self~myUnitAt(map~base(dest))
  if b == .nil then return .false
  c = assigned[b['LOC']]
  if c['KIND'] \== 'M' then return .false
  return map~base(c['DEST']) == s['BASE']
::method sendMove private
  expose map
  use strict arg assigned, taken, s, dest, role
  c = self~take(assigned, taken, s)
  c['KIND'] = 'M'
  c['DEST'] = dest
  c['ROLE'] = role
  taken~remove(s['BASE'])
  taken[map~base(dest)] = s['LOC']
  -- support for it to hold is void once it moves: those units are free again
  do k over heelTurnSorted(assigned~allIndexes)
    o = assigned[k]
    if o['KIND'] \== 'S' then iterate
    if o['SUP']~words = 2 then if o['SUP']~word(2) == s['LOC'] then self~release(assigned, taken, o['UNIT'])
  end
  return c
::method release private
  -- give a spent unit back its own order
  expose map
  use strict arg assigned, taken, s
  c = assigned[s['LOC']]
  if c['KIND'] == 'M' then taken~remove(map~base(c['DEST']))
  else taken~remove(s['BASE'])
  c~remove('SUP')
  c~remove('ROLE')
  c['KIND'] = 'H'
  c['DEST'] = ''
  if c~hasIndex('WAS') then do
    c['KIND'] = c['WAS'][1]
    c['DEST'] = c['WAS'][2]
    c~remove('WAS')
  end
  if c['KIND'] == 'M' then taken[map~base(c['DEST'])] = s['LOC']
  else taken[s['BASE']] = s['LOC']
::method defend private
  -- my centres: the unit on it holds against the worst case (a tie holds);
  -- an empty one under threat gets a unit moved in to occupy or bounce
  expose a me map fall constraints
  use strict arg assigned, taken
  do c over heelTurnSorted(a~view~centres~allIndexes)
    if a~owner(c) \== me then iterate
    foes = self~hostileUnits(c)
    if foes~items = 0 then iterate
    if constraints~hasIndex('NOHOLDSUPPORT') then if constraints['NOHOLDSUPPORT']~hasIndex(c) then iterate
    holder = self~myUnitAt(c)
    if holder \== .nil then if assigned[holder['LOC']]~hasIndex('ROLE') then if assigned[holder['LOC']]['ROLE'] == 'TREATY' then iterate
    if holder \== .nil then if assigned[holder['LOC']]['KIND'] == 'M' then do
      -- leaving under a supported threat (or any threat in the fall): stay
      -- and hold if the hold can be made to stand, unless another of my
      -- units is moving in
      leaveIt = .true
      promised = .false
      if constraints~hasIndex('MOVES') then promised = constraints['MOVES']~hasIndex(holder['LOC'])
      if \promised & (foes~items >= 2 | fall) & self~knob('defence') >= 0.4 & \taken~hasIndex(c) then do
        if 1 + self~supportersFor(assigned, c, holder['LOC'])~items + self~cutters(assigned, foes, c, taken, holder['LOC'])~items >= foes~items then do
          hc = assigned[holder['LOC']]
          if hc~hasIndex('ROLE') then if hc['ROLE'] \== '' then leaveIt = .true
          if \hc~hasIndex('ROLE') then do
            taken~remove(map~base(hc['DEST']))
            hc['KIND'] = 'H'
            hc['DEST'] = ''
            taken[c] = holder['LOC']
            leaveIt = .false
          end
        end
      end
      if leaveIt then holder = .nil
    end
    if holder \== .nil then do
      assigned[holder['LOC']]['ROLE'] = 'HOLD'
      self~backHold(assigned, taken, holder, c, foes)
      iterate
    end
    if taken~hasIndex(c) then iterate
    mover = .nil
    do s over self~available(assigned, 'OCCUPY')
      if self~destInto(s, c) == '' then iterate
      if self~swaps(assigned, s, self~destInto(s, c)) then iterate
      mover = s
      leave
    end
    if mover == .nil then iterate
    self~sendMove(assigned, taken, mover, self~destInto(mover, c), 'OCCUPY')
    -- moving in: a tie bounces and the centre stays mine, so match the worst case
    self~backMove(assigned, taken, mover, c, foes~items - 1)
  end
::method attack private
  -- my moves into an occupied or contested province get the support that
  -- wins it; support that cannot win is not spent (none into an agreed bounce)
  expose a me map constraints
  use strict arg assigned, taken
  do loc over heelTurnSorted(assigned~allIndexes)
    c = assigned[loc]
    if c['KIND'] \== 'M' then iterate
    if c~hasIndex('ROLE') then if c['ROLE'] == 'CUT' then iterate
    mover = c['UNIT']
    db = map~base(c['DEST'])
    if constraints~hasIndex('NOSUPPORTINTO') then if constraints['NOSUPPORTINTO']~hasIndex(db) then iterate
    if self~resisters(db)~items = 0 then if \a~unitAt~hasIndex(db) then iterate
    need = self~resistance(db)
    if need = 0 then iterate
    self~backMove(assigned, taken, mover, db, need)
  end
::method resistance private
  -- what a move into db must beat: 1 + the occupant's supporters, or the
  -- strongest hostile move into an empty db (all of them behind one)
  expose a me
  use strict arg db
  if a~unitAt~hasIndex(db) then do
    if a~unitAt[db]['OWNER'] == me then return 0
    return 1 + self~resisters(db)~items
  end
  return self~resisters(db)~items
::method backMove private
  -- supports, else cuts on the units that could resist, until the move beats
  -- need; if it cannot, every spare spent here is given back
  use strict arg assigned, taken, mover, db, need
  st = self~moveStrength(assigned, mover)
  if st > need then return .true
  foes = self~resisters(db)
  spent = .array~new
  do while st <= need
    sups = self~supportersFor(assigned, db, mover['LOC'])
    if sups~items > 0 then do
      self~giveMoveSupport(assigned, taken, sups[1], mover)
      spent~append(sups[1])
      st += 1
      iterate
    end
    cuts = self~cutters(assigned, foes, db, taken, mover['LOC'])
    if cuts~items = 0 then leave
    self~sendCut(assigned, taken, cuts[1][1], cuts[1][3])
    spent~append(cuts[1][1])
    foes~removeItem(cuts[1][2])
    need -= 1
  end
  if st > need then return .true
  do s over spent
    self~release(assigned, taken, s)
  end
  return .false
::method backHold private
  -- the same for a unit holding on my centre: hold supports, else cuts,
  -- until hold >= the worst-case attack (a tie holds); if it cannot, the
  -- units spent are given back (a hold that falls anyway is not worth them)
  use strict arg assigned, taken, holder, c, foes
  attack = foes~items
  h = self~holdStrength(assigned, holder['LOC'])
  left = foes~copy
  spent = .array~new
  do while h < attack
    sups = self~supportersFor(assigned, c, holder['LOC'])
    if sups~items > 0 then do
      self~giveHold(assigned, taken, sups[1], holder)
      spent~append(sups[1])
      h += 1
      iterate
    end
    cuts = self~cutters(assigned, left, c, taken, holder['LOC'])
    if cuts~items = 0 then leave
    self~sendCut(assigned, taken, cuts[1][1], cuts[1][3])
    spent~append(cuts[1][1])
    left~removeItem(cuts[1][2])
    attack -= 1
  end
  if h >= attack then return .true
  -- short of the worst case: units that were only holding keep supporting
  -- (it costs nothing and the enemy may not bring everything); units taken
  -- off a move get it back
  do s over spent
    c = assigned[s['LOC']]
    if c~hasIndex('WAS') then if c['WAS'][1] == 'M' then self~release(assigned, taken, s)
    if c['ROLE'] == 'CUT' then self~release(assigned, taken, s)
  end
  return .false
::method resisters private
  -- the units a move into db must beat: the occupant's own power's units that
  -- can support it, or the hostile units that can move into an empty db
  -- (none for a dislodge by agreement: the victim holds alone)
  expose a me map constraints
  use strict arg db
  out = .array~new
  if constraints~hasIndex('TREATY') then if constraints['TREATY']~hasIndex(db) then return out
  if a~unitAt~hasIndex(db) then do
    occ = a~unitAt[db]
    do u over a~view~units
      if u['OWNER'] \== occ['OWNER'] | u['BASE'] == db then iterate
      if map~reaches(u['TYPE'], u['LOC'], db) then out~append(u)
    end
    return out
  end
  return self~hostileUnits(db)
::method dislodge private
  -- an enemy unit my available units can beat: attack it when the province
  -- is worth having or the unit has nowhere to retreat (it is then
  -- disbanded); the best such target first
  expose a me map fall
  use strict arg assigned, taken
  tried = .directory~new
  do forever
    best = .nil
    bestValue = 0
    do e over a~view~units
      if e['OWNER'] == me then iterate
      if tried~hasIndex(e['BASE']) then iterate
      if self~hostility(e['OWNER']) < 0.6 then iterate
      if self~forbidden(e['BASE']) then iterate
      if taken~hasIndex(e['BASE']) then iterate
      atk = .nil
      do s over self~available(assigned, 'DISLODGE', e['BASE'])
        if self~destInto(s, e['BASE']) \== '' then do
          atk = s
          leave
        end
      end
      if atk == .nil then iterate
      v = 1
      if map~isCentre(e['BASE']) then do
        v += 4
        if fall then v += 4
        if a~owner(e['BASE']) == me then v += 4
      end
      if self~retreatsLeft(e, atk['BASE'], taken) = 0 then v += 6
      if v > bestValue then do
        bestValue = v
        best = .array~of(e, atk)
      end
    end
    if best == .nil then leave
    if bestValue < 5 then leave
    e = best[1]
    s = best[2]
    tried[e['BASE']] = 1
    self~sendMove(assigned, taken, s, self~destInto(s, e['BASE']), 'DISLODGE')
    if \self~backMove(assigned, taken, s, e['BASE'], self~resistance(e['BASE'])) then self~release(assigned, taken, s)
  end
::method retreatsLeft private
  -- where a unit I dislodge could still retreat: not my attacker's origin,
  -- not where any unit will stand, not where my units are going
  expose a map
  use strict arg e, attackerFrom, taken
  n = 0
  do d over map~dests(e['TYPE'], e['LOC'])
    b = map~base(d)
    if b == attackerFrom then iterate
    if taken~hasIndex(b) then iterate
    if a~unitAt~hasIndex(b) then if a~unitAt[b]['OWNER'] \== a~view~me then iterate
    n += 1
  end
  return n
::method deny private
  -- spares bounce hostile units out of provinces they should not have: in
  -- the fall a centre that is not mine; with deny set, the provinces next to
  -- my centres. A bounce keeps it empty; if no one comes, the spare is in.
  expose a me map fall
  use strict arg assigned, taken
  wanted = .array~new
  do c over heelTurnSorted(a~view~centres~allIndexes)
    if fall then if a~owner(c) \== me then if \a~unitAt~hasIndex(c) then wanted~append(c)
  end
  if self~knob('deny') >= 0.5 then do c over heelTurnSorted(a~view~centres~allIndexes)
    if a~owner(c) \== me then iterate
    do q over map~neighbours(c)
      if map~isCentre(q) then iterate
      if a~unitAt~hasIndex(q) then iterate
      if \wanted~hasItem(q) then wanted~append(q)
    end
  end
  do q over wanted
    if taken~hasIndex(q) then iterate
    if self~forbidden(q) then iterate
    foes = self~hostileUnits(q)
    if foes~items = 0 then iterate
    do s over self~available(assigned, 'DENY')
      d = self~destInto(s, q)
      if d == '' then iterate
      if self~swaps(assigned, s, d) then iterate
      self~sendMove(assigned, taken, s, d, 'DENY')
      leave
    end
  end
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
  -- a promised support: the unit named gives it, taken off its own move if
  -- that move is not itself a promise; else any unit holding that can
  expose map constraints
  use strict arg assigned, promise, plan, taken
  tdest = promise['TDEST']
  aim = promise['TLOC']
  if tdest \== '' then aim = tdest
  do hl over heelTurnSorted(assigned~allIndexes)
    h = assigned[hl]
    hu = h['UNIT']
    if promise['LOC'] \== '' then do
      if hu['BASE'] \== map~base(promise['LOC']) then iterate
      if h['KIND'] == 'M' then do
        if constraints~hasIndex('MOVES') then if constraints['MOVES']~hasIndex(hu['LOC']) then iterate
        taken~remove(map~base(h['DEST']))
        taken[hu['BASE']] = hu['LOC']
        h['KIND'] = 'H'
        h['DEST'] = ''
      end
    end
    if h['KIND'] \== 'H' then iterate
    if hu['BASE'] == map~base(aim) then iterate
    if \map~reaches(hu['TYPE'], hu['LOC'], aim) then iterate
    h['KIND'] = 'S'
    if tdest == '' then h['SUP'] = promise['TTYPE'] promise['TLOC']
    else h['SUP'] = promise['TTYPE'] promise['TLOC'] '-' tdest
    h['ROLE'] = 'PROMISE'
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
  -- A retreat is a move no movement order can bounce (only another retreat
  -- into the same province), so it is scored as a move: in the fall an
  -- unowned centre is taken (ownership changes after fall retreats) and a
  -- home centre of mine is left vacant when I will have a build; otherwise
  -- the province nearest a target, or a centre of mine under threat, and not
  -- one where the unit would be dislodged again.
  expose map a view me fall constraints
  plan = heelTurnPlan()
  standoff = self~standoffs
  tdist = self~targetDistances
  builds = self~expectedBuilds
  do u over view~task
    from = ''
    do d over view~dislodged
      if d['LOC'] == u['LOC'] then from = map~base(d['FROM'])
    end
    best = ''
    bestScore = -999
    agreed = ''
    if constraints~hasIndex('RETREATS') then if constraints['RETREATS']~hasIndex(u['LOC']) then agreed = map~base(constraints['RETREATS'][u['LOC']])
    do d over map~dests(u['TYPE'], u['LOC'])
      db = map~base(d)
      if db == from then iterate
      if a~unitAt~hasIndex(db) then iterate
      if standoff~hasIndex(db) then iterate
      if plan['INTO']~hasIndex(db) then iterate
      s = self~retreatScore(u, db, tdist, builds)
      -- the retreat agreed in a dislodge by agreement, if it is still open
      if db == agreed then s = s + 1000
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
::method retreatScore private
  expose map a me fall
  use strict arg u, db, tdist, builds
  s = 0
  owner = a~owner(db)
  if map~isCentre(db) then do
    select
      when owner == me then do
        t = self~hostileUnits(db)~items
        s += 2 + t * 2 * self~knob('defence')
        if fall & builds > 0 & a~map~homeOf(db) == me then s -= 4
      end
      when owner == 'N' then do
        if fall then s += 10 * self~knob('expand')
        else s += 3
      end
      otherwise do
        if self~rel(owner) == 'ALLY' then s -= 2
        else if fall then s += 8 * (0.4 + self~knob('aggression')) * self~hostility(owner)
        else s += 2 * self~hostility(owner)
      end
    end
  end
  -- next turn: closer to a target is better
  if tdist~hasIndex(db) then s -= tdist[db] * 1.5
  -- would it be dislodged again? more hostile units in reach is worse
  s -= self~hostileUnits(db)~items * 1.2
  return s
::method expectedBuilds private
  -- centres I will own after this phase minus units: a guess, for not
  -- blocking my own home centres with a retreat
  expose a me view
  n = 0
  do c over a~view~centres~allIndexes
    if a~owner(c) == me then n += 1
  end
  return n - a~myUnits~items
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
  return '0.2'
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
