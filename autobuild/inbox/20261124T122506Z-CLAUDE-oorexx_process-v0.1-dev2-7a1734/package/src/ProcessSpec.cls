/* ooRexx Process v0.1-dev2 -- execution specification
 * dev2 (Claude (Opus 5.5), 24 November 2026; architecture Tom Dyer):
 *   stdinDescriptor   an open descriptor (integer) the child gets as stdin
 *   stdoutDescriptor  with stdoutPolicy 'DESCRIPTOR', the child's stdout
 *   detach            start and return at once (termination 'RUNNING');
 *                     collect the outcome later with ProcessRunner~reap */
::class ProcessSpec public
::method init
  use strict arg argvArg
  self~argv = argvArg
  self~cwd = ''
  self~environment = .directory~new
  self~stdinBytes = .nil
  self~stdinDescriptor = .nil
  self~stdoutPolicy = 'CAPTURE'
  self~stdoutDescriptor = .nil
  self~stderrPolicy = 'CAPTURE'
  self~timeoutMs = 0
  self~maxOutputBytes = 1048576
  self~detach = .false
  self~processGroup = .false

::attribute argv
::attribute cwd
::attribute environment
::attribute stdinBytes
::attribute stdinDescriptor
::attribute stdoutPolicy
::attribute stdoutDescriptor
::attribute stderrPolicy
::attribute timeoutMs
::attribute maxOutputBytes
::attribute detach
::attribute processGroup
