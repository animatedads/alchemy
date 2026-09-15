/* Versioned design-system material tokens and recipes. */
::class WireUIMaterialSet subclass AlchemyObject public
::attribute materialId get
::attribute version get
::attribute contentAddress get
::method init
  expose materialId version tokens recipes contentAddress
  use arg materialId, version, tokens=.nil, recipes=.nil
  self~init:super(.WireUIDesignAlchemy~metadata("Versioned site material/design-system set"))
  materialId=materialId~string~strip; version=version~string~strip
  if materialId="" | version="" then raise syntax 93.906 array("material set", materialId)
  tokens=.WireUIDesignUtil~copyTable(tokens); recipes=.WireUIDesignUtil~copyTable(recipes)
  contentAddress=.WireUIDesignUtil~token(self~canonicalText)
  self~registerStateVariable("materialId","PUBLIC","stable material/design-system identity")
  self~registerStateVariable("version","PUBLIC","immutable material set version")
::method canonicalText
  expose materialId version tokens recipes
  return materialId"|"version"|".WireUIDesignUtil~canonicalTable(tokens)"|".WireUIDesignUtil~canonicalTable(recipes)
::method ref
  expose materialId version contentAddress
  return .WireUIArtifactRef~new("MATERIAL",materialId,version,contentAddress)
::method asWire
  expose materialId version tokens recipes contentAddress
  d=.table~new; d["materialId"]=materialId; d["version"]=version; d["tokens"]=.WireUIDesignUtil~copyTable(tokens); d["recipes"]=.WireUIDesignUtil~copyTable(recipes); d["contentAddress"]=contentAddress
  return d
::requires "WireUIDesignSupport.cls"
