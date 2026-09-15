/* Canonical factual observation accepted by the authoritative server. */
::class WireUIObservationRecord subclass AlchemyObject public
::attribute applicationId get
::attribute subscriptionId get
::attribute subscriptionRevision get
::attribute pointId get
::attribute purpose get
::attribute evidenceStrength get
::attribute viewRef get
::attribute renderedRevision get
::attribute messageId get
::attribute siteReleaseContentAddress get

::method init
  expose applicationId subscriptionId subscriptionRevision pointId purpose evidenceStrength observation viewRef renderedRevision messageId siteReleaseContentAddress
  use arg applicationId, subscriptionId, subscriptionRevision, pointId, purpose, evidenceStrength, observation, viewRef="", renderedRevision=.nil, messageId="", siteReleaseContentAddress=""
  self~init:super(.WireUIAlchemy~metadata("Accepted factual Wire UI interaction/render observation"))
  self~registerStateVariable("applicationId","CUSTOMER","owning application identity")
  self~registerStateVariable("subscriptionId","PUBLIC","authorising observation subscription")
  self~registerStateVariable("pointId","PUBLIC","authorised semantic observation point")
  self~registerStateVariable("observation","CUSTOMER","positive-list observation payload")

::method observation
  expose observation
  c=.table~new
  do k over observation~allIndexes; c[k]=observation[k]; end
  return c

::method asWire
  expose subscriptionId subscriptionRevision pointId purpose evidenceStrength observation viewRef renderedRevision messageId siteReleaseContentAddress
  d=.table~new
  d["subscription"]=subscriptionId
  d["subscriptionRevision"]=subscriptionRevision
  d["point"]=pointId
  d["purpose"]=purpose
  d["evidenceStrength"]=evidenceStrength
  copy=.table~new; do k over observation~allIndexes; copy[k]=observation[k]; end
  d["observation"]=copy
  if viewRef<>"" then d["viewRef"]=viewRef
  if renderedRevision<>.nil then d["renderedRevision"]=renderedRevision
  if messageId<>"" then d["messageId"]=messageId
  if siteReleaseContentAddress<>"" then d["siteReleaseContentAddress"]=siteReleaseContentAddress
  return d

::requires "WireUIAlchemy.cls"
