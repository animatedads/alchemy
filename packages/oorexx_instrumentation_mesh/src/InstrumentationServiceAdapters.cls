/* InstrumentationServiceAdapters.cls
 * Thin optional adapters for service families that already expose a semantic
 * event/progress seam.  The adapters own no service authority and retain no
 * secret/user payload fields.
 *
 * API: instrumentation.mesh/0.1
 */

::class InstrumentationServiceAdapterBuild public
::constant VERSION "0.1-dev8"
::constant API "instrumentation.mesh/0.1"

::class InstrumentationEventJournal public
::method init
  expose maxItems items keys
  use strict arg maxItemsArg=128
  maxItems=maxItemsArg
  if \datatype(maxItems,"W") | maxItems<1 then maxItems=128
  items=.array~new; keys=.directory~new

::method append
  expose maxItems items keys
  use strict arg event
  key=.InstrumentationCodec~eventKey(event)
  if keys[key]<>.nil then return .false
  items~append(.InstrumentationCodec~copyValue(event))
  keys[key]=.true
  do while items~items>maxItems
    old=items[1]
    trimmed=.array~new
    do i=2 to items~items
      trimmed~append(items[i])
    end
    items=trimmed
    oldKey=.InstrumentationCodec~eventKey(old)
    if keys[oldKey]<>.nil then keys~remove(oldKey)
  end
  return .true

::method events
  expose items
  use strict arg observedAt=""
  out=.array~new
  do event over items; out~append(.InstrumentationCodec~copyValue(event)); end
  return out

/* Generic bounded source-event observer.  Incident, change, deployment,
 * acceptance and application authorities may project their own events here.
 * Explicit correlation/causation/context identifiers are retained verbatim;
 * this adapter never manufactures them from timestamps or co-location. */
::class InstrumentationEventObserver public
::method init
  expose subjectRef eventAuthority eventJournal
  use strict arg identityArg,eventAuthorityArg,maxItemsArg=128
  if identityArg==.nil then raise syntax 88.900 array("instrumentation event observer identity is required")
  subjectRef=.InstrumentationCodec~semanticRef(identityArg)
  eventAuthority=eventAuthorityArg~string~strip
  if eventAuthority="" then raise syntax 88.900 array("instrumentation event observer authority is required")
  eventJournal=.InstrumentationEventJournal~new(maxItemsArg)

::method record
  expose subjectRef eventAuthority eventJournal
  use strict arg eventId,kind,severity="INFO",observedAt="",correlationId="",causationId="",operationId="",detail="",relatedRefs=.nil,contextRefs=.nil,evidence=.nil,dimensions=.nil
  event=.InstrumentationCodec~event(eventId,kind,subjectRef,eventAuthority,observedAt,severity,correlationId,operationId,detail,relatedRefs,evidence,dimensions,.false,causationId,contextRefs)
  return eventJournal~append(event)

::method events
  expose eventJournal
  use strict arg observedAt=""
  return eventJournal~events(observedAt)

/* Generic progress facade for deployment tools and finite service operations.
 * The deployment/service authority calls these methods at the point where it
 * already knows the operation state.  Instrumentation only projects it. */
::class InstrumentationOperationObserver public
::method init
  expose emitter eventJournal subjectRef eventAuthority
  use strict arg identityArg,eventAuthorityArg="SERVICE_OPERATION_OBSERVER"
  if identityArg==.nil then raise syntax 88.900 array("instrumentation operation identity is required")
  emitter=.InstrumentationEmitter~new(identityArg)
  emitter~setHealth(.InstrumentationHealth~STARTING)
  subjectRef=.InstrumentationCodec~semanticRef(identityArg)
  eventAuthority=eventAuthorityArg~string~strip
  if eventAuthority="" then eventAuthority="SERVICE_OPERATION_OBSERVER"
  eventJournal=.InstrumentationEventJournal~new

::method ready
  expose emitter
  emitter~setHealth(.InstrumentationHealth~HEALTHY)
  return self

::method degraded
  expose emitter
  emitter~setHealth(.InstrumentationHealth~DEGRADED)
  return self

::method stopping
  expose emitter
  emitter~setHealth(.InstrumentationHealth~STOPPING)
  return self

::method stopped
  expose emitter
  emitter~setHealth(.InstrumentationHealth~STOPPED)
  return self

::method started
  expose emitter eventJournal subjectRef eventAuthority
  use strict arg operationId,phase="RUNNING",total=0,unit="items",detail="",observedAt="",correlationId="",causationId="",contextRefs=.nil
  emitter~counterAdd(.InstrumentationVocabulary~OPERATION_STARTED_TOTAL,1,"operations")
  emitter~progress(operationId,phase,0,total,unit,observedAt,detail)
  evidence=.directory~new; evidence["phase"]=phase; evidence["current"]=0; evidence["total"]=total; evidence["unit"]=unit
  eventJournal~append(.InstrumentationCodec~event("operation:"||operationId||":STARTED","OPERATION_STARTED",subjectRef,eventAuthority,observedAt,.InstrumentationEventSeverity~INFO,correlationId,operationId,detail,.array~new,evidence,.nil,.false,causationId,contextRefs))
  return self

::method advanced
  expose emitter
  use strict arg operationId,phase,current,total,unit="items",detail="",observedAt=""
  emitter~progress(operationId,phase,current,total,unit,observedAt,detail)
  return self

::method completed
  expose emitter eventJournal subjectRef eventAuthority
  use strict arg operationId,current=1,total=1,unit="items",detail="",observedAt="",correlationId="",causationId="",contextRefs=.nil
  emitter~counterAdd(.InstrumentationVocabulary~OPERATION_COMPLETED_TOTAL,1,"operations")
  emitter~progress(operationId,"COMPLETED",current,total,unit,observedAt,detail)
  evidence=.directory~new; evidence["phase"]="COMPLETED"; evidence["current"]=current; evidence["total"]=total; evidence["unit"]=unit
  eventJournal~append(.InstrumentationCodec~event("operation:"||operationId||":COMPLETED","OPERATION_COMPLETED",subjectRef,eventAuthority,observedAt,.InstrumentationEventSeverity~INFO,correlationId,operationId,detail,.array~new,evidence,.nil,.false,causationId,contextRefs))
  return self

::method failed
  expose emitter eventJournal subjectRef eventAuthority
  use strict arg operationId,current=0,total=0,unit="items",detail="",observedAt="",correlationId="",causationId="",contextRefs=.nil
  emitter~counterAdd(.InstrumentationVocabulary~OPERATION_FAILED_TOTAL,1,"operations")
  emitter~progress(operationId,"FAILED",current,total,unit,observedAt,detail)
  evidence=.directory~new; evidence["phase"]="FAILED"; evidence["current"]=current; evidence["total"]=total; evidence["unit"]=unit
  eventJournal~append(.InstrumentationCodec~event("operation:"||operationId||":FAILED","OPERATION_FAILED",subjectRef,eventAuthority,observedAt,.InstrumentationEventSeverity~ERROR,correlationId,operationId,detail,.array~new,evidence,.nil,.false,causationId,contextRefs))
  return self

::method cancelled
  expose emitter eventJournal subjectRef eventAuthority
  use strict arg operationId,current=0,total=0,unit="items",detail="",observedAt="",correlationId="",causationId="",contextRefs=.nil
  emitter~counterAdd(.InstrumentationVocabulary~OPERATION_CANCELLED_TOTAL,1,"operations")
  emitter~progress(operationId,"CANCELLED",current,total,unit,observedAt,detail)
  evidence=.directory~new; evidence["phase"]="CANCELLED"; evidence["current"]=current; evidence["total"]=total; evidence["unit"]=unit
  eventJournal~append(.InstrumentationCodec~event("operation:"||operationId||":CANCELLED","OPERATION_CANCELLED",subjectRef,eventAuthority,observedAt,.InstrumentationEventSeverity~NOTICE,correlationId,operationId,detail,.array~new,evidence,.nil,.false,causationId,contextRefs))
  return self

::method retire
  expose emitter
  use strict arg operationId
  emitter~clearProgress(operationId)
  return self

::method snapshot
  expose emitter
  use strict arg observedAt=""
  return emitter~snapshot(observedAt)

::method events
  expose eventJournal
  use strict arg observedAt=""
  return eventJournal~events(observedAt)

/* SMTP dev9 already has smtp.event/0.1 as a service-owned semantic event seam.
 * This sink converts only bounded operational facts. It deliberately excludes
 * remoteAddress, principalId, mailFrom, signature identity/certificate data,
 * content and all other message payload fields. */
::class SmtpInstrumentationEventSink public
::method init
  expose emitter
  use strict arg identityArg
  if identityArg==.nil then raise syntax 88.900 array("SMTP instrumentation identity is required")
  emitter=.InstrumentationEmitter~new(identityArg)
  emitter~setHealth(.InstrumentationHealth~STARTING)

::method ready
  expose emitter
  emitter~setHealth(.InstrumentationHealth~HEALTHY)
  return self

::method degraded
  expose emitter
  emitter~setHealth(.InstrumentationHealth~DEGRADED)
  return self

::method stopping
  expose emitter
  emitter~setHealth(.InstrumentationHealth~STOPPING)
  return self

::method stopped
  expose emitter
  emitter~setHealth(.InstrumentationHealth~STOPPED)
  return self

::method emit
  expose emitter
  use strict arg event
  if event==.nil then return .false
  if \event~isA(.Directory) then return .false
  if .InstrumentationCodec~value(event,"schema","")<>"smtp.event/0.1" then return .false

  kind=.InstrumentationCodec~value(event,"kind","")~string~lower
  if kind="" then return .false
  bytes=.InstrumentationCodec~whole(event,"bytes",0)
  recipients=.InstrumentationCodec~whole(event,"recipientCount",0)
  if bytes<0 then bytes=0
  if recipients<0 then recipients=0

  emitter~counterAdd("smtp.events.total",1,"events")
  if recipients>0 then emitter~counterAdd("smtp.recipients.total",recipients,"recipients")

  if left(kind,8)="ingress." then do
    emitter~counterAdd("smtp.ingress.events.total",1,"events")
    if bytes>0 then do
      emitter~counterAdd("smtp.ingress.bytes.total",bytes,"bytes")
      emitter~bytesIn(bytes)
    end
    if left(kind,17)="ingress.accepted." then emitter~counterAdd("smtp.ingress.accepted.total",1,"messages")
    else if kind="ingress.denied" then emitter~counterAdd("smtp.ingress.denied.total",1,"messages")
  end
  else if left(kind,7)="egress." then do
    emitter~counterAdd("smtp.egress.events.total",1,"events")
    if kind="egress.spooled" then do
      emitter~counterAdd("smtp.egress.spooled.total",1,"messages")
      if bytes>0 then emitter~counterAdd("smtp.egress.bytes_spooled.total",bytes,"bytes")
    end
    else if kind="egress.failed" then emitter~counterAdd("smtp.egress.failed.total",1,"messages")
    else if kind="egress.denied" then emitter~counterAdd("smtp.egress.denied.total",1,"messages")
  end

  if .InstrumentationCodec~value(event,"tlsActive",.false)==.true then emitter~counterAdd("smtp.events.tls.total",1,"events")
  if .InstrumentationCodec~value(event,"authenticated",.false)==.true then emitter~counterAdd("smtp.events.authenticated.total",1,"events")
  return .true

::method snapshot
  expose emitter
  use strict arg observedAt=""
  return emitter~snapshot(observedAt)

::requires "InstrumentationMesh.cls"
