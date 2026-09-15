/* Immutable release graph: every deployed site version pins an exact artifact graph. */
::class WireUISiteRelease subclass AlchemyObject public
::attribute releaseId get
::attribute version get
::attribute contentAddress get
::method init
  expose releaseId version refs contentAddress sealed metadata
  use arg releaseId, version, metadata=.nil
  self~init:super(.WireUIDesignAlchemy~metadata("Immutable version-pinned Wire UI site release graph"))
  releaseId=releaseId~string~strip; version=version~string~strip; refs=.table~new; contentAddress=""; sealed=.false; metadata=.WireUIDesignUtil~copyTable(metadata)
  if releaseId="" | version="" then raise syntax 93.906 array("site release", releaseId)
::method pin
  expose refs sealed
  use arg artifactRef
  if sealed then return .WireUIDesignResult~failure("RELEASE_SEALED")
  if \artifactRef~isA(.WireUIArtifactRef) then return .WireUIDesignResult~failure("INVALID_ARTIFACT_REF")
  key=artifactRef~key
  if refs~hasIndex(key) then do
    prior=refs[key]
    if prior~contentAddress \= artifactRef~contentAddress then return .WireUIDesignResult~failure("RELEASE_REF_CONFLICT",key)
    return .WireUIDesignResult~success(prior,"ALREADY_PINNED")
  end
  refs[key]=artifactRef
  return .WireUIDesignResult~success(artifactRef)
::method seal
  expose refs sealed contentAddress
  if refs~items=0 then return .WireUIDesignResult~failure("EMPTY_RELEASE")
  contentAddress=.WireUIDesignUtil~strongToken(self~canonicalText); sealed=.true
  return .WireUIDesignResult~success(self)
::method isSealed
  expose sealed
  return sealed
::method refs
  expose refs
  a=.array~new; keys=refs~allIndexes; keys~sort; do k over keys; a~append(refs[k]); end; return a
::method canonicalText
  expose releaseId version refs metadata
  text=releaseId"|"version"|".WireUIDesignUtil~canonicalTable(metadata)
  keys=refs~allIndexes; keys~sort; do k over keys; text ||= "|"refs[k]~canonicalText; end
  return text
::method ref
  expose releaseId version contentAddress sealed
  if \sealed then return .nil
  return .WireUIArtifactRef~new("SITE_RELEASE",releaseId,version,contentAddress)
::method asWire
  expose releaseId version contentAddress sealed metadata
  d=.table~new; d["releaseId"]=releaseId; d["version"]=version; d["contentAddress"]=contentAddress; d["sealed"]=sealed; d["metadata"]=.WireUIDesignUtil~copyTable(metadata)
  rr=.array~new; do r over self~refs; rr~append(r~asWire); end; d["refs"]=rr
  return d
::requires "WireUIDesignSupport.cls"
