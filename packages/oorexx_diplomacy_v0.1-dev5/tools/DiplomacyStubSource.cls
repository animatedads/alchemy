/* Deliberately weak test player. No referee legality API. Public map only.
   Not a competitive prompt or strategy engine. */
::requires 'DiplomacyGame.cls'
::class DiplomacyStubSource public
::method init
  expose board rng mode
  use strict arg board, seed, mode
  if wordpos(mode,'HOLD RANDOM') = 0 then raise syntax 93.900 array('Unknown stub mode')
  numeric digits 20
  rng = seed // 2147483646 + 1
::method draw
  expose rng
  use strict arg n
  numeric digits 20
  if n < 1 then raise syntax 93.900 array('Empty random choice')
  rng = (rng * 48271) // 2147483647
  return rng // n + 1
::method orders
  expose board mode
  use strict arg view
  out = .array~new
  task = view['TASK']
  kind = view['KIND']
  if kind == 'MOVEMENT' then do
    do item over task
      parse var item typ loc
      if mode == 'HOLD' then do
        out~append(item 'H')
        iterate
      end
      roll = self~draw(10)
      if roll = 1 then iterate
      if roll = 2 then do
        out~append(item '- XXX')
        iterate
      end
      if roll = 3 then do
        out~append(item 'H')
        iterate
      end
      edges = board~neighbours(loc,typ)
      if edges~items = 0 then out~append(item 'H')
      else out~append(item '-' edges[self~draw(edges~items)])
    end
  end
  else if kind == 'RETREAT' then do
    do item over task
      parse var item typ loc
      if mode == 'HOLD' then out~append(item 'D')
      else do
        edges = board~neighbours(loc,typ)
        if edges~items = 0 then out~append(item 'D')
        else if self~draw(3) = 1 then out~append(item 'D')
        else out~append(item 'R' edges[self~draw(edges~items)])
      end
    end
  end
  else if kind == 'ADJUSTMENT' then do
    balance = view['BALANCE']
    if balance < 0 then do idx = 1 to -balance
      if idx <= task~items then out~append('DISBAND' task[idx])
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
      do idx = 1 to balance
        if mode == 'RANDOM' & idx <= choices~items then out~append('BUILD A' choices[idx])
        else out~append('WAIVE')
      end
    end
  end
  return .array~of('OK',out)
::method complete
  return
::method module_version class
  return '0.1-dev5'
::method module_version
  return self~class~module_version
::method module_lastChanged class
  return '2026-11-26'
::method module_lastChanged
  return self~class~module_lastChanged
