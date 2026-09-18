/* Optional QueueRexx adapter for component.projection/0.1. */
::class ComponentProjectionQueueRexxBuild public
::constant VERSION "0.1-dev1"
::constant API "component.projection.queuerexx/0.1"

::class QueueRexxProjectionSource subclass ComponentProjectionSource public
::attribute store get
::attribute statusProjector get
::attribute healthScanner get
::method init
  expose store statusProjector healthScanner
  use strict arg storeArg,statusProjectorArg=.nil,healthScannerArg=.nil
  if storeArg==.nil then raise syntax 88.900 array("COMPONENT_PROJECTION_QUEUEREXX_STORE_REQUIRED")
  store=storeArg; statusProjector=statusProjectorArg; healthScanner=healthScannerArg
::method read
  expose store statusProjector healthScanner
  use strict arg keyArg
  if keyArg~isA(.Array) | keyArg~items<2 then raise syntax 88.900 array("COMPONENT_PROJECTION_QUEUEREXX_KEY_INVALID")
  scope=keyArg[1]~string
  if scope="jobs" & keyArg[2]~string="count" then return store~records~items
  if scope="health" then do
    if healthScanner==.nil then raise syntax 88.900 array("COMPONENT_PROJECTION_QUEUEREXX_HEALTH_UNAVAILABLE")
    return healthScanner~scan~asDirectory
  end
  if scope<>"job" | keyArg~items<3 then raise syntax 88.900 array("COMPONENT_PROJECTION_QUEUEREXX_KEY_INVALID")
  qid=keyArg[2]~string; field=keyArg[3]~string
  if field="status" then do
    if statusProjector==.nil then raise syntax 88.900 array("COMPONENT_PROJECTION_QUEUEREXX_STATUS_UNAVAILABLE")
    return statusProjector~project(qid)~asDirectory
  end
  matches=store~findAll(qid)
  if matches~items<>1 then raise syntax 88.900 array("COMPONENT_PROJECTION_QUEUEREXX_JOB_NOT_UNIQUE",qid,matches~items)
  record=matches[1]
  select
    when field="state" then return record~stateName
    when field="path" then return record~path
    when field="name" then return record~name
    when field="class" then return record~effectiveJobClass
    when field="priority" then return record~priority
    when field="command" then return record~commandLine
    otherwise raise syntax 88.900 array("COMPONENT_PROJECTION_QUEUEREXX_FIELD_INVALID",field)
  end

::class QueueRexxComponentProjectionAdapter public
::attribute registry get
::attribute store get
::attribute root get
::attribute componentName get
::method init
  expose registry store root componentName source knownJobs statusProjector healthScanner
  use strict arg registryArg,storeArg,statusProjectorArg=.nil,healthScannerArg=.nil,rootArg="/queuerexx",componentArg="QueueRexx"
  if registryArg==.nil | storeArg==.nil then raise syntax 88.900 array("COMPONENT_PROJECTION_QUEUEREXX_ARGUMENT_REQUIRED")
  registry=registryArg; store=storeArg; statusProjector=statusProjectorArg; healthScanner=healthScannerArg
  root=.ComponentProjectionPath~normalize(rootArg); componentName=componentArg~string
  source=.QueueRexxProjectionSource~new(store,statusProjector,healthScanner); knownJobs=.directory~new
::method install
  expose root healthScanner
  self~registerReport(root||"/jobs/count",.array~of("jobs","count"),"Number of QueueRexx-visible queue records")
  if healthScanner<>.nil then self~registerReport(root||"/health",.array~of("health","scan"),"QueueRexx health scan","application/x-oorexx-directory")
  return self~refresh
::method refresh
  expose registry store root componentName knownJobs statusProjector
  now=.directory~new; records=store~records
  do record over records
    qid=record~qid~string
    if qid="" then iterate
    now[qid]=.true
    if knownJobs[qid]<>.nil then iterate
    base=root||"/jobs/"||self~pathName(qid)
    self~registerReport(base||"/state",.array~of("job",qid,"state"),"Authoritative QueueRexx queue state")
    self~registerReport(base||"/path",.array~of("job",qid,"path"),"Queue record path")
    self~registerReport(base||"/name",.array~of("job",qid,"name"),"Job name")
    self~registerReport(base||"/class",.array~of("job",qid,"class"),"Effective job class")
    self~registerReport(base||"/priority",.array~of("job",qid,"priority"),"Job priority")
    self~registerReport(base||"/command",.array~of("job",qid,"command"),"Command line")
    if statusProjector<>.nil then self~registerReport(base||"/status",.array~of("job",qid,"status"),"QueueRexx composite status projection","application/x-oorexx-directory")
  end
  do oldQid over knownJobs
    if now[oldQid]<>.nil then iterate
    registry~unregisterTree(root||"/jobs/"||self~pathName(oldQid),componentName)
  end
  knownJobs=now
  return now~items
::method uninstall
  expose registry root componentName knownJobs
  count=registry~unregisterTree(root,componentName); knownJobs=.directory~new
  return count
::method registerReport private
  expose registry componentName source
  use strict arg pathArg,keyArg,descriptionArg,mediaTypeArg="text/plain"
  if registry~endpoint(pathArg)==.nil then registry~registerReport(componentName,pathArg,source,keyArg,mediaTypeArg,descriptionArg)
  return .true
::method pathName private
  use strict arg nameArg
  name=nameArg~string
  name=changestr("%",name,"%25")
  name=changestr("/",name,"%2F")
  return name
::requires "ComponentProjection.cls"
