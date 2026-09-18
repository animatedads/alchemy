/* Optional Inspector Clouseau live-state adapter for component.projection/0.1.
 *
 * This adapter reports the Inspector itself: configured rules, current
 * counters/evidence arrays and operational state already resident in the
 * Inspector.  It deliberately does NOT call snapshot(), refreshObservation(),
 * walkObjectUniverse(), writeTimestampedSnapshot(), or any trace-request scan.
 * Process/object-tree publication is a separate capability.
 */
::class ComponentProjectionInspectorClouseauBuild public
::constant VERSION "0.1-dev2"
::constant API "component.projection.inspector-clouseau/0.1"

::class InspectorClouseauComponentProjectionSource subclass ComponentProjectionSource public
::method init
  expose inspector
  use strict arg inspectorArg
  if inspectorArg==.nil then raise syntax 88.900 array("COMPONENT_PROJECTION_INSPECTOR_REQUIRED")
  inspector=inspectorArg

::method current private
  expose inspector
  /* asDirectory is intentionally passive: it returns resident Inspector state. */
  return inspector~asDirectory

::method itemAt private
  use strict arg collection,indexArg
  if collection==.nil then return .nil
  n=indexArg+0
  if n<1 | n>collection~items then return .nil
  return collection[n]

::method countOf private
  use strict arg d,name
  v=d~at(name)
  if v==.nil then return 0
  return v~items

::method fieldOf private
  use strict arg rec,name
  if rec==.nil then return .nil
  if rec~hasIndex(name) then return rec~at(name)
  return .nil

::method read
  use strict arg keyArg
  if keyArg~isA(.Array) | keyArg~items<1 then raise syntax 88.900 array("COMPONENT_PROJECTION_INSPECTOR_KEY_INVALID")
  d=self~current
  scope=keyArg[1]~string
  if scope="top" then do
    field=keyArg[2]~string
    if d~hasIndex(field) then return d~at(field)
    raise syntax 88.900 array("COMPONENT_PROJECTION_INSPECTOR_FIELD_INVALID",field)
  end
  if scope="count" then return self~countOf(d,keyArg[2]~string)
  if scope="rule" then do
    rec=self~itemAt(d~at("rules"),keyArg[2])
    if keyArg~items=2 then return rec
    return self~fieldOf(rec,keyArg[3]~string)
  end
  if scope="finding" then do
    rec=self~itemAt(d~at("findings"),keyArg[2]); if keyArg~items=2 then return rec; return self~fieldOf(rec,keyArg[3]~string)
  end
  if scope="warning" then return self~itemAt(d~at("warnings"),keyArg[2])
  if scope="trigger" then do
    rec=self~itemAt(d~at("trigger_events"),keyArg[2]); if keyArg~items=2 then return rec; return self~fieldOf(rec,keyArg[3]~string)
  end
  if scope="security" then return self~itemAt(d~at("security_events"),keyArg[2])
  if scope="trace_report" then return self~itemAt(d~at("trace_reports"),keyArg[2])
  if scope="trace_request" then return self~itemAt(d~at("trace_request_events"),keyArg[2])
  if scope="scheduled_snapshot" then return self~itemAt(d~at("scheduled_snapshot_events"),keyArg[2])
  raise syntax 88.900 array("COMPONENT_PROJECTION_INSPECTOR_KEY_INVALID",scope)

::class InspectorClouseauComponentProjectionAdapter public
::method init
  expose registry inspector root componentName source installedShape
  use strict arg registryArg,inspectorArg,rootArg="/inspector",componentArg="InspectorClouseau"
  if registryArg==.nil | inspectorArg==.nil then raise syntax 88.900 array("COMPONENT_PROJECTION_INSPECTOR_ARGUMENT_REQUIRED")
  registry=registryArg; inspector=inspectorArg; root=.ComponentProjectionPath~normalize(rootArg); componentName=componentArg~string
  source=.InspectorClouseauComponentProjectionSource~new(inspector); installedShape=.directory~new

::method install
  expose root
  self~report(root||"/schema",.array~of("top","schema"),"Inspector snapshot schema identifier")
  self~report(root||"/generated_at",.array~of("top","generated_at"),"Time of the current passive Inspector view")
  self~report(root||"/rules/count",.array~of("count","rules"),"Configured Inspector rule count")
  self~report(root||"/findings/count",.array~of("count","findings"),"Current finding count")
  self~report(root||"/warnings/count",.array~of("count","warnings"),"Current warning count")
  self~report(root||"/triggers/count",.array~of("count","trigger_events"),"Recorded trigger event count")
  self~report(root||"/security_events/count",.array~of("count","security_events"),"Recorded security event count")
  self~report(root||"/trace_reports/count",.array~of("count","trace_reports"),"Recorded trace report count")
  self~report(root||"/trace_requests/count",.array~of("count","trace_request_events"),"Recorded trace-request event count")
  self~report(root||"/scheduled_snapshots/count",.array~of("count","scheduled_snapshot_events"),"Scheduled snapshot event count")
  self~report(root||"/state/roots",.array~of("count","roots"),"Attached Inspector root count")
  self~report(root||"/state/packages",.array~of("count","packages"),"Observed package record count")
  self~report(root||"/state/objects",.array~of("count","objects"),"Currently resident observed object record count")
  self~report(root||"/state/edges",.array~of("count","edges"),"Currently resident observed edge count")
  self~report(root||"/state/queues",.array~of("count","queues"),"Currently resident queue observation count")
  self~report(root||"/state/classes",.array~of("count","classes"),"Currently resident class record count")
  self~report(root||"/state/methods",.array~of("count","methods"),"Currently resident method record count")
  return self~refresh

::method refresh
  expose registry inspector root componentName installedShape
  d=inspector~asDirectory
  /* Only dynamic namespace shape changes here. Reading values remains live. */
  self~syncIndexed("rules",d~at("rules"),"rule")
  self~syncIndexed("findings",d~at("findings"),"finding")
  self~syncIndexed("warnings",d~at("warnings"),"warning")
  self~syncIndexed("triggers",d~at("trigger_events"),"trigger")
  self~syncIndexed("security_events",d~at("security_events"),"security")
  self~syncIndexed("trace_reports",d~at("trace_reports"),"trace_report")
  self~syncIndexed("trace_requests",d~at("trace_request_events"),"trace_request")
  self~syncIndexed("scheduled_snapshots",d~at("scheduled_snapshot_events"),"scheduled_snapshot")
  return .true

::method syncIndexed private
  expose registry root componentName installedShape
  use strict arg branch,collection,scope
  count=0; if collection<>.nil then count=collection~items
  old=installedShape[branch]; if old==.nil then old=0
  if count<old then do i=count+1 to old; ignore=registry~unregisterTree(root||"/"||branch||"/"||i,componentName); end
  if count>old then do i=old+1 to count
    p=root||"/"||branch||"/"||i
    self~report(p||"/record",.array~of(scope,i),"Inspector "||scope||" record","application/x-oorexx-object")
    if scope="rule" then do
      self~syncRuleFields(p,i,collection[i])
    end
    else if scope="trigger" then do
      self~report(p||"/sequence",.array~of(scope,i,"sequence"),"Trigger sequence")
      self~report(p||"/trigger_key",.array~of(scope,i,"trigger_key"),"Trigger key")
      self~report(p||"/trigger_kind",.array~of(scope,i,"trigger_kind"),"Trigger kind")
      self~report(p||"/generated_at",.array~of(scope,i,"generated_at"),"Trigger time")
    end
  end
  if scope="rule" then do i=1 to count
    self~syncRuleFields(root||"/"||branch||"/"||i,i,collection[i])
  end
  installedShape[branch]=count

::method syncRuleFields private
  expose registry componentName source
  use strict arg pathArg,indexArg,record
  if record==.nil then return .true
  if (record~isA(.Directory)) then return .true
  supplier=record~supplier
  do while supplier~available
    field=supplier~index
    value=supplier~item
    name=field~string
    seg=self~escapeSegment(name)
    media="text/plain"
    if value<>.nil then do
      if value~class~id<>"STRING" then media="application/x-oorexx-object"
    end
    epPath=pathArg||"/"||seg
    if registry~endpoint(epPath)==.nil then registry~registerReport(componentName,epPath,source,.array~of("rule",indexArg,name),media,"Inspector rule field "||name)
    supplier~next
  end
  return .true

::method escapeSegment private
  use strict arg valueArg
  s=valueArg~string
  s=s~changeStr("%","%25")
  s=s~changeStr("/","%2F")
  if s="." then s="%2E"
  if s=".." then s="%2E%2E"
  return s

::method uninstall
  expose registry root componentName installedShape
  n=registry~unregisterTree(root,componentName); installedShape=.directory~new; return n

::method report private
  expose registry componentName source
  use strict arg pathArg,keyArg,descriptionArg,mediaTypeArg="text/plain"
  if registry~endpoint(pathArg)==.nil then registry~registerReport(componentName,pathArg,source,keyArg,mediaTypeArg,descriptionArg)
  return .true

::requires "ComponentProjection.cls"
