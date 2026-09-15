/* Element-centric A/B experiment: exact projection variants for one semantic element. */
::class WireUIExperiment subclass AlchemyObject public
::attribute experimentId get
::attribute version get
::attribute targetElementId get
::attribute assignmentUnit get
::attribute contentAddress get
::method init
  expose experimentId version targetElementId assignmentUnit variants totalWeight contentAddress sealed
  use arg experimentId, version, targetElementId, assignmentUnit="USER"
  self~init:super(.WireUIDesignAlchemy~metadata("Versioned element-centric UI experiment"))
  experimentId=experimentId~string~strip; version=version~string~strip; targetElementId=targetElementId~string~strip; assignmentUnit=assignmentUnit~string~strip~translate
  variants=.array~new; totalWeight=0; contentAddress=""; sealed=.false
  if experimentId="" | version="" | targetElementId="" then raise syntax 93.906 array("experiment", experimentId)
::method addVariant
  expose variants totalWeight sealed targetElementId
  use arg variantId, weight, projectionRef
  if sealed then return .WireUIDesignResult~failure("EXPERIMENT_SEALED")
  if weight <= 0 then return .WireUIDesignResult~failure("INVALID_VARIANT_WEIGHT",weight)
  if \projectionRef~isA(.WireUIArtifactRef) then return .WireUIDesignResult~failure("INVALID_PROJECTION_REF")
  v=.table~new; v["variantId"]=variantId; v["weight"]=weight; v["projectionRef"]=projectionRef
  variants~append(v); totalWeight += weight
  return .WireUIDesignResult~success(self)
::method seal
  expose variants sealed contentAddress
  if variants~items < 2 then return .WireUIDesignResult~failure("EXPERIMENT_NEEDS_VARIANTS")
  contentAddress=.WireUIDesignUtil~token(self~canonicalText); sealed=.true
  return .WireUIDesignResult~success(self)
::method assign
  expose variants totalWeight sealed
  use arg subjectKey
  numeric digits 20
  if \sealed then return .WireUIDesignResult~failure("EXPERIMENT_NOT_SEALED")
  bucket=.WireUIDesignUtil~hashNumber(subjectKey~string || "|" || self~canonicalText) // totalWeight
  cursor=0
  do v over variants
    cursor += v["weight"]
    if bucket < cursor then return .WireUIDesignResult~success(v)
  end
  return .WireUIDesignResult~success(variants[variants~items])
::method variants
  expose variants
  a=.array~new; do v over variants; c=.table~new; c["variantId"]=v["variantId"]; c["weight"]=v["weight"]; c["projectionRef"]=v["projectionRef"]; a~append(c); end; return a
::method canonicalText
  expose experimentId version targetElementId assignmentUnit variants
  text=experimentId"|"version"|"targetElementId"|"assignmentUnit
  do v over variants; text ||= "|"v["variantId"]":"v["weight"]":"v["projectionRef"]~canonicalText; end
  return text
::method ref
  expose experimentId version contentAddress sealed
  if \sealed then return .nil
  return .WireUIArtifactRef~new("EXPERIMENT",experimentId,version,contentAddress)
::requires "WireUIDesignSupport.cls"
