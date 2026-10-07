/* Return real ooRexx objects to the native bridge. */
use strict arg operation, a = .nil, b = .nil, c = .nil
select
  when operation == 'ANIMAL' then return .Animal~new(a, b, c)
  when operation == 'LIVE_REXX_TARGET' then return .LiveRexxTarget~new
  when operation == 'COLLECTION' then return .AnimalCollection~new
  when operation == 'GUARDED' then return .GuardedAnimal~new(a)
  when operation == 'ARGPROBE' then return .ArgumentProbe~new
  when operation == 'UNKNOWN_COLLISION' then return .ExistingUnknownThing~new
  when operation == 'PYTHON_PROXY' then return .AlchemyPythonObject~new(a)
  when operation == 'ALCHEMY_PYTHON_PROBE' then do
    o = .AlchemyPythonObject~new(a)
    state = o~alchemyBaseState
    integrity = o~alchemyInheritanceIntegrity
    return o~isA(.AlchemyObject) || ":" || state["initialized"] || ":" || integrity["inherits_alchemy_object"] || ":" || integrity["reserved_override_count"]
  end
  when operation == 'STEMCONSUMER' then return .StemConsumer~new
  when operation == 'STEM' then do
    stem = .stem~new('ANIMAL.')
    stem['NAME'] = 'Monty'
    stem['SPECIES'] = 'parrot'
    stem['FOOD.1'] = 'biscuit'
    stem['FOOD.2'] = 'seed'
    stem~put(2, 0)
    stem~put('biscuit', 1)
    stem~put('seed', 2)
    return stem
  end
  otherwise raise syntax 93.900 array ('unknown factory operation', operation)
end
::requires 'animals.cls'


::class ArgumentProbe public
::method probe
  if \arg(1, "E") then return "OMITTED"
  use arg value
  if value == .nil then return "NIL"
  if value == "" then return "EMPTY"
  return "VALUE:" || value

::class StemConsumer public
::method consume
  use strict arg stem
  count = stem~at(0)
  text = ''
  do i = 1 to count
    if i > 1 then text ||= '|'
    text ||= stem~at(i)
  end
  return count || ':' || text

::class LiveRexxTarget public subclass AlchemyObject
/* The live callable deliberately targets the stable public VALUE wrapper.  The
   semantic implementation below that wrapper is amended by AlchemyObject; the
   Python callable therefore never owns or caches a Method object/generation. */
::method init
  self~init:super
  r = self~instrumentMethod("VALUE")
  if \r~ok then raise syntax 93.900 array("cannot instrument live Rexx target", r~code)

::method value
  return "R1"

/* Advance the semantic target while preserving coordinator identity. */
::method setR2
  state = self~semanticTargetState("VALUE")
  r = self~amendSemanticTarget("VALUE", .Method~new("VALUE", .array~of('return "R2"')), state["generation"])
  if \r~ok then raise syntax 93.900 array("cannot amend VALUE to R2", r~code)
  return self

::method setR3
  state = self~semanticTargetState("VALUE")
  r = self~amendSemanticTarget("VALUE", .Method~new("VALUE", .array~of('return "R3"')), state["generation"])
  if \r~ok then raise syntax 93.900 array("cannot amend VALUE to R3", r~code)
  return self

/* Compact machine-readable evidence used by the cross-runtime qualification.
   The wrapper identity comes from AlchemyObject and must remain unchanged. */
::method targetState
  state = self~semanticTargetState("VALUE")
  return state["generation"] || ":" || state["target_present"] || ":" || state["wrapper_identity_hash"]

::method revokeValue
  state = self~semanticTargetState("VALUE")
  r = self~removeSemanticTarget("VALUE", state["generation"])
  if \r~ok then raise syntax 93.900 array("cannot revoke VALUE", r~code)
  return self
