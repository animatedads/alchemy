/* Optional Instrumentation Mesh integration. Caller injects the accepted
 * InstrumentationEmitter/0.1 contract. No requires / transport ownership.
 * Metrics describe LOCAL transport completion, NOT remote method execution.
 * Observation is best-effort and must never change an RPC's outcome.
 */
::class JsonRpcInstrumentedTransport public
::method init
  expose underlying emitter
  use strict arg underlying, emitter
  if underlying==.nil | \underlying~hasMethod('EXCHANGE') | \underlying~hasMethod('SEND') then
    raise syntax 93.900 additional('RPC exchange/send transport required')
  if emitter==.nil | \emitter~hasMethod('REQUESTACCEPTED') | \emitter~hasMethod('BYTESOUT') then
    raise syntax 93.900 additional('Instrumentation Mesh emitter required')

::method exchange
  expose underlying
  use strict arg payload
  ignore=self~observe('accepted')
  ignore=self~observe('out',payload~length)
  signal on syntax name failed
  answer=underlying~exchange(payload)
  signal off syntax
  if answer==.nil then do
    ignore=self~observe('failed')
    return .nil
  end
  ignore=self~observe('in',answer~length)
  ignore=self~observe('completed')
  return answer
failed:
  signal off syntax
  ignore=self~observe('failed')
  raise syntax 93.900 additional('observed RPC exchange failed')

::method send
  expose underlying
  use strict arg payload
  ignore=self~observe('accepted')
  ignore=self~observe('out',payload~length)
  signal on syntax name failed
  answer=underlying~send(payload)
  signal off syntax
  if answer==.false then do
    ignore=self~observe('failed')
    return .false
  end
  ignore=self~observe('completed')
  return .true
failed:
  signal off syntax
  ignore=self~observe('failed')
  raise syntax 93.900 additional('observed RPC notification send failed')

::method observe private
  expose emitter
  use strict arg event, amount=0
  signal on syntax name observerFailed
  select
    when event=='accepted' then ignore=emitter~requestAccepted
    when event=='completed' then ignore=emitter~requestCompleted
    when event=='failed' then ignore=emitter~requestFailed
    when event=='in' then ignore=emitter~bytesIn(amount)
    when event=='out' then ignore=emitter~bytesOut(amount)
    otherwise return .false
  end
  signal off syntax
  return .true
observerFailed:
  signal off syntax
  return .false
