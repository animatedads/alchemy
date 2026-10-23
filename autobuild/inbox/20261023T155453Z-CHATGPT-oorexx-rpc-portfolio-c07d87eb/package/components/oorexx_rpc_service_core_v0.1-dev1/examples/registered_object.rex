/* Demonstrates server-published RPC method aliasing, no protocol required. */
registry=.RpcServiceRegistry~new
service=.Catalog~new
unused=registry~registerMethod('catalog','lookup',service,'fetch')
registry~freeze
arguments=.directory~new
arguments['id']='0007'
answer=.RpcServiceDispatcher~new(registry)~invoke('catalog','lookup',arguments,.nil)
if \answer~ok then exit 1
say answer~value
exit 0
::class Catalog
::method fetch
  use strict arg arguments,context
  return 'catalog:' || arguments['id']
::requires 'RpcServiceCore.cls'
