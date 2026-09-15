/* Server-authored factual timing evidence for a semantic Wire UI journey. */
::class WireUIJourneyTimingRecord subclass AlchemyObject public
::attribute sequence get
::attribute eventId get
::attribute applicationId get
::attribute journeyState get
::attribute journeyRevision get
::attribute transitionRef get
::attribute viewRef get
::attribute viewRevision get
::attribute correlationId get
::attribute clockMicros get
::attribute wallStamp get
::attribute siteReleaseContentAddress get

::method init
  expose sequence eventId applicationId journeyState journeyRevision transitionRef viewRef viewRevision correlationId clockMicros wallStamp detail siteReleaseContentAddress
  use arg sequence, eventId, applicationId, journeyState="", journeyRevision=.nil, transitionRef=.nil, viewRef="", viewRevision=.nil, correlationId="", clockMicros=.nil, wallStamp="", detail=.nil, siteReleaseContentAddress=""
  self~init:super(.WireUIAlchemy~metadata("Server-authored factual Wire UI journey timing evidence"))
  eventId=eventId~string~strip
  applicationId=applicationId~string~strip
  correlationId=correlationId~string
  if eventId="" | applicationId="" then raise syntax 93.906 array("journey timing record",eventId)
  if detail==.nil then detail=.table~new
  self~registerStateVariable("eventId","PUBLIC","semantic timing event identity")
  self~registerStateVariable("sequence","PUBLIC","application-local timing sequence")
  self~registerStateVariable("journeyState","CUSTOMER","server-authoritative journey state at evidence time")
  self~registerStateVariable("correlationId","PUBLIC","correlation identifier when available")
  self~registerStateVariable("clockMicros","PUBLIC","server clock reading in microseconds")
  self~registerStateVariable("detail","CUSTOMER","server-authored positive semantic timing detail")

::method detail
  expose detail
  copy=.table~new
  if detail==.nil then return copy
  do k over detail~allIndexes; copy[k]=detail[k]; end
  return copy

::method elapsedMicrosSince
  expose clockMicros sequence applicationId
  use arg prior
  if prior==.nil | \prior~isA(.WireUIJourneyTimingRecord) then return .WireUIResult~failure("JOURNEY_TIMING_RECORD_REQUIRED")
  if prior~applicationId<>applicationId then return .WireUIResult~failure("JOURNEY_TIMING_APPLICATION_MISMATCH")
  if prior~sequence>=sequence then return .WireUIResult~failure("JOURNEY_TIMING_ORDER_INVALID")
  if clockMicros==.nil | prior~clockMicros==.nil then return .WireUIResult~failure("JOURNEY_TIMING_CLOCK_UNAVAILABLE")
  elapsed=clockMicros-prior~clockMicros
  if elapsed<0 then return .WireUIResult~failure("JOURNEY_TIMING_CLOCK_REVERSED")
  return .WireUIResult~success(elapsed,"JOURNEY_TIMING_INTERVAL")

::method asWire
  expose sequence eventId applicationId journeyState journeyRevision transitionRef viewRef viewRevision correlationId clockMicros wallStamp detail siteReleaseContentAddress
  d=.table~new
  d["source"]="SERVER_AUTHORITATIVE"
  d["sequence"]=sequence
  d["eventId"]=eventId
  d["applicationId"]=applicationId
  if journeyState<>"" then d["journeyState"]=journeyState
  if journeyRevision<>.nil then d["journeyRevision"]=journeyRevision
  if transitionRef<>.nil then d["transitionRef"]=transitionRef
  if viewRef<>"" then d["viewRef"]=viewRef
  if viewRevision<>.nil then d["viewRevision"]=viewRevision
  if correlationId<>"" then d["correlationId"]=correlationId
  if clockMicros<>.nil then d["clockMicros"]=clockMicros
  if wallStamp<>"" then d["wallStamp"]=wallStamp
  if siteReleaseContentAddress<>"" then d["siteReleaseContentAddress"]=siteReleaseContentAddress
  copy=.table~new
  if detail<>.nil then do k over detail~allIndexes; copy[k]=detail[k]; end
  d["detail"]=copy
  return d

::requires "WireUIAlchemy.cls"

::requires "WireUIProtocol.cls"
