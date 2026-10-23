/* Shared RTP -> Instrumentation Mesh adapter. RTP owns these observations;
 * SIP does not absorb RTP operational state merely because it negotiated it. */
::class RtpInstrumentationVocabulary public
::constant RTP_ENDPOINTS_OPEN "rtp.endpoints.open"
::constant RTP_RX_RUNNING "rtp.receivers.running"
::constant RTP_TX_RUNNING "rtp.senders.running"
::constant RTP_RX_FRAMES_TOTAL "rtp.frames.rx.total"
::constant RTP_TX_FRAMES_TOTAL "rtp.frames.tx.total"
::constant RTP_RX_DROPPED_TOTAL "rtp.frames.rx.dropped.total"
::constant RTP_RX_SAMPLES_TOTAL "rtp.samples.rx.total"
::constant RTP_TX_SAMPLES_TOTAL "rtp.samples.tx.total"
::constant RTP_TX_BYTES_TOTAL "rtp.bytes.tx.total"

::class RtpInstrumentationSink public
::method init
  expose emitter endpointsOpen rxRunning txRunning eventJournal subjectRef authority
  use strict arg identity, authorityArg="RTP_SERVICE"
  emitter=.InstrumentationEmitter~new(identity)
  subjectRef=.InstrumentationCodec~semanticRef(identity)
  authority=authorityArg~string~strip
  if authority="" then authority="RTP_SERVICE"
  eventJournal=.InstrumentationEventJournal~new(256)
  emitter~setHealth(.InstrumentationHealth~STARTING)
  endpointsOpen=0; rxRunning=0; txRunning=0
  self~publishGauges
::method emitter
  expose emitter
  return emitter
::method snapshot
  expose emitter
  use strict arg observedAt=""
  return emitter~snapshot(observedAt)
::method recordEvent
  expose emitter endpointsOpen rxRunning txRunning eventJournal subjectRef authority
  use strict arg event
  if \event~isA(.Directory) then return .nil
  eventType=self~value(event,"eventType","")
  select
    when eventType="RTP.ENDPOINT.OPENED" then do
      endpointsOpen+=1
      emitter~setHealth(.InstrumentationHealth~HEALTHY)
      emitter~gaugeSet(.InstrumentationVocabulary~SERVICE_STATE,"RUNNING","state",.nil,.InstrumentationMetricKind~STATE)
    end
    when eventType="RTP.ENDPOINT.CLOSED" then do
      endpointsOpen-=1; if endpointsOpen<0 then endpointsOpen=0
      if endpointsOpen=0 then do
        emitter~setHealth(.InstrumentationHealth~STOPPED)
        emitter~gaugeSet(.InstrumentationVocabulary~SERVICE_STATE,"STOPPED","state",.nil,.InstrumentationMetricKind~STATE)
      end
    end
    when eventType="RTP.RECEIVER.STARTED" then rxRunning+=1
    when eventType="RTP.RECEIVER.STOPPED" | eventType="RTP.RECEIVER.CLOSED" then do; rxRunning-=1; if rxRunning<0 then rxRunning=0; end
    when eventType="RTP.SENDER.STARTED" then txRunning+=1
    when eventType="RTP.SENDER.STOPPED" | eventType="RTP.SENDER.CLOSED" then do; txRunning-=1; if txRunning<0 then txRunning=0; end
    when eventType="RTP.RECEIVER.FRAME" then do
      emitter~counterAdd(.RtpInstrumentationVocabulary~RTP_RX_FRAMES_TOTAL,1)
      emitter~counterAdd(.RtpInstrumentationVocabulary~RTP_RX_SAMPLES_TOTAL,self~whole(event,"samples",0),"samples")
    end
    when eventType="RTP.RECEIVER.DROPPED" then emitter~counterAdd(.RtpInstrumentationVocabulary~RTP_RX_DROPPED_TOTAL,1)
    when eventType="RTP.SENDER.FRAME" then do
      emitter~counterAdd(.RtpInstrumentationVocabulary~RTP_TX_FRAMES_TOTAL,1)
      emitter~counterAdd(.RtpInstrumentationVocabulary~RTP_TX_SAMPLES_TOTAL,self~whole(event,"samples",0),"samples")
      emitter~counterAdd(.RtpInstrumentationVocabulary~RTP_TX_BYTES_TOTAL,self~whole(event,"bytes",0),"bytes")
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
    when eventType="RTP.ENDPOINT.OPENED" then severity=.InstrumentationEventSeverity~INFO
    when eventType="RTP.ENDPOINT.CLOSED" then severity=.InstrumentationEventSeverity~NOTICE
    when eventType="RTP.RECEIVER.STARTED" then severity=.InstrumentationEventSeverity~INFO
    when eventType="RTP.RECEIVER.STOPPED" then severity=.InstrumentationEventSeverity~NOTICE
    when eventType="RTP.RECEIVER.CLOSED" then severity=.InstrumentationEventSeverity~NOTICE
    when eventType="RTP.SENDER.STARTED" then severity=.InstrumentationEventSeverity~INFO
    when eventType="RTP.SENDER.STOPPED" then severity=.InstrumentationEventSeverity~NOTICE
    when eventType="RTP.SENDER.CLOSED" then severity=.InstrumentationEventSeverity~NOTICE
    when eventType="RTP.RECEIVER.DROPPED" then severity=.InstrumentationEventSeverity~WARNING
    otherwise return .nil
  end
  sourceId=self~value(source,"eventId","")
  if sourceId="" then sourceId=eventType||":"||self~value(source,"eventSequence","0")
  correlation=self~value(source,"callId","")
  evidence=.directory~new
  evidence["source_schema"]=self~value(source,"schema","")
  evidence["source_event_sequence"]=self~value(source,"eventSequence",0)
  evidence["component"]=self~value(source,"component","")
  evidence["object_id"]=self~value(source,"objectId","")
  detail=eventType
  causation=self~value(source,"causationId","")
  contextRefs=.array~new
  objectId=self~value(source,"objectId","")
  if objectId<>"" then contextRefs~append("rtp-object:"||objectId)
  suppliedContexts=source["contextRefs"]
  if suppliedContexts<>.nil then do contextRef over suppliedContexts
    if contextRef~string~strip<>"" then contextRefs~append(contextRef~string)
  end
  return .InstrumentationCodec~event("rtp:"||sourceId,eventType,subjectRef,authority,"",severity,correlation,"",detail,.array~new,evidence,.nil,.false,causation,contextRefs)
::method publishGauges
  expose emitter endpointsOpen rxRunning txRunning
  emitter~gaugeSet(.RtpInstrumentationVocabulary~RTP_ENDPOINTS_OPEN,endpointsOpen,"endpoints")
  emitter~gaugeSet(.RtpInstrumentationVocabulary~RTP_RX_RUNNING,rxRunning,"receivers")
  emitter~gaugeSet(.RtpInstrumentationVocabulary~RTP_TX_RUNNING,txRunning,"senders")
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