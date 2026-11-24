/* ShellLog.cls - newshell progress and receipts through oorexx_logging v0.7
   Architecture: Tom Dyer. Coding: Claude (Opus 5.5).
   NEWSHELL_LOG=path appends receipts; NEWSHELL_ECHO=0 stops the stderr echo. */
::requires 'LoggingCore.cls'

/* ------------------------------------------------------------------ log -- */
::class NewshellLog public
::method setup class
  expose logger
  logPath = value('NEWSHELL_LOG',, 'ENVIRONMENT')
  echo = value('NEWSHELL_ECHO',, 'ENVIRONMENT') \== '0'
  service = .LogService~new('newshell')
  service~addTarget(.NewshellLogTarget~new('newshell', .Log~INTERNAL, logPath, echo))
  rule = .LogRule~new('newshell-events', 'newshell', 'NewshellLog', 'event', -
    .Log~INTERNAL, .Log~INTERNAL, .Log~INFO, .nil, .array~of('newshell'))
  service~addRule(rule)
  logger = service~loggerFor(.NewshellLog~new, 'event', .array~new, .Log~INTERNAL)
  return self
::method event class
  expose logger
  use strict arg text
  if var('logger') = 0 then self~setup
  logger~log(.Log~INFO, text)
  return .true

::class NewshellLogTarget public
::attribute name get
::attribute scope get
::attribute scopeObject get
::attribute enabled get
::method init
  expose name scope scopeObject enabled path echo
  use strict arg name, scopeValue, path, echo
  scopeObject = .Log~normalizeScope(scopeValue)
  scope = scopeObject~disclosure
  enabled = .true
::method accept
  expose enabled path echo
  use strict arg event
  if \enabled then return .false
  if path \== '' then do
    s = .stream~new(path)
    s~lineout(date('S') time('L') 'newshell' event~payload)
    s~close
  end
  if echo then .error~lineout('[newshell]' event~payload)
  return .true

