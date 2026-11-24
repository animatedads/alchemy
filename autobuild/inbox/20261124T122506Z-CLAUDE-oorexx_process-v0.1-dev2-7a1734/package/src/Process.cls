/*----------------------------------------------------------------------------*/
/* ooRexx Process v0.1-dev2                                                   */
/* argv-first process execution library. This is intentionally not POSIX.      */
/*----------------------------------------------------------------------------*/
::class ProcessBuild public
::constant VERSION '0.1-dev2'
::constant API 'oorexx.process/0.1'

::class ProcessRunner public
::method init
  expose provider
  use strict arg providerArg = .nil
  if providerArg == .nil then provider = .ProcessNativeProvider~new
  else provider = providerArg

::method provider
  expose provider
  return provider~name

::method capabilities
  expose provider
  return provider~capabilities

::method run
  expose provider
  use strict arg spec
  return provider~run(spec)

/* dev2: the outcome of a detached child, without waiting. */
::method reap
  expose provider
  use strict arg pid
  return provider~reap(pid)

/* dev2: send a signal (by number) to a child, or to its process group. */
::method signal
  expose provider
  use strict arg pid, sig, group = .false
  return provider~signal(pid, sig, group)

::requires 'ProcessSpec.cls'
::requires 'ProcessResult.cls'
::requires 'ProcessNativeProvider.cls'
