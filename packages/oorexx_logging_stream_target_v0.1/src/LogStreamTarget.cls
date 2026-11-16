/* oorexx_logging_stream_target v0.1 -- running progress logs for estate tools.
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 2026-11-14.
 *
 * Additive companion to oorexx_logging_v0.7.  v0.7 ships memory and queue
 * targets only; a command-line tool needs its run visible as it happens.
 * LogStreamTarget is an ordinary v0.7 target (NAME + ACCEPT), so every event
 * still passes through LogService, LogRule levels and scopes.  Nothing in
 * v0.7 is modified.  Candidate to fold into oorexx_logging v0.8.
 *
 * ToolProgress wires one service + one stream target + one rule for a tool
 * object, and hands back the logger for its run method:
 *
 *   progress = .ToolProgress~new("rc-corpus", self, "RUN")
 *   log = progress~logger
 *   log~log(.Log~INFO, "checking" path)
 *
 * Lines go to .error by default so a tool's JSON report on .output stays
 * machine-readable.
 */

::class LogStreamTarget public
::attribute name get
::attribute scope get
::attribute scopeObject get
::attribute enabled get
::attribute written get

::method init
  expose name scope scopeObject enabled stream written
  use strict arg name = "stream", scopeValue = "INTERNAL", stream = .nil
  name = name~string
  scopeObject = .Log~normalizeScope(scopeValue)
  scope = scopeObject~disclosure
  if stream == .nil then stream = .error
  enabled = .true
  written = 0

::method accept public
  expose enabled stream scopeObject written
  use strict arg event
  if \enabled then return .false
  if event~hasMethod("DELIVERYSCOPEOBJECT") then
    if \scopeObject~equivalent(event~deliveryScopeObject) then return .false
  stream~lineout(self~format(event))
  written += 1
  return .true

::method format public
  use strict arg event
  payload = event~payload
  if payload == .nil then text = ""
  else text = payload~string
  return event~occurredAt event~levelName~left(5) event~component":" text

::method enable public
  expose enabled
  enabled = .true
  return self

::method disable public
  expose enabled
  enabled = .false
  return self


::class ToolProgress public
::attribute service get
::attribute target get
::attribute logger get

::method init
  expose service target logger
  use strict arg component, receiver, methodName, minimumLevel = (.Log~INFO), stream = .nil
  service = .LogService~new(component)
  target = .LogStreamTarget~new("progress", .Log~INTERNAL, stream)
  service~addTarget(target)
  rule = .LogRule~new(component"-progress", component, receiver~class~id, methodName, -
    .Log~INTERNAL, .Log~INTERNAL, minimumLevel, .nil, .array~of("progress"))
  service~addRule(rule)
  logger = service~loggerFor(receiver, methodName, .array~new, .Log~INTERNAL)

::method quiet public
  expose target
  target~disable
  return self

::requires "../../oorexx_logging_v0.7/src/LoggingCore.cls"
