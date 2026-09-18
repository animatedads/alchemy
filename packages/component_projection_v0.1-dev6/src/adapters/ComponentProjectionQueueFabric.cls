/* Optional Queue Fabric adapter for component.projection/0.1. */
::class ComponentProjectionQueueFabricBuild public
::constant VERSION "0.1-dev1"
::constant API "component.projection.queue-fabric/0.1"

::class QueueFabricProjectionSource subclass ComponentProjectionSource public
::attribute manager get
::attribute principal get
::method init
  expose manager principal
  use strict arg managerArg, principalArg=""
  if managerArg==.nil then raise syntax 88.900 array("COMPONENT_PROJECTION_QUEUE_FABRIC_MANAGER_REQUIRED")
  manager=managerArg; principal=principalArg~string
::method read
  expose manager principal
  use strict arg keyArg
  if keyArg~isA(.Array) | keyArg~items<2 then raise syntax 88.900 array("COMPONENT_PROJECTION_QUEUE_FABRIC_KEY_INVALID")
  scope=keyArg[1]~string
  if scope="manager" then do
    field=keyArg[2]~string
    select
      when field="queue_count" then return manager~queues~items
      when field="active_uow_count" then return manager~activeUnitOfWorkCount
      when field="transfer_receipt_count" then return manager~transferReceiptCount
      otherwise raise syntax 88.900 array("COMPONENT_PROJECTION_QUEUE_FABRIC_FIELD_INVALID",field)
    end
  end
  if scope<>"queue" | keyArg~items<3 then raise syntax 88.900 array("COMPONENT_PROJECTION_QUEUE_FABRIC_KEY_INVALID")
  queueName=keyArg[2]~string; field=keyArg[3]~string
  q=manager~queue(queueName)
  if q==.nil then raise syntax 88.900 array("COMPONENT_PROJECTION_QUEUE_FABRIC_QUEUE_GONE",queueName)
  select
    when field="state" then return q~state
    when field="lifecycle" then return q~lifecycle
    when field="security_domain" then return q~securityDomain
    when field="max_depth" then return q~maxDepth
    when field="owner" then return q~owner
    when field="created_at" then return q~createdAt
    when field="backout_threshold" then return q~backoutThreshold
    when field="backout_queue" then return q~backoutQueue
    when field="expiring_depth" then return q~expiringDepth
    when field="earliest_expiry_tick" then return q~earliestExpiryTick
    when field="depth" then do
      result=manager~depth(queueName,principal)
      if esult~ok then raise syntax 88.900 array("COMPONENT_PROJECTION_QUEUE_FABRIC_READ_DENIED",result~code,result~detail)
      return result~value
    end
    otherwise raise syntax 88.900 array("COMPONENT_PROJECTION_QUEUE_FABRIC_FIELD_INVALID",field)
  end
::method write
  expose manager principal
  use strict arg keyArg, valueArg
  if keyArg~isA(.Array) | keyArg~items<3 then raise syntax 88.900 array("COMPONENT_PROJECTION_QUEUE_FABRIC_CONTROL_INVALID")
  if keyArg[1]~string<>"queue" | keyArg[3]~string<>"inject" then raise syntax 88.900 array("COMPONENT_PROJECTION_QUEUE_FABRIC_CONTROL_INVALID")
  result=manager~put(keyArg[2]~string,valueArg,.nil,principal)
  return result~ok

::class QueueFabricComponentProjectionAdapter public
::attribute registry get
::attribute manager get
::attribute principal get
::attribute root get
::attribute componentName get
::method init
  expose registry manager principal root componentName source knownQueues
  use strict arg registryArg, managerArg, principalArg="", rootArg="/queuefabric", componentArg="QueueFabric"
  if registryArg==.nil | managerArg==.nil then raise syntax 88.900 array("COMPONENT_PROJECTION_QUEUE_FABRIC_ARGUMENT_REQUIRED")
  registry=registryArg; manager=managerArg; principal=principalArg~string
  root=.ComponentProjectionPath~normalize(rootArg); componentName=componentArg~string
  source=.QueueFabricProjectionSource~new(manager,principal); knownQueues=.directory~new
::method install
  expose root
  self~registerReport(root||"/queue_count",.array~of("manager","queue_count"),"Number of currently defined local queues")
  self~registerReport(root||"/active_uow_count",.array~of("manager","active_uow_count"),"Active local units of work")
  self~registerReport(root||"/transfer_receipt_count",.array~of("manager","transfer_receipt_count"),"Recorded transfer receipts")
  return self~refresh
::method refresh
  expose registry manager root componentName knownQueues
  now=.directory~new; queues=manager~queues
  do q over queues
    name=q~name~string; now[name]=.true
    if knownQueues[name]<>.nil then iterate
    base=root||"/queues/"||self~pathName(name)
    self~registerReport(base||"/state",.array~of("queue",name,"state"),"Queue state")
    self~registerReport(base||"/lifecycle",.array~of("queue",name,"lifecycle"),"Queue lifecycle")
    self~registerReport(base||"/security_domain",.array~of("queue",name,"security_domain"),"Queue security domain")
    self~registerReport(base||"/max_depth",.array~of("queue",name,"max_depth"),"Configured maximum depth")
    self~registerReport(base||"/owner",.array~of("queue",name,"owner"),"Queue owner")
    self~registerReport(base||"/created_at",.array~of("queue",name,"created_at"),"Queue creation timestamp")
    self~registerReport(base||"/depth",.array~of("queue",name,"depth"),"Authorised ready/inflight/total queue depth","application/x-oorexx-directory")
    self~registerReport(base||"/backout_threshold",.array~of("queue",name,"backout_threshold"),"Backout threshold")
    self~registerReport(base||"/backout_queue",.array~of("queue",name,"backout_queue"),"Backout queue")
    self~registerControl(base||"/inject",.array~of("queue",name,"inject"),"Put one text payload through Queue Fabric normal PUT authority seam",65536)
  end
  do oldName over knownQueues
    if now[oldName]<>.nil then iterate
    registry~unregisterTree(root||"/queues/"||self~pathName(oldName),componentName)
  end
  knownQueues=now
  return queues~items
::method uninstall
  expose registry root componentName knownQueues
  count=registry~unregisterTree(root,componentName); knownQueues=.directory~new
  return count
::method registerReport private
  expose registry componentName source
  use strict arg pathArg,keyArg,descriptionArg,mediaTypeArg="text/plain"
  if registry~endpoint(pathArg)==.nil then registry~registerReport(componentName,pathArg,source,keyArg,mediaTypeArg,descriptionArg)
  return .true
::method registerControl private
  expose registry componentName source
  use strict arg pathArg,keyArg,descriptionArg,maxBytesArg=65536
  if registry~endpoint(pathArg)==.nil then registry~registerControl(componentName,pathArg,source,keyArg,"text/plain",descriptionArg,.false,maxBytesArg)
  return .true
::method pathName private
  use strict arg nameArg
  name=nameArg~string
  name=changestr("%",name,"%25")
  name=changestr("/",name,"%2F")
  return name
::requires "ComponentProjection.cls"
