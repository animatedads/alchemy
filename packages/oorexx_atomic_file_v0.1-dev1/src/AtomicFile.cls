/*----------------------------------------------------------------------------*/
/* ooRexx Atomic File v0.1-dev1                                               */
/* Durable publication/replacement semantics. This is intentionally not POSIX.*/
/*----------------------------------------------------------------------------*/
::class AtomicFileBuild public
::constant VERSION '0.1-dev1'
::constant API 'oorexx.atomic-file/0.1'

::class AtomicFile public
::method init
  expose provider
  use strict arg providerArg = .nil
  if providerArg == .nil then provider = .AtomicNativeProvider~new
  else provider = providerArg

::method provider
  expose provider
  return provider~name

::method capabilities
  expose provider
  return provider~capabilities

::method replace
  expose provider
  use strict arg path, bytes, options = .nil
  if options == .nil then options = .AtomicFileOptions~new
  return provider~replace(path, bytes, options)

::requires 'AtomicFileOptions.cls'
::requires 'AtomicFileResult.cls'
::requires 'AtomicNativeProvider.cls'
