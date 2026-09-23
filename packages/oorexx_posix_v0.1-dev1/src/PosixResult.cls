/* ooRexx POSIX Foundation v0.1-dev1 - structured results and evidence. */

::class PosixEvidence public
::attribute operation get
::attribute provider get
::attribute capability get
::attribute path get
::attribute paths get
::attribute followLinks get
::attribute coherent get
::attribute observationCount get
::attribute strength get
::attribute warning get

::method init
  expose operation provider capability path paths followLinks coherent observationCount strength warning
  use strict arg operation, provider, capability = '', path = '', paths = .nil, -
                 followLinks = .nil, coherent = .nil, observationCount = 1, -
                 strength = 'NORMAL', warning = ''
  if paths == .nil then paths = .array~new

::method string
  expose operation provider capability coherent strength warning
  s = operation || ' provider=' || provider
  if capability \== '' then s ||= ' capability=' || capability
  if coherent \== .nil then s ||= ' coherent=' || coherent
  if strength \== '' then s ||= ' strength=' || strength
  if warning \== '' then s ||= ' warning=' || warning
  return s


::class PosixError public
::attribute operation get
::attribute path get
::attribute paths get
::attribute errno get
::attribute errnoName get
::attribute message get
::attribute provider get
::attribute capability get
::attribute recoverable get
::attribute kind get

::method init
  expose operation path paths errno errnoName message provider capability recoverable kind
  use strict arg operation, provider, capability = '', path = '', paths = .nil, -
                 errno = .nil, errnoName = '', message = '', recoverable = .false, -
                 kind = 'NATIVE_FAILURE'
  if paths == .nil then paths = .array~new

::method string
  expose operation path errno errnoName message provider capability kind
  s = kind || ': ' || operation || ' provider=' || provider
  if capability \== '' then s ||= ' capability=' || capability
  if path \== '' then s ||= ' path=' || path
  if errno \== .nil then s ||= ' errno=' || errno
  if errnoName \== '' then s ||= '(' || errnoName || ')'
  if message \== '' then s ||= ' ' || message
  return s


::class PosixResult public
::attribute ok get
::attribute value get
::attribute error get
::attribute evidence get

::method init
  expose ok value error evidence
  use strict arg ok, value = .nil, error = .nil, evidence = .nil

::method success class
  use strict arg value = .nil, evidence = .nil
  return self~new(.true, value, .nil, evidence)

::method failure class
  use strict arg error, evidence = .nil
  return self~new(.false, .nil, error, evidence)

::method unsupported class
  use strict arg operation, provider, capability, path = ''
  evidence = .PosixEvidence~new(operation, provider, capability, path, .nil, .nil, .nil, 0, 'UNAVAILABLE')
  error = .PosixError~new(operation, provider, capability, path, .nil, .nil, '', -
                          'Capability is not available from this provider', .false, 'CAPABILITY_UNAVAILABLE')
  return self~failure(error, evidence)

::method requireValue
  expose ok value error
  if \ok then raise syntax 88.900 array(error~string)
  return value
