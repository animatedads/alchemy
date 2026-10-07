/* Queue Fabric command boundary for durable WebDAV mutations. */
::class WebDavQueueProtocol public
::constant API 'webdav.queue/0.1'
::constant PUT 'DAV.PUT'
::constant DELETE 'DAV.DELETE'
::constant MKCOL 'DAV.MKCOL'
::constant COPY 'DAV.COPY'
::constant MOVE 'DAV.MOVE'
::constant PROPPATCH 'DAV.PROPPATCH'

/* Request objects are carried whole.  Queue transport serialization, when
 * needed, is Queue Fabric authority; WebDAV does not flatten its object model. */
::class WebDavQueueMutation public
::attribute operation get
::attribute path get
::attribute body get
::attribute contentType get
::attribute ifMatch get
::attribute ifNoneMatch get
::attribute ifHeader get
::attribute destination get
::attribute overwrite get
::attribute depth get
::attribute propertyPatches get
::method init
  expose operation path body contentType ifMatch ifNoneMatch ifHeader destination overwrite depth propertyPatches
  use arg operationArg,pathArg,bodyArg='',contentTypeArg='application/octet-stream',ifMatchArg='',ifNoneMatchArg='',ifHeaderArg='',destinationArg='',overwriteArg=.true,depthArg='infinity',patchesArg=.nil
  operation=operationArg~string~upper; path=.StoragePath~normalize(pathArg); body=bodyArg
  contentType=contentTypeArg~string; ifMatch=ifMatchArg~string; ifNoneMatch=ifNoneMatchArg~string; ifHeader=ifHeaderArg~string
  destination=destinationArg~string; overwrite=(overwriteArg==.true); depth=depthArg~string
  if patchesArg==.nil then propertyPatches=.array~new; else propertyPatches=patchesArg

::class WebDavQueueService public
::method init
  expose manager queueName principal adapter
  use arg managerArg, queueArg, principalArg, adapterArg
  manager=managerArg; queueName=queueArg~string; principal=principalArg~string; adapter=adapterArg
::method serveOne
  expose manager queueName principal adapter
  claim=manager~claim(queueName,principal)
  if \claim~ok then return claim
  package=claim~value; payload=package~payload
  if payload~isA(.WebDavQueueMutation) then outcome=self~executeObject(payload)
  else outcome=self~executeLegacy(payload)
  /* Only ACK after the adapter has returned a completed mutation outcome. */
  ignore=manager~ack(queueName,package~packageId,package~claimToken,principal)
  return outcome
::method executeObject private
  expose adapter
  use arg m
  select
    when m~operation=.WebDavQueueProtocol~PUT then outcome=adapter~putBytes(m~path,m~body,m~contentType,m~ifMatch,m~ifNoneMatch,m~ifHeader)
    when m~operation=.WebDavQueueProtocol~DELETE then outcome=adapter~deletePath(m~path,m~ifMatch,m~ifHeader)
    when m~operation=.WebDavQueueProtocol~MKCOL then outcome=adapter~makeCollection(m~path,m~ifHeader)
    when m~operation=.WebDavQueueProtocol~COPY then outcome=adapter~copyPath(m~path,m~destination,m~overwrite,m~depth,m~ifHeader)
    when m~operation=.WebDavQueueProtocol~MOVE then outcome=adapter~movePath(m~path,m~destination,m~overwrite,m~ifHeader)
    when m~operation=.WebDavQueueProtocol~PROPPATCH then do
      do p over m~propertyPatches
        if p~action='SET' then ok=adapter~setDeadProperty(m~path,p~namespace,p~name,p~value)
        else ok=adapter~removeDeadProperty(m~path,p~namespace,p~name)
      end
      adapter~namespace~environment~advanceGeneration
      outcome=.WebDavMutationResult~new(.true,207,'PROPPATCH','',.nil)
    end
    otherwise outcome=.WebDavMutationResult~new(.false,400,'UNKNOWN_OPERATION',m~operation,.nil)
  end
  return outcome
::method executeLegacy private
  expose adapter
  use arg payload
  op=payload['op']~string~upper
  select
    when op=.WebDavQueueProtocol~PUT then outcome=adapter~putBytes(payload['path'],payload['body'],payload['contentType'],payload['ifMatch'],payload['ifNoneMatch'])
    when op=.WebDavQueueProtocol~DELETE then outcome=adapter~deletePath(payload['path'],payload['ifMatch'])
    when op=.WebDavQueueProtocol~MKCOL then outcome=adapter~makeCollection(payload['path'])
    otherwise outcome=.WebDavMutationResult~new(.false,400,'UNKNOWN_OPERATION',op,.nil)
  end
  return outcome

::requires 'WebDavCore.cls'
::requires 'ObjectQueueFabric.cls'
