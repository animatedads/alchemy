/* MasConnectSelectorBinding.cls
 * Host-side transport-neutral call port for MAS production provider adapters.
 * ConnectSelector owns selection. MAS does not retry/fallback after dispatch.
 */
::class MasConnectSelectorPort public
::method init public
  expose selector
  use strict arg selectorArg
  if selectorArg==.nil then raise syntax 88.900 array('MAS_CONNECT_SELECTOR_REQUIRED')
  if \selectorArg~hasMethod('execute') | \selectorArg~hasMethod('explain') then -
    raise syntax 88.900 array('MAS_CONNECT_SELECTOR_CONTRACT')
  selector=selectorArg

::method request public
  expose selector
  use strict arg operation, payload=.nil, preferred='AUTO', destination='', options=.nil
  intent=.ConnectIntent~new(operation,'REQUEST','IMMEDIATE',preferred,destination,options)
  result=selector~execute(intent,payload)
  if \result~ok then raise syntax 88.900 array('MAS_CONNECT_REQUEST:'||result~code||':'||result~detail)
  if \result~accepted | \result~completed then raise syntax 88.900 array('MAS_CONNECT_REQUEST_INCOMPLETE')
  return result~value

::method notify public
  expose selector
  use strict arg operation, payload=.nil, preferred='AUTO', destination='', options=.nil
  intent=.ConnectIntent~new(operation,'NOTIFY','BEST_EFFORT',preferred,destination,options)
  result=selector~execute(intent,payload)
  if \result~ok | \result~accepted then raise syntax 88.900 array('MAS_CONNECT_NOTIFY:'||result~code||':'||result~detail)
  return result

::method enqueue public
  expose selector
  use strict arg operation, payload=.nil, requirement='DURABLE', preferred='QUEUE', destination='', options=.nil
  intent=.ConnectIntent~new(operation,'ENQUEUE',requirement,preferred,destination,options)
  result=selector~execute(intent,payload)
  if \result~ok | \result~accepted then raise syntax 88.900 array('MAS_CONNECT_ENQUEUE:'||result~code||':'||result~detail)
  if requirement~string~translate='DURABLE' & \result~durable then raise syntax 88.900 array('MAS_CONNECT_DURABILITY_NOT_PROVEN')
  return result

::method explain public
  expose selector
  use strict arg operation, mode='REQUEST', requirement='IMMEDIATE', preferred='AUTO', destination='', options=.nil
  return selector~explain(.ConnectIntent~new(operation,mode,requirement,preferred,destination,options))

::requires 'ConnectSelector.cls'
