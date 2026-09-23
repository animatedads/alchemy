/*----------------------------------------------------------------------------*/
/* ooRexx Process v0.1-dev1                                                   */
/* argv-first process execution library. This is intentionally not POSIX.      */
/*----------------------------------------------------------------------------*/
::class ProcessBuild public
::constant VERSION '0.1-dev1'
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

::requires 'ProcessSpec.cls'
::requires 'ProcessResult.cls'
::requires 'ProcessNativeProvider.cls'
