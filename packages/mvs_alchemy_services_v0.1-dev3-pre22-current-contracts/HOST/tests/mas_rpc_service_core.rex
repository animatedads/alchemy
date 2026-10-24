registry=.RpcServiceRegistry~new
publisher=.MasRpcServicePublisher~new(registry)
mapping=.Directory~new
mapping['database.get']='databaseGet'
mapping['database.put']='databasePut'
publisher~publishObject('mas.providers',.TestProvider~new,mapping)~freeze

dispatcher=.RpcServiceDispatcher~new(registry)
policy=.ConnectRoutePolicy~new
policy~allow('mas.providers.database.get','REQUEST','DIRECT','LOCAL')
policy~allow('mas.providers.database.put','REQUEST','DIRECT','LOCAL')
selector=.ConnectSelector~new(policy)
selector~register('DIRECT',.ConnectRpcDispatchAdapter~new(dispatcher,'mas.providers','LOCAL'),'LOCAL')
port=.MasConnectSelectorPort~new(selector)

args=.Directory~new; args['key']='A'
opts=.Directory~new; opts['context']=.TestContextFactory~new~contextFor('database.get')
value=port~request('mas.providers.database.get',args,'DIRECT','LOCAL',opts)
if value \== 'VALUE:A:trusted-host' then do
  say 'FAIL request value' value
  exit 1
end

args2=.Directory~new; args2['key']='B'; args2['value']='two'
opts2=.Directory~new; opts2['context']=.TestContextFactory~new~contextFor('database.put')
value2=port~request('mas.providers.database.put',args2,'DIRECT','LOCAL',opts2)
if value2 \== 'PUT:B:two:trusted-host' then do
  say 'FAIL put value' value2
  exit 1
end

if registry~resolve('mas.providers','database.get')==.nil then do
  say 'FAIL registry missing'
  exit 1
end
if registry~resolve('mas.providers','unpublished') \== .nil then do
  say 'FAIL unpublished exposed'
  exit 1
end

say 'PASS MAS_RPC_SERVICE_CORE_PRE22'
exit 0

::class TestContextFactory
::method contextFor
  use strict arg operation
  d=.Directory~new; d['principal']='trusted-host'; d['operation']=operation
  return d

::class TestProvider
::method databaseGet
  use strict arg arguments, context
  return 'VALUE:'||arguments['key']||':'||context['principal']
::method databasePut
  use strict arg arguments, context
  return 'PUT:'||arguments['key']||':'||arguments['value']||':'||context['principal']

::requires 'ConnectSelector.cls'
::requires 'ConnectRpcDispatchAdapter.cls'
::requires 'RpcServiceCore.cls'
::requires '../src/MasRpcServiceBinding.cls'
::requires '../src/MasConnectSelectorBinding.cls'
