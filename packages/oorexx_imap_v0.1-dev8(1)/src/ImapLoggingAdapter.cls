/* Optional ooRexx Logging v0.7 bridge for IMAP diagnostics.
 *
 * The IMAP core owns a tiny event-sink seam and does not require LoggingCore.
 * This adapter maps that seam onto structured LogEvent objects.  It deliberately
 * receives already-redacted protocol diagnostics: never raw LOGIN/AUTHENTICATE
 * command text, passwords, message bodies, header blocks, or literal bytes.
 */

::class ImapLoggingAdapter public
::attribute service get
::attribute nativeScope get
::method init
  expose service nativeScope
  use strict arg serviceArg, nativeScopeArg = "INTERNAL"
  if serviceArg == .nil then raise syntax 88.900 array("IMAP_LOG_SERVICE_REQUIRED")
  service = serviceArg
  nativeScope = nativeScopeArg
::method emit public
  expose service nativeScope
  use strict arg owner, point, level, payload = .nil
  logger = service~loggerFor(owner, "EVENT", .array~of(point), nativeScope)
  if \logger~active then return .false
  return logger~point(point, payload, self~mapLevel(level))
::method mapLevel private
  use strict arg level
  if datatype(level, "W") then return level + 0
  name = level~string~translate
  select
    when name = "TRACE" then return .Log~TRACE
    when name = "DEBUG" then return .Log~DEBUG
    when name = "INFO" then return .Log~INFO
    when name = "WARN" | name = "WARNING" then return .Log~WARN
    when name = "ERROR" then return .Log~ERROR
    when name = "FATAL" then return .Log~FATAL
    otherwise raise syntax 88.900 array("IMAP_LOG_LEVEL_INVALID", level)
  end

::requires "LoggingCore.cls"
