/* Browser/AI semantic-action adapter for draft project operations. */
::class WireUIBuilderProjectActionAdapter subclass AlchemyObject public
::attribute project get
::method init
  expose project
  use arg project
  self~init:super(.WireUIDesignAlchemy~metadata("Wire UI semantic-action adapter for draft Builder projects"))
  if \project~isA(.WireUIBuilderProject) then raise syntax 93.948 array("project")
::method apply
  expose project
  use arg action, detail
  action=action~string~strip~translate
  if detail==.nil | \(detail~isA(.Table) | detail~isA(.Directory)) then return .WireUIDesignResult~failure("BUILDER_ACTION_DETAIL_REQUIRED")
  operationId=self~field(detail,"operationId","")
  if operationId="" then operationId="builder-"project~revision"-".WireUIDesignUtil~token(action"|".WireUIDesignUtil~canonicalTable(detail))
  expected=self~field(detail,"expectedRevision",project~revision)
  actorRef=self~field(detail,"actorRef","")
  reason=self~field(detail,"reason","")
  payload=.WireUIDesignUtil~copyTable(self~field(detail,"payload",.nil))
  /* Forms may send artifactId/spec fields directly rather than a nested payload. */
  if payload~items=0 & detail~hasIndex("artifactId") then do
    payload["artifactId"]=detail["artifactId"]
    if detail~hasIndex("spec") then payload["spec"]=detail["spec"]
  end
  if payload~items=0 then return .WireUIDesignResult~failure("BUILDER_PROJECT_PAYLOAD_REQUIRED")
  op=.WireUIDesignOperation~new(operationId,action,expected,.nil,payload,actorRef,reason)
  return project~applyOperation(op)
::method field private
  use arg t,k,default=.nil
  if t~hasIndex(k) then return t[k]
  return default
::requires "WireUIBuilderProject.cls"
