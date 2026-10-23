/* DEPRECATED adapter for dev1/dev2 applications only.
 * Deliberately not loaded by JsonRpcFabric.cls or exported by the core.
 * New applications MUST use ConnectSelector to choose DIRECT, RPC or QUEUE.
 * This compatibility file is an optional, explicitly imported shim.
 */
/** Named connector selection. No implicit fallback on failed mutations. */
::class JsonRpcConnectorRegistry public
::method init
  expose entries
  entries=.Directory~new
::method register
  expose entries
  use strict arg name, connector
  if name == '' then raise syntax 93.900 additional('connector name required')
  if \connector~hasMethod('request') | \connector~hasMethod('notify') then raise syntax 93.900 additional('connector must expose request and notify')
  entries[name]=connector
  return self
::method connector
  expose entries
  use strict arg name
  return entries[name]
::method request
  use strict arg name, methodName, params = .nil
  selected=self~connector(name)
  if selected == .nil then return .JsonRpcCallResult~new(.false,.nil,.JsonRpcFault~new(-32000,'Unknown connector'),.nil)
  return selected~request(methodName,params)
::method notify
  use strict arg name, methodName, params = .nil
  selected=self~connector(name)
  if selected == .nil then return .false
  return selected~notify(methodName,params)



::requires 'JsonRpcFabric.cls'
