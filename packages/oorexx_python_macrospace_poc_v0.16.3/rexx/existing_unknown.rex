/*
 * v0.16 collision POC.
 *
 * ExistingUnknownThing is deliberately bridge-unaware at definition time and
 * already owns UNKNOWN.  installPythonProjection() captures the actual Method
 * object currently selected for UNKNOWN, installs that Method object under a
 * unique per-object alias, then overlays UNKNOWN on this object only.
 */
::class ExistingUnknownThing public

::attribute foreignHandle
::attribute bridgePythonMethods
::attribute bridgeOriginalUnknownAlias

::method init
  expose foreignHandle bridgePythonMethods bridgeOriginalUnknownAlias
  use strict arg foreignHandle, bridgePythonMethods
  bridgeOriginalUnknownAlias = ""

::method known
  return "REXX-KNOWN"

/* This method existed before the Python projection arrived. */
::method unknown
  use strict arg messageName, arguments
  return "ORIGINAL-UNKNOWN:" || messageName || ":" || arguments~items

::method installPythonProjection
  expose bridgeOriginalUnknownAlias
  original = self~instanceMethod("UNKNOWN")
  if original == .nil then raise syntax 93.900 array ("expected an existing UNKNOWN")

  /* The alias is deliberately object-unique rather than a public fixed name. */
  bridgeOriginalUnknownAlias = "!PYBRIDGE_ORIGINAL_UNKNOWN_" || self~identityHash

  /* setMethod is intentionally invoked from the receiving object's own method,
   * satisfying ooRexx's protected/private authority rule.  We preserve the
   * Method object itself -- not copied source text. */
  self~setMethod(bridgeOriginalUnknownAlias, original, "OBJECT")

  source = .array~of( -
    "expose foreignHandle bridgePythonMethods bridgeOriginalUnknownAlias", -
    "/* Direct invocation of UNKNOWN is not the unknown-message protocol. */", -
    "if arg() <> 2 | \arg(1,'E') | \arg(2,'E') then return self~bridgePythonCall('unknown')", -
    "messageName = arg(1)", -
    "arguments = arg(2)", -
    "if \arguments~isA(.Array) then return self~bridgePythonCall('unknown')", -
    "if wordpos(messageName~upper, bridgePythonMethods) > 0 then do", -
    "  select", -
    "    when arguments~items == 0 then return self~bridgePythonCall(messageName)", -
    "    otherwise raise syntax 93.900 array ('v0.16 collision POC Python projection accepts zero args here')", -
    "  end", -
    "end", -
    "/* Python declined this message: invoke the relocated original Method. */", -
    "return self~sendWith(bridgeOriginalUnknownAlias, .array~of(messageName, arguments))" -
  )
  self~setMethod("UNKNOWN", source, "OBJECT")
  return bridgeOriginalUnknownAlias


::method bridgePythonCall
  expose foreignHandle
  use strict arg messageName
  return PYCALL(foreignHandle, messageName)
