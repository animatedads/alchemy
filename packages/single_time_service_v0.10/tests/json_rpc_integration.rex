/* Real JSON-RPC Fabric dev3 loopback + ConnectSelector dev2 routes.
 * JSON transport is exercised; sockets/network are not. */
numeric digits 30
p=.TzifZoneProvider~new('fixtures','2025b-test-snapshot')
s=.SingleTimeService~new
s~registerZone(p~load('Europe/London'))
s~registerZone(p~load('Australia/Sydney'))
endpoint=.TimeServiceEndpoint~new(s)
handler=.TimeJsonRpcHandler~new(endpoint)
registry=.JsonRpcMethodRegistry~new
registry~register('time.zone.resolve',handler)
registry~register('time.zone.compare',handler)
registry~register('time.recurrence.expand',handler)
codec=.JsonRpcCodec~new
transport=.JsonRpcLoopbackTransport~new(.JsonRpcDispatcher~new(registry))
client=.JsonRpcClient~new(transport)
policy=.ConnectRoutePolicy~new
policy~allow('time.zone.resolve','REQUEST','RPC','LOOPBACK')
policy~allow('time.recurrence.expand','REQUEST','RPC','LOOPBACK')
sel=.ConnectSelector~new(policy)
sel~register('RPC',.ConnectCallAdapter~new(client,'RPC','LOOPBACK'),'LOOPBACK')
args=.directory~new
args['zone']=.JsonString~new('Europe/London')
args['local']=.JsonString~new('2026-10-25T01:30:00')
r=sel~execute(.ConnectIntent~new('time.zone.resolve','REQUEST','IMMEDIATE','AUTO','LOOPBACK'),args)
if \r~ok | \r~completed then do; say 'FAIL JSONRPC return' r~code r~detail; probe=client~request('time.zone.resolve',args); say 'CLIENT:' probe~ok probe~fault~code probe~fault~message; exit 1; end
if r~value['status'] \= 'FOLD' | r~value['candidates']~items \= 2 then do; say 'FAIL typed fold'; exit 1; end
if r~value['candidates'][1]['instantPosixSeconds'] \= 1792888200 then do; say 'FAIL JSON epoch number'; exit 1; end
if r~value['candidates'][1]['instantPosixSeconds']~isA(.JsonString) then do; say 'FAIL numeric epoch encoded as string'; exit 1; end

args=.directory~new
args['id']=.JsonString~new('007')
args['zone']=.JsonString~new('Europe/London')
args['anchorLocal']=.JsonString~new('2026-10-24T01:30:00')
args['fromLocal']=.JsonString~new('2026-10-24T00:00:00')
args['throughLocal']=.JsonString~new('2026-10-26T23:59:59')
args['foldPolicy']=.JsonString~new('BOTH')
r=sel~execute(.ConnectIntent~new('time.recurrence.expand','REQUEST','IMMEDIATE','AUTO','LOOPBACK'),args)
if \r~ok then do; say 'FAIL recurrence RPC' r~code; exit 1; end
if r~value['generatedCount'] \= 4 then do; say 'FAIL recurrence number' r~value['generatedCount']; exit 1; end
if r~value['id'] \= '007' | \r~value['id']~isA(.JsonString) then do; say 'FAIL string identity'; exit 1; end
if r~value['occurrences'][2]['instantPosixSeconds'] \= 1792888200 then do; say 'FAIL response candidate'; exit 1; end

missing=.directory~new
missing['zone']=.JsonString~new('Europe/London')
r=sel~execute(.ConnectIntent~new('time.zone.resolve','REQUEST','IMMEDIATE','RPC','LOOPBACK'),missing)
if r~ok | r~code \= 'CALL_FAILED' then do; say 'FAIL remote invalid arguments'; exit 1; end
say 'PASS: JSON-RPC 2.0 loopback via ConnectSelector, typed epoch, preserved ID, explicit fault'
::requires 'TzifZoneProvider.cls'
::requires 'TimeServiceEndpoint.cls'
::requires 'ConnectSelector.cls'
::requires 'TimeJsonRpcBinding.cls'
