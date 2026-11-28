/* HeelTurnBoard.cls - Heel Turn SLAM: the framework's text read as a board.
   Architecture: Tom Dyer. Code: Claude (Opus 5.5).
   Reads exactly what any runner (Haiku, Sol) receives: the rendered SYSTEM
   and USER text. No referee object and no legal-order list exist here; the
   map, the state and the published results are all there is. */
::requires 'HeelTurnLanguage.cls'

::class HeelTurnView public
::attribute year get
::attribute phase get
::attribute me get
::attribute kind get
::attribute balance get
::attribute round get
::attribute rounds get
::attribute mapLines get
::attribute units get
::attribute centres get
::attribute history get
::attribute dislodged get
::attribute results get
::attribute playerList get
::attribute mail get
::attribute memory get
::attribute task get
::attribute prompt get
::method init
  expose year phase me kind balance round rounds mapLines units centres history dislodged results playerList mail memory task prompt
  use strict arg system, input
  -- The designer prompt follows the fixed framework header and a blank line.
  normal = changestr('0D0A'x, system, '0A'x)
  at = pos('0A0A'x, normal)
  if at > 0 then prompt = normal~substr(at + 2)
  else prompt = normal
  mapLines = .array~new
  units = .array~new
  centres = .directory~new
  history = .array~new
  dislodged = .array~new
  results = .array~new
  playerList = .array~new
  mail = .array~new
  memory = .array~new
  task = .array~new
  year = 0
  phase = ''
  me = ''
  kind = ''
  balance = 0
  round = 0
  rounds = 0
  section = ''
  headers = .array~of('=== RULES ===', '=== MAP ===', '=== STATE ===', '=== LAST RESULTS ===', '=== PLAYER LIST ===', '=== INBOX ===', '=== MEMORY ===', '=== END MEMORY ===', '=== TASK ===')
  nextHeader = 1
  pendingResult = .nil
  frame = .nil
  lines = changestr('0D0A'x, input, '0A'x)~makeArray('0A'x)
  do line over lines
    -- Headers come in a fixed order, so text inside a section (rules, mail)
    -- can never open a later section early.
    if nextHeader <= headers~items then if line == headers[nextHeader] then do
      section = line
      nextHeader += 1
      iterate
    end
    select
      when section == '=== MAP ===' then do
        if line~left(5) == 'code|' then iterate
        if line \== '' then mapLines~append(line)
      end
      when section == '=== STATE ===' then do
        parse var line tag '|' rest
        select
          when tag == 'UNIT' then do
            parse var rest owner '|' utype '|' loc
            units~append(heelTurnUnit(owner, utype, loc))
          end
          when tag == 'CENTRE' then do
            parse var rest code '|' owner
            centres[code] = owner
          end
          when tag == 'YEAR' then history~append(rest)
          when tag == 'DISLODGED' then do
            parse var rest owner '|' utype '|' loc '|' fromLoc '|' convoyed
            u = heelTurnUnit(owner, utype, loc)
            u['FROM'] = fromLoc
            dislodged~append(u)
          end
          otherwise do
            if words(line) >= 4 then if line~word(3) == 'POWER' then do
              year = line~word(1)
              phase = line~word(2)
              me = line~word(4)
            end
          end
        end
      end
      when section == '=== LAST RESULTS ===' then do
        if line~left(2) == '> ' then do
          if pendingResult \== .nil then do
            pendingResult['LINE'] = line~substr(3)
            results~append(pendingResult)
            pendingResult = .nil
          end
          iterate
        end
        if line~countStr('|') = 3 then do
          parse var line ry '|' rp '|' rpow '|' rstatus
          pendingResult = .directory~new
          pendingResult['YEAR'] = ry
          pendingResult['PHASE'] = rp
          pendingResult['POWER'] = rpow
          pendingResult['STATUS'] = rstatus
        end
      end
      when section == '=== PLAYER LIST ===' then do
        if words(line) = 2 then if line~word(1)~datatype('W') then playerList~append(line~word(2))
      end
      when section == '=== INBOX ===' then do
        if frame == .nil then do
          if line~left(9) == '=== MAIL ' then do
            parse var line '=== MAIL ' mid ' FROM ' sender ' TO ' recips ' ===' .
            frame = .directory~new
            frame['ID'] = mid
            frame['FROM'] = sender
            frame['TO'] = recips
            frame['BODY'] = .array~new
          end
        end
        else do
          if line == '=== END MAIL' frame['ID'] '===' then do
            frame['TEXT'] = frame['BODY']~makeString('L', '0A'x)
            mail~append(frame)
            frame = .nil
          end
          else frame['BODY']~append(line)
        end
      end
      when section == '=== MEMORY ===' then do
        if line~left(2) == '> ' then memory~append(line~substr(3))
        else if line == '>' then nop
      end
      when section == '=== TASK ===' then do
        if kind == '' then do
          kind = line~word(1)
          balance = line~word(5)
          iterate
        end
        if line~left(6) == 'Round ' then do
          round = line~word(2)
          rounds = line~word(4)
          iterate
        end
        if words(line) = 2 then if wordpos(line~word(1), 'A F') > 0 then task~append(heelTurnUnit(me, line~word(1), line~word(2)))
      end
      otherwise nop
    end
  end
::method numberFor
  -- The number to address a power by, in this round's own list.
  expose playerList
  use strict arg power
  do idx = 1 to playerList~items
    if playerList[idx] == power then return idx
  end
  return 0
::method module_version class
  return '0.1r9'
::method module_version
  return self~class~module_version
::method module_lastChanged class
  return '2026-11-27'
::method module_lastChanged
  return self~class~module_lastChanged

::routine heelTurnUnit public
  use strict arg owner, utype, loc
  u = .directory~new
  u['OWNER'] = owner
  u['TYPE'] = utype
  u['LOC'] = loc
  parse var loc b '/' .
  u['BASE'] = b
  return u

/* The map as a graph, plus who is where. Provinces by base code. */
::class HeelTurnMap public
::attribute powers get
::method init
  expose nodes powers adj
  use strict arg mapLines
  nodes = .directory~new
  adj = .directory~new
  powers = .array~of('AUS', 'ENG', 'FRA', 'GER', 'ITA', 'RUS', 'TUR')
  do line over mapLines
    parse var line code '|' name '|' nkind '|' home '|' army '|' fleet
    n = .directory~new
    n['CODE'] = code
    n['NAME'] = name
    n['KIND'] = nkind
    n['HOME'] = home
    n['ARMY'] = army~strip
    n['FLEET'] = fleet~strip
    nodes[code] = n
  end
  seen = .directory~new
  do code over nodes~allIndexes
    b = self~base(code)
    if \seen~hasIndex(b) then seen[b] = .directory~new
    do d over (nodes[code]['ARMY'] nodes[code]['FLEET'])~space~makeArray(' ')
      seen[b][self~base(d)] = 1
    end
  end
  do b over seen~allIndexes
    adj[b] = heelTurnSorted(seen[b]~allIndexes)
  end
::method node
  expose nodes
  use strict arg code
  if nodes~hasIndex(code) then return nodes[code]
  return .nil
::method kindOf
  use strict arg code
  n = self~node(self~base(code))
  if n == .nil then return ''
  return n['KIND']
::method base
  use strict arg code
  parse var code b '/' .
  return b
::method provinces
  -- Base provinces, sorted.
  expose nodes
  out = .array~new
  do code over nodes~allIndexes
    if code~pos('/') = 0 then out~append(code)
  end
  return out~sort
::method isCentre
  use strict arg code
  n = self~node(self~base(code))
  if n == .nil then return .false
  return n['HOME'] \== '-'
::method homeOf
  -- Owner of a home centre, N for a neutral centre, - for no centre.
  use strict arg code
  n = self~node(self~base(code))
  if n == .nil then return '-'
  return n['HOME']
::method homes
  expose nodes
  use strict arg power
  out = .array~new
  do code over self~provinces
    if nodes[code]['HOME'] == power then out~append(code)
  end
  return out
::method coasts
  -- Coast nodes of a split province (STP/NC STP/SC), sorted; empty if none.
  expose nodes
  use strict arg province
  out = .array~new
  do code over nodes~allIndexes
    if code~left(province~length + 1) == province'/' then out~append(code)
  end
  return out~sort
::method dests
  -- Where a unit may try to move, as the exact text an order must use.
  -- Armies move between base provinces; fleets between the nodes the
  -- fleet column names (split coasts named, as the strict rules want).
  use strict arg utype, loc
  if utype == 'A' then do
    n = self~node(self~base(loc))
    if n == .nil then return .array~new
    if n['ARMY'] == '' then return .array~new
    return n['ARMY']~makeArray(' ')
  end
  n = self~node(loc)
  if n == .nil then return .array~new
  if n['FLEET'] == '' then return .array~new
  return n['FLEET']~makeArray(' ')
::method reaches
  -- Can this unit move into the province (any coast)? Support reach is to
  -- the province (SUPPORT_REACH=PROVINCE).
  use strict arg utype, loc, province
  target = self~base(province)
  do d over self~dests(utype, loc)
    if self~base(d) == target then return .true
  end
  return .false
::method destInto
  -- The exact destination text for this unit into a province, or ''.
  use strict arg utype, loc, province
  target = self~base(province)
  do d over self~dests(utype, loc)
    if self~base(d) == target then return d
  end
  return ''
::method neighbours
  -- Base provinces next to a province by army or fleet (built once).
  expose adj
  use strict arg province
  b = self~base(province)
  if adj~hasIndex(b) then return adj[b]
  return .array~new
::method convoyRoute
  -- Is there a physical convoy route now: a chain of sea provinces, each
  -- holding a fleet (anyone's), from the army's coast to the destination
  -- coast? This is the board fact the rules use
  -- (NONADJACENT_ARMY_MOVE=CONVOY_IF_PHYSICAL_ROUTE); it is not a promise
  -- that the convoy will be ordered.
  use strict arg units, fromProv, toProv
  fleetSeas = .directory~new
  do u over units
    if u['TYPE'] == 'F' then if self~kindOf(u['LOC']) == 'sea' then fleetSeas[u['BASE']] = 1
  end
  from = self~base(fromProv)
  dest = self~base(toProv)
  if self~kindOf(from) \== 'coast' | self~kindOf(dest) \== 'coast' then return .false
  seen = .directory~new
  frontier = .array~new
  do sea over heelTurnSorted(fleetSeas~allIndexes)
    if self~reaches('F', sea, from) then do
      seen[sea] = 1
      frontier~append(sea)
    end
  end
  do while frontier~items > 0
    nextFrontier = .array~new
    do sea over frontier
      if self~reaches('F', sea, dest) then return .true
      do q over self~neighbours(sea)
        if seen~hasIndex(q) then iterate
        if \fleetSeas~hasIndex(q) then iterate
        seen[q] = 1
        nextFrontier~append(q)
      end
    end
    frontier = nextFrontier
  end
  return .false
::method distances
  -- Moves from a set of provinces to every province, army or fleet alike.
  use strict arg starts
  dist = .directory~new
  frontier = .array~new
  do s over starts
    b = self~base(s)
    if dist~hasIndex(b) then iterate
    dist[b] = 0
    frontier~append(b)
  end
  do while frontier~items > 0
    nextFrontier = .array~new
    do p over frontier
      do q over self~neighbours(p)
        if dist~hasIndex(q) then iterate
        dist[q] = dist[p] + 1
        nextFrontier~append(q)
      end
    end
    frontier = nextFrontier
  end
  return dist
::method module_version class
  return '0.1r9'
::method module_version
  return self~class~module_version
::method module_lastChanged class
  return '2026-11-27'
::method module_lastChanged
  return self~class~module_lastChanged

/* Assessing a position: counts, who touches whom, what is threatened. */
::class HeelTurnAssessment public
::attribute map get
::attribute view get
::attribute me get
::attribute unitAt get
::attribute centreCount get
::attribute unitCount get
::attribute leader get
::method init
  expose map view me unitAt centreCount unitCount leader contact
  use strict arg map, view
  me = view~me
  unitAt = .directory~new
  centreCount = .directory~new
  unitCount = .directory~new
  contact = .directory~new
  do p over map~powers
    centreCount[p] = 0
    unitCount[p] = 0
  end
  do u over view~units
    unitAt[u['BASE']] = u
    if unitCount~hasIndex(u['OWNER']) then unitCount[u['OWNER']] += 1
  end
  do code over heelTurnSorted(view~centres~allIndexes)
    owner = view~centres[code]
    if centreCount~hasIndex(owner) then centreCount[owner] += 1
  end
  leader = ''
  best = -1
  do p over map~powers
    if centreCount[p] > best then do
      best = centreCount[p]
      leader = p
    end
    else if centreCount[p] = best then leader = ''
  end
  -- contact: how many of a power's units can reach my centres or my units'
  -- provinces in one move, and how many of mine can reach theirs.
  mine = self~myGround
  do p over map~powers
    contact[p] = 0
  end
  do u over view~units
    if u['OWNER'] == me then iterate
    do g over mine
      if map~reaches(u['TYPE'], u['LOC'], g) then do
        contact[u['OWNER']] += 1
        leave
      end
    end
  end
::method myGround
  -- My centres and the provinces my units stand on.
  expose view me
  ground = .directory~new
  do code over view~centres~allIndexes
    if view~centres[code] == me then ground[code] = 1
  end
  do u over view~units
    if u['OWNER'] == me then ground[u['BASE']] = 1
  end
  return heelTurnSorted(ground~allIndexes)
::method groundOf
  expose view
  use strict arg power
  ground = .directory~new
  do code over view~centres~allIndexes
    if view~centres[code] == power then ground[code] = 1
  end
  do u over view~units
    if u['OWNER'] == power then ground[u['BASE']] = 1
  end
  return heelTurnSorted(ground~allIndexes)
::method contact
  expose contact
  use strict arg power
  if contact~hasIndex(power) then return contact[power]
  return 0
::method isNeighbour
  -- A power is a neighbour when its ground is within two moves of mine.
  expose map me
  use strict arg power
  if power == me then return .false
  if self~contact(power) > 0 then return .true
  mine = self~myGround
  if mine~items = 0 then return .false
  dist = map~distances(mine)
  do g over self~groundOf(power)
    if dist~hasIndex(g) then if dist[g] <= 2 then return .true
  end
  return .false
::method distanceTo
  expose map me
  use strict arg power
  mine = self~myGround
  if mine~items = 0 then return 99
  dist = map~distances(mine)
  best = 99
  do g over self~groundOf(power)
    if dist~hasIndex(g) then if dist[g] < best then best = dist[g]
  end
  return best
::method threats
  -- Foreign units that can move into a province.
  expose map view me
  use strict arg province, exclude = ''
  out = .array~new
  do u over view~units
    if u['OWNER'] == me then iterate
    if wordpos(u['OWNER'], exclude) > 0 then iterate
    if map~reaches(u['TYPE'], u['LOC'], province) then out~append(u)
  end
  return out
::method myUnits
  expose view me
  out = .array~new
  do u over view~units
    if u['OWNER'] == me then out~append(u)
  end
  return out
::method owner
  expose view
  use strict arg province
  if view~centres~hasIndex(province) then return view~centres[province]
  return '-'
::method alive
  expose map
  out = .array~new
  do p over map~powers
    if self~centreCount[p] > 0 | self~unitCount[p] > 0 then out~append(p)
  end
  return out
::method summary
  expose map me leader
  parts = .array~new
  do p over self~alive
    tag = ''
    if p == me then tag = '*'
    if self~isNeighbour(p) then tag = tag'n'
    parts~append(p || tag'='self~centreCount[p]'c/'self~unitCount[p]'u')
  end
  return 'leader='leader parts~makeString('L', ' ')
::method module_version class
  return '0.1r9'
::method module_version
  return self~class~module_version
::method module_lastChanged class
  return '2026-11-27'
::method module_lastChanged
  return self~class~module_lastChanged
