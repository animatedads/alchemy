/* Adapter from ooRexx SIP's recordEvent(Directory) sink contract to the
   shared ooRexx Logging Framework v0.7.  The framework remains an external
   dependency and is not copied into this package. */
::class SipAlchemyLogSink public
::method init
  expose service level nativeScope
  use strict arg service, level = .nil, nativeScope = .nil
  if level == .nil then level = .Log~INFO
  if nativeScope == .nil then nativeScope = .Log~INTERNAL
  if service == .nil | \service~isA(.LogService) then raise syntax 88.900 array("SipAlchemyLogSink requires LogService")
  service = service
  level = level
  nativeScope = .Log~normalizeScope(nativeScope)
::method recordEvent
  expose service level nativeScope
  use strict arg event
  if \event~isA(.Directory) then raise syntax 88.900 array("SIP log event must be a Directory")
  logger = service~loggerFor(self, "recordEvent", .array~of(event), nativeScope)
  return logger~log(level, event, .Log~BODY)

::requires "LoggingCore.cls"
