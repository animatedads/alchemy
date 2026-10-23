/* BoshInstrumentationAdapter.cls
 * Optional estate instrumentation adapter for generic BOSH.
 * Core BoshTransport.cls has no Instrumentation Mesh dependency.
 *
 * dev5: Instrumentation Mesh dev8 event/correlation projection.  Correlation,
 * causation and external context are accepted only when supplied by an upper
 * authority.  This adapter never infers them from time, endpoint, carrier or
 * payload coincidence.
 */
::class BoshInstrumentationMetrics public
::constant SESSION_OPEN_TOTAL "bosh.session.open.total"
::constant SESSION_OPEN_FAILED_TOTAL "bosh.session.open.failed.total"
::constant SESSION_CLOSE_TOTAL "bosh.session.close.total"
::constant SESSION_FAILED_TOTAL "bosh.session.failed.total"
::constant HTTP_EXCHANGE_TOTAL "bosh.http.exchange.total"
::constant HTTP_EXCHANGE_FAILED_TOTAL "bosh.http.exchange.failed.total"
::constant HTTP_OUTSTANDING "bosh.http.outstanding"
::constant NEGOTIATED_WAIT_SECONDS "bosh.session.wait.seconds"
::constant NEGOTIATED_HOLD_REQUESTS "bosh.session.hold.requests"

::class BoshInstrumentationObserver public subclass BoshObserver
::method init
  expose emitter eventObserver correlationId causationId contextRefs operationId eventSequence
  use strict arg instrumentationEmitter, instrumentationEventObserver=.nil, correlationIdArg="", causationIdArg="", contextRefsArg=.nil, operationIdArg=""
  if instrumentationEmitter=.nil then raise syntax 88.900 array("InstrumentationEmitter required")
  emitter=instrumentationEmitter
  eventObserver=instrumentationEventObserver
  correlationId=correlationIdArg~string
  causationId=causationIdArg~string
  operationId=operationIdArg~string
  if contextRefsArg=.nil then contextRefs=.array~new
  else contextRefs=contextRefsArg
  eventSequence=0

::method forIdentity class
  use strict arg identity, authority="BOSH_TRANSPORT", correlationId="", causationId="", contextRefs=.nil, operationId=""
  emitter=.InstrumentationEmitter~new(identity)
  events=.InstrumentationEventObserver~new(identity,authority)
  return .BoshInstrumentationObserver~new(emitter,events,correlationId,causationId,contextRefs,operationId)

::method snapshot
  expose emitter
  use strict arg observedAt=""
  return emitter~snapshot(observedAt)

::method events
  expose eventObserver
  use strict arg observedAt=""
  if eventObserver=.nil then return .array~new
  return eventObserver~events(observedAt)

::method sessionOpenAttempt
  expose emitter
  emitter~requestAccepted
  return .true

::method sessionOpened
  expose emitter
  use strict arg waitSeconds, holdRequests
  emitter~counterAdd(.BoshInstrumentationMetrics~SESSION_OPEN_TOTAL,1)
  emitter~gaugeSet(.BoshInstrumentationMetrics~NEGOTIATED_WAIT_SECONDS,waitSeconds,"seconds")
  emitter~gaugeSet(.BoshInstrumentationMetrics~NEGOTIATED_HOLD_REQUESTS,holdRequests,"requests")
  emitter~setHealth(.InstrumentationHealth~HEALTHY)
  emitter~requestCompleted
  self~recordEvent("BOSH_SESSION_OPENED",.InstrumentationEventSeverity~INFO)
  return .true

::method sessionOpenFailed
  expose emitter
  use strict arg reason
  emitter~counterAdd(.BoshInstrumentationMetrics~SESSION_OPEN_FAILED_TOTAL,1)
  emitter~setHealth(.InstrumentationHealth~DEGRADED)
  emitter~requestFailed
  self~recordEvent("BOSH_SESSION_OPEN_FAILED",.InstrumentationEventSeverity~ERROR)
  return .true

::method sessionClosed
  expose emitter
  emitter~counterAdd(.BoshInstrumentationMetrics~SESSION_CLOSE_TOTAL,1)
  emitter~setHealth(.InstrumentationHealth~STOPPED)
  self~recordEvent("BOSH_SESSION_CLOSED",.InstrumentationEventSeverity~NOTICE)
  return .true

::method sessionFailed
  expose emitter
  use strict arg reason
  emitter~counterAdd(.BoshInstrumentationMetrics~SESSION_FAILED_TOTAL,1)
  emitter~setHealth(.InstrumentationHealth~DEGRADED)
  self~recordEvent("BOSH_SESSION_FAILED",.InstrumentationEventSeverity~ERROR)
  return .true

::method httpExchangeStarted
  expose emitter
  use strict arg requestBytes
  emitter~counterAdd(.BoshInstrumentationMetrics~HTTP_EXCHANGE_TOTAL,1)
  emitter~gaugeSet(.BoshInstrumentationMetrics~HTTP_OUTSTANDING,emitter~gaugeValue(.BoshInstrumentationMetrics~HTTP_OUTSTANDING)+1,"requests")
  emitter~bytesOut(requestBytes)
  return .true

::method httpExchangeCompleted
  expose emitter
  use strict arg statusCode, responseBytes
  n=emitter~gaugeValue(.BoshInstrumentationMetrics~HTTP_OUTSTANDING)-1
  if n<0 then n=0
  emitter~gaugeSet(.BoshInstrumentationMetrics~HTTP_OUTSTANDING,n,"requests")
  emitter~bytesIn(responseBytes)
  return .true

::method httpExchangeFailed
  expose emitter
  use strict arg reason, statusCode=0, responseBytes=0
  n=emitter~gaugeValue(.BoshInstrumentationMetrics~HTTP_OUTSTANDING)-1
  if n<0 then n=0
  emitter~gaugeSet(.BoshInstrumentationMetrics~HTTP_OUTSTANDING,n,"requests")
  emitter~counterAdd(.BoshInstrumentationMetrics~HTTP_EXCHANGE_FAILED_TOTAL,1)
  if responseBytes>0 then emitter~bytesIn(responseBytes)
  evidence=.directory~new
  if statusCode<>0 then evidence["http_status_class"]=(statusCode%100)||"xx"
  self~recordEvent("BOSH_HTTP_EXCHANGE_FAILED",.InstrumentationEventSeverity~WARNING,evidence)
  return .true

::method recordEvent private
  expose eventObserver correlationId causationId contextRefs operationId eventSequence
  use strict arg kind,severity,evidence=.nil
  if eventObserver=.nil then return .false
  eventSequence+=1
  prefix="bosh"
  if operationId<>"" then prefix=operationId
  eventId=prefix||":"||eventSequence||":"||kind
  /* Deliberately no URI, target domain, payload, credential, stanza or raw
   * failure detail is copied into instrumentation. */
  return eventObserver~record(eventId,kind,severity,"",correlationId,causationId,operationId,"",.array~new,contextRefs,evidence)

::method capability class
  use strict arg identity
  metrics=.array~of( -
    .InstrumentationVocabulary~REQUEST_ACCEPTED_TOTAL, -
    .InstrumentationVocabulary~REQUEST_INFLIGHT, -
    .InstrumentationVocabulary~REQUEST_COMPLETED_TOTAL, -
    .InstrumentationVocabulary~REQUEST_FAILED_TOTAL, -
    .InstrumentationVocabulary~BYTES_IN_TOTAL, -
    .InstrumentationVocabulary~BYTES_OUT_TOTAL, -
    .BoshInstrumentationMetrics~SESSION_OPEN_TOTAL, -
    .BoshInstrumentationMetrics~SESSION_OPEN_FAILED_TOTAL, -
    .BoshInstrumentationMetrics~SESSION_CLOSE_TOTAL, -
    .BoshInstrumentationMetrics~SESSION_FAILED_TOTAL, -
    .BoshInstrumentationMetrics~HTTP_EXCHANGE_TOTAL, -
    .BoshInstrumentationMetrics~HTTP_EXCHANGE_FAILED_TOTAL, -
    .BoshInstrumentationMetrics~HTTP_OUTSTANDING, -
    .BoshInstrumentationMetrics~NEGOTIATED_WAIT_SECONDS, -
    .BoshInstrumentationMetrics~NEGOTIATED_HOLD_REQUESTS)
  /* Observation only: no management commands are granted by this adapter. */
  return .InstrumentationCodec~capability(identity,.array~of("LATEST","HISTORY","SERIES","EVENTS","EVENTS_HISTORY"),metrics,.array~new)

::requires "BoshTransport.cls"
::requires "InstrumentationMesh.cls"
::requires "InstrumentationServiceAdapters.cls"
