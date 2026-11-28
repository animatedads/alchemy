/* HeelTurnBench.cls - directed positions for the tactics tests.
   Architecture: Tom Dyer. Code: Claude (Opus 5.5).
   Everything is the framework's own: DiplomacyPlayer renders the call and
   parses the reply exactly as in a game, DiplomacyAdjudicator decides the
   outcome. The bench only sets up a position and scripts the other powers'
   orders. It invents no rule. */
::requires 'DiplomacyGame.cls'
::requires 'DiplomacyPlayer.cls'
::requires 'HeelTurnEngine.cls'

::class HeelTurnBench public
::attribute board get
::attribute judge get
::method init
  expose board judge journal engine mapLines rules droot journalPath
  use strict arg droot, hroot, journalPath
  board = .DiplomacyBoard~new(droot'/data/standard.source')
  judge = .DiplomacyAdjudicator~new(board, droot'/data/rules.conf')
  journal = .DiplomacyGameJournal~new(journalPath, .false)
  engine = .HeelTurnEngine~new(hroot'/data', '', .false)
  rules = 'Standard Diplomacy, 1901 to 1910. Strict literal orders.'
  mapLines = .array~new
  do code over board~nodeCodes
    node = board~node(code)
    mapLines~append(code'|'node['NAME']'|'node['KIND']'|'node['HOME']'|'node['ARMY']'|'node['FLEET'])
  end
::method position
  -- lines: 'AUS A BUD' ...; returns a directory province -> DiplomacyUnit
  expose board
  use strict arg lines
  units = .directory~new
  do line over lines
    parse var line power typ loc
    province = board~provinceOf(loc)
    if units~hasIndex(province) then raise syntax 93.900 array('Two units in' province)
    units[province] = .DiplomacyUnit~new(power, typ, loc)
  end
  return units
::method ownership
  -- the 1901 ownership with changes: 'RUM AUS' ...
  expose judge
  use strict arg changes = (.array~new)
  own = judge~initialOwnership
  do c over changes
    parse var c centre owner
    own[centre] = owner
  end
  return own
::method view
  -- the directory DiplomacyGame~makeView builds, for any position
  expose mapLines
  use strict arg kind, power, phase, year, units, ownership, movement = .nil, inbox = (.array~new), resultsPhase = ''
  task = .array~new
  if kind == 'RETREAT' then do loc over movement~dislodged~allIndexes~sort
    unit = movement~dislodged[loc][1]
    if unit~owner == power then task~append(unit~unitType unit~location)
  end
  else do loc over units~allIndexes~sort
    unit = units[loc]
    if unit~owner == power then task~append(unit~unitType unit~location)
  end
  centres = 0
  do c over ownership~allIndexes
    if ownership[c] == power then centres += 1
  end
  v = .directory~new
  v['YEAR'] = year
  v['PHASE'] = phase
  v['KIND'] = kind
  v['POWER'] = power
  v['BALANCE'] = centres - task~items
  if kind == 'RETREAT' then v['BALANCE'] = 0
  v['TASK'] = task
  v['MAP'] = mapLines~copy
  board = .array~new
  do loc over units~allIndexes~sort
    unit = units[loc]
    board~append(unit~owner'|'unit~unitType'|'unit~location)
  end
  v['BOARD'] = board
  own = .array~new
  do loc over ownership~allIndexes~sort
    own~append(loc'|'ownership[loc])
  end
  v['OWNERSHIP'] = own
  v['LAST_RESULTS'] = .array~new
  v['PUBLIC_SINCE_CALL'] = .array~new
  -- a retreat call sees the movement results just published, as in a game
  if resultsPhase == '' then resultsPhase = phase~left(pos('_', phase))'MOVEMENT'
  if movement \== .nil then do row over movement~published
    v['PUBLIC_SINCE_CALL']~append(.array~of(year, resultsPhase, row[1], row[2], row[3]))
  end
  v['DISLODGED'] = .array~new
  if kind == 'RETREAT' then do loc over movement~dislodged~allIndexes~sort
    entry = movement~dislodged[loc]
    if entry == .nil then iterate
    unit = entry[1]
    v['DISLODGED']~append(unit~owner'|'unit~unitType'|'unit~location'|'entry[2]'|'entry[3])
  end
  v['HISTORY'] = .array~new
  v['PLAYER_LIST'] = .array~of('AUS', 'ENG', 'FRA', 'GER', 'ITA', 'RUS', 'TUR')
  if kind == 'PRESS' then do
    v['ROUND'] = 1
    v['ROUNDS'] = 2
    v['INBOX'] = inbox
  end
  else if inbox~items > 0 then v['INBOX'] = inbox
  return v
::method player
  -- a framework player for one power's designer prompt (the others say
  -- "Play well."); it keeps that power's memory between calls, as in a game
  expose engine rules journal
  use strict arg power, prompt
  prompts = .directory~new
  do p over .array~of('AUS', 'ENG', 'FRA', 'GER', 'ITA', 'RUS', 'TUR')
    prompts[p] = 'Play well.'
  end
  prompts[power] = prompt
  return .DiplomacyPlayer~new(engine, prompts, rules, journal, 'BENCH', 1)
::method lastReply
  -- the reply text of the last player call, from the framework's own audit
  expose journalPath
  s = .stream~new(journalPath'.operator.log')
  if s~open('READ') \== 'READY:' then return ''
  last = ''
  do while s~lines > 0
    line = s~linein
    if line~left(12) == 'PLAYER_CALL|' then last = line
  end
  s~close
  if last == '' then return ''
  f = .array~new
  rest = last
  do while rest \== ''
    parse var rest field '|' rest
    f~append(field)
  end
  return f[12]~x2c
::method mail
  -- an inbox frame as DiplomacyPress renders one
  use strict arg mid, from, to, body
  return '=== MAIL' mid 'FROM' from 'TO' to '===' || '0A'x || body || '0A'x || '=== END MAIL' mid '==='
::method move
  -- submitted: power -> array of raw order lines
  expose judge
  use strict arg units, submitted
  return judge~movement(units, submitted)
::method retreat
  expose judge
  use strict arg movement, submitted
  return judge~retreats(movement, submitted)
::method module_version class
  return '0.2'
