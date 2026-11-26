/* Architecture Tom Dyer; implementation ChatGPT GPT-6.2.
   Canonical replay event projection via the estate logging service.
   The target writes only immutable event payload strings. Wall-clock
   metadata and process identities are deliberately outside replay bytes. */
::requires 'LoggingCore.cls'
::class DiplomacyGameJournal public
::method init
  expose service target log
  use strict arg filename, progress = .false
  target = .DiplomacyGameJournalTarget~new(filename,progress)
  service = .LogService~new('diplomacy-game')
  service~addTarget(target)
  rule = .LogRule~new('game-journal','diplomacy-game','DiplomacyGameJournal','record',.Log~INTERNAL,.Log~INTERNAL,.Log~INFO,.LogConditionAlways~new,.array~of(target~name),.array~of(.Log~BODY))
  service~addRule(rule)
  log = service~loggerFor(self,'record',.array~new,.Log~INTERNAL)
  if \log~active then raise syntax 93.900 array('Game journal is inactive')
::method record
  expose log
  use strict arg canonical
  if \log~log(.Log~INFO,canonical) then raise syntax 93.900 array('Game journal record not delivered')
::method close
  expose target
  target~close
::method module_version class
  return '0.1-dev5'
::method module_version
  return self~class~module_version
::method module_lastChanged class
  return '2026-11-26'
::method module_lastChanged
  return self~class~module_lastChanged

::class DiplomacyGameJournalTarget
::attribute name get
::attribute scope get
::attribute enabled get
::method init
  expose name scope enabled out progress
  use strict arg filename, progress = .false
  name = 'game-replay'
  scope = .Log~INTERNAL
  enabled = .true
  out = .stream~new(filename)
  if out~open('WRITE REPLACE') \== 'READY:' then raise syntax 93.900 array('Cannot open game journal:' filename)
::method accept
  expose out enabled progress
  use strict arg event
  if \enabled then return .false
  if event~deliveryScope \== .Log~INTERNAL then return .false
  if out~lineout(event~payload) \= 0 then return .false
  if progress then do
    line = event~payload
    parse var line kind '|' .
    if wordpos(kind,'PHASE CALL END ERROR') > 0 then say line
  end
  return .true
::method close
  expose out enabled
  if \enabled then return
  enabled = .false
  out~close
::method module_version class
  return '0.1-dev5'
::method module_version
  return self~class~module_version
::method module_lastChanged class
  return '2026-11-26'
::method module_lastChanged
  return self~class~module_lastChanged
