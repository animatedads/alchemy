/* Queue Fabric command boundary for durable WebDAV mutations. */
::class WebDavQueueProtocol public
::constant API 'webdav.queue/0.1'
::constant PUT 'DAV.PUT'
::constant DELETE 'DAV.DELETE'
::constant MKCOL 'DAV.MKCOL'

::class WebDavQueueService public
::method init
  expose manager queueName principal adapter
  use arg managerArg, queueArg, principalArg, adapterArg
  manager=managerArg; queueName=queueArg~string; principal=principalArg~string; adapter=adapterArg
::method serveOne
  expose manager queueName principal adapter
  claim=manager~claim(queueName,principal)
  if \claim~ok then return claim
  package=claim~value
  payload=package~payload
  op=payload['op']~string~upper
  select
    when op=.WebDavQueueProtocol~PUT then result=adapter~putBytes(payload['path'],payload['body'],payload['contentType'],payload['ifMatch'],payload['ifNoneMatch'])
    when op=.WebDavQueueProtocol~DELETE then result=adapter~deletePath(payload['path'],payload['ifMatch'])
    when op=.WebDavQueueProtocol~MKCOL then result=adapter~makeCollection(payload['path'])
    otherwise result=.WebDavMutationResult~new(.false,400,'UNKNOWN_OPERATION',op,.nil)
  end
  ignore=manager~ack(queueName,package~packageId,package~claimToken,principal)
  return result

::requires 'WebDavCore.cls'
::requires 'ObjectQueueFabric.cls'
