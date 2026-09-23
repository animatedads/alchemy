/* ooRexx Process v0.1-dev1 -- native argv-first synchronous provider */
::class ProcessNativeProvider public

::method name
  return 'rxprocessnative'

::method capabilities
  return .array~of('process.run.argv', 'process.capture.stdout', 'process.capture.stderr', -
                   'process.stdin.bytes', 'process.timeout', 'process.output.bounded', -
                   'process.cwd', 'process.group')

::method unsupported private
  use strict arg stage, message
  return .ProcessResult~new(.false, 0, 'NOT_STARTED', -1, 0, .false, '', '', .false, 0, self~name, 0, message, stage)

::method run
  use strict arg spec
  if spec~detach then return self~unsupported('DETACH', 'Detached execution is not implemented by the dev1 provider')
  if spec~environment~items > 0 then return self~unsupported('ENVIRONMENT', 'Environment overlays are not implemented by the dev1 provider')

  outPolicy = translate(spec~stdoutPolicy)
  errPolicy = translate(spec~stderrPolicy)
  if outPolicy == 'STREAM' | errPolicy == 'STREAM' then -
    return self~unsupported('STREAM', 'Streaming callbacks are not implemented by the dev1 provider')

  options = .directory~new
  options['CWD'] = spec~cwd
  options['STDOUT_POLICY'] = outPolicy
  options['STDERR_POLICY'] = errPolicy
  options['TIMEOUT_MS'] = spec~timeoutMs
  options['MAX_OUTPUT_BYTES'] = spec~maxOutputBytes
  options['PROCESS_GROUP'] = spec~processGroup
  if spec~stdinBytes \== .nil then options['STDIN_BYTES'] = spec~stdinBytes

  d = ProcessNativeRun(spec~argv, options)
  if \d['OK'] then -
    return .ProcessResult~new(.false, 0, 'NOT_STARTED', -1, 0, .false, '', '', .false, 0, self~name, -
                              d['ERRNO'], d['ERROR_MESSAGE'], d['STAGE'])

  return .ProcessResult~new(.true, d['PID'], d['TERMINATION'], d['EXIT_CODE'], d['TERM_SIGNAL'], -
                            d['TIMED_OUT'], d['STDOUT'], d['STDERR'], d['OUTPUT_TRUNCATED'], -
                            d['DURATION_MS'], self~name)

::requires 'ProcessSpec.cls'
::requires 'ProcessResult.cls'
::requires 'rxprocessnative' LIBRARY
