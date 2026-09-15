/* AlchemyCoreComponent.cls - common Alchemy operational component base. */

::class AlchemyCoreComponent subclass AlchemyObject public
::constant CORE_COMPONENT_VERSION "0.1"

::attribute alchemyComponentName get
::attribute alchemyComponentVersion get

::method init public
  use strict arg componentName = "ALCHEMY_COMPONENT", componentVersion = "0", purpose = "Alchemy operational component", sealer = .nil, authority = .nil
  self~initCoreComponent(componentName, componentVersion, purpose, sealer, authority)

::method initCoreComponent public protected
  expose alchemyComponentName alchemyComponentVersion
  use strict arg componentName, componentVersion, purpose, sealer = .nil, authority = .nil
  alchemyComponentName = componentName~string~strip
  alchemyComponentVersion = componentVersion~string~strip
  if alchemyComponentName = "" then raise syntax 88.900 array("Alchemy core component name must not be empty")
  if alchemyComponentVersion = "" then raise syntax 88.900 array("Alchemy core component version must not be empty")
  meta = .directory~new
  meta["purpose"] = purpose~string
  meta["package_version"] = alchemyComponentVersion
  meta["alchemy_core_component"] = alchemyComponentName
  self~initAlchemy(meta, sealer, authority)
  self~registerStateVariable("alchemyComponentName", "CUSTOMER", "Alchemy operational component name")
  self~registerStateVariable("alchemyComponentVersion", "CUSTOMER", "Alchemy operational component version")
  self~registerMethodContract("COMPONENTDESCRIPTOR", "Return stable operational component identity", .array~new, "DIRECTORY", .false, "AUTO", "PUBLIC", "NORMAL", "READ", "NONE")
  return self

::method componentDescriptor public
  expose alchemyComponentName alchemyComponentVersion
  self~alchemyTouch("COMPONENTDESCRIPTOR")
  d = .directory~new
  d["name"] = alchemyComponentName
  d["version"] = alchemyComponentVersion
  d["object_id"] = self~alchemyObjectId
  return d

::requires "AlchemyObject.cls"
