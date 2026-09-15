/* Semantic design history: exact predecessor + causal operation + evidence. */
::class WireUIDesignLineage subclass AlchemyObject public
::attribute derivedRef get
::attribute predecessorRef get
::attribute operationRef get
::attribute contentAddress get
::method init
  expose derivedRef predecessorRef operationRef evidenceRefs contentAddress
  use arg derivedRef, predecessorRef, operationRef, evidenceRefs=.nil
  self~init:super(.WireUIDesignAlchemy~metadata("Semantic Wire UI design lineage"))
  if \derivedRef~isA(.WireUIArtifactRef) | \predecessorRef~isA(.WireUIArtifactRef) | \operationRef~isA(.WireUIArtifactRef) then raise syntax 93.948 array("lineage refs")
  evidenceRefs=.WireUIDesignUtil~copyArray(evidenceRefs)
  contentAddress=.WireUIDesignUtil~strongToken(self~canonicalText)
  self~registerStateVariable("derivedRef","PUBLIC","exact derived immutable design object")
  self~registerStateVariable("predecessorRef","PUBLIC","exact predecessor immutable design object")
  self~registerStateVariable("operationRef","PUBLIC","causal typed authoring operation")
::method evidenceRefs
  expose evidenceRefs
  return .WireUIDesignUtil~copyArray(evidenceRefs)
::method canonicalText
  expose derivedRef predecessorRef operationRef evidenceRefs
  return derivedRef~canonicalText"|"predecessorRef~canonicalText"|"operationRef~canonicalText"|".WireUIDesignUtil~canonicalArray(evidenceRefs)
::method ref
  expose derivedRef contentAddress
  return .WireUIArtifactRef~new("DESIGN_LINEAGE",derivedRef~key,"1",contentAddress)
::method asWire
  expose derivedRef predecessorRef operationRef evidenceRefs contentAddress
  d=.table~new; d["derivedRef"]=derivedRef~asWire; d["predecessorRef"]=predecessorRef~asWire; d["operationRef"]=operationRef~asWire
  er=.array~new; do r over evidenceRefs; if r~isA(.WireUIArtifactRef) then er~append(r~asWire); else er~append(r); end
  d["evidenceRefs"]=er; d["contentAddress"]=contentAddress; return d
::requires "WireUIDesignSupport.cls"
