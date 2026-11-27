/* HeelTurnLog.cls - Heel Turn SLAM: running log through the estate's logging.
   Architecture: Tom Dyer. Code: Claude (Opus 5.5).
   One LogService ('heelturn'), one INTERNAL rule, one file target. With
   progress on, each line is also said, so a run is never a black box.
   Same pattern as DiplomacyGameJournal (oorexx_logging_v0.7). */
::requires 'LoggingCore.cls'

::class HeelTurnLog public
::method init
  expose log active target
  use strict arg path = '', progress = .false
  active = .false
  target = .nil
  if path == '' & \progress then return
  target = .HeelTurnLogTarget~new(path, progress)
  service = .LogService~new('heelturn')
  service~addTarget(target)
  rule = .LogRule~new('heelturn-run', 'heelturn', 'HeelTurnLog', 'say', .Log~INTERNAL, .Log~INTERNAL, .Log~INFO, .LogConditionAlways~new, .array~of(target~name), .array~of(.Log~BODY))
  service~addRule(rule)
  log = service~loggerFor(self, 'say', .array~new, .Log~INTERNAL)
  if \log~active then raise syntax 93.900 array('Heel Turn log is inactive')
  active = .true
::method close
  -- Flush and close the file target; later lines are not written.
  expose active target
  if \active then return
  target~close
  active = .false
::method say
  expose log active
  use strict arg line
  if \active then return
  if \log~log(.Log~INFO, line) then raise syntax 93.900 array('Heel Turn log line not delivered')
::method module_version class
  return '0.1r8'
::method module_version
  return self~class~module_version
::method module_lastChanged class
  return '2026-11-27'
::method module_lastChanged
  return self~class~module_lastChanged

::class HeelTurnLogTarget
::attribute name get
::attribute scope get
::attribute enabled get
::method init
  expose name scope enabled out progress
  use strict arg path, progress
  name = 'heelturn-file'
  scope = .Log~INTERNAL
  enabled = .true
  out = .nil
  if path \== '' then do
    out = .stream~new(path)
    if out~open('WRITE APPEND') \== 'READY:' then raise syntax 93.900 array('Cannot open Heel Turn log:' path)
  end
::method accept
  expose out enabled progress
  use strict arg event
  if \enabled then return .false
  if event~deliveryScope \== .Log~INTERNAL then return .false
  if out \== .nil then if out~lineout(event~payload) \= 0 then return .false
  if progress then say 'heelturn|'event~payload
  return .true
::method close
  expose out enabled
  enabled = .false
  if out \== .nil then out~close
::method module_version class
  return '0.1r8'
::method module_version
  return self~class~module_version
::method module_lastChanged class
  return '2026-11-27'
::method module_lastChanged
  return self~class~module_lastChanged
