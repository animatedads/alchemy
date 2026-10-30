/* Registry for language structural adapters.  It is intentionally tiny: the
 * language service declares the adapter identity; this registry owns the live
 * parser object. */
::class SemanticSourceStructuralAdapterRegistry public
::method init
  self~adapters = .directory~new
  self~register("oorexx", .SemanticSourceOorexxStructuralAdapter~new)
::attribute adapters get
::attribute adapters set private
::method register
  use strict arg languageId, adapter
  if adapter == .nil then raise syntax 88.900 array("structural adapter is required")
  self~adapters[languageId~lower] = adapter
  return adapter
::method adapterFor
  use strict arg languageId
  key = languageId~lower
  if \self~adapters~hasIndex(key) then return .nil
  return self~adapters[key]
::requires "SemanticSourceOorexxStructuralAdapter.cls"
