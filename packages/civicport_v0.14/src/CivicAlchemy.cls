/* CivicAlchemy.cls - CivicPort v0.14 AlchemyObject house-base bridge. */

::class CivicAlchemyObject subclass AlchemyObject public
::constant CIVICPORT_VERSION "0.14"
::constant ALCHEMY_OBJECTS_VERSION "0.4.3"

::method init public
  use arg sealer = .nil, authority = .nil
  ignore = self~initCivicAlchemy(sealer, authority)

::method initCivicAlchemy protected
  expose civicAlchemyInitialized
  use arg sealer = .nil, authority = .nil
  if symbol("CIVICALCHEMYINITIALIZED") = "VAR" then return self

  meta = .directory~new
  meta["component"] = "CivicPort"
  meta["package_version"] = self~CIVICPORT_VERSION
  meta["purpose"] = self~class~id || " CivicPort object"
  meta["evidence_rule"] = "Preserve HTTP evidence first. Project later. Promote never by accident."
  self~initAlchemy(meta, sealer, authority)

  civicAlchemyInitialized = .true
  self~registerStateVariable("civicAlchemyInitialized", "INTERNAL", "CivicPort house-base initialization marker")
  self~registerExternalRequirement("library", "alchemy_objects", self~ALCHEMY_OBJECTS_VERSION, .true)
  self~registerInstrumentationPoint("CIVIC.OBJECT.USE", "CivicPort object operation evidence", .true, "COLLAPSE", "INTERNAL")
  self~registerMethodContract("CIVICOBJECTPROFILE", "Return bounded CivicPort/Alchemy base identity", .array~new, "DIRECTORY", .false, "AUTO", "PUBLIC", "NORMAL", "READ", "NONE")
  return self

::method civicObjectProfile public
  d = .directory~new
  d["component"] = "CivicPort"
  d["package_version"] = self~CIVICPORT_VERSION
  d["alchemy_objects_version"] = self~ALCHEMY_OBJECTS_VERSION
  d["class"] = self~class~id
  d["object_id"] = self~alchemyObjectId
  d["evidence_rule"] = "Preserve HTTP evidence first. Project later. Promote never by accident."
  return d

::requires "AlchemyObject.cls"
