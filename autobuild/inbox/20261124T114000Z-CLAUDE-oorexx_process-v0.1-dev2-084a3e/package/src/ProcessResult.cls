/* ooRexx Process v0.1-dev1 -- normalized execution result */
::class ProcessResult public
::method init
  expose started pid termination exitCode termSignal timedOut stdout stderr outputTruncated durationMs provider errorCode errorMessage errorStage
  use strict arg started, pid = 0, termination = 'NOT_STARTED', exitCode = (0 - 1), termSignal = 0, timedOut = .false, -
                 stdout = '', stderr = '', outputTruncated = .false, durationMs = 0, provider = '', -
                 errorCode = 0, errorMessage = '', errorStage = ''

::attribute started get
::attribute pid get
::attribute termination get
::attribute exitCode get
::attribute termSignal get
::attribute timedOut get
::attribute stdout get
::attribute stderr get
::attribute outputTruncated get
::attribute durationMs get
::attribute provider get
::attribute errorCode get
::attribute errorMessage get
::attribute errorStage get

::method succeeded
  expose started termination exitCode timedOut
  return started & \timedOut & termination == 'EXIT' & exitCode = 0

::method failedToStart
  expose started
  return \started
