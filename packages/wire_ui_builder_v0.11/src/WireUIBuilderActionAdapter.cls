/*
  Meeting point between a Wire UI builder access point and the authoring model.
  The owning Wire UIApplication remains responsible for authentication/authorisation.
  This adapter only converts an already-authorised semantic action to the same
  typed WireUIDesignOperation used by direct human/AI tooling.
*/
::class WireUIBuilderActionAdapter subclass AlchemyObject public
::attribute workspace get
::method init
  expose workspace
  use arg workspace
  self~init:super(.WireUIDesignAlchemy~metadata("Wire UI semantic-action adapter for Builder authoring operations"))
  if \workspace~isA(.WireUIDesignWorkspace) then raise syntax 93.948 array("workspace")
::method apply
  expose workspace
  use arg action, detail
  action=action~string~strip~translate
  if detail==.nil | \(detail~isA(.Table) | detail~isA(.Directory)) then return .WireUIDesignResult~failure("BUILDER_ACTION_DETAIL_REQUIRED")
  operationId=self~field(detail,"operationId","")
  expected=self~field(detail,"expectedRevision",-1)
  actorRef=self~field(detail,"actorRef","")
  reason=self~field(detail,"reason","")
  target=self~refFromWire(self~field(detail,"targetRef",.nil))
  if self~field(detail,"targetRef",.nil)<>.nil & target==.nil then return .WireUIDesignResult~failure("BUILDER_TARGET_REF_INVALID")
  payload=.WireUIDesignUtil~copyTable(self~field(detail,"payload",.nil))
  if payload~hasIndex("componentRef") then do
    cr=self~refFromWire(payload["componentRef"]); if cr==.nil then return .WireUIDesignResult~failure("BUILDER_COMPONENT_REF_INVALID")
    payload["componentRef"]=cr
  end
  evidence=.array~new
  rawEvidence=self~field(detail,"evidenceRefs",.nil)
  if rawEvidence<>.nil then do r over rawEvidence
    rr=self~refFromWire(r); if rr==.nil then return .WireUIDesignResult~failure("BUILDER_EVIDENCE_REF_INVALID")
    evidence~append(rr)
  end
  if operationId="" | expected<0 then return .WireUIDesignResult~failure("BUILDER_OPERATION_ID_OR_REVISION_REQUIRED")
  op=.WireUIDesignOperation~new(operationId,action,expected,target,payload,actorRef,reason,evidence)
  return workspace~applyOperation(op)
::method refFromWire private
  use arg value
  if value==.nil then return .nil
  if value~isA(.WireUIArtifactRef) then return value
  if \(value~isA(.Table) | value~isA(.Directory)) then return .nil
  kind=self~field(value,"kind",""); id=self~field(value,"id",""); version=self~field(value,"version",""); address=self~field(value,"contentAddress","")
  if kind="" | id="" | version="" then return .nil
  return .WireUIArtifactRef~new(kind,id,version,address)
::method field private
  use arg t,k,default=.nil
  if t==.nil then return default
  if t~hasIndex(k) then return t[k]
  return default
::requires "WireUIDesignWorkspace.cls"
