/* NoSQLServerInstrumentation.cls - instrumentation.mesh/0.1 adapter v0.88
 *
 * Observation only. This adapter does not grant mutation authority and does
 * not alter query, storage, transaction, or publication semantics.
 */

::class NoSQLServerInstrumentationSource public
::method init
  expose emitter dimensions
  use strict arg identity, dimensionsArg=.nil
  dimensions=.InstrumentationCodec~copyDirectory(dimensionsArg)
  emitter=.InstrumentationEmitter~new(identity)
  emitter~setHealth(.InstrumentationHealth~HEALTHY)

::method databaseEvent
  expose emitter dimensions
  use strict arg backend, eventName, data
  dims=.InstrumentationCodec~copyDirectory(dimensions)
  dims["database_family"]="nosqlserver"
  dims["implementation_id"]=.NoSQLServerBuild~ENGINE
  dims["product"]=.NoSQLServerBuild~PRODUCT
  dims["release"]=.NoSQLServerBuild~RELEASE
  dims["instrumentation_api"]="instrumentation.mesh/0.1"
  operation=data["operation"]
  if operation<>.nil then dims["operation"]=operation
  projection=data["projection"]
  if projection<>.nil then dims["projection"]=projection

  select
    when eventName="QUERY_ACCEPTED" then do
      emitter~requestAccepted
      emitter~counterAdd("database.query.accepted_total",1,"count",dims)
      sqlBytes=data["sql_bytes"]
      if sqlBytes<>.nil then emitter~bytesIn(sqlBytes)
    end
    when eventName="QUERY_COMPLETED" then do
      emitter~requestCompleted
      emitter~counterAdd("database.query.completed_total",1,"count",dims)
      self~duration("database.query.duration_seconds",data,dims)
      self~shape(data,dims)
      self~executionEvidence(data,dims)
    end
    when eventName="QUERY_FAILED" then do
      emitter~requestFailed
      emitter~counterAdd("database.query.failed_total",1,"count",dims)
      self~duration("database.query.duration_seconds",data,dims)
      self~executionEvidence(data,dims)
    end
    when eventName="MATERIALISE_COMPLETED" then do
      emitter~counterAdd("database.result.materialisations_total",1,"count",dims)
      emitter~counterAdd("database.result.rows_materialised_total",self~whole(data,"rows"),"rows",dims)
      emitter~counterAdd("database.result.values_materialised_total",self~whole(data,"values"),"values",dims)
      self~duration("database.result.materialise_seconds",data,dims)
      self~shape(data,dims)
    end
    when eventName="MATERIALISE_CACHE_HIT" then emitter~counterAdd("database.result.materialise_cache_hits_total",1,"count",dims)
    when eventName="JSON_COMPLETED" then do
      emitter~counterAdd("database.result.json_serialisations_total",1,"count",dims)
      bytes=self~whole(data,"bytes")
      emitter~counterAdd("database.result.json_bytes_total",bytes,"bytes",dims)
      emitter~bytesOut(bytes)
      self~duration("database.result.json_seconds",data,dims)
    end
    when eventName="JSON_CACHE_HIT" then emitter~counterAdd("database.result.json_cache_hits_total",1,"count",dims)
    otherwise emitter~counterAdd("database.instrumentation.unknown_events_total",1,"count",dims)
  end
  return self

::method executionEvidence private
  expose emitter
  use strict arg data, dims
  rows=data["rows"]
  scanned=data["rows_scanned"]
  affected=data["affected_rows"]
  accessPath=data["access_path"]

  if rows<>.nil then emitter~gaugeSet("database.query.rows_returned",rows,"rows",dims,.InstrumentationMetricKind~DISTRIBUTION)
  if scanned<>.nil then do
    emitter~gaugeSet("database.query.rows_scanned",scanned,"rows",dims,.InstrumentationMetricKind~DISTRIBUTION)
    emitter~gaugeSet("database.query.last_rows_scanned",scanned,"rows",dims)
    if rows<>.nil then do
      denom=rows
      if denom<1 then denom=1
      emitter~gaugeSet("database.query.scan_amplification",scanned/denom,"ratio",dims,.InstrumentationMetricKind~DISTRIBUTION)
    end
  end
  if affected<>.nil then emitter~gaugeSet("database.query.affected_rows",affected,"rows",dims,.InstrumentationMetricKind~DISTRIBUTION)
  if accessPath<>.nil then if accessPath<>"" then emitter~gaugeSet("database.query.last_access_path",accessPath,"state",dims,.InstrumentationMetricKind~STATE)
  return

::method duration private
  expose emitter
  use strict arg name, data, dims
  value=data["seconds"]
  if value==.nil then return
  emitter~gaugeSet(name,value,"seconds",dims,.InstrumentationMetricKind~DISTRIBUTION)

::method shape private
  expose emitter
  use strict arg data, dims
  rows=data["rows"]
  fields=data["fields"]
  if rows<>.nil then emitter~gaugeSet("database.result.last_rows",rows,"rows",dims)
  if fields<>.nil then emitter~gaugeSet("database.result.last_fields",fields,"fields",dims)

::method whole private
  use strict arg data, name
  value=data[name]
  if value==.nil then return 0
  if datatype(value,"W") then return value
  return 0

::method snapshot
  expose emitter
  use strict arg observedAt=""
  return emitter~snapshot(observedAt)

::requires "NoSQLServer.cls"
::requires "InstrumentationMesh.cls"
