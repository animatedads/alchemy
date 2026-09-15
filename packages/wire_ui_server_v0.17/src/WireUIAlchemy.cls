/* Shared Alchemy house metadata for Wire UI derived objects. */
::class WireUIAlchemy public
::constant PACKAGE_VERSION "0.17"
::method metadata class
  use arg purpose, limitations = .nil
  m = .directory~new
  m["purpose"] = purpose
  m["package"] = "wire_ui_server"
  m["package_version"] = self~PACKAGE_VERSION
  m["authorship"] = .array~of("Alchemy Wire UI")
  m["standards"] = .array~of("ALCHEMY-HOUSE-OBJECT-0.5", "WIRE-UI/0.1")
  if limitations == .nil then limitations = .array~of("v0.17; WIRE-UI/0.1 unchanged; workspace command authority may bind exact authoritative result revision in addition to query/scope/order/selection context; transport remains Queue Fabric adapter; gateway remains transport-only")
  m["design_limitations"] = limitations
  return m
::requires "AlchemyObject.cls"
