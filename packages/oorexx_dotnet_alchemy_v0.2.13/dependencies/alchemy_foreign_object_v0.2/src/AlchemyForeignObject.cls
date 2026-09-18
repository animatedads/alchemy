/* Alchemy Foreign Object v0.2
 * Shared ooRexx-side base for foreign-runtime object bridges.
 * External dependency: authoritative AlchemyObject.cls.
 */
::class AlchemyForeignObject public subclass AlchemyObject
::method init
  expose clsPaths foreignUnknownOriginalAlias foreignUnknownBridgeSelector
  clsPaths = .array~new
  foreignUnknownOriginalAlias = .nil
  foreignUnknownBridgeSelector = .nil
  self~init:super
::method foreignRuntime abstract
::method addClsPath
  expose clsPaths
  use strict arg path
  path = path~string
  if path == "" then return self
  do existing over clsPaths
    if existing == path then return self
  end
  clsPaths~append(path)
  return self
::method removeClsPath
  expose clsPaths
  use strict arg path
  path = path~string
  replacement = .array~new
  do existing over clsPaths
    if existing \== path then replacement~append(existing)
  end
  clsPaths = replacement
  return self
::method clsPath
  expose clsPaths
  return clsPaths~copy
::method inheritClsPath
  use strict arg source
  do path over source~clsPath
    self~addClsPath(path)
  end
  return self
::method installForeignUnknownComposition
  expose foreignUnknownOriginalAlias foreignUnknownBridgeSelector
  use strict arg bridgeSelector
  bridgeSelector = bridgeSelector~string~translate
  if bridgeSelector == "" then raise syntax 93.900 array ("foreign UNKNOWN bridge selector must not be empty")
  if foreignUnknownOriginalAlias \== .nil then raise syntax 93.900 array ("foreign UNKNOWN composition is already installed")
  original = self~instanceMethod("UNKNOWN")
  if original == .nil then raise syntax 93.900 array ("existing UNKNOWN Method object not found")
  bridge = self~instanceMethod(bridgeSelector)
  if bridge == .nil then raise syntax 93.900 array ("foreign UNKNOWN bridge Method object not found", bridgeSelector)
  runtime = self~foreignRuntime~string~translate
  foreignUnknownOriginalAlias = "!ALCHEMY_FOREIGN_ORIGINAL_UNKNOWN_" || runtime || "_" || self~identityHash
  foreignUnknownBridgeSelector = bridgeSelector
  self~setMethod(foreignUnknownOriginalAlias, original, "OBJECT")
  self~setMethod("UNKNOWN", bridge, "OBJECT")
  return foreignUnknownOriginalAlias
::method foreignUnknownFallback
  expose foreignUnknownOriginalAlias
  use strict arg messageName, arguments
  if foreignUnknownOriginalAlias == .nil then raise syntax 93.900 array ("foreign UNKNOWN composition is not installed")
  return self~sendWith(foreignUnknownOriginalAlias, .array~of(messageName, arguments))
::method foreignUnknownCompositionState
  expose foreignUnknownOriginalAlias foreignUnknownBridgeSelector
  d = .directory~new
  d["installed"] = (foreignUnknownOriginalAlias \== .nil)
  d["original_alias"] = foreignUnknownOriginalAlias
  d["bridge_selector"] = foreignUnknownBridgeSelector
  return d
::method alchemyForeignState
  expose clsPaths foreignUnknownOriginalAlias foreignUnknownBridgeSelector
  d = .directory~new
  d["runtime"] = self~foreignRuntime
  d["cls_path"] = clsPaths~copy
  d["alchemy_initialized"] = self~alchemyBaseState["initialized"]
  d["unknown_composed"] = (foreignUnknownOriginalAlias \== .nil)
  d["unknown_original_alias"] = foreignUnknownOriginalAlias
  d["unknown_bridge_selector"] = foreignUnknownBridgeSelector
  return d
::requires 'AlchemyObject.cls'
