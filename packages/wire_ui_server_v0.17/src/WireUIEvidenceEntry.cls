/* Factual, attributable event suitable for an ordered operational evidence stream. */
::class WireUIEvidenceEntry subclass AlchemyObject public
::attribute eventRef get
::attribute eventType get
::attribute occurredAt get
::attribute severity get
::attribute summary get
::attribute sourceRef get
::attribute provenanceRef get
::attribute correlationRef get

::method init
  expose eventRef eventType occurredAt severity summary sourceRef provenanceRef correlationRef attributes
  use arg eventRef, eventType, occurredAt, severity="INFO", summary="", sourceRef="", provenanceRef="", correlationRef="", attributes=.nil
  self~init:super(.WireUIAlchemy~metadata("Factual attributable Wire UI operational evidence entry"))
  eventRef=eventRef~string~strip
  eventType=eventType~string~strip~translate
  occurredAt=occurredAt~string~strip
  severity=severity~string~strip~translate
  summary=summary~string
  sourceRef=sourceRef~string
  provenanceRef=provenanceRef~string
  correlationRef=correlationRef~string
  if eventRef="" | eventType="" | occurredAt="" then raise syntax 93.906 array("evidence entry",eventRef)
  if attributes==.nil then attributes=.table~new
  attributes=self~copyTable(attributes)
  self~registerStateVariable("eventRef","PUBLIC","stable factual evidence identity")
  self~registerStateVariable("eventType","PUBLIC","factual event type")
  self~registerStateVariable("occurredAt","PUBLIC","authoritative event time representation")
  self~registerStateVariable("provenanceRef","PUBLIC","source/provenance reference")

::method asSlots
  expose eventRef eventType occurredAt severity summary sourceRef provenanceRef correlationRef attributes
  d=.table~new
  d["eventRef"]=eventRef
  d["eventType"]=eventType
  d["occurredAt"]=occurredAt
  d["severity"]=severity
  d["summary"]=summary
  d["sourceRef"]=sourceRef
  d["provenanceRef"]=provenanceRef
  d["correlationRef"]=correlationRef
  d["attributes"]=self~copyTable(attributes)
  return d

::method copyTable private
  use arg source
  target=.table~new
  if source==.nil then return target
  do key over source~allIndexes; target[key]=source[key]; end
  return target

::method asWire
  return self~asSlots

::requires "WireUIAlchemy.cls"
