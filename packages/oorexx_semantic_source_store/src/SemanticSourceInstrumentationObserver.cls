/* Observation-only bridge into instrumentation.mesh/0.1. */
::class SemanticSourceInstrumentationObserver public
::method init
  use strict arg emitter, dimensions=.nil
  if emitter == .nil then raise syntax 88.900 array("InstrumentationEmitter is required")
  self~emitter=emitter; if dimensions == .nil then dimensions=.directory~new; self~dimensions=dimensions
::attribute emitter get
::attribute emitter set private
::attribute dimensions get
::attribute dimensions set private
::method record
  use strict arg event
  if event == .nil then return .false
  eventName=event["event"]; data=event["data"]; if data == .nil then data=.directory~new
  dims=self~copyDirectory(self~dimensions); dims["service"]="semantic-source-control"; dims["instrumentation_api"]="instrumentation.mesh/0.1"
  select
    when eventName="DATABASE_QUERY_COMPLETED" then do
      path=data["path"]; if path == .nil | path="" then path="UNKNOWN"
      qd=self~copyDirectory(dims); qd["materialisation_path"]=path
      self~emitter~counterAdd("semantic_source.database.queries_total",1,"count",qd)
      self~emitter~counterAdd("semantic_source.database.rows_total",self~whole(data,"rows"),"rows",qd)
      self~emitter~gaugeSeriesSet("semantic_source.database.last_rows",self~whole(data,"rows"),"rows",qd)
      self~emitter~gaugeSeriesSet("semantic_source.database.query_seconds",self~number(data,"seconds"),"seconds",qd,.InstrumentationMetricKind~DISTRIBUTION)
      self~emitter~gaugeSet("semantic_source.database.last_materialisation_path",path,"state",dims,.InstrumentationMetricKind~STATE)
    end
    when eventName="PACKAGE_RESOURCES_MATERIALISED" then do
      self~emitter~counterAdd("semantic_source.package.resource_materialisations_total",1,"count",dims)
      self~emitter~gaugeSet("semantic_source.package.last_resources",self~whole(data,"resources"),"resources",dims)
      self~emitter~gaugeSet("semantic_source.package.last_resource_relations",self~whole(data,"relations"),"relations",dims)
    end
    when eventName="PACKAGE_MATERIALISED" then do
      self~emitter~counterAdd("semantic_source.package.materialisations_total",1,"count",dims)
      self~emitter~gaugeSet("semantic_source.package.last_files",self~whole(data,"files"),"files",dims)
      self~emitter~gaugeSet("semantic_source.package.last_source_objects",self~whole(data,"source_objects"),"objects",dims)
      self~emitter~gaugeSet("semantic_source.package.last_resources",self~whole(data,"resources"),"resources",dims)
    end
    otherwise self~emitter~counterAdd("semantic_source.instrumentation.unknown_events_total",1,"count",dims)
  end
  return .true
::method snapshot
  use strict arg observedAt=""
  return self~emitter~snapshot(observedAt)
::method instrumentationSnapshot
  use strict arg observedAt=""
  return self~snapshot(observedAt)
::method copyDirectory private
  use strict arg source
  out=.directory~new; if source == .nil then return out
  s=source~supplier; do while s~available; out[s~index]=s~item; s~next; end
  return out
::method whole private
  use strict arg data,key
  v=data[key]; if v == .nil then return 0; if datatype(v,"W") then return v; return 0
::method number private
  use strict arg data,key
  v=data[key]; if v == .nil then return 0; if datatype(v,"N") then return v; return 0
::requires "InstrumentationMesh.cls"
