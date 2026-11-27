/* Independent step-5 game auditor.
   Review tooling by Claude (Opus 5.5). Architecture: Tom Dyer.
   Usage: rexx review/game_audit.rex games firstSeed RICH|RANDOM|HOLD workDir
   For each seed: run a full game, replay it, run it again from scratch, and
   require all three journals to be byte-identical. Then re-derive the rules
   from the journal alone, using only the public map:
     - one unit per province; armies never at sea or on a coast node; fleets
       only where fleets can stand
     - 34 centres in every snapshot; ownership changes only after Fall retreats
     - movement removes exactly the dislodged units; nothing new appears
     - a retreating unit lands adjacent to where it was dislodged, in an empty
       province, not a standoff, and not the attacker's origin unless the
       attack came by convoy
     - a built unit stands on a vacant home centre its power owns
     - after Winter no power has more units than centres
     - calls: retreat calls exactly to powers with dislodged units; winter
       calls exactly to powers whose centres and units differ
     - every published result matches a submitted order, byte for byte
     - END: YEAR_LIMIT only in the last year with no solo; SOLO only with
       18+ centres after Fall and no Winter in that year
   Progress is printed every 10 games. Failures print seed, phase and reason. */
parse arg agGames agSeed agMode agDir
if agGames == '' then agGames = 20
if agSeed == '' then agSeed = 1
if agMode == '' then agMode = 'RICH'
agMode = agMode~upper
if agDir == '' then agDir = '/tmp/game-audit'
if agMode == 'FILE' then do
  /* Audit one existing journal: rexx review/game_audit.rex 0 0 FILE path */
  fileBoard = .DiplomacyBoard~new('data/standard.source')
  fileConfig = .DiplomacyGameConfig~load('data/game.conf')
  found = auditJournal(fileBoard, fileConfig, agDir, .directory~new, .directory~new)
  do item over found
    say '  ' item
  end
  say 'Journal' agDir 'findings:' found~items
  exit (found~items > 0)
end
address system 'mkdir -p' agDir
board = .DiplomacyBoard~new('data/standard.source')
judge = .DiplomacyAdjudicator~new(board,'data/rules.conf')
config = .DiplomacyGameConfig~load('data/game.conf')
agFailures = 0
agStatus = .directory~new
agTotals = .directory~new
call time 'R'
do agIdx = 0 to agGames - 1
  seed = agSeed + agIdx
  first = agDir'/'agMode'-'seed'-a.log'
  second = agDir'/'agMode'-'seed'-b.log'
  replayed = agDir'/'agMode'-'seed'-r.log'
  do path over .array~of(first, second, replayed)
    address system 'rm -f' path
  end
  stateA = playGame(board, judge, config, newSource(board, seed, agMode), first, seed)
  stateB = playGame(board, judge, config, newSource(board, seed, agMode), second, seed)
  problems = .array~new
  if stateA \== 'FINISHED' then problems~append('first run state' stateA)
  if stateB \== 'FINISHED' then problems~append('second run state' stateB)
  if problems~items = 0 then do
    replaySource = .DiplomacyReplaySource~new(first)
    stateR = playGame(board, judge, replaySource~config, replaySource, replayed, replaySource~seed)
    if stateR \== 'FINISHED' then problems~append('replay state' stateR)
    if \diplomacySameJournal(first, second) then problems~append('two runs of the same seed differ')
    if \diplomacySameJournal(first, replayed) then problems~append('replay differs from original')
    found = auditJournal(board, config, first, agStatus, agTotals)
    do item over found
      problems~append(item)
    end
  end
  if problems~items > 0 then do
    agFailures += 1
    say 'AUDIT FAIL seed' seed 'mode' agMode':'
    do item over problems
      say '  ' item
    end
  end
  else do path over .array~of(first, second, replayed)
    address system 'rm -f' path
  end
  if (agIdx + 1) // 10 = 0 then say 'progress' agIdx + 1'/'agGames 'failures' agFailures 'elapsed' format(time('E'),,1)'s'
end
line = 'Call statuses:'
do key over agStatus~allIndexes~sort
  line = line key'='agStatus[key]
end
say line
line = 'Coverage:'
do key over agTotals~allIndexes~sort
  line = line key'='agTotals[key]
end
say line
say 'Games audited:' agGames 'mode' agMode 'first seed' agSeed 'failures' agFailures
exit (agFailures > 0)

::routine newSource
  use strict arg board, seed, mode
  if mode == 'RICH' then return .DiplomacyRichStubSource~new(board, seed)
  return .DiplomacyStubSource~new(board, seed, mode)

::routine playGame
  use strict arg board, judge, config, source, path, seed
  initial = diplomacyInitialUnits(board,'data/initial-1901.source')
  journal = .DiplomacyGameJournal~new(path)
  game = .DiplomacyGame~new(board, judge, config, initial, judge~initialOwnership, source, journal, seed)
  return game~run

::routine bump
  use strict arg counter, key, amount = 1
  if \counter~hasIndex(key) then counter[key] = 0
  counter[key] += amount

::routine auditJournal
  use strict arg board, config, path, statusCount, totals
  problems = .array~new
  input = .stream~new(path)
  if input~open('READ') \== 'READY:' then return .array~of('cannot open journal')
  powers = .array~of('AUS','ENG','FRA','GER','ITA','RUS','TUR')
  units = .directory~new
  centres = .directory~new
  prevUnits = .nil
  prevCentres = .nil
  year = ''
  phase = 'INITIAL'
  calls = .directory~new
  orders = .array~new
  results = .array~new
  dislodged = .array~new
  standoffs = .directory~new
  lastDislodged = .array~new
  lastStandoffs = .directory~new
  yearCounts = .directory~new
  finish = ''
  soloSeen = .false
  winterYears = .directory~new
  callOwner = ''
  do while input~lines > 0
    row = input~linein
    parse var row kind '|' body
    select
      when kind == 'PHASE' then do
        parse var body year '|' phase
        calls = .directory~new
        orders = .array~new
        results = .array~new
        dislodged = .array~new
        standoffs = .directory~new
        units = .directory~new
        centres = .directory~new
        if phase == 'WINTER_ADJUSTMENTS' then winterYears[year] = .true
      end
      when kind == 'CALL' then do
        parse var body . '|' . '|' callOwner '|' status '|' .
        calls[callOwner] = status
        call bump statusCount, status
      end
      when kind == 'ORDER' then orders~append(callOwner'|'body)
      when kind == 'RESULT' then do
        parse var body rPower '|' rHex '|' rStatus
        results~append(rPower'|'rHex)
        parse var rStatus rStatus ':' .
        call bump totals, 'result_'rStatus
      end
      when kind == 'DISLODGED' then do
        parse var body dLoc '|' dOwner '|' dType '|' dFrom '|' dOrigin '|' dConvoy
        dislodged~append(.array~of(dOwner, dType, dFrom, dOrigin, dConvoy))
        call bump totals, 'dislodged'
      end
      when kind == 'STANDOFF' then standoffs[body] = .true
      when kind == 'PARADOX' then call bump totals, 'paradox'
      when kind == 'REMOVED' then call bump totals, 'removed'
      when kind == 'AUTOMATIC' then call bump totals, 'automatic'
      when kind == 'UNIT' then do
        parse var body uOwner '|' uType '|' uLoc
        province = board~provinceOf(uLoc)
        if units~hasIndex(province) then problems~append(year phase 'two units in' province)
        units[province] = .array~of(uOwner, uType, uLoc)
        node = board~node(uLoc)
        if uType == 'A' then do
          if node['KIND'] == 'sea' then problems~append(year phase 'army at sea' uLoc)
          if uLoc~pos('/') > 0 then problems~append(year phase 'army on a coast node' uLoc)
        end
        else if node['FLEET'] == '' then problems~append(year phase 'fleet where fleets cannot stand' uLoc)
      end
      when kind == 'CENTRE' then do
        parse var body cLoc '|' cOwner
        centres[cLoc] = cOwner
      end
      when kind == 'PHASE_END' then do
        found = checkPhase(board, powers, year, phase, units, centres, prevUnits, prevCentres, calls, orders, results, dislodged, lastDislodged, lastStandoffs)
        do item over found
          problems~append(item)
        end
        if phase~right(8) == 'MOVEMENT' then do
          lastDislodged = dislodged
          lastStandoffs = standoffs
        end
        prevUnits = units
        prevCentres = centres
        call bump totals, 'phases'
      end
      when kind == 'YEAR' then do
        parse var body yYear '|' yPower '|' yCount
        if yCount >= config~soloCentres then soloSeen = .true
        call bump yearCounts, yYear, yCount
      end
      when kind == 'END' then parse var body finish '|' winner '|' endYear '|' .
      otherwise nop
    end
    if prevUnits == .nil then if kind == 'CENTRE' then if centres~items = 34 then do
      prevUnits = units~copy
      prevCentres = centres~copy
      units = .directory~new
      centres = .directory~new
    end
  end
  input~close
  do key over yearCounts~allIndexes~sort
    if yearCounts[key] > 34 then problems~append(key 'more than 34 centres counted')
  end
  if finish == 'YEAR_LIMIT' then do
    if endYear \= config~endYear then problems~append('YEAR_LIMIT before the last year')
    if soloSeen then problems~append('YEAR_LIMIT although a power reached the solo threshold')
  end
  else if finish == 'SOLO' then do
    if winterYears~hasIndex(endYear) then problems~append('Winter played in the solo year')
    call bump totals, 'solo_games'
  end
  else problems~append('no END line or unknown finish' finish)
  return problems

::routine countBy
  use strict arg units, powers
  counts = .directory~new
  do power over powers
    counts[power] = 0
  end
  do key over units~allIndexes~sort
    owner = units[key][1]
    if counts~hasIndex(owner) then counts[owner] += 1
  end
  return counts

::routine checkPhase
  use strict arg board, powers, year, phase, units, centres, prevUnits, prevCentres, calls, orders, results, dislodged, lastDislodged, lastStandoffs
  problems = .array~new
  where = year phase
  if centres~items \= 34 then problems~append(where 'centre count' centres~items)
  if prevCentres \== .nil then if phase \== 'FALL_RETREATS' then do key over centres~allIndexes~sort
    if prevCentres[key] \== centres[key] then problems~append(where 'ownership changed outside Fall retreats at' key)
  end
  /* Orders and results must match one for one, in order. */
  if orders~items \= results~items then problems~append(where 'orders' orders~items 'results' results~items)
  else do idx = 1 to orders~items
    if orders[idx] \== results[idx] then problems~append(where 'result' idx 'does not match its order')
  end
  if prevUnits == .nil then return problems
  now = countBy(units, powers)
  before = countBy(prevUnits, powers)
  owned = .directory~new
  do power over powers
    owned[power] = 0
  end
  do key over centres~allIndexes~sort
    if owned~hasIndex(centres[key]) then owned[centres[key]] += 1
  end
  if phase~right(8) == 'MOVEMENT' then do
    lost = .directory~new
    do power over powers
      lost[power] = 0
    end
    do entry over dislodged
      lost[entry[1]] += 1
    end
    do power over powers
      if now[power] \= before[power] - lost[power] then problems~append(where power 'unit count' now[power] 'expected' before[power] - lost[power])
    end
    /* Every surviving unit must have come from a unit of the same owner and type. */
    do key over units~allIndexes~sort
      unit = units[key]
      matched = .false
      do pkey over prevUnits~allIndexes~sort
        prev = prevUnits[pkey]
        if prev[1] == unit[1] then if prev[2] == unit[2] then matched = .true
      end
      if \matched then problems~append(where 'unit from nowhere' unit~makeString('L',' '))
    end
  end
  else if phase~right(8) == 'RETREATS' then do
    expected = .directory~new
    do entry over lastDislodged
      expected[entry[1]] = .true
    end
    do power over powers
      if expected~hasIndex(power) \= calls~hasIndex(power) then problems~append(where power 'retreat call mismatch')
    end
    do key over units~allIndexes~sort
      if prevUnits~hasIndex(key) then iterate
      unit = units[key]
      ok = .false
      do entry over lastDislodged
        if entry[1] \== unit[1] | entry[2] \== unit[2] then iterate
        if board~neighbours(entry[3], entry[2])~hasItem(unit[3]) then do
          origin = board~provinceOf(entry[4])
          if key == origin then if entry[5] \== '1' then iterate
          ok = .true
        end
      end
      if \ok then problems~append(where 'illegal retreat to' unit[3] 'by' unit[1])
      if lastStandoffs~hasIndex(key) then problems~append(where 'retreat into standoff' key)
    end
    do power over powers
      if now[power] < before[power] then problems~append(where power 'lost units in a retreat phase')
    end
  end
  else if phase == 'WINTER_ADJUSTMENTS' then do
    do power over powers
      balance = owned[power] - before[power]
      if (balance \= 0) \= calls~hasIndex(power) then problems~append(where power 'winter call mismatch, balance' balance)
      if now[power] > owned[power] then problems~append(where power 'has' now[power] 'units for' owned[power] 'centres')
    end
    do key over units~allIndexes~sort
      if prevUnits~hasIndex(key) then iterate
      unit = units[key]
      if board~node(key)['HOME'] \== unit[1] then problems~append(where 'build outside home centre' key 'by' unit[1])
      if centres[key] \== unit[1] then problems~append(where 'build on unowned centre' key 'by' unit[1])
    end
  end
  return problems

::requires 'DiplomacyGame.cls'
::requires 'DiplomacyReplaySource.cls'
::requires 'DiplomacyStubSource.cls'
::requires 'DiplomacyRichStubSource.cls'
