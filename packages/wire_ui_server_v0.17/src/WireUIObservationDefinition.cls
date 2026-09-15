/* Immutable positive-list observation point definition. */
::class WireUIObservationDefinition subclass AlchemyObject public
::attribute observationId get
::attribute version get
::attribute purpose get
::attribute evidenceStrength get
::attribute contentAddress get

::method init
  expose observationId version purpose evidenceStrength allowedFields contentAddress
  use arg observationId, version, purpose, allowedFields=.nil, evidenceStrength="CLIENT_APPLICATION_ASSERTED"
  self~init:super(.WireUIAlchemy~metadata("Immutable authorised Wire UI observation definition"))
  observationId=observationId~string~strip
  version=version~string~strip
  purpose=purpose~string~strip
  evidenceStrength=evidenceStrength~string~strip
  if observationId="" | version="" | purpose="" then raise syntax 93.906 array("observation definition",observationId)
  if allowedFields==.nil then allowedFields=.array~new
  fields=.set~new
  do field over allowedFields
    f=field~string~strip
    if f<>"" then fields~put(f)
  end
  allowedFields=fields
  canonical=observationId"|"version"|"purpose"|"evidenceStrength"|"
  sorted=allowedFields~makeArray
  sorted~sort
  do f over sorted; canonical=canonical||f";"; end
  contentAddress=self~token(canonical)
  self~registerStateVariable("observationId","PUBLIC","semantic observation point identity")
  self~registerStateVariable("version","PUBLIC","immutable observation definition version")
  self~registerStateVariable("purpose","PUBLIC","authorised observation purpose")
  self~registerStateVariable("evidenceStrength","PUBLIC","server-declared evidence strength")

::method exactKey
  expose observationId version
  return observationId"@"version

::method allowedFields
  expose allowedFields
  return allowedFields~makeArray

::method allowsField
  expose allowedFields
  use arg field
  /* Empty list means no payload fields are permitted, not wildcard access. */
  return allowedFields~hasIndex(field)

::method token private
  use arg text
  numeric digits 20
  h=2166136261
  do i=1 to text~length
    h=(h*16777619+text~substr(i,1)~c2d)//2147483647
  end
  return "wuiobs01-"d2x(h~format(,0),8)

::method asPlanPoint
  expose observationId purpose evidenceStrength allowedFields
  p=.table~new
  p["id"]=observationId
  p["purpose"]=purpose
  p["evidenceStrength"]=evidenceStrength
  a=allowedFields~makeArray; a~sort; p["allowedFields"]=a
  return p

::requires "WireUIAlchemy.cls"
