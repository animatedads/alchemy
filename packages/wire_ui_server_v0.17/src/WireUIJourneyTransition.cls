/* Attributable evidence of movement through a semantic journey graph. */
::class WireUIJourneyTransition subclass AlchemyObject public
::attribute fromState get
::attribute toState get
::attribute trigger get
::attribute purpose get
::attribute evidence get
::attribute sequence get

::method init
  expose fromState toState trigger purpose evidence sequence
  use arg fromState, toState, trigger = "", purpose = "", evidence = .nil, sequence = 0
  self~init:super(.WireUIAlchemy~metadata("Evidence of a Wire UI journey transition"))
  self~registerStateVariable("fromState", "CUSTOMER", "prior semantic journey state")
  self~registerStateVariable("toState", "CUSTOMER", "new semantic journey state")
  self~registerStateVariable("trigger", "CUSTOMER", "semantic transition trigger")
  self~registerStateVariable("purpose", "CUSTOMER", "declared journey purpose")
  self~registerStateVariable("sequence", "CUSTOMER", "monotonic journey transition sequence")

::method asWire
  expose fromState toState trigger purpose evidence sequence
  d=.table~new
  d["fromState"]=fromState
  d["toState"]=toState
  d["trigger"]=trigger
  d["purpose"]=purpose
  d["sequence"]=sequence
  if evidence \== .nil then d["evidence"]=evidence
  return d
::requires "WireUIAlchemy.cls"
