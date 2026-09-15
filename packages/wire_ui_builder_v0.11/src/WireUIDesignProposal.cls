/* Reviewable bridge from an assessment to one or more exact typed operations. */
::class WireUIDesignProposal subclass AlchemyObject public
::attribute proposalId get
::attribute version get
::attribute assessmentRef get
::attribute contentAddress get
::method init
  expose proposalId version assessmentRef operationRefs contentAddress
  use arg proposalId, version, assessmentRef, operationRefs=.nil
  self~init:super(.WireUIDesignAlchemy~metadata("Reviewable Wire UI design change proposal"))
  proposalId=proposalId~string~strip; version=version~string~strip
  if proposalId="" | version="" | \assessmentRef~isA(.WireUIArtifactRef) then raise syntax 93.906 array("design proposal",proposalId)
  operationRefs=.WireUIDesignUtil~copyArray(operationRefs)
  do r over operationRefs; if \r~isA(.WireUIArtifactRef) then raise syntax 93.948 array("operationRef"); end
  contentAddress=.WireUIDesignUtil~strongToken(self~canonicalText)
::method operationRefs
  expose operationRefs
  return .WireUIDesignUtil~copyArray(operationRefs)
::method canonicalText
  expose proposalId version assessmentRef operationRefs
  return proposalId"|"version"|"assessmentRef~canonicalText"|".WireUIDesignUtil~canonicalArray(operationRefs)
::method ref
  expose proposalId version contentAddress
  return .WireUIArtifactRef~new("DESIGN_PROPOSAL",proposalId,version,contentAddress)
::requires "WireUIDesignSupport.cls"
