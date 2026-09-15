/* Exact profile projection from a semantic element into a visual/agent component. */
::class WireUIProjectionDesign subclass AlchemyObject public
::attribute projectionId get
::attribute version get
::attribute profile get
::attribute elementRef get
::attribute componentRef get
::attribute definitionId get
::attribute styleRole get
::attribute materialRole get
::attribute contentAddress get
::method init
  expose projectionId version profile elementRef componentRef definitionId action styleRole materialRole bindings metadata resourceBindings contentAddress
  use arg projectionId, version, profile, elementRef, componentRef, definitionId, action="", styleRole="", materialRole="", bindings=.nil, metadata=.nil, resources=.nil
  self~init:super(.WireUIDesignAlchemy~metadata("Versioned semantic-to-access-point projection"))
  projectionId=projectionId~string~strip; version=version~string~strip; profile=profile~string~strip~translate; definitionId=definitionId~string~strip
  if projectionId="" | version="" | profile="" | definitionId="" then raise syntax 93.906 array("projection", projectionId)
  if \elementRef~isA(.WireUIArtifactRef) | \componentRef~isA(.WireUIArtifactRef) then raise syntax 93.948 array("projection refs")
  action=action~string~strip; styleRole=styleRole~string~strip; materialRole=materialRole~string~strip
  bindings=.WireUIDesignUtil~copyTable(bindings); metadata=.WireUIDesignUtil~copyTable(metadata)
  resourceBindings=.array~new
  if resources<>.nil then do row over resources; resourceBindings~append(self~normaliseResourceBinding(row)); end
  contentAddress=.WireUIDesignUtil~token(self~canonicalText)
  self~registerStateVariable("projectionId","PUBLIC","stable projection identity")
  self~registerStateVariable("version","PUBLIC","immutable projection version")
  self~registerStateVariable("profile","PUBLIC","interaction profile selected by this projection")
::method normaliseResourceBinding private
  use arg row
  if row==.nil | \(row~isA(.Table) | row~isA(.Directory)) then raise syntax 93.948 array("resource binding")
  role=""; if row~hasIndex("role") then role=row["role"]~string~strip~translate
  if role="" then raise syntax 93.906 array("resource binding role",projectionId)
  rr=.nil
  if row~hasIndex("resourceRef") then do
    source=row["resourceRef"]
    if source~isA(.WireUIResourceRef) then rr=source; else rr=.WireUIResourceRef~fromWire(source)
  end
  if rr==.nil then raise syntax 93.906 array("resourceRef",role)
  d=.table~new; d["role"]=role; d["resourceRef"]=rr~asWire
  required=.true; if row~hasIndex("required") then required=row["required"]
  d["required"]=required
  return d
::method resourceBindings
  expose resourceBindings
  a=.array~new; do row over resourceBindings; a~append(.WireUIDesignUtil~copyTable(row)); end; return a
::method canonicalText
  expose projectionId version profile elementRef componentRef definitionId action styleRole materialRole bindings metadata resourceBindings
  return projectionId"|"version"|"profile"|"elementRef~canonicalText"|"componentRef~canonicalText"|"definitionId"|"action"|"styleRole"|"materialRole"|".WireUIDesignUtil~canonicalTable(bindings)"|".WireUIDesignUtil~canonicalTable(metadata)"|".WireUIDesignUtil~canonicalArray(resourceBindings)
::method ref
  expose projectionId version contentAddress
  return .WireUIArtifactRef~new("PROJECTION",projectionId,version,contentAddress)
::method asWire
  expose projectionId version profile elementRef componentRef definitionId action styleRole materialRole bindings metadata resourceBindings contentAddress
  d=.table~new; d["projectionId"]=projectionId; d["version"]=version; d["profile"]=profile; d["elementRef"]=elementRef~asWire; d["componentRef"]=componentRef~asWire; d["definitionId"]=definitionId; d["action"]=action; d["styleRole"]=styleRole; d["materialRole"]=materialRole; d["bindings"]=.WireUIDesignUtil~copyTable(bindings); d["metadata"]=.WireUIDesignUtil~copyTable(metadata); d["resourceBindings"]=self~resourceBindings; d["contentAddress"]=contentAddress
  return d
::requires "WireUIDesignSupport.cls"
::requires "WireUIResourceRef.cls"
