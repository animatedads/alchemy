/* Versioned renderer-facing component vocabulary. */
::class WireUIVisualComponent subclass AlchemyObject public
::attribute componentId get
::attribute version get
::attribute primitive get
::attribute contentAddress get
::method init
  expose componentId version primitive slotSchema styleHooks capabilities contentAddress
  use arg componentId, version, primitive, slotSchema=.nil, styleHooks=.nil, capabilities=.nil
  self~init:super(.WireUIDesignAlchemy~metadata("Versioned visual component available to the Wire UI builder"))
  componentId=componentId~string~strip; version=version~string~strip; primitive=primitive~string~strip
  if componentId="" | version="" | primitive="" then raise syntax 93.906 array("visual component", componentId)
  slotSchema=.WireUIDesignUtil~copyTable(slotSchema)
  styleHooks=.WireUIDesignUtil~copyArray(styleHooks)
  capabilities=.WireUIDesignUtil~copyArray(capabilities)
  contentAddress=.WireUIDesignUtil~token(self~canonicalText)
  self~registerStateVariable("componentId","PUBLIC","stable visual component identity")
  self~registerStateVariable("version","PUBLIC","immutable visual component version")
  self~registerStateVariable("contentAddress","PUBLIC","deterministic component content address")
::method canonicalText
  expose componentId version primitive slotSchema styleHooks capabilities
  return componentId"|"version"|"primitive"|".WireUIDesignUtil~canonicalTable(slotSchema)"|".WireUIDesignUtil~canonicalArray(styleHooks)"|".WireUIDesignUtil~canonicalArray(capabilities)
::method ref
  expose componentId version contentAddress
  return .WireUIArtifactRef~new("COMPONENT",componentId,version,contentAddress)
::method asWire
  expose componentId version primitive slotSchema styleHooks capabilities contentAddress
  d=.table~new; d["componentId"]=componentId; d["version"]=version; d["primitive"]=primitive; d["slotSchema"]=.WireUIDesignUtil~copyTable(slotSchema); d["styleHooks"]=.WireUIDesignUtil~copyArray(styleHooks); d["capabilities"]=.WireUIDesignUtil~copyArray(capabilities); d["contentAddress"]=contentAddress
  return d
::requires "WireUIDesignSupport.cls"
