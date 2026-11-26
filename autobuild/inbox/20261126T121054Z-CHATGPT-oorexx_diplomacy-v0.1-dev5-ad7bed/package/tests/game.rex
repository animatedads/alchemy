/* Full-game gate over the native referee, deterministic replay and isolation. */
parse arg directory
if directory == '' then exit 2
board = .DiplomacyBoard~new('data/standard.source')
judge = .DiplomacyAdjudicator~new(board,'data/rules.conf')
initial = diplomacyInitialUnits(board,'data/initial-1901.source')
owned = judge~initialOwnership
config = .DiplomacyGameConfig~load('data/game.conf')
checks = 0
failures = 0
call check initial~items = 22,'initial units'
call check config~startYear = 1901,'start year'
call check config~endYear = 1925,'end year'
call check config~soloCentres = 18,'solo threshold'
do mode over .array~of('HOLD','RANDOM')
  seed = 7
  if mode == 'RANDOM' then seed = 20261126
  path = directory'/'mode'.log'
  game = .DiplomacyGame~new(board,judge,config,initial,owned,.DiplomacyStubSource~new(board,seed,mode),.DiplomacyGameJournal~new(path),seed)
  call check game~run == 'FINISHED',mode 'finishes'
  call check game~year = 1925,mode 'year'
  call check game~phaseCount = 125,mode '125 phases'
  call check game~finishReason == 'YEAR_LIMIT',mode 'end condition'
  call check game~stateOwnership~items = 34,mode 'centre ownership'
  if mode == 'HOLD' then do
    call check game~stateUnits~items = 22,'hold units retained'
    call check game~callCount = 350,'hold movement calls only'
    call check game~invalidCount = 0,'hold no invalid orders'
  end
  else do
    call check game~callCount > 350,'random calls include adjustments'
    call check game~invalidCount > 0,'random invalid orders'
  end
  replayPath = directory'/'mode'-replay.log'
  replay = .DiplomacyReplaySource~new(path)
  again = .DiplomacyGame~new(board,judge,replay~config,initial,owned,replay,.DiplomacyGameJournal~new(replayPath),replay~seed)
  call check again~run == 'FINISHED',mode 'replay finishes'
  call check diplomacySameJournal(path,replayPath),mode 'byte identical from logged calls'
  say 'Full game' mode 'phases:' game~phaseCount 'calls:' game~callCount 'invalid:' game~invalidCount
end
call check initial~items = 22,'initial remains unchanged'
call check owned['BEL'] == 'N','initial ownership not mutated'

-- A directed integration position tests nonempty retreats and winter changes.
position = .directory~new
position['PAR'] = .DiplomacyUnit~new('FRA','A','PAR')
position['MAR'] = .DiplomacyUnit~new('FRA','A','MAR')
position['BUR'] = .DiplomacyUnit~new('GER','A','BUR')
single = .DiplomacyGameConfig~new(1901,1901,18)
path = directory'/DIRECTED.log'
scripted = .DirectedSource~new
game = .DiplomacyGame~new(board,judge,single,position,owned,scripted,.DiplomacyGameJournal~new(path),1)
call check game~run == 'FINISHED','directed game finishes'
call check game~phaseCount = 5,'directed five phases'
call check game~stateUnits['PIC']~owner == 'GER','retreat completed'
call check game~stateOwnership['BEL'] == 'FRA','fall capture ownership'
call check game~stateUnits['BRE']~owner == 'FRA','winter build Brest'
call check game~stateUnits['PAR']~owner == 'FRA','winter build Paris'
call check game~stateUnits['BEL']~owner == 'FRA','move into Belgium'
call check scripted~retreatCalls = 1,'only dislodged power called'
call check scripted~fallNeutral,'ownership not changed before Fall retreats'
call check scripted~winterBalance = 2,'winter balance computed after capture'
call check scripted~publicStateIntact,'player mutation did not alter next snapshot'
call check scripted~rawResultsIntact,'prior raw results not repaired'
replay = .DiplomacyReplaySource~new(path)
again = .DiplomacyGame~new(board,judge,replay~config,position,owned,replay,.DiplomacyGameJournal~new(directory'/DIRECTED-replay.log'),1)
call check again~run == 'FINISHED','directed replay finishes'
call check diplomacySameJournal(path,directory'/DIRECTED-replay.log'),'directed replay exact'
call check position~items = 3,'scenario input units unchanged'
call check owned['BEL'] == 'N','scenario input ownership unchanged'

-- Exact 18-centre solo from a test state; no Winter call after the Fall gate.
soloOwned = owned~copy
idx = 0
do loc over soloOwned~allIndexes~sort
  soloOwned[loc] = 'N'
  if loc == 'BEL' then iterate
  if idx < 17 then do
    soloOwned[loc] = 'FRA'
    idx += 1
  end
end
soloSource = .DirectedSource~new
game = .DiplomacyGame~new(board,judge,config,position,soloOwned,soloSource,.DiplomacyGameJournal~new(directory'/SOLO.log'),1)
call check game~run == 'FINISHED','solo finishes'
call check game~winner == 'FRA','solo winner'
call check game~finishReason == 'SOLO','solo end reason'
call check game~phaseCount = 4,'solo at Fall retreat boundary'
call check soloSource~winterBalance == -99,'no winter call after solo'
call check containsLine(directory'/SOLO.log','YEAR|1901|FRA|18'),'solo centre count recorded'

-- Failed/malformed callbacks are atomic: all lines dropped, units hold.
fault = .FaultSource~new
game = .DiplomacyGame~new(board,judge,single,initial,owned,fault,.DiplomacyGameJournal~new(directory'/FAULT.log'),3)
call check game~run == 'FINISHED','player errors do not stop game'
call check game~stateUnits~items = 22,'failed callbacks leave units holding'
call check containsLine(directory'/FAULT.log','CALL|1901|SPRING_MOVEMENT|AUS|TIMEOUT|0'),'timeout logged'
call check containsLine(directory'/FAULT.log','CALL|1901|SPRING_MOVEMENT|FRA|BAD_RESPONSE|0'),'malformed logged'
call check containsLine(directory'/FAULT.log','CALL|1901|SPRING_MOVEMENT|GER|ERROR|0'),'syntax error logged'
call check containsLine(directory'/FAULT.log','ORDER|'||('  F LON - XX |  ')~c2x),'raw bytes preserved'
replay = .DiplomacyReplaySource~new(directory'/FAULT.log')
again = .DiplomacyGame~new(board,judge,replay~config,initial,owned,replay,.DiplomacyGameJournal~new(directory'/FAULT-replay.log'),3)
call check again~run == 'FINISHED','fault replay finishes'
call check diplomacySameJournal(directory'/FAULT.log',directory'/FAULT-replay.log'),'failure and raw-byte replay exact'

-- A referee exception emits ERROR but neither a result nor a success END.
badJudge = .FailingAdjudicator~new(board,'data/rules.conf')
game = .DiplomacyGame~new(board,badJudge,single,initial,owned,.DiplomacyStubSource~new(board,1,'HOLD'),.DiplomacyGameJournal~new(directory'/FAILED.log'),1)
call check game~run == 'FAILED','referee failure stops'
call check game~phaseCount = 1,'no subsequent phase after failure'
call check game~stateUnits~items = 22,'failed referee leaves prior board'
call check \containsLine(directory'/FAILED.log','PHASE_END'),'failed phase not published'
call check errorDetail(directory'/FAILED.log'),'referee error detail logged'
call check rejectReplay(directory'/FAILED.log'),'incomplete/failed journal rejected'
-- A change to recorded result only must be detected in regenerated bytes.
call copyTampered directory'/DIRECTED.log',directory'/TAMPERED.log'
replay = .DiplomacyReplaySource~new(directory'/TAMPERED.log')
again = .DiplomacyGame~new(board,judge,replay~config,position,owned,replay,.DiplomacyGameJournal~new(directory'/TAMPERED-replay.log'),1)
call check again~run == 'FINISHED','tampered output replay recomputes'
call check \diplomacySameJournal(directory'/TAMPERED.log',directory'/TAMPERED-replay.log'),'tampering mismatch detected'
say 'Game checks:' checks 'Failures:' failures
exit (failures > 0)
check:
  use strict arg good, detail
  checks += 1
  if \good then do
    failures += 1
    say 'FAIL' detail
  end
  return

::routine containsLine
  use strict arg path, wanted
  input = .stream~new(path)
  if input~open('READ') \== 'READY:' then return .false
  found = .false
  do while input~lines > 0
    if input~linein == wanted then do
      found = .true
      leave
    end
  end
  input~close
  return found
::routine errorDetail
  use strict arg path
  input = .stream~new(path)
  if input~open('READ') \== 'READY:' then return .false
  found = .false
  do while input~lines > 0
    line = input~linein
    if line~left(6) \== 'ERROR|' then iterate
    parse var line . '|' . '|' . '|' . '|' detail
    if detail \== '' then found = .true
  end
  input~close
  return found
::routine rejectReplay
  use strict arg path
  signal on syntax name rejected
  source = .DiplomacyReplaySource~new(path)
  return .false
rejected:
  return .true
::routine copyTampered
  use strict arg from, dest
  input = .stream~new(from)
  output = .stream~new(dest)
  if input~open('READ') \== 'READY:' then raise syntax 93.900 array('Cannot read')
  if output~open('WRITE REPLACE') \== 'READY:' then raise syntax 93.900 array('Cannot write')
  changed = .false
  do while input~lines > 0
    line = input~linein
    if \changed then if line~left(7) == 'RESULT|' then do
      line = line'|tampered'
      changed = .true
    end
    if output~lineout(line) \= 0 then raise syntax 93.900 array('Cannot write')
  end
  input~close
  output~close

::class DirectedSource
::attribute retreatCalls get
::attribute fallNeutral get
::attribute winterBalance get
::attribute publicStateIntact get
::attribute rawResultsIntact get
::method init
  expose retreatCalls fallNeutral winterBalance publicStateIntact rawResultsIntact
  retreatCalls = 0
  fallNeutral = .false
  winterBalance = -99
  publicStateIntact = .false
  rawResultsIntact = .false
::method orders
  expose retreatCalls fallNeutral winterBalance publicStateIntact rawResultsIntact
  use strict arg view
  power = view['POWER']
  phase = view['PHASE']
  kind = view['KIND']
  lines = .array~new
  if phase == 'SPRING_MOVEMENT' then do
    if power == 'FRA' then do
      lines~append('A PAR - BUR')
      lines~append('a mar s a par - bur  ')
      view['BOARD']~empty
    end
    if power == 'GER' then do
      publicStateIntact = view['BOARD']~items = 3
      lines~append('A BUR H')
    end
  end
  else if phase == 'SPRING_RETREATS' then do
    retreatCalls += 1
    if power == 'GER' then do
      lines~append('A BUR R PIC')
      do row over view['LAST_RESULTS']
        if row[2] == 'a mar s a par - bur  ' then rawResultsIntact = .true
      end
    end
  end
  else if phase == 'FALL_MOVEMENT' then do
    if power == 'FRA' then do
      fallNeutral = view['OWNERSHIP']~hasItem('BEL|N')
      lines~append('A BUR - BEL')
      lines~append('A MAR H')
    end
    if power == 'GER' then lines~append('A PIC H')
  end
  else if kind == 'ADJUSTMENT' then do
    if power == 'FRA' then do
      winterBalance = view['BALANCE']
      lines~append('BUILD A PAR')
      lines~append('BUILD A BRE')
    end
    else if view['BALANCE'] > 0 then do idx = 1 to view['BALANCE']
      lines~append('WAIVE')
    end
  end
  return .array~of('OK',lines)
::method complete
  return

::class FaultSource
::method orders
  use strict arg view
  select
    when view['POWER'] == 'AUS' then return .array~of('TIMEOUT',.array~of('A BUD - VIE'))
    when view['POWER'] == 'FRA' then return .array~of('OK',.array~of('A PAR H','a'||'0A'x||'b'))
    when view['POWER'] == 'GER' then raise syntax 93.900 array('scripted failure')
    when view['POWER'] == 'ENG' then return .array~of('OK',.array~of('  F LON - XX |  '))
    otherwise return .array~of('OK',.array~new)
  end
::method complete
  return

::class FailingAdjudicator subclass DiplomacyAdjudicator
::method movement
  raise syntax 93.900 array('scripted referee failure')

::requires 'DiplomacyGame.cls'
::requires 'DiplomacyReplaySource.cls'
::requires 'DiplomacyStubSource.cls'
