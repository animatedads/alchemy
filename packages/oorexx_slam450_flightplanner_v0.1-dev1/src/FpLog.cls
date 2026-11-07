/* FpLog.cls - SLAM 450 Flight Planner v0.1: progress logging for every
 * planner tool, through the estate's own logging framework (oorexx_logging
 * v0.7), so no tool run is a black box.
 *
 * A tool is a class with a RUN method. FpLog~for(tool) registers one rule
 * for that class's RUN (component "flightplanner", level INFO and up) and
 * returns the logger for this run. Events go to:
 *   - FpProgressTarget: one line per event on the console, as it happens
 *     ("12:01:07 INFO  fp_sky_day: sunrise 05:49 AEDT");
 *   - any further target added with FpLog~addTarget, e.g. the framework's
 *     LogQueueDirectTarget when a tool runs on the ed209 fleet, so the run's
 *     log lands in Queue Fabric next to its results.
 *
 * Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-07.
 */
::requires 'LoggingCore.cls'

::class FpLog public
::attribute service class get
::attribute targets class get

::method activate class
  expose service targets
  if var('service') then return service
  service = .LogService~new("flightplanner")
  targets = .array~new
  self~addTarget(.FpProgressTarget~new("progress"))
  return service

::method addTarget class
  expose service targets
  use strict arg target
  if \var('service') then self~activate
  service~addTarget(target)
  targets~append(target~name)
  return target

/* the logger for one run of tool's RUN method (the rule is added once per class) */
::method for class
  expose service targets registered
  use strict arg tool, methodName = "RUN"
  if \var('service') then self~activate
  if \var('registered') then registered = .set~new
  key = tool~class~id~translate"|"methodName~translate
  if \registered~hasItem(key) then do
    rule = .LogRule~new("fp-"key, "flightplanner", tool~class~id, methodName, .Log~INTERNAL, .Log~INTERNAL, .Log~INFO, .nil, targets~copy)
    service~addRule(rule)
    registered~put(key)
  end
  return service~loggerFor(tool, methodName, .array~new, .Log~INTERNAL)


/* One console line per event: time, level, tool, message. */
::class FpProgressTarget public
::attribute name get
::attribute scope get
::attribute scopeObject get
::attribute enabled get

::method init
  expose name scope scopeObject enabled
  use strict arg name = "progress"
  name = name~string
  scopeObject = .Log~normalizeScope(.Log~INTERNAL)
  scope = scopeObject~disclosure
  enabled = .true

::method accept
  expose enabled
  use strict arg event
  if \enabled then return .false
  msg = event~payload
  if \msg~isA(.String) then msg = msg~string
  say time() left(event~levelName, 5) event~receiverClass~lower":" msg
  return .true

::method enable
  expose enabled
  enabled = .true
  return self

::method disable
  expose enabled
  enabled = .false
  return self
