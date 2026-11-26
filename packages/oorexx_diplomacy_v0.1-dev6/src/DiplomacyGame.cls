/* Architecture Tom Dyer. Implementation ChatGPT GPT-6.2.
   Competition phase controller over the unchanged, qualified referee.
   Order provider receives detached public-state / own-task strings, never
   the referee, legal-order API, opponent submissions, or live state objects. */
::requires 'DiplomacyAdjudicator.cls'
::requires 'DiplomacyGameJournal.cls'
::requires 'DiplomacyPress.cls'

::class DiplomacyGameConfig public
::attribute startYear get
::attribute endYear get
::attribute soloCentres get
::attribute pressRounds get
::method init
  expose startYear endYear soloCentres pressRounds
  use strict arg startYear, endYear, soloCentres, pressRounds = 0
  if \startYear~datatype('W') then raise syntax 93.900 array('Invalid start year')
  if \endYear~datatype('W') then raise syntax 93.900 array('Invalid end year')
  if \soloCentres~datatype('W') then raise syntax 93.900 array('Invalid solo threshold')
  if startYear < 1 | endYear < startYear | soloCentres < 1 | soloCentres > 34 then raise syntax 93.900 array('Invalid game bounds')
  if \pressRounds~datatype('W') then raise syntax 93.900 array('Invalid press rounds')
  if pressRounds < 0 then raise syntax 93.900 array('Negative press rounds')
  pressRounds = pressRounds + 0
  startYear = startYear + 0
  endYear = endYear + 0
  soloCentres = soloCentres + 0
::method load class
  use strict arg path
  input = .stream~new(path)
  if input~open('READ') \== 'READY:' then raise syntax 93.900 array('Cannot open lifecycle config')
  fields = .directory~new
  do while input~lines > 0
    row = input~linein~strip
    if row == '' then iterate
    if row~left(1) == '#' then iterate
    parse var row key '=' value
    if wordpos(key,'START_YEAR END_YEAR SOLO_CENTRES PRESS_ROUNDS') = 0 then raise syntax 93.900 array('Unexpected lifecycle setting:' key)
    if fields~hasIndex(key) then raise syntax 93.900 array('Duplicate lifecycle setting:' key)
    fields[key] = value
  end
  input~close
  if fields~items \= 4 then raise syntax 93.900 array('Incomplete lifecycle config')
  return self~new(fields['START_YEAR'],fields['END_YEAR'],fields['SOLO_CENTRES'],fields['PRESS_ROUNDS'])
::method module_version class
  return '0.1-dev6'
::method module_version
  return self~class~module_version
::method module_lastChanged class
  return '2026-11-26'
::method module_lastChanged
  return self~class~module_lastChanged

::class DiplomacyGame public
::method init
  expose board judge config units ownership journal source seed powers year phase state history prior mapLines phaseCount invalidCount callCount winner finishReason press pressCallCount
  use strict arg board, judge, config, initialUnits, initialOwnership, source, journal, seed
  if \seed~datatype('W') then raise syntax 93.900 array('Integer game seed required')
  if seed < 0 | seed > 999999999 then raise syntax 93.900 array('Game seed out of range')
  units = initialUnits~copy
  ownership = initialOwnership~copy
  powers = .array~of('AUS','ENG','FRA','GER','ITA','RUS','TUR')
  history = .array~new
  prior = .array~new
  mapLines = .array~new
  do code over board~nodeCodes
    node = board~node(code)
    mapLines~append(code'|'node['NAME']'|'node['KIND']'|'node['HOME']'|'node['ARMY']'|'node['FLEET'])
  end
  year = config~startYear
  phase = ''
  state = 'READY'
  phaseCount = 0
  invalidCount = 0
  callCount = 0
  pressCallCount = 0
  press = .DiplomacyPress~new(seed,journal)
  winner = '-'
  finishReason = ''
::attribute state get
::attribute phaseCount get
::attribute invalidCount get
::attribute callCount get
::attribute pressCallCount get
::attribute winner get
::attribute finishReason get
::attribute year get
::attribute phase get
::method stateUnits
  expose units
  return units~copy
::method stateOwnership
  expose ownership
  return ownership~copy
::method run
  expose board judge config units ownership journal source seed powers year phase state history prior mapLines phaseCount invalidCount callCount winner finishReason pressCallCount
  if state \== 'READY' then raise syntax 93.900 array('Game already started')
  state = 'RUNNING'
  signal on syntax name failed
  if config~pressRounds = 0 then do
    journal~record('DIPLOG|1')
    journal~record('META|'seed'|'config~startYear'|'config~endYear'|'config~soloCentres)
  end
  else do
    journal~record('DIPLOG|2')
    journal~record('META|'seed'|'config~startYear'|'config~endYear'|'config~soloCentres'|'config~pressRounds)
  end
  journal~record('REFEREE|'judge~module_version)
  do line over mapLines
    journal~record('MAP|'line~c2x)
  end
  do rule over judge~ruleLines
    journal~record('RULE|'rule~c2x)
  end
  self~recordState
  do year = config~startYear to config~endYear
    phase = 'SPRING_MOVEMENT'
    self~beginPhase
    if config~pressRounds > 0 then self~negotiate
    submitted = self~collect('MOVEMENT',.nil)
    movement = judge~movement(units,submitted)
    units = movement~units
    self~recordMovement(movement)
    phase = 'SPRING_RETREATS'
    self~beginPhase
    submitted = self~collect('RETREAT',movement)
    season = judge~retreats(movement,submitted)
    units = season~units
    self~recordSeason(season)
    phase = 'FALL_MOVEMENT'
    self~beginPhase
    if config~pressRounds > 0 then self~negotiate
    submitted = self~collect('MOVEMENT',.nil)
    movement = judge~movement(units,submitted)
    units = movement~units
    self~recordMovement(movement)
    phase = 'FALL_RETREATS'
    self~beginPhase
    submitted = self~collect('RETREAT',movement)
    season = judge~retreats(movement,submitted)
    units = season~units
    ownership = judge~afterFallRetreats(ownership,season)
    self~recordSeason(season)
    counts = self~counts
    do power over powers
      if counts[power] >= config~soloCentres then do
        winner = power
        finishReason = 'SOLO'
        leave
      end
    end
    if finishReason == 'SOLO' then do
      self~recordYear(counts)
      leave
    end
    phase = 'WINTER_ADJUSTMENTS'
    self~beginPhase
    submitted = self~collect('ADJUSTMENT',.nil)
    season = judge~adjustments(units,ownership,submitted)
    units = season~units
    self~recordSeason(season)
    self~recordYear(counts)
    if year = config~endYear then do
      finishReason = 'YEAR_LIMIT'
      leave
    end
  end
  source~complete
  state = 'FINISHED'
  if config~pressRounds > 0 then journal~record('PRESS_TOTAL|'pressCallCount)
  journal~record('END|'finishReason'|'winner'|'year'|'phaseCount'|'callCount'|'invalidCount)
  journal~close
  return state
failed:
  failureCode = rc
  failureInfo = condition('O')
  signal off syntax
  state = 'FAILED'
  finishReason = 'REFEREE_OR_JOURNAL_FAILURE'
  -- A failure is recorded before returning; no result is emitted for the failing phase.
  journal~record('ERROR|'year'|'phase'|'failureCode'|'failureInfo['MESSAGE']~c2x)
  journal~close
  return state
::method beginPhase
  expose journal year phase phaseCount
  phaseCount += 1
  journal~record('PHASE|'year'|'phase)
::method counts
  expose powers ownership
  counts = .directory~new
  do power over powers
    counts[power] = 0
  end
  do loc over ownership~allIndexes~sort
    power = ownership[loc]
    if counts~hasIndex(power) then counts[power] += 1
  end
  return counts
::method recordYear
  expose journal history year powers
  use strict arg counts
  tally = .array~new
  do power over powers
    tally~append(year'|'power'|'counts[power])
    journal~record('YEAR|'year'|'power'|'counts[power])
  end
  history~append(tally)
::method collect
  expose board powers year phase units ownership source journal prior history mapLines seed callCount config press
  use strict arg kind, movement
  submitted = .directory~new
  counts = self~counts
  do power over powers
    task = .array~new
    if kind == 'RETREAT' then do
      do loc over movement~dislodged~allIndexes~sort
        unit = movement~dislodged[loc][1]
        if unit~owner == power then task~append(unit~unitType unit~location)
      end
      if task~items = 0 then iterate
      balance = 0
    end
    else do
      do loc over units~allIndexes~sort
        unit = units[loc]
        if unit~owner == power then task~append(unit~unitType unit~location)
      end
      balance = counts[power] - task~items
      if kind == 'ADJUSTMENT' then do
        if balance = 0 then iterate
      end
      else if task~items = 0 & counts[power] = 0 then iterate
    end
    view = self~makeView(kind,power,task,balance,movement)
    if config~pressRounds > 0 then if kind == 'MOVEMENT' then view['INBOX'] = press~inbox(power)
    reply = safeOrders(source,view)
    status = reply[1]
    lines = reply[2]
    callCount += 1
    journal~record('CALL|'year'|'phase'|'power'|'status'|'lines~items)
    do raw over lines
      journal~record('ORDER|'raw~c2x)
    end
    submitted[power] = lines~copy
  end
  return submitted
::method negotiate
  expose config units powers year phase source journal press pressCallCount
  press~beginMovement
  counts = self~counts
  active = .array~new
  tasks = .directory~new
  do power over powers
    task = .array~new
    do loc over units~allIndexes~sort
      unit = units[loc]
      if unit~owner == power then task~append(unit~unitType unit~location)
    end
    if task~items = 0 & counts[power] = 0 then iterate
    active~append(power)
    tasks[power] = task
  end
  do round = 1 to config~pressRounds
    journal~record('PRESS_ROUND|'year'|'phase'|'round)
    lists = .directory~new
    responses = .directory~new
    -- Every private list is generated before any callback.
    do power over active
      lists[power] = press~playerList(year,phase,round,power,active)
    end
    do power over active
      task = tasks[power]~copy
      view = self~makeView('PRESS',power,task,counts[power]-task~items,.nil)
      view['ROUND'] = round
      view['ROUNDS'] = config~pressRounds
      view['PLAYER_LIST'] = lists[power]~copy
      view['INBOX'] = press~inbox(power)
      reply = safePress(source,view)
      responses[power] = reply
      pressCallCount += 1
      journal~record('PRESS_CALL|'year'|'phase'|'round'|'power'|'reply[1]'|'reply[2]~c2x)
    end
    press~finishRound(year,phase,round,responses,lists)
  end
::method makeView
  expose year phase mapLines prior history
  use strict arg kind, power, task, balance, movement
  view = .directory~new
  view['YEAR'] = year
  view['PHASE'] = phase
  view['KIND'] = kind
  view['POWER'] = power
  view['BALANCE'] = balance
  view['TASK'] = task
  view['MAP'] = mapLines~copy
  view['BOARD'] = self~unitLines
  view['OWNERSHIP'] = self~ownershipLines
  view['LAST_RESULTS'] = .array~new
  do entry over prior
    view['LAST_RESULTS']~append(entry~copy)
  end
  view['DISLODGED'] = .array~new
  if kind == 'RETREAT' then do
    do loc over movement~dislodged~allIndexes~sort
      entry = movement~dislodged[loc]
      unit = entry[1]
      view['DISLODGED']~append(unit~owner'|'unit~unitType'|'unit~location'|'entry[2]'|'entry[3])
    end
  end
  view['HISTORY'] = .array~new
  do entry over history
    view['HISTORY']~append(entry~copy)
  end
  return view
::method unitLines
  expose units
  lines = .array~new
  do loc over units~allIndexes~sort
    unit = units[loc]
    lines~append(unit~owner'|'unit~unitType'|'unit~location)
  end
  return lines
::method ownershipLines
  expose ownership
  lines = .array~new
  do loc over ownership~allIndexes~sort
    lines~append(loc'|'ownership[loc])
  end
  return lines
::method recordState
  expose journal
  do line over self~unitLines
    journal~record('UNIT|'line)
  end
  do line over self~ownershipLines
    journal~record('CENTRE|'line)
  end
::method recordResults
  expose journal prior invalidCount
  use strict arg published
  prior = .array~new
  do row over published
    line = row[1]'|'row[2]~c2x'|'row[3]
    prior~append(row~copy)
    journal~record('RESULT|'line)
    if row[3]~left(8) == 'INVALID:' then invalidCount += 1
  end
::method recordMovement
  expose journal
  use strict arg movement
  self~recordResults(movement~published)
  do loc over movement~dislodged~allIndexes~sort
    row = movement~dislodged[loc]
    journal~record('DISLODGED|'loc'|'row[1]~owner'|'row[1]~unitType'|'row[1]~location'|'row[2]'|'row[3])
  end
  do loc over movement~standoffs~allIndexes~sort
    journal~record('STANDOFF|'loc)
  end
  do key over movement~paradoxes
    journal~record('PARADOX|'key)
  end
  self~recordState
  journal~record('PHASE_END')
::method recordSeason
  expose journal
  use strict arg season
  self~recordResults(season~published)
  do row over season~automatic
    journal~record('AUTOMATIC|'row~makeString('L','|'))
  end
  do loc over season~removed~allIndexes~sort
    unit = season~removed[loc]
    journal~record('REMOVED|'unit~owner'|'unit~unitType'|'unit~location)
  end
  self~recordState
  journal~record('PHASE_END')
::method module_version class
  return '0.1-dev6'
::method module_version
  return self~class~module_version
::method module_lastChanged class
  return '2026-11-26'
::method module_lastChanged
  return self~class~module_lastChanged

::routine safePress
  use strict arg source, view
  signal on syntax name badPress
  response = source~press(view)
  if \response~isA(.array) then return .array~of('BAD_RESPONSE','')
  if response~items \= 2 then return .array~of('BAD_RESPONSE','')
  status = response[1]
  raw = response[2]
  if \.array~of('OK','BAD_RESPONSE','ERROR','TIMEOUT')~hasItem(status) then return .array~of('BAD_RESPONSE','')
  if \raw~isA(.string) then return .array~of('BAD_RESPONSE','')
  return .array~of(status,raw)
badPress:
  return .array~of('ERROR','')

::routine safeOrders
  use strict arg source, view
  signal on syntax name badCall
  response = source~orders(view)
  if \response~isA(.array) then return .array~of('BAD_RESPONSE',.array~new)
  if response~items \= 2 then return .array~of('BAD_RESPONSE',.array~new)
  status = response[1]
  lines = response[2]
  if \.array~of('OK','BAD_RESPONSE','ERROR','TIMEOUT')~hasItem(status) then return .array~of('BAD_RESPONSE',.array~new)
  if \lines~isA(.array) then return .array~of('BAD_RESPONSE',.array~new)
  if status \== 'OK' then return .array~of(status,.array~new)
  clean = .array~new
  do idx = 1 to lines~items
    if \lines~hasIndex(idx) then return .array~of('BAD_RESPONSE',.array~new)
    raw = lines[idx]
    if \raw~isA(.string) then return .array~of('BAD_RESPONSE',.array~new)
    if raw~pos('0A'x) > 0 | raw~pos('0D'x) > 0 then return .array~of('BAD_RESPONSE',.array~new)
    clean~append(raw)
  end
  return .array~of(status,clean)
badCall:
  return .array~of('ERROR',.array~new)

::routine diplomacyInitialUnits public
  use strict arg board, path
  input = .stream~new(path)
  if input~open('READ') \== 'READY:' then raise syntax 93.900 array('Cannot open initial deployment')
  units = .directory~new
  do while input~lines > 0
    line = input~linein~strip
    if line == '' then iterate
    if line~left(1) == '#' then iterate
    parse var line power '|' typ '|' loc
    province = board~provinceOf(loc)
    if units~hasIndex(province) then raise syntax 93.900 array('Duplicate initial province')
    units[province] = .DiplomacyUnit~new(power,typ,loc)
  end
  input~close
  return units
