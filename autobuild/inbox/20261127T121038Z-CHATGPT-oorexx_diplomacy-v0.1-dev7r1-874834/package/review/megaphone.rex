/* megaphone.rex - does the press controller favour a sender by seat or volume?
   Review tooling by Claude (Opus 5.5). Architecture: Tom Dyer.
   Engine: oorexx_diplomacy dev6 (implementation ChatGPT GPT-6.2).

   Usage: rexx review/megaphone.rex years workdir
     Run from the engine package root so data/ resolves.
   Scenarios:
     QUIET        every power sends one short note to all others
     LOUD=<power> that power sends six 1500 code point messages to all others
   Every unit holds in every scenario, so only press differs. */
parse arg years workdir .
if \years~datatype('W') | workdir == '' then do
  say 'Usage: rexx review/megaphone.rex years workdir'
  exit 2
end
log = .MegaphoneLog~new
board = .DiplomacyBoard~new('data/standard.source')
judge = .DiplomacyAdjudicator~new(board,'data/rules.conf')
config = .DiplomacyGameConfig~new(1901, 1900 + years, 18, 3)
log~record('engine DiplomacyPress' .DiplomacyPress~module_version', years' years', press rounds' config~pressRounds)

quiet = runScenario(log, board, judge, config, workdir, 'QUIET', '')
powers = sendersOf(quiet)
log~record('powers seen in mail:' powers~makeString('L',' '))
call reportSeat log, quiet, powers

loudShares = .array~new
do power over powers
  stats = runScenario(log, board, judge, config, workdir, 'LOUD-'power, power)
  loudShares~append(reportLoud(log, stats, power, powers))
end
log~record('summary: loud sender share of each opponent order-call inbox, by loud power')
do line over loudShares
  log~record('  'line)
end
exit 0

::routine runScenario
  use strict arg log, board, judge, config, workdir, name, loud
  journalPath = workdir'/'name'.log'
  if .stream~new(journalPath)~query('EXISTS') \== '' then raise syntax 93.900 array('Journal exists:' journalPath)
  initial = diplomacyInitialUnits(board,'data/initial-1901.source')
  ownership = judge~initialOwnership
  source = .DiplomacyMegaphoneSource~new(loud)
  journal = .DiplomacyGameJournal~new(journalPath,.false)
  game = .DiplomacyGame~new(board,judge,config,initial,ownership,source,journal,7)
  status = game~run
  log~record('scenario' name': status' status', phases' game~phaseCount', press calls' game~pressCallCount', order calls' game~callCount)
  if status \== 'FINISHED' then raise syntax 93.900 array('Scenario did not finish:' name)
  return source~stats

::routine sendersOf
  use strict arg stats
  found = .directory~new
  do key over stats~allIndexes
    parse var key kind '|' power '|' field
    if field == 'RANKN' then found[power] = .true
  end
  return found~allIndexes~sort

::routine statValue
  use strict arg stats, key
  if stats~hasIndex(key) then return stats[key]
  return 0

::routine reportSeat
  use strict arg log, stats, powers
  log~record('seat test (QUIET, identical behaviour): where each sender lands in other inboxes')
  log~record('  call   sender      mean rank   first%   last%')
  do kind over .array~of('ORDER','PRESS')
    do power over powers
      n = statValue(stats, kind'|'power'|RANKN')
      if n = 0 then iterate
      mean = format(statValue(stats, kind'|'power'|RANKSUM') / n,,2)
      first = format(100 * statValue(stats, kind'|'power'|FIRST') / n,,0)
      last = format(100 * statValue(stats, kind'|'power'|LAST') / n,,0)
      log~record('  'left(kind,6) left(power,10) right(mean,10) right(first,8) right(last,7))
    end
  end

::routine reportLoud
  use strict arg log, stats, loud, powers
  -- Share of one quiet recipient's order-call inbox that came from the loud power.
  total = 0
  fromLoud = 0
  inboxes = 0
  do power over powers
    if power == loud then iterate
    total += statValue(stats, 'ORDER|'power'|RECEIVED')
    inboxes += statValue(stats, 'ORDER|'power'|INBOXES')
  end
  -- Loud BYTES counts every frame it sent into any inbox, its own excluded by design
  -- (it never addresses itself), so all of it landed in quiet inboxes.
  fromLoud = statValue(stats, 'ORDER|'loud'|BYTES')
  share = 0
  if total > 0 then share = format(100 * fromLoud / total,,1)
  perInbox = 0
  if inboxes > 0 then perInbox = format(fromLoud / inboxes,,0)
  tokens = format(perInbox / 4,,0)
  pressTotal = 0
  pressInboxes = 0
  do power over powers
    if power == loud then iterate
    pressTotal += statValue(stats, 'PRESS|'power'|RECEIVED')
    pressInboxes += statValue(stats, 'PRESS|'power'|INBOXES')
  end
  pressLoud = statValue(stats, 'PRESS|'loud'|BYTES')
  pressPer = 0
  if pressInboxes > 0 then pressPer = format(pressLoud / pressInboxes,,0)
  line = left(loud,10) 'share' right(share,5)'%' '| loud bytes per opponent order inbox' right(perInbox,6) '(~'tokens 'tokens)' '| per press inbox' right(pressPer,6)
  log~record('scenario LOUD-'loud': ' line)
  return line

::class MegaphoneLog public
::method init
  expose log
  target = .MegaphoneConsoleTarget~new
  service = .LogService~new('megaphone')
  service~addTarget(target)
  rule = .LogRule~new('progress','megaphone','MegaphoneLog','record',.Log~INTERNAL,.Log~INTERNAL,.Log~INFO,.LogConditionAlways~new,.array~of(target~name),.array~of(.Log~BODY))
  service~addRule(rule)
  log = service~loggerFor(self,'record',.array~new,.Log~INTERNAL)
  if \log~active then raise syntax 93.900 array('progress log is inactive')
::method record
  expose log
  use strict arg text
  if \log~log(.Log~INFO, text) then say text
::method module_version class
  return '0.1'
::method module_version
  return self~class~module_version
::method module_lastChanged class
  return '2026-11-27'
::method module_lastChanged
  return self~class~module_lastChanged

::class MegaphoneConsoleTarget
::attribute name get
::attribute scope get
::attribute enabled get
::method init
  expose name scope enabled
  name = 'console'
  scope = .Log~INTERNAL
  enabled = .true
::method accept
  expose enabled
  use strict arg event
  if \enabled then return .false
  say time('N') event~payload
  return .true
::method module_version class
  return '0.1'
::method module_version
  return self~class~module_version
::method module_lastChanged class
  return '2026-11-27'
::method module_lastChanged
  return self~class~module_lastChanged

::requires 'LoggingCore.cls'
::requires 'DiplomacyGame.cls'
::requires 'DiplomacyMegaphoneSource.cls'
