/* Explicit definition/observation wiring for one access point. */
::class WireUISubscription subclass AlchemyObject public
::attribute subscriptionId get
::attribute version get
::attribute purpose get
::attribute policyRef get
::attribute active get

::method init
  expose subscriptionId version purpose policyRef active definitionKeys observationIds
  use arg subscriptionId, version, purpose, policyRef = ""
  self~init:super(.WireUIAlchemy~metadata("Explicit Wire UI definition/observation subscription"))
  definitionKeys = .set~new
  observationIds = .set~new
  active = .false
  self~registerStateVariable("subscriptionId", "CUSTOMER", "semantic subscription identity")
  self~registerStateVariable("active", "CUSTOMER", "whether this wiring is currently active")

::method addDefinition
  expose active definitionKeys
  use arg definitionKey
  if active then return .false
  definitionKeys~put(definitionKey)
  return .true

::method addObservation
  expose active observationIds
  use arg observationId
  if active then return .false
  observationIds~put(observationId)
  return .true

::method definitionIds
  expose definitionKeys
  return definitionKeys~makeArray

::method definitionKeys
  expose definitionKeys
  return definitionKeys~makeArray

::method observationIds
  expose observationIds
  return observationIds~makeArray

::method activate
  expose active
  active = .true
  return self

::method deactivate
  expose active
  active = .false
  return self

::method containsDefinition
  expose definitionKeys
  use arg definitionKey
  return definitionKeys~hasIndex(definitionKey)

::method asPlanEntry
  expose subscriptionId version purpose
  e=.table~new
  e["name"]=subscriptionId
  e["revision"]=version
  e["purpose"]=purpose
  return e
::requires "WireUIAlchemy.cls"
