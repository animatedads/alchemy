/* Immutable snapshot of one mutable project draft. Draft revisions are not public artifact versions. */
::class WireUIBuilderDraft subclass AlchemyObject public
::attribute kind get
::attribute artifactId get
::attribute draftRevision get
::attribute baseRef get
::attribute contentAddress get
::method init
  expose kind artifactId draftRevision baseRef spec contentAddress
  use arg kind, artifactId, draftRevision, spec=.nil, baseRef=.nil
  self~init:super(.WireUIDesignAlchemy~metadata("Builder working draft snapshot; not a published artifact version"))
  kind=kind~string~strip~translate; artifactId=artifactId~string~strip
  if kind="" | artifactId="" | draftRevision<0 then raise syntax 93.906 array("builder draft",artifactId)
  if baseRef<>.nil then if \baseRef~isA(.WireUIArtifactRef) then raise syntax 93.948 array("baseRef")
  spec=.WireUIDesignUtil~copyTable(spec)
  contentAddress="draft-" || .WireUIDesignUtil~token(self~canonicalText)
  self~registerStateVariable("artifactId","PUBLIC","stable draft artifact identity")
  self~registerStateVariable("draftRevision","PUBLIC","project revision which produced this draft snapshot")
  self~registerStateVariable("contentAddress","PUBLIC","tamper-evident draft snapshot address")
::method key
  expose kind artifactId
  return kind":"artifactId
::method spec
  expose spec
  return .WireUIDesignUtil~copyTable(spec)
::method canonicalText
  expose kind artifactId draftRevision baseRef spec
  base=""; if baseRef<>.nil then base=baseRef~canonicalText
  return kind"|"artifactId"|"draftRevision"|"base"|".WireUIDesignUtil~canonicalTable(spec)
::method asWire
  expose kind artifactId draftRevision baseRef spec contentAddress
  d=.directory~new; d["kind"]=kind; d["artifactId"]=artifactId; d["draftRevision"]=draftRevision
  if baseRef==.nil then d["baseRef"]=.nil; else d["baseRef"]=baseRef~asWire
  d["spec"]=.WireUIDesignUtil~copyTable(spec); d["contentAddress"]=contentAddress
  return d
::requires "WireUIDesignSupport.cls"
