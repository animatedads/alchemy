/* Optional entry point for the temporary native gap provider. */

::class PosixGapFactory public
::method create class
  return .Posix~new(.PosixGapProvider~new)

::requires 'Posix.cls'
::requires 'PosixGapProvider.cls'
