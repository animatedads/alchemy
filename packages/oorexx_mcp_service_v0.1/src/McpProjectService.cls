/* ooRexx MCP Project Service v0.1
 * Authoritative project coordination semantics behind Wire/HTTPS adapters.
 * State is reconstructed from an append-only event journal.
 */

::class McpProjectBuild public
::constant VERSION "0.1"
::constant API "oorexx.mcp.project/0.1"
::constant MCP_SPEC "2026-07-28"
::constant JOURNAL_SCHEMA "oorexx.mcp.project.event/1"

::class McpProjectUtil public
::method string class
  use strict arg value, defaultValue=''
  if value == .nil then return defaultValue
  return value~string

::method required class
  use strict arg args, name
  if args == .nil | \args~hasIndex(name) then return ''
  value=self~string(args[name])
  return value~strip

::method optional class
  use strict arg args, name, defaultValue=''
  if args == .nil | \args~hasIndex(name) then return defaultValue
  return self~string(args[name],defaultValue)

::method bool class
  use strict arg args, name, defaultValue=.false
  if args == .nil | \args~hasIndex(name) then return defaultValue
  value=self~string(args[name])~lower
  return value='1' | value='true' | value='yes' | value='on'

::method copyDirectory class
  use strict arg source
  target=.directory~new
  if source == .nil then return target
  do key over source
    target[key]=source[key]
  end
  return target

::method now class
  /* ISO-like UTC-ish process timestamp suitable for evidence, not ordering. */
  return date('S') || 'T' || time('L')

::class McpProjectComponentCatalog public
::attribute sourceArtifact get
::attribute sourceSha256 get

::method init
  expose components byId sourceArtifact sourceSha256
  use strict arg components, sourceArtifact='', sourceSha256=''
  byId=.directory~new
  do component over components
    id=.McpProjectUtil~string(component['componentId'])
    if id<>'' then byId[id]=component
  end

::method fromJsonFile class
  use strict arg path
  parsed=.json~fromJSON(charin(path,1,chars(path)))
  call stream path,'c','close'
  if parsed == .nil | \parsed~hasIndex('components') then -
    raise syntax 40.900 array('Invalid MCP component catalog',path)
  sourceArtifact=.McpProjectUtil~optional(parsed,'sourceArtifact','')
  sourceSha256=.McpProjectUtil~optional(parsed,'sourceSha256','')
  return self~new(parsed['components'],sourceArtifact,sourceSha256)

::method has
  expose byId
  use strict arg componentId
  return byId~hasIndex(componentId)

::method get
  expose byId
  use strict arg componentId
  if byId~hasIndex(componentId) then return byId[componentId]
  return .nil

::method list
  expose components
  out=.array~new
  do component over components
    out~append(component)
  end
  return out

::class McpProjectMemoryJournal public
::method init
  expose journalEvents
  journalEvents=.array~new

::method append
  expose journalEvents
  use strict arg event
  journalEvents~append(event)
  return event

::method events
  expose journalEvents
  out=.array~new
  do event over journalEvents; out~append(event); end
  return out

::class McpProjectJsonlJournal public
::attribute path get

::method init
  expose path
  use strict arg path
  if path='' then raise syntax 40.900 array('Journal path is required')

::method append
  expose path
  use strict arg event
  json=.json~toJSON(event)
  result=stream(path,'c','open write append')
  if result~left(5) <> 'READY' & result~left(6) <> 'NORMAL' then -
    raise syntax 40.900 array('Unable to open MCP project journal for append',path,result)
  call lineout path,json
  call stream path,'c','close'
  return event

::method events
  expose path
  out=.array~new
  if stream(path,'c','query exists')='' then return out
  result=stream(path,'c','open read')
  if result~left(5) <> 'READY' & result~left(6) <> 'NORMAL' then -
    raise syntax 40.900 array('Unable to open MCP project journal for read',path,result)
  lineNumber=0
  do while lines(path)>0
    line=linein(path); lineNumber+=1
    if line~strip='' then iterate
    signal on syntax name badJournalLine
    event=.json~fromJSON(line)
    signal off syntax
    if event == .nil | \event~hasIndex('schema') | \event~hasIndex('eventType') then -
      raise syntax 40.900 array('Invalid MCP project journal event',path,lineNumber)
    if .McpProjectUtil~string(event['schema']) <> .McpProjectBuild~JOURNAL_SCHEMA then -
      raise syntax 40.900 array('Unsupported MCP project journal schema',path,lineNumber,event['schema'])
    out~append(event)
  end
  call stream path,'c','close'
  return out
badJournalLine:
  call stream path,'c','close'
  raise syntax 40.900 array('Malformed MCP project journal JSON',path,lineNumber)

::class McpProjectNullSphereChecker public
::method check
  use strict arg args
  return .WireUIResult~failure('SPHERE_CHECKER_UNAVAILABLE','No sphere checker is configured')

::class McpProjectWireService public
::attribute catalog get
::attribute journal get

::method init
  expose catalog journal sphereChecker requests requestOrder ownerships receipts sequence
  use strict arg catalog, journal, sphereChecker=.nil
  if catalog == .nil then raise syntax 40.900 array('Component catalog is required')
  if journal == .nil then raise syntax 40.900 array('Project journal is required')
  if sphereChecker == .nil then sphereChecker=.McpProjectNullSphereChecker~new
  requests=.directory~new
  requestOrder=.array~new
  ownerships=.directory~new
  receipts=.directory~new
  sequence=0
  self~replay

::method dispatch
  use strict arg operation, args=.nil, actorId=''
  operation=operation~upper
  select
    when operation='PROJECT.COMPONENTS.LIST' then return self~componentsList(args,actorId)
    when operation='SPHERE.CHECK' then return self~sphereCheck(args,actorId)
    when operation='PROJECT.REQUEST.CREATE' then return self~requestCreate(args,actorId)
    when operation='PROJECT.OWNERSHIP.CLAIM' then return self~ownershipClaim(args,actorId)
    when operation='PROJECT.REQUESTS.LIST' then return self~requestsList(args,actorId)
    when operation='PROJECT.REQUEST.MARK_READ' then return self~requestMarkRead(args,actorId)
    when operation='PROJECT.REQUEST.REPLY' then return self~requestReply(args,actorId)
    otherwise return .WireUIResult~failure('UNKNOWN_OPERATION','Unknown project operation: '||operation)
  end

::method componentsList
  expose catalog ownerships requests requestOrder receipts
  use strict arg args, actorId=''
  filter=.McpProjectUtil~optional(args,'componentId','')
  out=.array~new
  do component over catalog~list
    componentId=.McpProjectUtil~string(component['componentId'])
    if filter<>'' & componentId<>filter then iterate
    row=.McpProjectUtil~copyDirectory(component)
    if ownerships~hasIndex(componentId) then row['ownership']=ownerships[componentId]
    else row['ownership']=.nil
    openCount=0; unreadCount=0
    do requestId over requestOrder
      request=requests[requestId]
      if .McpProjectUtil~string(request['componentId'])<>componentId then iterate
      openCount+=1
      if actorId<>'' & self~visible(request,actorId) & \self~isRead(requestId,actorId) then unreadCount+=1
    end
    row['requestCount']=openCount
    row['unreadRequestCount']=unreadCount
    out~append(row)
  end
  value=.directory~new
  value['schema']='oorexx.mcp.component.list/1'
  value['components']=out
  value['count']=out~items
  value['catalogSourceArtifact']=catalog~sourceArtifact
  value['catalogSourceSha256']=catalog~sourceSha256
  return .WireUIResult~success(value,'COMPONENTS_LISTED')

::method sphereCheck
  expose sphereChecker catalog
  use strict arg args, actorId=''
  componentId=.McpProjectUtil~optional(args,'componentId','')
  if componentId<>'' & \catalog~has(componentId) then -
    return .WireUIResult~failure('COMPONENT_NOT_FOUND','Unknown project component: '||componentId)
  return sphereChecker~check(args)

::method requestCreate
  expose catalog ownerships
  use strict arg args, actorId=''
  auth=self~requireActor(actorId); if auth<>.nil then return auth
  componentId=.McpProjectUtil~required(args,'componentId')
  if componentId='' then return .WireUIResult~failure('INVALID_ARGUMENT','componentId is required')
  if \catalog~has(componentId) then return .WireUIResult~failure('COMPONENT_NOT_FOUND','Unknown project component: '||componentId)
  recipientId=.McpProjectUtil~optional(args,'recipientId','')
  if recipientId='' then do
    if ownerships~hasIndex(componentId) then recipientId=.McpProjectUtil~string(ownerships[componentId]['ownerId'])
    else recipientId='component:'||componentId
  end
  body=.McpProjectUtil~required(args,'body')
  if body='' then return .WireUIResult~failure('INVALID_ARGUMENT','body is required')
  subject=.McpProjectUtil~optional(args,'subject','')
  requestType=.McpProjectUtil~optional(args,'requestType','WORK')
  requestId=self~nextId('REQ')
  event=self~baseEvent('REQUEST_CREATED')
  event['requestId']=requestId
  event['rootRequestId']=requestId
  event['parentRequestId']=''
  event['componentId']=componentId
  event['senderId']=actorId
  event['recipientId']=recipientId
  event['requestType']=requestType
  event['subject']=subject
  event['body']=body
  self~commit(event)
  return .WireUIResult~success(self~requestValue(requestId,actorId),'REQUEST_CREATED')

::method ownershipClaim
  expose catalog ownerships
  use strict arg args, actorId=''
  auth=self~requireActor(actorId); if auth<>.nil then return auth
  componentId=.McpProjectUtil~required(args,'componentId')
  if componentId='' then return .WireUIResult~failure('INVALID_ARGUMENT','componentId is required')
  if \catalog~has(componentId) then return .WireUIResult~failure('COMPONENT_NOT_FOUND','Unknown project component: '||componentId)
  if ownerships~hasIndex(componentId) then do
    current=ownerships[componentId]
    if .McpProjectUtil~string(current['ownerId'])=actorId then -
      return .WireUIResult~success(current,'ALREADY_OWNED_BY_CALLER')
    return .WireUIResult~failure('OWNERSHIP_CONFLICT','Component is already owned',current)
  end
  event=self~baseEvent('OWNERSHIP_CLAIMED')
  event['ownershipId']=self~nextId('OWN')
  event['componentId']=componentId
  event['ownerId']=actorId
  event['claimRequestId']=.McpProjectUtil~optional(args,'claimRequestId','')
  self~commit(event)
  return .WireUIResult~success(ownerships[componentId],'OWNERSHIP_CLAIMED')

::method requestsList
  expose requests requestOrder
  use strict arg args, actorId=''
  auth=self~requireActor(actorId); if auth<>.nil then return auth
  componentFilter=.McpProjectUtil~optional(args,'componentId','')
  unreadOnly=.McpProjectUtil~bool(args,'unreadOnly',.false)
  out=.array~new
  do requestId over requestOrder
    request=requests[requestId]
    if \self~visible(request,actorId) then iterate
    if componentFilter<>'' & .McpProjectUtil~string(request['componentId'])<>componentFilter then iterate
    if unreadOnly & self~isRead(requestId,actorId) then iterate
    out~append(self~requestValue(requestId,actorId))
  end
  value=.directory~new
  value['schema']='oorexx.mcp.request.list/1'
  value['requests']=out
  value['count']=out~items
  return .WireUIResult~success(value,'REQUESTS_LISTED')

::method requestMarkRead
  expose requests receipts
  use strict arg args, actorId=''
  auth=self~requireActor(actorId); if auth<>.nil then return auth
  requestId=.McpProjectUtil~required(args,'requestId')
  if requestId='' then return .WireUIResult~failure('INVALID_ARGUMENT','requestId is required')
  if \requests~hasIndex(requestId) then return .WireUIResult~failure('REQUEST_NOT_FOUND','Unknown request: '||requestId)
  request=requests[requestId]
  if \self~visible(request,actorId) then return .WireUIResult~failure('REQUEST_NOT_VISIBLE','Request is not visible to caller')
  key=requestId||'|'||actorId
  if receipts~hasIndex(key) then return .WireUIResult~success(receipts[key],'ALREADY_READ')
  event=self~baseEvent('REQUEST_READ')
  event['receiptId']=self~nextId('RCP')
  event['requestId']=requestId
  event['readerId']=actorId
  self~commit(event)
  return .WireUIResult~success(receipts[key],'REQUEST_MARKED_READ')

::method requestReply
  expose requests catalog
  use strict arg args, actorId=''
  auth=self~requireActor(actorId); if auth<>.nil then return auth
  parentId=.McpProjectUtil~required(args,'requestId')
  if parentId='' then return .WireUIResult~failure('INVALID_ARGUMENT','requestId is required')
  if \requests~hasIndex(parentId) then return .WireUIResult~failure('REQUEST_NOT_FOUND','Unknown request: '||parentId)
  parent=requests[parentId]
  if \self~visible(parent,actorId) then return .WireUIResult~failure('REQUEST_NOT_VISIBLE','Request is not visible to caller')
  body=.McpProjectUtil~required(args,'body')
  if body='' then return .WireUIResult~failure('INVALID_ARGUMENT','body is required')
  recipientId=.McpProjectUtil~optional(args,'recipientId',.McpProjectUtil~string(parent['senderId']))
  if recipientId='' then return .WireUIResult~failure('INVALID_ARGUMENT','recipientId could not be resolved')
  subject=.McpProjectUtil~optional(args,'subject','')
  if subject='' then do
    parentSubject=.McpProjectUtil~string(parent['subject'])
    if parentSubject='' then subject='Re: request '||parentId
    else if parentSubject~left(3)~lower='re:' then subject=parentSubject
    else subject='Re: '||parentSubject
  end
  requestId=self~nextId('REQ')
  event=self~baseEvent('REQUEST_CREATED')
  event['requestId']=requestId
  event['rootRequestId']=.McpProjectUtil~string(parent['rootRequestId'],parentId)
  event['parentRequestId']=parentId
  event['componentId']=.McpProjectUtil~string(parent['componentId'])
  event['senderId']=actorId
  event['recipientId']=recipientId
  event['requestType']=.McpProjectUtil~optional(args,'requestType','REPLY')
  event['subject']=subject
  event['body']=body
  self~commit(event)
  return .WireUIResult~success(self~requestValue(requestId,actorId),'REQUEST_REPLY_CREATED')

::method requireActor private
  use strict arg actorId
  if actorId='' then return .WireUIResult~failure('AUTHENTICATED_PRINCIPAL_REQUIRED','Authenticated HTTPS principal is required')
  return .nil

::method visible private
  expose ownerships
  use strict arg request, actorId
  sender=.McpProjectUtil~string(request['senderId'])
  recipient=.McpProjectUtil~string(request['recipientId'])
  if actorId=sender | actorId=recipient | recipient='*' then return .true
  componentId=.McpProjectUtil~string(request['componentId'])
  if recipient='component:'||componentId & ownerships~hasIndex(componentId) then -
    return .McpProjectUtil~string(ownerships[componentId]['ownerId'])=actorId
  return .false

::method isRead private
  expose receipts
  use strict arg requestId, actorId
  return receipts~hasIndex(requestId||'|'||actorId)

::method requestValue private
  expose requests
  use strict arg requestId, actorId=''
  request=requests[requestId]
  out=.McpProjectUtil~copyDirectory(request)
  if actorId<>'' then out['readByCaller']=self~isRead(requestId,actorId)
  return out

::method nextId private
  expose sequence
  use strict arg prefix
  sequence+=1
  return prefix||'-'||sequence~right(8,'0')

::method baseEvent private
  use strict arg eventType
  event=.directory~new
  event['schema']=.McpProjectBuild~JOURNAL_SCHEMA
  event['eventType']=eventType
  event['eventId']=self~nextId('EVT')
  event['occurredAt']=.McpProjectUtil~now
  return event

::method commit private
  expose journal
  use strict arg event
  /* Persistence is authoritative: only apply after append succeeds. */
  journal~append(event)
  self~apply(event)
  return event

::method replay private
  expose journal sequence
  events=journal~events
  sequence=0
  do event over events
    self~observeIds(event)
    self~apply(event)
  end

::method observeIds private
  expose sequence
  use strict arg event
  do key over event
    if key~right(2)~lower<>'id' then iterate
    value=.McpProjectUtil~string(event[key])
    parse var value . '-' suffix
    if suffix~datatype('W') & suffix>sequence then sequence=suffix
  end

::method apply private
  expose requests requestOrder ownerships receipts
  use strict arg event
  eventType=.McpProjectUtil~string(event['eventType'])
  select
    when eventType='REQUEST_CREATED' then do
      id=.McpProjectUtil~string(event['requestId'])
      if requests~hasIndex(id) then raise syntax 40.900 array('Duplicate request event',id)
      request=.directory~new
      do key over event
        if key<>'schema' & key<>'eventType' & key<>'eventId' then request[key]=event[key]
      end
      requests[id]=request
      requestOrder~append(id)
    end
    when eventType='OWNERSHIP_CLAIMED' then do
      componentId=.McpProjectUtil~string(event['componentId'])
      if ownerships~hasIndex(componentId) then raise syntax 40.900 array('Duplicate active ownership event',componentId)
      ownership=.directory~new
      ownership['ownershipId']=event['ownershipId']
      ownership['componentId']=event['componentId']
      ownership['ownerId']=event['ownerId']
      ownership['claimedAt']=event['occurredAt']
      ownership['claimRequestId']=event['claimRequestId']
      ownership['status']='ACTIVE'
      ownerships[componentId]=ownership
    end
    when eventType='REQUEST_READ' then do
      requestId=.McpProjectUtil~string(event['requestId'])
      readerId=.McpProjectUtil~string(event['readerId'])
      key=requestId||'|'||readerId
      if \receipts~hasIndex(key) then do
        receipt=.directory~new
        receipt['receiptId']=event['receiptId']
        receipt['requestId']=event['requestId']
        receipt['readerId']=event['readerId']
        receipt['firstReadAt']=event['occurredAt']
        receipt['lastReadAt']=event['occurredAt']
        receipts[key]=receipt
      end
      else receipts[key]['lastReadAt']=event['occurredAt']
    end
    otherwise raise syntax 40.900 array('Unsupported MCP project journal event',eventType)
  end

::requires 'WireUIProtocol.cls'
::requires 'json.cls'
