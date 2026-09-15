/* Site semantic vocabulary: business meaning independent of renderer/profile. */
::class WireUISemanticElement subclass AlchemyObject public
::attribute elementId get
::attribute version get
::attribute semanticType get
::attribute audiencePolicyRef get
::attribute contentAddress get
::method init
  expose elementId version semanticType fields actions audiencePolicyRef metadata contentAddress
  use arg elementId, version, semanticType, fields=.nil, actions=.nil, audiencePolicyRef="PUBLIC", metadata=.nil
  self~init:super(.WireUIDesignAlchemy~metadata("Versioned semantic interaction element"))
  elementId=elementId~string~strip; version=version~string~strip; semanticType=semanticType~string~strip
  audiencePolicyRef=audiencePolicyRef~string~strip
  if elementId="" | version="" | semanticType="" then raise syntax 93.906 array("semantic element", elementId)
  fields=.WireUIDesignUtil~copyArray(fields); actions=.WireUIDesignUtil~copyArray(actions); metadata=.WireUIDesignUtil~copyTable(metadata)
  contentAddress=.WireUIDesignUtil~token(self~canonicalText)
  self~registerStateVariable("elementId","PUBLIC","stable site semantic identity")
  self~registerStateVariable("version","PUBLIC","immutable semantic element version")
  self~registerStateVariable("audiencePolicyRef","PUBLIC","declarative audience policy reference; never an authority grant")
::method canonicalText
  expose elementId version semanticType fields actions audiencePolicyRef metadata
  return elementId"|"version"|"semanticType"|"audiencePolicyRef"|".WireUIDesignUtil~canonicalArray(fields)"|".WireUIDesignUtil~canonicalArray(actions)"|".WireUIDesignUtil~canonicalTable(metadata)
::method ref
  expose elementId version contentAddress
  return .WireUIArtifactRef~new("ELEMENT",elementId,version,contentAddress)
::method asWire
  expose elementId version semanticType fields actions audiencePolicyRef metadata contentAddress
  d=.table~new; d["elementId"]=elementId; d["version"]=version; d["semanticType"]=semanticType; d["fields"]=.WireUIDesignUtil~copyArray(fields); d["actions"]=.WireUIDesignUtil~copyArray(actions); d["audiencePolicyRef"]=audiencePolicyRef; d["metadata"]=.WireUIDesignUtil~copyTable(metadata); d["contentAddress"]=contentAddress
  return d
::requires "WireUIDesignSupport.cls"
