/* Typed authoritative semantic state for professional operational workspaces.
   This is application/view meaning, not a browser styling instruction. */
::class WireUISemanticState subclass AlchemyObject public
::attribute kind get
::attribute code get
::attribute displayValue get
::attribute severity get
::attribute unit get
::attribute role get
::attribute provenanceRef get

::method init
  expose kind code displayValue severity unit role provenanceRef
  use arg kind, code, displayValue="", severity="", unit="", role="", provenanceRef=""
  self~init:super(.WireUIAlchemy~metadata("Typed authoritative semantic UI state"))
  kind=kind~string~strip~translate
  code=code~string~strip
  severity=severity~string~strip~translate
  unit=unit~string~strip
  role=role~string~strip
  provenanceRef=provenanceRef~string~strip
  if kind="" | code="" then raise syntax 93.906 array("semantic state",kind"/"code)
  if severity<>"" & \self~severityAllowed(severity) then raise syntax 93.906 array("semantic state severity",severity)
  self~registerStateVariable("kind","PUBLIC","semantic state kind")
  self~registerStateVariable("code","PUBLIC","authoritative semantic state code")
  self~registerStateVariable("severity","PUBLIC","authoritative semantic severity")
  self~registerStateVariable("provenanceRef","PUBLIC","state provenance reference")

::method asWire
  expose kind code displayValue severity unit role provenanceRef
  t=.table~new
  t["kind"]=kind
  t["code"]=code
  t["displayValue"]=displayValue
  if severity<>"" then t["severity"]=severity
  if unit<>"" then t["unit"]=unit
  if role<>"" then t["role"]=role
  if provenanceRef<>"" then t["provenanceRef"]=provenanceRef
  return t

/* Conventional slot expansion for definitions that choose to expose the
   semantic facets separately. A renderer is free to map these slots however
   its compiled definition declares; the server does not prescribe CSS/DOM. */
::method asSlots
  expose code displayValue severity unit role provenanceRef kind
  t=.table~new
  t["value"]=displayValue
  t["stateCode"]=code
  t["stateKind"]=kind
  if severity<>"" then t["severity"]=severity
  if unit<>"" then t["unit"]=unit
  if role<>"" then t["semanticRole"]=role
  if provenanceRef<>"" then t["provenanceRef"]=provenanceRef
  return t

::method severityAllowed private
  use arg value
  return value="NEUTRAL" | value="INFO" | value="GOOD" | value="WARNING" | value="CRITICAL"

::requires "WireUIAlchemy.cls"
