/* Immutable runtime selection of one exact compiled experiment variant. */
::class WireUIExperimentAssignment subclass AlchemyObject public
::attribute experimentId get
::attribute variantId get
::attribute targetElementId get
::attribute assignmentUnit get
::attribute definitionKey get
::attribute subjectRef get
::attribute siteReleaseContentAddress get

::method init
  expose experimentId variantId targetElementId assignmentUnit definitionKey subjectRef siteReleaseContentAddress
  use arg experimentId, variantId, targetElementId, assignmentUnit, definitionKey, subjectRef, siteReleaseContentAddress
  self~init:super(.WireUIAlchemy~metadata("Exact compiled Wire UI experiment assignment"))
  experimentId=experimentId~string~strip
  variantId=variantId~string~strip
  targetElementId=targetElementId~string~strip
  assignmentUnit=assignmentUnit~string~strip~translate
  definitionKey=definitionKey~string~strip
  subjectRef=subjectRef~string
  siteReleaseContentAddress=siteReleaseContentAddress~string~strip
  if experimentId="" | variantId="" | targetElementId="" | definitionKey="" | siteReleaseContentAddress="" then raise syntax 93.906 array("experiment assignment",experimentId)
  self~registerStateVariable("experimentId","PUBLIC","compiled experiment identity")
  self~registerStateVariable("variantId","PUBLIC","selected exact experiment variant")
  self~registerStateVariable("definitionKey","PUBLIC","exact selected renderer definition")
  self~registerStateVariable("subjectRef","PRIVATE","server-side assignment subject; never emitted on Wire UI")

::method asWire
  expose experimentId variantId targetElementId assignmentUnit definitionKey siteReleaseContentAddress
  d=.table~new
  d["experimentId"]=experimentId
  d["variantId"]=variantId
  d["targetElementId"]=targetElementId
  d["assignmentUnit"]=assignmentUnit
  d["definitionKey"]=definitionKey
  d["siteReleaseContentAddress"]=siteReleaseContentAddress
  return d

::requires "WireUIAlchemy.cls"
