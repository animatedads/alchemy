/* HeelTurnGame.cls - one Diplomacy game with Heel Turn SLAM in every seat,
   and the framework's own replay of it.
   Architecture: Tom Dyer. Code: Claude (Opus 5.5).
   Uses the unchanged oorexx_diplomacy package: DiplomacyPlayer, DiplomacyGame,
   the pinned referee, DiplomacyReplaySource. One engine for every power, as
   the competition requires; each power has its own designer prompt. */
::requires 'DiplomacyGame.cls'
::requires 'DiplomacyPlayer.cls'
::requires 'DiplomacyReplaySource.cls'
::requires 'HeelTurnEngine.cls'

::class HeelTurnGame public
::method run
  -- Returns a directory: STATUS ORDER_CALLS PRESS_CALLS INVALID SECONDS.
  use strict arg droot, heelRoot, promptDir, endYear, seed, journalPath, logPath = '', progress = .false
  if .stream~new(journalPath)~query('EXISTS') \== '' then raise syntax 93.900 array('Journal exists, refusing to overwrite:' journalPath)
  board = .DiplomacyBoard~new(droot'/data/standard.source')
  judge = .DiplomacyAdjudicator~new(board, droot'/data/rules.conf')
  configured = .DiplomacyGameConfig~load(droot'/data/game.conf')
  config = .DiplomacyGameConfig~new(configured~startYear, endYear, configured~soloCentres, configured~pressRounds)
  initial = diplomacyInitialUnits(board, droot'/data/initial-1901.source')
  journal = .DiplomacyGameJournal~new(journalPath, progress)
  prompts = .directory~new
  do power over .array~of('AUS', 'ENG', 'FRA', 'GER', 'ITA', 'RUS', 'TUR')
    prompts[power] = heelTurnGameRead(promptDir'/'power'.txt')
  end
  engine = .HeelTurnEngine~new(heelRoot'/data', logPath, .false)
  rules = 'Standard Diplomacy, 1901 to' endYear'. Strict literal orders.'
  source = .DiplomacyPlayer~new(engine, prompts, rules, journal, 'HEELTURN-'seed, seed)
  game = .DiplomacyGame~new(board, judge, config, initial, judge~initialOwnership, source, journal, seed)
  started = time('E')
  status = game~run
  journal~close
  engine~log~close
  out = .directory~new
  out['STATUS'] = status
  out['ORDER_CALLS'] = game~callCount
  out['PRESS_CALLS'] = game~pressCallCount
  out['INVALID'] = game~invalidCount
  out['SECONDS'] = format(time('E') - started,, 1)
  return out
::method replay
  -- The framework's replay: re-adjudicate the logged calls, compare bytes.
  use strict arg droot, original, out
  board = .DiplomacyBoard~new(droot'/data/standard.source')
  judge = .DiplomacyAdjudicator~new(board, droot'/data/rules.conf')
  initial = diplomacyInitialUnits(board, droot'/data/initial-1901.source')
  source = .DiplomacyReplaySource~new(original)
  journal = .DiplomacyGameJournal~new(out, .false)
  game = .DiplomacyGame~new(board, judge, source~config, initial, judge~initialOwnership, source, journal, source~seed)
  status = game~run
  journal~close
  if status \== 'FINISHED' then return .false
  return diplomacySameJournal(original, out)
::method callStatuses
  -- Count PLAYER_CALL statuses in the operator journal (field 13).
  use strict arg operatorPath
  counts = .directory~new
  src = .stream~new(operatorPath)
  if src~open('READ') \== 'READY:' then raise syntax 93.900 array('Cannot read' operatorPath)
  do while src~lines > 0
    line = src~linein
    if line~left(12) \== 'PLAYER_CALL|' then iterate
    f = (line'|.')~makeArray('|')
    st = f[13]
    if \counts~hasIndex(st) then counts[st] = 0
    counts[st] += 1
  end
  src~close
  return counts
::method module_version class
  return '0.1r8'
::method module_version
  return self~class~module_version
::method module_lastChanged class
  return '2026-11-27'
::method module_lastChanged
  return self~class~module_lastChanged

::routine heelTurnGameRead public
  use strict arg path
  src = .stream~new(path)
  if src~open('READ') \== 'READY:' then raise syntax 93.900 array('Cannot read' path)
  t = src~charin(1, src~chars)
  src~close
  return t
