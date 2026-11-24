/* ooRexx Process v0.1-dev2 -- native argv-first provider
 * dev2 (Claude (Opus 5.5), 24 November 2026; architecture Tom Dyer):
 * descriptor stdio, detached start, reap and signal. */
::class ProcessNativeProvider public

::method name
  return 'rxprocessnative'

::method capabilities
  return .array~of('process.run.argv', 'process.capture.stdout', 'process.capture.stderr', -
                   'process.stdin.bytes', 'process.timeout', 'process.output.bounded', -
                   'process.cwd', 'process.group', -
                   'process.stdio.descriptor', 'process.detach', 'process.reap', 'process.signal', -
                   'process.cloexec.inherited')

::method unsupported private
  use strict arg stage, message
  return .ProcessResult~new(.false, 0, 'NOT_STARTED', -1, 0, .false, '', '', .false, 0, self~name, 0, message, stage)

::method run
  use strict arg spec
  if spec~environment~items > 0 then return self~unsupported('ENVIRONMENT', 'Environment overlays are not implemented by the dev2 provider')

  outPolicy = translate(spec~stdoutPolicy)
  errPolicy = translate(spec~stderrPolicy)
  if outPolicy == 'STREAM' | errPolicy == 'STREAM' then -
    return self~unsupported('STREAM', 'Streaming callbacks are not implemented by the dev2 provider')

  options = .directory~new
  options['CWD'] = spec~cwd
  options['STDOUT_POLICY'] = outPolicy
  options['STDERR_POLICY'] = errPolicy
  options['TIMEOUT_MS'] = spec~timeoutMs
  options['MAX_OUTPUT_BYTES'] = spec~maxOutputBytes
  options['PROCESS_GROUP'] = spec~processGroup
  options['DETACH'] = spec~detach
  if spec~stdinBytes \== .nil then options['STDIN_BYTES'] = spec~stdinBytes
  if spec~stdinDescriptor \== .nil then options['STDIN_FD'] = spec~stdinDescriptor
  if spec~stdoutDescriptor \== .nil then options['STDOUT_FD'] = spec~stdoutDescriptor

  d = ProcessNativeRun(spec~argv, options)
  if \d['OK'] then -
    return .ProcessResult~new(.false, 0, 'NOT_STARTED', -1, 0, .false, '', '', .false, 0, self~name, -
                              d['ERRNO'], d['ERROR_MESSAGE'], d['STAGE'])

  return .ProcessResult~new(.true, d['PID'], d['TERMINATION'], d['EXIT_CODE'], d['TERM_SIGNAL'], -
                            d['TIMED_OUT'], d['STDOUT'], d['STDERR'], d['OUTPUT_TRUNCATED'], -
                            d['DURATION_MS'], self~name)

/* The outcome of a detached child, without waiting: termination 'RUNNING',
 * 'EXIT', 'SIGNAL' or 'GONE' (not our child, or already reaped). */
::method reap
  use strict arg pid
  d = ProcessNativeReap(pid)
  if \d['OK'] then return .ProcessResult~new(.false, pid, 'NOT_STARTED', -1, 0, .false, '', '', .false, 0, self~name, d['ERRNO'], d['ERROR_MESSAGE'], d['STAGE'])
  state = d['STATE']
  if state == 'EXIT' | state == 'SIGNAL' then -
    return .ProcessResult~new(.true, pid, state, d['EXIT_CODE'], d['TERM_SIGNAL'], .false, '', '', .false, 0, self~name)
  return .ProcessResult~new(.true, pid, state, -1, 0, .false, '', '', .false, 0, self~name)

/* Send a signal by number; group .true sends it to the child's process group.
 * Returns 0 or the errno. */
::method signal
  use strict arg pid, sig, group = .false
  return ProcessNativeSignal(pid, sig, group)

::requires 'ProcessSpec.cls'
::requires 'ProcessResult.cls'
::requires 'rxprocessnative' LIBRARY
