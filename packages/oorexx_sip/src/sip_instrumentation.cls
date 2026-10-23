/* SIP -> Instrumentation Mesh adapter.
 * Alchemy Log remains the forensic event authority. This adapter projects
 * SIP-owned operational facts only; shared RTP has its own adapter. */
::class SipInstrumentationVocabulary public
::constant SIP_RX_MESSAGES_TOTAL "sip.messages.rx.total"
::constant SIP_TX_MESSAGES_TOTAL "sip.messages.tx.total"
::constant SIP_WIRE_ERRORS_TOTAL "sip.wire.errors.total"
::constant SIP_AUTH_CHALLENGES_TOTAL "sip.auth.challenges.total"
::constant SIP_AUTH_ACCEPTED_TOTAL "sip.auth.accepted.total"
::constant SIP_AUTH_REJECTED_TOTAL "sip.auth.rejected.total"
::constant SIP_REGISTRATIONS_ACTIVE "sip.registrations.active"
::constant SIP_REGISTRATIONS_BOUND_TOTAL "sip.registrations.bound.total"
::constant SIP_REGISTRATIONS_REFRESHED_TOTAL "sip.registrations.refreshed.total"
::constant SIP_REGISTRATIONS_EXPIRED_TOTAL "sip.registrations.expired.total"
::constant SIP_CALLS_ACTIVE "sip.calls.active"
::constant SIP_CALLS_CREATED_TOTAL "sip.calls.created.total"
::constant SIP_CALLS_REMOVED_TOTAL "sip.calls.removed.total"
::constant SIP_CLIENT_CALLS_CREATED_TOTAL "sip.client.calls.created.total"
::constant SIP_CLIENT_DIALOGS_TERMINATED_TOTAL "sip.client.dialogs.terminated.total"
::constant SIP_CLIENT_INVITE_FAILURES_TOTAL "sip.client.invite.failures.total"

::class SipEventFanoutSink public
::method init
  expose sinks errors
  sinks=.array~new
  errors=.directory~new
::method add
  expose sinks
  use strict arg sink
  if sink==.nil then return self
  sinks~append(sink)
  return self
::method recordEvent
  expose sinks
  use strict arg event
  index=0
  do sink over sinks
    index+=1
    self~deliver(sink,event,index)
  end
  return event
::method deliver
  expose errors
  use strict arg sink,event,index
  signal on syntax name sinkFailed
  sink~recordEvent(event)
  signal off syntax
  return .true
sinkFailed:
  say 'SIP observer failure rc=' rc 'sigl=' sigl 'condition=' condition('C') 'description=' condition('D')
  errors[index]=condition('O')
  signal off syntax
  return .false
::method error
  expose errors
  use strict arg index
  return errors[index]
::method sinkCount
  expose sinks
  return sinks~items

::class SipInstrumentationSink public
::method init
  expose emitter registrationsActive callsActive eventJournal subjectRef authority
  use strict arg identity, authorityArg="SIP_SERVICE"
  emitter=.InstrumentationEmitter~new(identity)
  subjectRef=.InstrumentationCodec~semanticRef(identity)
  authority=authorityArg~string~strip
  if authority="" then authority="SIP_SERVICE"
  eventJournal=.InstrumentationEventJournal~new(256)
  emitter~setHealth(.InstrumentationHealth~STARTING)
  registrationsActive=0; callsActive=0
  self~publishGauges
::method emitter
  expose emitter
  return emitter
::method snapshot
  expose emitter
  use strict arg observedAt=""
  return emitter~snapshot(observedAt)
::method recordEvent
  expose emitter registrationsActive callsActive eventJournal subjectRef authority
  use strict arg event
  if \event~isA(.Directory) then return .nil
  eventType=self~value(event,"eventType","")
  select
    when eventType="SIP.SERVER.STARTED" then do
      emitter~setHealth(.InstrumentationHealth~HEALTHY)
      emitter~gaugeSet(.InstrumentationVocabulary~SERVICE_STATE,"RUNNING","state",.nil,.InstrumentationMetricKind~STATE)
    end
    when eventType="SIP.SERVER.STOPPED" then do
      emitter~setHealth(.InstrumentationHealth~STOPPED)
      emitter~gaugeSet(.InstrumentationVocabulary~SERVICE_STATE,"STOPPED","state",.nil,.InstrumentationMetricKind~STATE)
    end
    when eventType="SIP.WIRE.RX" then do
      emitter~counterAdd(.SipInstrumentationVocabulary~SIP_RX_MESSAGES_TOTAL,1)
      bytes=self~whole(event,"bytes",0); if bytes>0 then emitter~bytesIn(bytes)
    end
    when eventType="SIP.WIRE.TX" then do
      emitter~counterAdd(.SipInstrumentationVocabulary~SIP_TX_MESSAGES_TOTAL,1)
      bytes=self~whole(event,"bytes",0); if bytes>0 then emitter~bytesOut(bytes)
    end
    when eventType="SIP.WIRE.ERROR" then emitter~counterAdd(.SipInstrumentationVocabulary~SIP_WIRE_ERRORS_TOTAL,1)
    when eventType="SIP.AUTH.CHALLENGE" then emitter~counterAdd(.SipInstrumentationVocabulary~SIP_AUTH_CHALLENGES_TOTAL,1)
    when eventType="SIP.AUTH.ACCEPTED" then emitter~counterAdd(.SipInstrumentationVocabulary~SIP_AUTH_ACCEPTED_TOTAL,1)
    when eventType="SIP.AUTH.REJECTED" then emitter~counterAdd(.SipInstrumentationVocabulary~SIP_AUTH_REJECTED_TOTAL,1)
    when eventType="SIP.REGISTRATION.BOUND" then do
      registrationsActive+=1
      emitter~counterAdd(.SipInstrumentationVocabulary~SIP_REGISTRATIONS_BOUND_TOTAL,1)
    end
    when eventType="SIP.REGISTRATION.REFRESHED" then emitter~counterAdd(.SipInstrumentationVocabulary~SIP_REGISTRATIONS_REFRESHED_TOTAL,1)
    when eventType="SIP.REGISTRATION.REMOVED" | eventType="SIP.REGISTRATION.EXPIRED" then do
      registrationsActive-=1; if registrationsActive<0 then registrationsActive=0
      if eventType="SIP.REGISTRATION.EXPIRED" then emitter~counterAdd(.SipInstrumentationVocabulary~SIP_REGISTRATIONS_EXPIRED_TOTAL,1)
    end
    when eventType="SIP.CALL.CREATED" then do
      callsActive+=1
      emitter~counterAdd(.SipInstrumentationVocabulary~SIP_CALLS_CREATED_TOTAL,1)
    end
    when eventType="SIP.CALL.REMOVED" then do
      callsActive-=1; if callsActive<0 then callsActive=0
      emitter~counterAdd(.SipInstrumentationVocabulary~SIP_CALLS_REMOVED_TOTAL,1)
    end
    when eventType="SIP.CLIENT.CALL.CREATED" then emitter~counterAdd(.SipInstrumentationVocabulary~SIP_CLIENT_CALLS_CREATED_TOTAL,1)
    when eventType="SIP.CLIENT.DIALOG.TERMINATED" then emitter~counterAdd(.SipInstrumentationVocabulary~SIP_CLIENT_DIALOGS_TERMINATED_TOTAL,1)
    when eventType="SIP.CLIENT.INVITE.RESPONSE" then do
      status=self~whole(event,"status",0)
      if status>=300 then emitter~counterAdd(.SipInstrumentationVocabulary~SIP_CLIENT_INVITE_FAILURES_TOTAL,1)
    end
    otherwise nop
  end
  instrumentationEvent=self~operationalEvent(event,eventType,subjectRef,authority)
  if instrumentationEvent<>.nil then eventJournal~append(instrumentationEvent)
  self~publishGauges
  return event
::method events
  expose eventJournal
  use strict arg observedAt=""
  return eventJournal~events(observedAt)
::method operationalEvent
  use strict arg source,eventType,subjectRef,authority
  if eventType="" then return .nil
  select
    when eventType="SIP.SERVER.STARTED" then severity=.InstrumentationEventSeverity~INFO
    when eventType="SIP.SERVER.STOPPED" then severity=.InstrumentationEventSeverity~NOTICE
    when eventType="SIP.WIRE.ERROR" then severity=.InstrumentationEventSeverity~ERROR
    when eventType="SIP.AUTH.REJECTED" then severity=.InstrumentationEventSeverity~WARNING
    when eventType="SIP.AUTH.CHALLENGE" then severity=.InstrumentationEventSeverity~NOTICE
    when eventType="SIP.AUTH.ACCEPTED" then severity=.InstrumentationEventSeverity~INFO
    when left(eventType,17)="SIP.REGISTRATION." then severity=.InstrumentationEventSeverity~INFO
    when left(eventType,9)="SIP.CALL." then severity=.InstrumentationEventSeverity~INFO
    when left(eventType,11)="SIP.CLIENT." then severity=.InstrumentationEventSeverity~INFO
    otherwise return .nil
  end
  sourceId=self~value(source,"eventId","")
  if sourceId="" then sourceId=eventType||":"||self~value(source,"eventSequence","0")
  correlation=self~value(source,"callId","")
  if correlation="" then correlation=self~value(source,"registrationId","")
  evidence=.directory~new
  evidence["source_schema"]=self~value(source,"schema","")
  evidence["source_event_sequence"]=self~value(source,"eventSequence",0)
  evidence["component"]=self~value(source,"component","")
  evidence["object_id"]=self~value(source,"objectId","")
  detail=eventType
  causation=self~value(source,"causationId","")
  contextRefs=.array~new
  objectId=self~value(source,"objectId","")
  if objectId<>"" then contextRefs~append("sip-object:"||objectId)
  suppliedContexts=source["contextRefs"]
  if suppliedContexts<>.nil then do contextRef over suppliedContexts
    if contextRef~string~strip<>"" then contextRefs~append(contextRef~string)
  end
  return .InstrumentationCodec~event("sip:"||sourceId,eventType,subjectRef,authority,"",severity,correlation,"",detail,.array~new,evidence,.nil,.false,causation,contextRefs)
::method publishGauges
  expose emitter registrationsActive callsActive
  emitter~gaugeSet(.SipInstrumentationVocabulary~SIP_REGISTRATIONS_ACTIVE,registrationsActive,"registrations")
  emitter~gaugeSet(.SipInstrumentationVocabulary~SIP_CALLS_ACTIVE,callsActive,"calls")
  return self
::method value
  use strict arg event,key,defaultValue=""
  value=event[key]
  if value==.nil then return defaultValue
  return value
::method whole
  use strict arg event,key,defaultValue=0
  value=self~value(event,key,defaultValue)
  if \datatype(value,"W") then return defaultValue
  return value

::requires "InstrumentationServiceAdapters.cls"
::requires "InstrumentationMesh.cls"