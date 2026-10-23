/* Confirms no ConnectSelector, Queue Fabric or legacy selector required
 * by the protocol-only package entrypoint. Run in a fresh interpreter.
 */
reg=.JsonRpcMethodRegistry~new
reg~register('pure.echo',.Echo~new)
callResult=.JsonRpcClient~new(.JsonRpcLoopbackTransport~new(.JsonRpcDispatcher~new(reg)))~request('pure.echo',.Array~of(9))
if \callResult~ok | callResult~result[1]<>9 then do
  say 'FAIL core-only protocol request'
  exit 1
end
if .JsonRpcConnectorRegistry~isA(.Class) then do
  say 'FAIL legacy connector registry unexpectedly loaded by core'
  exit 1
end
if .ConnectSelector~isA(.Class) then do
  say 'FAIL ConnectSelector unexpectedly required by core'
  exit 1
end
say 'PASS protocol-only request without ConnectSelector or legacy registry'
exit 0
::class Echo
::method invoke
  use strict arg name, params, context
  return params
::requires 'JsonRpcFabric.cls'
