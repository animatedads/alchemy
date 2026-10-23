/* Optional ConnectSelector adapter. Only REQUEST allowed; no fabricated notification. */
::class SoapConnectAdapter public
::method init
  expose client destination
  use strict arg client, destination=''
  destination=destination~translate
::method supports
  expose destination
  use strict arg intention
  if intention~mode \== 'REQUEST' then return .false
  if intention~requirement == 'DURABLE' then return .false
  return intention~destination~translate == destination
::method execute
  expose client
  use strict arg intention, payload = .nil
  if \self~supports(intention) then return .ConnectResult~failure('RPC','UNSUPPORTED')
  answer=client~request(intention~operation,payload)
  if \answer~ok then return .ConnectResult~failure('RPC','CALL_FAILED','SOAP service returned fault',answer~fault)
  return .ConnectResult~success('RPC',answer~value,.true,.true,.false)

::requires 'ConnectSelector.cls'
