/* Remote Compute MU v0.1-dev2: native ooRexx semantic frontage.
 * No allocator, WLU, provider or queue implementation is embedded here.
 * A controller must be explicitly injected; absent one this is inert.
 */
::class RemoteComputeMUIntent public
::method init
  expose fields
  use strict arg fields

::method verify
  expose fields
  if \fields~isA(.Directory) then return 'BAD_ENVELOPE'
  required = 'jobId backend workload inputRef outputRef lease entitlement'
  do i = 1 to words(required)
    name = word(required, i)
    if \fields~hasIndex(name) then return 'MISSING_' || name
    if fields~at(name) == .nil then return 'NULL_' || name
  end
  backend = fields~at('backend')
  if backend \= 'colab' & backend \= 'zerogpu' & backend \= 'windows_vm' & backend \= 'windows_container' then return 'UNSUPPORTED_BACKEND'
  if \fields~at('workload')~isA(.Directory) then return 'BAD_WORKLOAD'
  return 'OK'

::method asDirectory
  expose fields
  use strict arg
  return fields~copy

::class RemoteComputeMUFront public
::method init
  expose controller
  use strict arg controller = .nil

::method dispatch
  expose controller
  use strict arg intent
  if \intent~isA(.RemoteComputeMUIntent) then return 'BAD_INTENT'
  assessment = intent~verify
  if assessment \= 'OK' then return assessment
  if controller == .nil then return 'NO_CONTROLLER_BOUND'
  /* Bound controller owns journal, pre-dispatch lease check and provider side effects. */
  return controller~dispatch(intent~asDirectory)

::method refresh
  expose controller
  use strict arg jobId
  if controller == .nil then return 'NO_CONTROLLER_BOUND'
  return controller~refresh(jobId)

::method cancel
  expose controller
  use strict arg jobId
  if controller == .nil then return 'NO_CONTROLLER_BOUND'
  return controller~cancel(jobId)

::method reconcile
  expose controller
  use strict arg jobId
  if controller == .nil then return 'NO_CONTROLLER_BOUND'
  return controller~recover(jobId)
