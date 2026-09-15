/* Immutable typed authoring operation. Humans and AI use the same operation vocabulary. */
::class WireUIDesignOperation subclass AlchemyObject public
::attribute operationId get
::attribute verb get
::attribute expectedRevision get
::attribute targetRef get
::attribute actorRef get
::attribute reason get
::attribute contentAddress get
::method init
  expose operationId verb expectedRevision targetRef payload actorRef reason evidenceRefs contentAddress auditDigest
  use arg operationId, verb, expectedRevision, targetRef=.nil, payload=.nil, actorRef="", reason="", evidenceRefs=.nil
  self~init:super(.WireUIDesignAlchemy~metadata("Immutable typed Wire UI design operation"))
  operationId=operationId~string~strip
  verb=verb~string~strip~translate
  actorRef=actorRef~string~strip
  reason=reason~string~strip
  if operationId="" | verb="" | expectedRevision<0 then raise syntax 93.906 array("design operation",operationId)
  if targetRef<>.nil then if \targetRef~isA(.WireUIArtifactRef) then raise syntax 93.948 array("targetRef")
  payload=.WireUIDesignUtil~copyTable(payload)
  evidenceRefs=.WireUIDesignUtil~copyArray(evidenceRefs)
  contentAddress=.WireUIDesignUtil~token(self~canonicalText); auditDigest=""
  self~registerStateVariable("operationId","PUBLIC","globally unique immutable authoring operation identity")
  self~registerStateVariable("verb","PUBLIC","typed semantic design mutation")
  self~registerStateVariable("expectedRevision","PUBLIC","workspace compare-and-swap revision")
  self~registerStateVariable("contentAddress","PUBLIC","fast deterministic authoring operation identity")

::method auditDigest
  expose auditDigest
  if auditDigest="" then auditDigest=.WireUIDesignUtil~strongToken(self~canonicalText)
  return auditDigest
::method payload
  expose payload
  return .WireUIDesignUtil~copyTable(payload)
::method evidenceRefs
  expose evidenceRefs
  return .WireUIDesignUtil~copyArray(evidenceRefs)
::method canonicalText
  expose operationId verb expectedRevision targetRef payload actorRef reason evidenceRefs
  target=""
  if targetRef<>.nil then target=targetRef~canonicalText
  return operationId"|"verb"|"expectedRevision"|"target"|"actorRef"|"reason"|".WireUIDesignUtil~canonicalTable(payload)"|".WireUIDesignUtil~canonicalArray(evidenceRefs)
::method ref
  expose operationId contentAddress
  return .WireUIArtifactRef~new("DESIGN_OPERATION",operationId,"1",contentAddress)
::method projectWire
  expose operationId verb expectedRevision targetRef payload actorRef reason evidenceRefs contentAddress
  d=.table~new
  d["operationId"]=operationId; d["verb"]=verb; d["expectedRevision"]=expectedRevision
  if targetRef==.nil then d["targetRef"]=.nil; else d["targetRef"]=targetRef~asWire
  d["payload"]=.WireUIDesignUtil~copyTable(payload); d["actorRef"]=actorRef; d["reason"]=reason
  er=.array~new; do r over evidenceRefs; if r~isA(.WireUIArtifactRef) then er~append(r~asWire); else er~append(r); end
  d["evidenceRefs"]=er; d["contentAddress"]=contentAddress
  return d
::method asWire
  d=self~projectWire; d["auditDigest"]=self~auditDigest; return d
::method fromProjectWire class
  use arg row
  if row==.nil | \(row~isA(.Table) | row~isA(.Directory)) then return .WireUIDesignResult~failure("DESIGN_OPERATION_WIRE_INVALID")
  target=.nil
  if row~hasIndex("targetRef") & row["targetRef"]<>.nil then do
    t=row["targetRef"]
    target=.WireUIArtifactRef~new(t["kind"],t["id"],t["version"],t["contentAddress"])
  end
  evidence=.array~new
  if row~hasIndex("evidenceRefs") & row["evidenceRefs"]<>.nil then do e over row["evidenceRefs"]
    if (e~isA(.Table) | e~isA(.Directory)) & e~hasIndex("kind") & e~hasIndex("id") & e~hasIndex("version") then evidence~append(.WireUIArtifactRef~new(e["kind"],e["id"],e["version"],e["contentAddress"]))
    else evidence~append(e)
  end
  op=self~new(row["operationId"],row["verb"],row["expectedRevision"]+0,target,row["payload"],row["actorRef"],row["reason"],evidence)
  if row~hasIndex("contentAddress") & row["contentAddress"]<>"" then if op~contentAddress<>row["contentAddress"] then return .WireUIDesignResult~failure("DESIGN_OPERATION_CONTENT_MISMATCH",op~operationId)
  return .WireUIDesignResult~success(op,"DESIGN_OPERATION_RESTORED")
::requires "WireUIDesignSupport.cls"
