/* AlchemyRubyObject.cls - ooRexx Ruby Alchemy v0.1-dev10
 * Ruby projection on authoritative AlchemyForeignObject v0.2 / AlchemyObject v0.8.1.
 */
::class AlchemyRubyObject public subclass AlchemyForeignObject

/* Construct a live Ruby projection, declare its evidence-facing contracts,
 * then compose Ruby dispatch into UNKNOWN without destroying prior UNKNOWN. */
::method init
  expose rubyBridge rubyHandle
  use strict arg rubyBridge, rubyHandle
  self~init:super
  self~addClsPath("ruby:Object")
  self~registerExternalRequirement("runtime", "MRI Ruby", "", .true, "", "CUSTOMER")
  self~registerMethodContract("RUBYHANDLE", "Return resident Ruby identity handle", .array~new, "ANY", .false, "FALSE", "INTERNAL", "SENSITIVE", "READ", "NONE")
  self~registerMethodContract("RUBYUNKNOWN", "Dispatch unresolved Rexx messages through Ruby normal lookup and method_missing", .array~of("MESSAGE", "ARGUMENTS"), "ANY", .false, "FALSE", "INTERNAL", "SECURITY_BOUNDARY", "EXTERNAL", "USE")
  self~installForeignUnknownComposition("RUBYUNKNOWN")

/* Preserve standard Rexx unresolved-message behavior as the pre-projection
 * UNKNOWN target. AlchemyForeignObject retains this exact Method object before
 * replacing UNKNOWN with RUBYUNKNOWN on this projection instance. */
::method unknown
  use strict arg messageName, arguments
  raise syntax 97.1 array(messageName)

/* Identify the originating runtime in Alchemy Foreign Object evidence. */
::method foreignRuntime
  return "RUBY"

/* Return the bridge-owned Ruby identity handle; never copies the Ruby value. */
::method rubyHandle
  expose rubyHandle
  return rubyHandle

/* Execute Ruby lookup. Only a proven unresolved Ruby send may use the preserved
 * Rexx UNKNOWN fallback; an executed Ruby method that raises remains a failure. */
::method rubyUnknown
  expose rubyBridge rubyHandle
  use strict arg messageName, arguments
  result = rubyBridge~dispatch(rubyHandle, messageName, arguments)
  if result~kind == "missing" then
    return self~foreignUnknownFallback(messageName, arguments)
  if result~kind == "raised" then
    result~raiseForeign
  return result~value

::requires 'AlchemyForeignObject.cls'
