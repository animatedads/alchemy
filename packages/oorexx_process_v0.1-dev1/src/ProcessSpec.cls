/* ooRexx Process v0.1-dev1 -- execution specification */
::class ProcessSpec public
::method init
  use strict arg argvArg
  self~argv = argvArg
  self~cwd = ''
  self~environment = .directory~new
  self~stdinBytes = .nil
  self~stdoutPolicy = 'CAPTURE'
  self~stderrPolicy = 'CAPTURE'
  self~timeoutMs = 0
  self~maxOutputBytes = 1048576
  self~detach = .false
  self~processGroup = .false

::attribute argv
::attribute cwd
::attribute environment
::attribute stdinBytes
::attribute stdoutPolicy
::attribute stderrPolicy
::attribute timeoutMs
::attribute maxOutputBytes
::attribute detach
::attribute processGroup
