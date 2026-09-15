/* Authoritative pre-action / pre-trade semantic projection.
   It describes what the server currently believes an intent would do; it is
   evidence for presentation and confirmation, never transaction authority. */
::class WireUIIntentProjection subclass AlchemyObject public
::attribute intentRef get
::attribute intentType get
::attribute state get
::attribute revision get
::attribute inputs get
::attribute consequences get
::attribute warnings get
::attribute admissibleActions get
::attribute requiredConfirmations get
::attribute provenanceRef get

::method init
  expose intentRef intentType state revision inputs consequences warnings admissibleActions requiredConfirmations provenanceRef
  use arg intentRef, intentType, state="PROPOSED", revision=1, inputs=.nil, consequences=.nil, warnings=.nil, admissibleActions=.nil, requiredConfirmations=.nil, provenanceRef=""
  self~init:super(.WireUIAlchemy~metadata("Authoritative semantic projection of proposed action consequences"))
  intentRef=intentRef~string~strip
  intentType=intentType~string~strip~translate
  state=state~string~strip~translate
  provenanceRef=provenanceRef~string~strip
  if intentRef="" | intentType="" then raise syntax 93.906 array("intent projection",intentRef)
  if \datatype(revision,"W") | revision<1 then raise syntax 93.906 array("intent projection revision",revision)
  inputs=self~copyTable(inputs)
  consequences=self~copyTable(consequences)
  warnings=self~copyArray(warnings)
  admissibleActions=self~copyArray(admissibleActions)
  requiredConfirmations=self~copyArray(requiredConfirmations)
  self~registerStateVariable("intentRef","PUBLIC","semantic intent identity")
  self~registerStateVariable("intentType","PUBLIC","semantic intent type")
  self~registerStateVariable("state","PUBLIC","authoritative projection lifecycle state")
  self~registerStateVariable("revision","PUBLIC","projection revision")
  self~registerStateVariable("provenanceRef","PUBLIC","business/legal/risk provenance reference")

::method asWire
  expose intentRef intentType state revision inputs consequences warnings admissibleActions requiredConfirmations provenanceRef
  t=.table~new
  t["intentRef"]=intentRef
  t["intentType"]=intentType
  t["state"]=state
  t["revision"]=revision
  t["inputs"]=self~copyTable(inputs)
  t["consequences"]=self~copyTable(consequences)
  t["warnings"]=self~copyArray(warnings)
  t["admissibleActions"]=self~copyArray(admissibleActions)
  t["requiredConfirmations"]=self~copyArray(requiredConfirmations)
  if provenanceRef<>"" then t["provenanceRef"]=provenanceRef
  return t

::method asSlots
  expose intentRef intentType state revision consequences warnings admissibleActions requiredConfirmations provenanceRef
  t=.table~new
  t["intentRef"]=intentRef
  t["intentType"]=intentType
  t["intentState"]=state
  t["intentRevision"]=revision
  t["consequences"]=self~copyTable(consequences)
  t["warnings"]=self~copyArray(warnings)
  t["admissibleActions"]=self~copyArray(admissibleActions)
  t["requiredConfirmations"]=self~copyArray(requiredConfirmations)
  if provenanceRef<>"" then t["provenanceRef"]=provenanceRef
  return t

::method copyTable private
  use arg source
  t=.table~new
  if source==.nil then return t
  do k over source~allIndexes; t[k]=source[k]; end
  return t

::method copyArray private
  use arg source
  a=.array~new
  if source==.nil then return a
  do v over source; a~append(v); end
  return a

::requires "WireUIAlchemy.cls"
