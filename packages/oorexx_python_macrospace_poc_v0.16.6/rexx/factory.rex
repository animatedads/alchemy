/* Return real ooRexx objects to the native bridge. */
use strict arg operation, a = .nil, b = .nil, c = .nil
select
  when operation == 'ANIMAL' then return .Animal~new(a, b, c)
  when operation == 'COLLECTION' then return .AnimalCollection~new
  when operation == 'GUARDED' then return .GuardedAnimal~new(a)
  when operation == 'EXISTINGUNKNOWN' then do
    use arg , handle, methods
    return .ExistingUnknownThing~new(handle, methods)
  end
  when operation == 'ARGPROBE' then return .ArgumentProbe~new
  when operation == 'SLOTARRAY' then do
    a = .array~new(4)
    /* index 1 deliberately absent */
    a[2] = .nil
    a[3] = ""
    a[4] = "hello"
    return a
  end
  when operation == 'STEM' then do
    stem = .stem~new('ANIMAL.')
    stem['NAME'] = 'Monty'
    stem['SPECIES'] = 'parrot'
    stem['FOOD.1'] = 'biscuit'
    stem['FOOD.2'] = 'seed'
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


/* v0.16.6: collision class kept in factory package. */
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
    "if arg() <> 2 | \arg(1,'E') | \arg(2,'E') then return PYCALL(foreignHandle, 'unknown')", -
    "messageName = arg(1)", -
    "arguments = arg(2)", -
    "if \arguments~isA(.Array) then return PYCALL(foreignHandle, 'unknown')", -
    "if wordpos(messageName~upper, bridgePythonMethods) > 0 then do", -
    "  select", -
    "    when arguments~items == 0 then return PYCALL(foreignHandle, messageName)", -
    "    otherwise raise syntax 93.900 array ('v0.16 collision POC Python projection accepts zero args here')", -
    "  end", -
    "end", -
    "/* Python declined this message: invoke the relocated original Method. */", -
    "return self~sendWith(bridgeOriginalUnknownAlias, .array~of(messageName, arguments))" -
  )
  self~setMethod("UNKNOWN", source, "OBJECT")
  return bridgeOriginalUnknownAlias



