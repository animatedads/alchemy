/* WorkflowLog.cls - Alchemy Workflow v0.1-dev1: the running progress log, through ooRexx Logging v0.7.
 *
 * Architecture: Tom Dyer (a tool that runs a task shows a running progress log, through the estate's own
 * Alchemy logging framework, never ad hoc output). Code: Claude (Opus 5.5), 2026-11-11.
 *
 * One LogService ("alchemy.workflow") with one rule (workflow-progress) on WorkflowLog's PROGRESS point,
 * delivering to WorkflowLogFileTarget, which writes each event to the run's log file and to stdout.
 * Lowering the rule's level, adding a Queue Fabric target or switching the file off is done with the
 * logging framework's own controls (service~enableTarget, LogRuntimeControl), not here.
 */
::requires 'LoggingCore.cls'

::class WorkflowLog public
::constant MODULE_VERSION '0.1-dev1'
::constant MODULE_LASTCHANGED '2026-11-11'
::attribute service get
::attribute target get

::method init
  expose service target
  use strict arg path, echo = .true
  service = .LogService~new('alchemy.workflow')
  target = .WorkflowLogFileTarget~new('workflow-file', path, echo)
  service~addTarget(target)
  rule = .LogRule~new('workflow-progress', 'alchemy_workflow', 'WorkflowLog', 'PROGRESS', .Log~INTERNAL, .Log~INTERNAL, .Log~INFO, .nil, .array~of('workflow-file'), .array~new)
  service~addRule(rule)

::method emit
  expose service
  use strict arg level, text
  logger = service~loggerFor(self, 'PROGRESS', .array~of(text), .Log~INTERNAL)
  if \logger~active then return .false
  return logger~log(level, text)

::method info
  use strict arg text
  return self~emit(.Log~INFO, text)

::method warn
  use strict arg text
  return self~emit(.Log~WARN, text)

::method error
  use strict arg text
  return self~emit(.Log~ERROR, text)

::method close
  expose target
  target~close

/* ------------------------------------------------------------------------------------------------ */
::class WorkflowLogFileTarget public
::constant MODULE_VERSION '0.1-dev1'
::constant MODULE_LASTCHANGED '2026-11-11'
::attribute name get
::attribute path get
::attribute enabled get

::method init
  expose name path echo enabled out
  use strict arg name, path, echo = .true
  enabled = .true
  out = .stream~new(path)
  if out~open('write append') \= 'READY:' then raise syntax 98.900 array('Workflow log: cannot write' path)

::method accept
  expose enabled echo out
  use strict arg event
  if \enabled then return .false
  line = event~occurredAt~string~left(19) event~levelName~left(5) event~payload
  out~lineOut(line)
  if echo then say line
  return .true

::method enable
  expose enabled
  enabled = .true
  return self

::method disable
  expose enabled
  enabled = .false
  return self

::method close
  expose out
  out~close
