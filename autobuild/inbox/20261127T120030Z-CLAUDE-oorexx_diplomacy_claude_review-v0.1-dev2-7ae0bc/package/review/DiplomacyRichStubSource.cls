/* Adversarial test player for the step-5 controller.
   Review tooling by Claude (Opus 5.5). Architecture: Tom Dyer.
   Not a strategy. It uses only the public view (map, board, ownership, task)
   and deliberately mixes valid orders with supports, convoys, VIA CONVOY,
   fleet builds with and without coasts, malformed orders, duplicate orders,
   orders for other powers' units, omitted orders, and failed calls
   (TIMEOUT, ERROR, non-array response, embedded newline). */
::requires 'DiplomacyGame.cls'
::class DiplomacyRichStubSource public
::method init
  expose board rng coasts coastal seas
  use strict arg board, seed
  numeric digits 20
  rng = seed // 2147483646 + 1
  coasts = .directory~new
  coastal = .array~new
  seas = .directory~new
  do code over board~nodeCodes
    if code~pos('/') > 0 then do
      parse var code province '/' .
      if \coasts~hasIndex(province) then coasts[province] = .array~new
      coasts[province]~append(code)
    end
    if board~node(code)['KIND'] == 'coast' then coastal~append(code)
    if board~node(code)['KIND'] == 'sea' then seas[code] = .true
  end
::method draw
  expose rng
  use strict arg n
  numeric digits 20
  if n < 1 then raise syntax 93.900 array('Empty random choice')
  rng = (rng * 48271) // 2147483647
  return rng // n + 1
::method pick
  use strict arg items
  return items[self~draw(items~items)]
::method orders
  expose board coasts coastal seas
  use strict arg view
  roll = self~draw(200)
  if roll = 1 then return .array~of('TIMEOUT',.array~new)
  if roll = 2 then return .array~of('ERROR',.array~new)
  if roll = 3 then return 'not an array'
  if roll = 4 then return .array~of('OK',.array~of('A PAR H' || '0A'x || 'A MAR H'))
  out = .array~new
  task = view['TASK']
  kind = view['KIND']
  boardUnits = .array~new
  do row over view['BOARD']
    parse var row owner '|' typ '|' loc
    boardUnits~append(typ loc)
  end
  if kind == 'MOVEMENT' then do
    /* Pass 1: one order per own unit. Pass 2: some own units switch to a valid
       support of another own unit's planned move into a province they reach. */
    planned = .array~new
    do item over task
      planned~append(self~movementOrder(item~word(1), item~word(2), boardUnits))
    end
    do idx = 1 to task~items
      if self~draw(3) > 1 then iterate
      parse value task[idx] with typ loc
      reach = .directory~new
      do code over board~neighbours(loc, typ)
        reach[board~provinceOf(code)] = .true
      end
      do other = 1 to planned~items
        if other = idx then iterate
        parse value planned[other] with oTyp oLoc oVerb oDest .
        if oVerb \== '-' then iterate
        if \reach~hasIndex(board~provinceOf(oDest)) then iterate
        planned[idx] = typ loc 'S' oTyp oLoc '-' oDest
        leave
      end
    end
    do order over planned
      out~append(order)
    end
    if self~draw(20) = 1 then if task~items > 0 then out~append(self~pick(task) 'H')
    if self~draw(10) = 1 then if boardUnits~items > 0 then out~append(self~pick(boardUnits) 'H')
  end
  else if kind == 'RETREAT' then do
    do item over task
      parse var item typ loc
      choice = self~draw(10)
      if choice = 1 then iterate
      if choice <= 3 then do
        out~append(item 'D')
        iterate
      end
      edges = board~neighbours(loc, typ)
      if edges~items = 0 then out~append(item 'D')
      else out~append(item 'R' self~stripCoastSometimes(self~pick(edges)))
    end
  end
  else if kind == 'ADJUSTMENT' then do
    balance = view['BALANCE']
    if balance < 0 then do
      if self~draw(5) > 1 then do idx = 1 to -balance + self~draw(2) - 1
        out~append('DISBAND' self~pick(task))
      end
    end
    else do
      occupied = .directory~new
      do row over view['BOARD']
        parse var row . '|' . '|' loc
        occupied[board~provinceOf(loc)] = .true
      end
      choices = .array~new
      do row over view['OWNERSHIP']
        parse var row loc '|' owner
        if owner \== view['POWER'] then iterate
        if board~node(loc)['HOME'] \== owner then iterate
        if occupied~hasIndex(loc) then iterate
        choices~append(loc)
      end
      wanted = balance + self~draw(2) - 1
      do idx = 1 to wanted
        if choices~items = 0 | self~draw(8) = 1 then out~append('WAIVE')
        else out~append(self~buildOrder(self~pick(choices)))
      end
      if self~draw(15) = 1 then out~append('BUILD A' self~pick(coastal))
    end
  end
  return .array~of('OK',out)
::method movementOrder
  expose board coasts coastal seas
  use strict arg typ, loc, boardUnits
  roll = self~draw(100)
  edges = board~neighbours(loc, typ)
  if roll <= 4 then return typ loc '- XXX'
  if roll <= 6 then return typ~lower loc~lower '-' self~pickOr(edges, loc)~lower
  if roll <= 8 then return self~otherType(typ) loc 'H'
  if roll <= 10 then return typ loc '-' self~stripCoastSometimes(self~pickOr(edges, loc))
  if roll <= 20 then return typ loc 'H'
  if roll <= 55 then return typ loc '-' self~pickOr(edges, loc)
  if roll <= 75 then do
    target = self~pick(boardUnits)
    parse var target tTyp tLoc
    if self~draw(2) = 1 then return typ loc 'S' tTyp tLoc
    tEdges = board~neighbours(tLoc, tTyp)
    return typ loc 'S' tTyp tLoc '-' self~pickOr(tEdges, tLoc)
  end
  if typ == 'A' then do
    dest = self~pick(coastal)
    if self~draw(2) = 1 then return 'A' loc '-' dest 'VIA CONVOY'
    return 'A' loc '-' dest
  end
  if seas~hasIndex(loc) then do
    armies = .array~new
    do unitText over boardUnits
      if unitText~word(1) == 'A' then armies~append(unitText)
    end
    if armies~items > 0 then return 'F' loc 'C' self~pick(armies) '-' self~pick(coastal)
  end
  return typ loc '-' self~pickOr(edges, loc)
::method pickOr
  use strict arg items, fallback
  if items~items = 0 then return fallback
  return self~pick(items)
::method otherType
  use strict arg typ
  if typ == 'A' then return 'F'
  return 'A'
::method stripCoastSometimes
  use strict arg code
  if code~pos('/') = 0 then return code
  if self~draw(3) > 1 then return code
  parse var code province '/' .
  return province
::method buildOrder
  expose board coasts
  use strict arg loc
  if board~node(loc)['FLEET'] == '' then if \coasts~hasIndex(loc) then return 'BUILD A' loc
  if self~draw(2) = 1 then return 'BUILD A' loc
  if coasts~hasIndex(loc) then do
    if self~draw(4) = 1 then return 'BUILD F' loc
    return 'BUILD F' self~pick(coasts[loc])
  end
  return 'BUILD F' loc
::method complete
  return
::method module_version class
  return '0.1-review'
::method module_version
  return self~class~module_version
::method module_lastChanged class
  return '2026-11-26'
::method module_lastChanged
  return self~class~module_lastChanged
