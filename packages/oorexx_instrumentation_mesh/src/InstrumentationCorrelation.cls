/* InstrumentationCorrelation.cls
 * Read-only correlation of explicitly linked operational events.
 *
 * Correlation is evidence organization, not incident/change authority.  Events
 * are joined only by producer-supplied correlation_id.  Wall-clock proximity,
 * shared host, service kind or severity never creates a correlation group.
 * Optional causation_id and context_refs are carried verbatim from producers.
 *
 * API: instrumentation.correlation/0.1
 */

::class InstrumentationCorrelationBuild public
::constant VERSION "0.1-dev8"
::constant API "instrumentation.correlation/0.1"

::class InstrumentationCorrelationView public
::method init
  expose collector
  use strict arg collectorArg
  if collectorArg==.nil then raise syntax 88.900 array("instrumentation correlation view requires a collector")
  collector=collectorArg

/* Groups preserve collector acceptance order. observed_at remains source
 * evidence and is not used to infer ordering or causality. */
::method groups
  expose collector
  use strict arg selector=.nil,limit=0
  events=collector~eventsHistory(selector,limit)
  byId=.directory~new
  order=.array~new
  do event over events
    correlationId=.InstrumentationCodec~value(event,"correlation_id","")~string~strip
    if correlationId="" then iterate
    group=byId[correlationId]
    if group==.nil then do
      group=self~newGroup(correlationId)
      byId[correlationId]=group
      order~append(correlationId)
    end
    self~appendEvent(group,event)
  end
  out=.array~new
  do correlationId over order
    out~append(self~finalizeGroup(byId[correlationId]))
  end
  return out

::method byId
  use strict arg correlationId,limit=0
  wanted=correlationId~string~strip
  if wanted="" then return .nil
  selector=.directory~new; selector["correlation_id"]=wanted
  groups=self~groups(selector,limit)
  if groups~items=0 then return .nil
  return groups[1]

/* Select correlations touching any explicit semantic reference.  subject,
 * related and context references all qualify; no spatial/co-location inference
 * is performed. */
::method forRefs
  use strict arg refs,limit=0
  wanted=.directory~new
  if refs<>.nil then do ref over refs
    value=ref~string~strip
    if value<>"" then wanted[value]=.true
  end
  out=.array~new
  do group over self~groups(.nil,limit)
    if self~groupTouches(group,wanted) then out~append(group)
  end
  return out

::method forContext
  use strict arg contextRef,limit=0
  context=contextRef~string~strip
  if context="" then return .array~new
  return self~forRefs(.array~of(context),limit)

::method newGroup
  use strict arg correlationId
  d=.directory~new
  d["schema"]=.InstrumentationContract~CORRELATION_SCHEMA
  d["api"]=.InstrumentationContract~API
  d["correlation_api"]=.InstrumentationCorrelationBuild~API
  d["correlation_id"]=correlationId
  d["authority"]="READ_ONLY_CORRELATION_VIEW"
  d["basis"]="EXPLICIT_CORRELATION_ID"
  d["ordering"]="COLLECTOR_ACCEPTANCE_ORDER"
  d["events"]=.array~new
  d["subject_refs"]=.array~new
  d["related_refs"]=.array~new
  d["context_refs"]=.array~new
  d["authorities"]=.array~new
  d["kinds"]=.array~new
  d["causation_edges"]=.array~new
  d["source_event_count"]=0
  d["derived_event_count"]=0
  d["severity"]="INFO"
  d["_subjects"]=.directory~new
  d["_related"]=.directory~new
  d["_contexts"]=.directory~new
  d["_authorities"]=.directory~new
  d["_kinds"]=.directory~new
  d["_event_ids"]=.directory~new
  return d

::method appendEvent
  use strict arg group,event
  copied=.InstrumentationCodec~copyValue(event)
  events=group["events"]
  events~append(copied)
  eventId=.InstrumentationCodec~value(copied,"event_id","")
  group["_event_ids"][eventId]=.true
  if events~items=1 then do
    group["first_event_id"]=eventId
    group["first_seen_observed_at"]=.InstrumentationCodec~value(copied,"observed_at","")
  end
  group["last_event_id"]=eventId
  group["last_seen_observed_at"]=.InstrumentationCodec~value(copied,"observed_at","")

  self~appendUnique(group["subject_refs"],group["_subjects"],.InstrumentationCodec~value(copied,"subject_ref",""))
  self~appendUnique(group["authorities"],group["_authorities"],.InstrumentationCodec~value(copied,"authority",""))
  self~appendUnique(group["kinds"],group["_kinds"],.InstrumentationCodec~value(copied,"kind",""))
  related=copied["related_refs"]
  if related<>.nil then do ref over related; self~appendUnique(group["related_refs"],group["_related"],ref); end
  contexts=copied["context_refs"]
  if contexts<>.nil then do ref over contexts; self~appendUnique(group["context_refs"],group["_contexts"],ref); end

  if .InstrumentationCodec~value(copied,"derived",.false)==.true then group["derived_event_count"]+=1
  else group["source_event_count"]+=1
  severity=.InstrumentationCodec~value(copied,"severity","INFO")~string~upper
  if self~severityRank(severity)>self~severityRank(group["severity"]) then group["severity"]=severity

  cause=.InstrumentationCodec~value(copied,"causation_id","")~string~strip
  if cause<>"" then do
    edge=.directory~new
    edge["cause_id"]=cause
    edge["effect_event_id"]=eventId
    edge["declared_by_authority"]=.InstrumentationCodec~value(copied,"authority","")
    group["causation_edges"]~append(edge)
  end
  return group

::method finalizeGroup
  use strict arg group
  group["event_count"]=group["events"]~items
  eventIds=group["_event_ids"]
  do edge over group["causation_edges"]
    edge["resolved_in_retained_group"]=(eventIds[edge["cause_id"]]<>.nil)
  end
  group~remove("_subjects")
  group~remove("_related")
  group~remove("_contexts")
  group~remove("_authorities")
  group~remove("_kinds")
  group~remove("_event_ids")
  return .InstrumentationCodec~copyDirectory(group)

/* Pure read-side helpers stay message-visible for asynchronous consumers. */
::method appendUnique
  use strict arg values,seen,value
  text=value~string~strip
  if text="" then return .false
  if seen[text]<>.nil then return .false
  seen[text]=.true
  values~append(text)
  return .true

::method groupTouches
  use strict arg group,wanted
  if wanted==.nil | wanted~items=0 then return .false
  do key over .array~of("subject_refs","related_refs","context_refs")
    values=group[key]
    do value over values
      if wanted[value]<>.nil then return .true
    end
  end
  return .false

::method severityRank
  use strict arg severity
  level=severity~string~upper
  select
    when level=.InstrumentationEventSeverity~INFO then return 1
    when level=.InstrumentationEventSeverity~NOTICE then return 2
    when level=.InstrumentationEventSeverity~WARNING then return 3
    when level=.InstrumentationEventSeverity~ERROR then return 4
    when level=.InstrumentationEventSeverity~CRITICAL then return 5
    otherwise return 1
  end

::requires "InstrumentationMesh.cls"
