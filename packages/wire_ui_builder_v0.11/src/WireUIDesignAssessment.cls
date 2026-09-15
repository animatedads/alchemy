/* Evidence-backed assessment is deliberately separate from measured render facts. */
::class WireUIDesignAssessment subclass AlchemyObject public
::attribute assessmentId get
::attribute version get
::attribute classification get
::attribute severity get
::attribute confidence get
::attribute finding get
::attribute evidenceRef get
::attribute contentAddress get
::method init
  expose assessmentId version classification severity confidence finding evidenceRef facts affectedRefs proposedVerbs contentAddress
  use arg assessmentId, version, classification, severity, confidence, finding, evidenceRef, facts=.nil, affectedRefs=.nil, proposedVerbs=.nil
  self~init:super(.WireUIDesignAlchemy~metadata("Evidence-backed human/AI Wire UI design assessment"))
  assessmentId=assessmentId~string~strip; version=version~string~strip; classification=classification~string~strip~translate; severity=severity~string~strip~translate; finding=finding~string~strip
  if assessmentId="" | version="" | classification="" | severity="" | finding="" | confidence<0 | confidence>1 then raise syntax 93.906 array("design assessment",assessmentId)
  if \evidenceRef~isA(.WireUIArtifactRef) then raise syntax 93.948 array("evidenceRef")
  facts=.WireUIDesignUtil~copyTable(facts); affectedRefs=.WireUIDesignUtil~copyArray(affectedRefs); proposedVerbs=.WireUIDesignUtil~copyArray(proposedVerbs)
  contentAddress=.WireUIDesignUtil~strongToken(self~canonicalText)
::method canonicalText
  expose assessmentId version classification severity confidence finding evidenceRef facts affectedRefs proposedVerbs
  return assessmentId"|"version"|"classification"|"severity"|"confidence"|"finding"|"evidenceRef~canonicalText"|".WireUIDesignUtil~canonicalTable(facts)"|".WireUIDesignUtil~canonicalArray(affectedRefs)"|".WireUIDesignUtil~canonicalArray(proposedVerbs)
::method ref
  expose assessmentId version contentAddress
  return .WireUIArtifactRef~new("DESIGN_ASSESSMENT",assessmentId,version,contentAddress)
::method asWire
  expose assessmentId version classification severity confidence finding evidenceRef facts affectedRefs proposedVerbs contentAddress
  d=.table~new; d["assessmentId"]=assessmentId; d["version"]=version; d["classification"]=classification; d["severity"]=severity; d["confidence"]=confidence; d["finding"]=finding; d["evidenceRef"]=evidenceRef~asWire; d["facts"]=.WireUIDesignUtil~copyTable(facts)
  a=.array~new; do r over affectedRefs; if r~isA(.WireUIArtifactRef) then a~append(r~asWire); else a~append(r); end; d["affectedRefs"]=a; d["proposedVerbs"]=.WireUIDesignUtil~copyArray(proposedVerbs); d["contentAddress"]=contentAddress; return d
::requires "WireUIDesignSupport.cls"
