/* Optional NoSQLServer renderer for component.projection/0.1.
 *
 * The registry remains canonical. This renderer creates read-only object-table
 * snapshots. It does not make NoSQLServer a dependency of Component Projection
 * core and does not provide a mutation path around endpoint authority.
 */
::class ComponentProjectionNoSQLBuild public
::constant VERSION "0.1-dev2"
::constant API "component.projection.nosql/0.1"

::class ComponentProjectionNoSQLEndpointRow public
::attribute component get
::attribute path get
::attribute kind get
::attribute readable get
::attribute writable get
::attribute mediaType get
::attribute description get
::attribute maxWriteBytes get
::method init
  expose component path kind readable writable mediaType description maxWriteBytes
  use strict arg endpoint
  component=endpoint~component; path=endpoint~path; kind=endpoint~kind
  if endpoint~readable then readable=1; else readable=0
  if endpoint~writable then writable=1; else writable=0
  mediaType=endpoint~mediaType; description=endpoint~description; maxWriteBytes=endpoint~maxWriteBytes

::class ComponentProjectionNoSQLValueRow public
::attribute component get
::attribute path get
::attribute kind get
::attribute mediaType get
::attribute valueClass get
::attribute valueObject get
::attribute valueText get
::method init
  expose component path kind mediaType valueClass valueObject valueText
  use strict arg endpoint,valueArg
  component=endpoint~component; path=endpoint~path; kind=endpoint~kind; mediaType=endpoint~mediaType
  valueObject=valueArg
  if valueArg==.nil then do; valueClass="NIL"; valueText=""; end
  else do
    valueClass=valueArg~class~id
    valueText=.ComponentProjectionText~render(valueArg)
    /* NoSQL text is a value, not a Unix file record: remove the renderer's
     * final line terminator while preserving embedded newlines. */
    if valueText~length>0 then do
      if valueText~right(1)==d2c(10) then valueText=valueText~left(valueText~length-1)
    end
  end

::class ComponentProjectionNoSQLAdapter public
::attribute registry get
::attribute prefix get
::method init
  expose registry prefix
  use strict arg registryArg,prefixArg="component_"
  if registryArg==.nil then raise syntax 88.900 array("COMPONENT_PROJECTION_NOSQL_REGISTRY_REQUIRED")
  registry=registryArg; prefix=prefixArg~string

::method rows private
  expose registry
  endpointRows=.array~new; valueRows=.array~new
  paths=registry~paths
  do p over paths
    ep=registry~endpoint(p)
    if ep==.nil then iterate
    endpointRows~append(.ComponentProjectionNoSQLEndpointRow~new(ep))
    if ep~readable then valueRows~append(.ComponentProjectionNoSQLValueRow~new(ep,ep~readObject))
  end
  return .array~of(endpointRows,valueRows)

::method endpointMapping private
  expose prefix
  m=.ObjectTableMapping~new(prefix||"endpoints")
  ignore=m~column("path","VARCHAR","path"); ignore=m~column("component","VARCHAR","component")
  ignore=m~column("kind","VARCHAR","kind"); ignore=m~column("readable","INTEGER","readable")
  ignore=m~column("writable","INTEGER","writable"); ignore=m~column("media_type","VARCHAR","mediaType")
  ignore=m~column("description","VARCHAR","description"); ignore=m~column("max_write_bytes","INTEGER","maxWriteBytes")
  ignore=m~identity("path")
  return m

::method valueMapping private
  expose prefix
  vm=.ObjectTableMapping~new(prefix||"values")
  ignore=vm~column("path","VARCHAR","path"); ignore=vm~column("component","VARCHAR","component")
  ignore=vm~column("kind","VARCHAR","kind"); ignore=vm~column("media_type","VARCHAR","mediaType")
  ignore=vm~column("value_class","VARCHAR","valueClass"); ignore=vm~column("value_text","VARCHAR","valueText")
  ignore=vm~identity("path")
  return vm

::method buildEngine
  expose prefix
  rows=self~rows; endpointRows=rows[1]; valueRows=rows[2]
  engine=.ObjectDatabaseEngine~new
  ignore=engine~registerSnapshot(prefix||"endpoints",endpointRows,self~endpointMapping)
  ignore=engine~registerSnapshot(prefix||"values",valueRows,self~valueMapping)
  return engine

::method query
  use strict arg sqlText
  return .NoSQLServerSQL~new(self~buildEngine)~execute(sqlText)

::method snapshotInto
  expose prefix
  use strict arg federatedEngine
  rows=self~rows
  if \federatedEngine~registerSnapshot(prefix||"endpoints",rows[1],self~endpointMapping) then return .false
  if \federatedEngine~registerSnapshot(prefix||"values",rows[2],self~valueMapping) then return .false
  return .true

::requires "ComponentProjection.cls"
::requires "NoSQLServer.cls"
