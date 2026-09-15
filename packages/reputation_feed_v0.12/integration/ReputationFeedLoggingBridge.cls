/*
 * Reputation Feed v0.12 optional ooRexx Logging bridge.
 *
 * Feed owns the DecisionTrace payload semantics.  ooRexx Logging owns
 * disclosure scope, target selection, retention, persistence and logging
 * policy.  This bridge never creates or changes logging rules.
 */

::class ReputationFeedLoggingBridge subclass ReputationFeedAlchemyObject public
::attribute nativeScope get
::attribute level get

::method init
  expose logService nativeScope level
  use arg logServiceArg, nativeScopeArg = .nil, levelArg = .nil, alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationFeedLoggingBridge", alchemyContextArg)
  logService = logServiceArg
  if nativeScopeArg == .nil then nativeScope = .Log~INTERNAL; else nativeScope = nativeScopeArg
  if levelArg == .nil then level = .Log~INFO; else level = levelArg
  self~registerExternalRequirement("library", "oorexx_logging", "0.5", .false)
  self~registerMethodContract("RECORD", "Offer one sealed Feed decision trace to caller-configured ooRexx Logging", .array~of("TRACE"), "BOOLEAN", .false)

::method record
  expose logService nativeScope level
  use arg trace
  self~alchemyTouch("DECISION_TRACE_LOG_OFFER")
  if trace == .nil | \trace~isA(.ReputationFeedDecisionTrace) then raise syntax 88.900 array("Logging bridge requires ReputationFeedDecisionTrace")
  if \trace~sealed then raise syntax 88.900 array("Logging bridge requires sealed decision trace")
  if logService == .nil | \logService~hasMethod("LOGGERFOR") then return .false
  logger = logService~loggerFor(self, "record", .array~of(trace), nativeScope)
  return logger~point("DECISION", trace, level)

::requires "LoggingCore.cls"
::requires "ReputationDecisionAudit.cls"
