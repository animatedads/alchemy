/* Immutable, exact-version, session-independent semantic element definition. */
::class WireUIElementDefinition subclass AlchemyObject public
::attribute definitionId get
::attribute version get
::attribute primitive get
::attribute semanticAction get
::attribute label get
::attribute styleRole get
::attribute contentAddress get
::attribute metadata get

::method init
  expose definitionId version primitive semanticAction label styleRole contentAddress metadata sealed
  use arg definitionId, version, primitive, semanticAction = "", label = "", styleRole = "", metadata = .nil, suppliedContentAddress = ""
  self~init:super(.WireUIAlchemy~metadata("Immutable exact-version Wire UI semantic element definition"))
  definitionId = definitionId~string~strip
  version = version~string~strip
  primitive = primitive~string~strip
  if definitionId = "" | version = "" | primitive = "" then raise syntax 93.906 array("definition", definitionId)
  if metadata == .nil then metadata = .table~new
  metadata = self~copyTable(metadata)
  if suppliedContentAddress = "" then contentAddress = self~token(self~canonicalText)
  else contentAddress = suppliedContentAddress~string~strip
  sealed = .true
  self~registerStateVariable("definitionId", "PUBLIC", "site semantic definition identity")
  self~registerStateVariable("version", "PUBLIC", "immutable definition version")
  self~registerStateVariable("primitive", "PUBLIC", "known renderer primitive")
  self~registerStateVariable("contentAddress", "PUBLIC", "deterministic definition cache token")

::method definitionKey
  expose definitionId version
  return definitionId"@"version

::method canonicalText
  expose definitionId version primitive semanticAction label styleRole metadata
  text = definitionId"|"version"|"primitive"|"semanticAction"|"label"|"styleRole
  keys = metadata~allIndexes
  keys~sort
  do key over keys
    text ||= "|"key"="metadata[key]
  end
  return text

::method asWire
  expose definitionId version primitive semanticAction label styleRole contentAddress metadata
  d = .table~new
  d["definitionId"] = definitionId
  d["definitionVersion"] = version
  d["version"] = version
  d["definitionKey"] = self~definitionKey
  d["primitive"] = primitive
  d["action"] = semanticAction
  d["label"] = label
  d["styleRole"] = styleRole
  d["contentAddress"] = contentAddress
  d["metadata"] = self~copyTable(metadata)
  return d

::method copyTable private
  use arg source
  target = .table~new
  do key over source
    target[key] = source[key]
  end
  return target

::method token private
  use arg text
  numeric digits 20
  h = 2166136261
  do i = 1 to text~length
    h = (h * 16777619 + text~substr(i, 1)~c2d) // 2147483647
  end
  return "wui01-"d2x(h~format(, 0), 8)
::requires "WireUIAlchemy.cls"
