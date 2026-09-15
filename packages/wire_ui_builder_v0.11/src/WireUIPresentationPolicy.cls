/* Arbitration for simultaneously-valid conditional placements. */
::class WireUIPresentationPolicy subclass AlchemyObject public
::attribute policyId get
::attribute version get
::attribute contentAddress get
::method init
  expose policyId version precedence capacities metadata contentAddress
  use arg policyId, version, precedence=.nil, capacities=.nil, metadata=.nil
  self~init:super(.WireUIDesignAlchemy~metadata("Versioned presentation arbitration policy"))
  policyId=policyId~string~strip; version=version~string~strip
  if policyId="" | version="" then raise syntax 93.906 array("presentation policy",policyId)
  precedence=.WireUIDesignUtil~copyArray(precedence); capacities=.WireUIDesignUtil~copyTable(capacities); metadata=.WireUIDesignUtil~copyTable(metadata)
  do k over capacities~allIndexes
    n=capacities[k]+0
    if n<0 | n<>n~trunc then raise syntax 93.914 array("presentation capacity",k)
  end
  contentAddress=.WireUIDesignUtil~token(self~canonicalText)
::method canonicalText
  expose policyId version precedence capacities metadata
  return policyId"|"version"|".WireUIDesignUtil~canonicalArray(precedence)"|".WireUIDesignUtil~canonicalTable(capacities)"|".WireUIDesignUtil~canonicalTable(metadata)
::method ref
  expose policyId version contentAddress
  return .WireUIArtifactRef~new("PRESENTATION_POLICY",policyId,version,contentAddress)
::method asWire
  expose policyId version precedence capacities metadata contentAddress
  d=.table~new; d["policyId"]=policyId; d["version"]=version; d["precedence"]=.WireUIDesignUtil~copyArray(precedence); d["capacities"]=.WireUIDesignUtil~copyTable(capacities); d["metadata"]=.WireUIDesignUtil~copyTable(metadata); d["contentAddress"]=contentAddress; return d
::requires "WireUIDesignSupport.cls"
